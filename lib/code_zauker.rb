# -*- mode:ruby ; -*- -*
require "code_zauker/version"
require "code_zauker/constants"
require 'code_zauker/grep'
# require 'redis/connection/hiredis'
require 'redis'
require 'set'
require 'pdf/reader'
require 'date'

#require 'digest'
require 'digest/md5'

# This module implements a simple reverse indexer 
# based on Redis
# The idea is ispired by http://swtch.com/~rsc/regexp/regexp4.html
module CodeZauker
  GRAM_SIZE=3
  SPACE_GUY=" "*GRAM_SIZE

  # = Basic utility class
  class Util
    # Compute all the possible case-mixed trigrams
    # It works for every string size
    # TODO: Very bad implementation, need improvements
    def mixCase(trigram) 
      caseMixedElements=[]
      lx=trigram.length
      combos=2**lx
      startString=trigram.downcase
      #puts "Combos... 1..#{combos}... #{startString}"
      for c in 0..(combos-1) do
        # Make binary
        maskForStuff=c.to_s(2)
        p=0
        #puts maskForStuff
        currentMix=""
        # Pad it
        if maskForStuff.length < lx
          maskForStuff = ("0"*(lx-maskForStuff.length)) +maskForStuff
        end        
        maskForStuff.each_char { | x |          
          #putc x
          if x=="1"
            currentMix +=startString[p].upcase
          else
            currentMix +=startString[p].downcase
          end
          #puts currentMix
          p+=1
        }        
        caseMixedElements.push(currentMix)
      end
      return caseMixedElements
    end

    # = Ensure Data are correctly imported
    # http://blog.grayproductions.net/articles/ruby_19s_string
    # This code try to "guess" the right encoding
    # switching to ISO-8859-1 if UTF-8 is not valid.
    # Tipical use case: an italian source code wronlgy interpreted as a UTF-8 
    # whereas it is a ISO-8859 windows code.
    def ensureUTF8(untrusted_string)
      if untrusted_string.valid_encoding?()==false 
        #puts "DEBUG Trouble on #{untrusted_string}"
        untrusted_string.force_encoding("ISO-8859-1")        
        # We try ISO-8859-1 tipical windows 
        begin
          valid_string=untrusted_string.encode("UTF-8", { :undef =>:replace, :invalid => :replace} )           
        rescue Encoding::InvalidByteSequenceError => e   
          raise e
        end
        # if valid_string != untrusted_string
        #   puts "CONVERTED #{valid_string} Works?#{valid_string.valid_encoding?}"
        # end
        return valid_string
      else
        return untrusted_string
      end
    end

    def is_pdf?(filename)
      return filename.downcase().end_with?(".pdf")
    end

    # Obtain lines from a filename
    # It works even with pdf files
    def get_lines(filename)
      lines=[]
      if self.is_pdf?(filename)
        # => enable pdf processing....
        #puts "PDF..."
        File.open(filename, "rb") do |io|
          reader = PDF::Reader.new(io)
          #puts "PDF Scanning...#{reader.info}"
          reader.pages.each do |page|
            linesToTrim=page.text.split("\n")
            linesToTrim.each do |l|
              lines.push(l.strip())
            end
          end
          #puts "PDF Lines:#{lines.length}"
        end
      else
        File.open(filename,"r") { |f|
          lines=f.readlines()        
        }
      end
      return lines
    end
  end

  # Manage the index and keep it well organized
  class IndexManager
    def initialize(redisConnection=nil)
      if redisConnection==nil
        @redis=Redis.new
      else
        @redis=redisConnection
      end
    end    
    
    def check_repair
      
      puts "Staring index check"
      dbversion=@redis.hget("codezauker","db_version")
      if dbversion==nil
        puts "DB Version <=0.7"
        @redis.hset("codezauker","db_version",CodeZauker::DB_VERSION)
        # no other checks to do right now
      else
        if dbversion.to_i() > CodeZauker::DB_VERSION
          raise "DB Version #{dbversion} is greater than my #{CodeZauker::DB_VERSION}"
        else
          puts "Migrating from #{dbversion} to #{CodeZauker::DB_VERSION}"
          # Nothing to do right now
        end
      end
      puts "Summary....."
      dbversion=@redis.hget("codezauker","db_version")
      last_check=@redis.hget("codezauker","last_check")
      puts "DB Version: #{dbversion}"
      puts "Last Check: #{last_check}"
      puts "Checking...."
      @redis.hset("codezauker","last_check",DateTime.now().to_s())      
      puts "Issuing save..."
      @redis.save()
      puts "Save successful"
      @redis.quit()
      puts "Disconnected from redis"
    end
  end

  # Scan a file and push it inside redis...
  # then it can provide handy method to find file scontaining the trigram...
  class FileScanner
    def initialize(redisConnection=nil)
      if redisConnection==nil
        @redis=Redis.new
      else
        @redis=redisConnection
      end
    end

    
    def disconnect()    
      begin
        @redis.quit
      rescue Errno::EAGAIN =>e
        # Nothing to do...
        puts "Ignored EAGAIN ERROR during disconnect..."
      end
    end


   


    def pushTrigramsSet(s, fid, filename)
      case_insensitive_trigram_failed=false
      showlog=false
      if s.length > (TRIGRAM_DEFAULT_PUSH_SIZE/2)
        puts " >Pushing...#{s.length} for id #{fid}=#{filename}"
        showlog=true
      end
      # Ask for a protected transaction
      # Sometimes can fail...
      welldone=false
      tryCounter=0
      while welldone == false do
        begin
          tryCounter +=1
          case_insensitive_trigram_failed=pushTrigramsSetRecoverable(s,fid,filename)          
          welldone=true
        rescue Errno::EAGAIN =>ea
          if tryCounter >=MAX_PUSH_TRIGRAM_RETRIES
            puts "FATAL: Too many Errno::EAGAIN Errors"
            raise ea
          else
            puts "Trouble storing #{s.length} data. Retrying..." 
            welldone=false
          end
        end
      end
      # if showlog
      #   puts " <Pushed #{s.length}..."
      # end      
      puts "WARN: Some invalid UTF-8  char on #{filename} Case insensitive search will be compromised" if case_insensitive_trigram_failed      
    end

    def pushTrigramsSetRecoverable(s, fid, filename)
      error=false
      # @redis.multi do
      # From 5.8 
      # to   7.6 Files per sec
      # changing multi into pipielined
      @redis.pipelined do 
        s.each do | trigram |        
          begin
            @redis.sadd "trigram:ci:#{trigram.downcase}",fid
            @redis.sadd "fscan:trigramsOnFile:#{fid}", trigram
          rescue ArgumentError 
            error=true          
          end
        end
      end # multi/pipelined
      return error
    end
    private :pushTrigramsSetRecoverable


    def load(filename)
      # Define my redis id...      
      # Already exists?...
      fid=@redis.get "fscan:id:#{filename}"
      if fid==nil 
        @redis.setnx "fscan:nextId",0
        fid=@redis.incr "fscan:nextId"
        # BUG: Consider storing it at the END of the processing
        @redis.set "fscan:id:#{filename}", fid
        @redis.set "fscan:id2filename:#{fid}",filename
      else
        # ADD MD5 Checksum
        #Digest::MD5.hexdigest("aaa")
        fileDigest = Digest::MD5.hexdigest(File.read(filename))
        storedDigest=@redis.get("cz:md5:#{filename}")
        if(fileDigest!=storedDigest)
          puts "#{filename} CHANGED...MD5: #{fileDigest} REINDEXING..."
          self.remove([filename]) 
        else          
          ## puts "#{filename} id:#{fid} MD% UP TO DATE and NOT RELOADED"
          return nil
        end

      end      
      # fid is the set key!...
      trigramScanned=0
      # TEST_LICENSE.txt: 3290 Total Scanned: 24628
      # The ratio is below 13% of total trigrams are unique for very big files
      # So we avoid a huge roundtrip to redis, and store the trigram on a memory-based set
      # before sending it to redis. This avoid
      # a lot of spourios work      
      s=Set.new
      util=Util.new()
      lines=util.get_lines(filename)
      adaptiveSize= TRIGRAM_DEFAULT_PUSH_SIZE

      lines.each do  |lineNotUTF8|
        l= util.ensureUTF8(lineNotUTF8)
        # Split each line into GRAM_SIZE-char chunks, and store in a redis set
        i=0
        for istart in 0...(l.length-GRAM_SIZE) 
          trigram = l[istart, GRAM_SIZE]
          # Avoid storing the 3space guy enterely
          if trigram==SPACE_GUY
            next
          end
          # push the trigram to redis (highly optimized)
          s.add(trigram)
          if s.length > adaptiveSize
            pushTrigramsSet(s,fid,filename)
            s=Set.new()             
          end
          trigramScanned += 1
          #puts "#{istart} Gram fscan:#{trigram}/  FileId: #{fid}"
        end
      end
      

      if s.length > 0
        pushTrigramsSet(s,fid,filename)
        s=nil
        #puts "Final push of #{s.length}"
      end


      trigramsOnFile=@redis.scard "fscan:trigramsOnFile:#{fid}"
      @redis.sadd "fscan:processedFiles", "#{filename}"
      trigramRatio=( (trigramsOnFile*1.0) / trigramScanned )* 100.0
      if trigramRatio < 10 or trigramRatio >75        
        puts "#{filename}\n\tRatio:#{trigramRatio.round}%  Unique #{GRAM_SIZE}-grams:#{trigramsOnFile} Total Scanned: #{trigramScanned} ?Binary" if trigramRatio >90 and trigramsOnFile>70
      end

      # Register digest...do at last for better security
      fileDigest = Digest::MD5.hexdigest(File.read(filename))
      @redis.set("cz:md5:#{filename}",fileDigest)

      return nil
    end

    def split_in_trigrams(term, prefix)
      trigramInAnd=Set.new()
      # Search=> Sea AND ear AND arc AND rch
      for j in 0...term.length
        currentTrigram=term[j,GRAM_SIZE]
        if currentTrigram.length <GRAM_SIZE
          # We are at the end...
          break
        end
        trigramInAnd.add("#{prefix}:#{currentTrigram}")
      end
      return trigramInAnd
    end

    def map_ids_to_files(fileIds)
      filenames=[]
      # fscan:id2filename:#{fid}....
      fileIds.each do | id |
        file_name=@redis.get("fscan:id2filename:#{id}")
        filenames.push(file_name)  if !file_name.nil?
      end      
      #puts " ** Files found:#{filenames} from ids #{fileIds}"
      return filenames
    end

    


    # = Do a case-insenitive search    
    # using the special set of trigrams 
    # "trigram:ci:*"
    # all downcase
    def isearch(term)
      if term.length < GRAM_SIZE
        raise "FATAL: #{term} is shorter then the minimum size of #{GRAM_SIZE} character"
      end      
      termLowercase=term.downcase()
      trigramInAnd=split_in_trigrams(termLowercase,"trigram:ci")
      if trigramInAnd.length==0
        return []
      end      
      fileIds=    @redis.sinter(*trigramInAnd)
      return map_ids_to_files(fileIds)      
    end

    # = wild cards search
    # You can search trigram in the form
    # public*class*Apple
    # will match java declaration of MyApple  but not
    # YourAppManager
    def wsearch(term)
      # Split stuff
      #puts "Wild Search request:#{term}"
      m=term.split("*")
      if m.length>0
        trigramInAnd=Set.new()
        #puts "*= Found:#{m.length}"
        m.each do | wtc |
          wt=wtc.downcase()
          #puts "Splitting  #{wt}"
          trigSet=split_in_trigrams(wt,"trigram:ci")
          trigramInAnd=trigramInAnd.merge(trigSet)
        end
        # puts "Trigrams: #{trigramInAnd.length}"
        # trigramInAnd.each do | x |
        #   puts "#{x}"
        # end
        if trigramInAnd.length==0
          return []
        end      
        fileIds=@redis.sinter(*trigramInAnd)
        fileNames=map_ids_to_files(fileIds)
        #puts "DEBUG #{fileIds} #{fileNames}"
        return fileNames     
      else
        puts "Warn no Wild!"
        return search(term)
      end
    end


    # = search
    # Find a list of file candidates to a search string
    # The search string is padded into trigrams    
    # Starting from 0.0.9 is case insensitive and
    # equal to isearch
    def search(term)
      return self.isearch(term)
    end

    def reindex(fileList)
      #puts "Reindexing... #{fileList.length} files..."
      fileList.each do |current_file |
        self.remove([current_file])        
        self.load(current_file)
      end
    end

    # Remove all the keys
    def removeAll()
      tokill=[]
      tokill=@redis.keys("fscan:*")
      tokill.push(*(@redis.keys("trigram*")))      
      tokill.each do | x |
        @redis.del x
        #puts "Deleted #x"
      end
      @redis.del "fscan:processedFiles"
    end

    # Remove the files from the index, updating trigrams
    def remove(filePaths=nil)
      if filePaths==nil
        fileList=[]
        storedFiles=@redis.keys "fscan:id:*"
        storedFiles.each do |fileKey|
          filename=fileKey.split("fscan:id:")[1]
          fileList.push(filename)
        end
      else
        fileList=filePaths
      end
      # puts "Files to remove from index...#{fileList.length}"      
      fileList.each do |filename|
        fid=@redis.get "fscan:id:#{filename}"
        trigramsToExpurge=@redis.smembers "fscan:trigramsOnFile:#{fid}"
        if trigramsToExpurge.length==0
          puts "?Nothing to do on #{filename}"
        end
        puts "#{filename} id=#{fid} Trigrams: #{trigramsToExpurge.length} Expurging..."        
        trigramsToExpurge.each do | ts |          
          begin
            @redis.srem "trigram:ci:#{ts.downcase}",fid
            #putc "."
          rescue ArgumentError
            # Ignore  "ArgumentError: invalid byte sequence in UTF-8"
            # and proceed...
          end
        end
        #putc "\n"
        
        @redis.del  "fscan:id:#{filename}", "fscan:trigramsOnFile:#{fid}", "fscan:id2filename:#{fid}"
        @redis.srem "fscan:processedFiles",  filename
      end
      return nil
    end

    private :pushTrigramsSet
    private :split_in_trigrams
    #private :map_ids_to_files


  end
end
