# -*- mode:ruby ; -*- -*
require "code_zauker/version"
require "code_zauker/constants"
require 'redis/connection/hiredis'
require 'redis'
require 'set'
require 'zip/zip'

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
      @redis.quit
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
      if showlog
        puts " <Pushed #{s.length}..."
      end      
      puts "WARN: Some invalid UTF-8  char on #{filename} Case insensitive search will be compromised" if case_insensitive_trigram_failed      
    end

    def pushTrigramsSetRecoverable(s, fid, filename)
      error=false
      @redis.multi do
        s.each do | trigram |        
          @redis.sadd "trigram:#{trigram}",fid
          @redis.sadd "fscan:trigramsOnFile:#{fid}", trigram
          # Add the case-insensitive-trigram
          begin
            @redis.sadd "trigram:ci:#{trigram.downcase}",fid
          rescue ArgumentError 
            error=true          
          end
        end
      end # multi
      return error
    end
    private :pushTrigramsSetRecoverable


    # = Utility function to read lines into memory
    # We avoid a huge roundtrip to redis, and store the trigram on a memory-based set
    # before sending it to redis. This avoid
    # a lot of spourios work
    def loadLines(lines,fid,filename)
      trigramScanned=0
      s=Set.new
      adaptiveSize= TRIGRAM_DEFAULT_PUSH_SIZE
      util=Util.new()
      lines.each do  |lineNotUTF8|
        l= util.ensureUTF8(lineNotUTF8)
        # Split each line into 3-char chunks, and store in a redis set
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
          #puts "#{istart} Trigram fscan:#{trigram}/  FileId: #{fid}"
        end
      end
      if s.length > 0
        pushTrigramsSet(s,fid,filename)
        s=nil
        #puts "Final push of #{s.length}"
      end
      @redis.sadd "fscan:processedFiles", "#{filename}"
      return trigramScanned
    end

    # Allocate a new file entry
    # Also ensure a special hash for zip files
    # 
    def build_id(filename)
      @redis.setnx "fscan:nextId",0
      fid=@redis.incr "fscan:nextId"
      # BUG: Consider storing it at the END of the processing
      @redis.set "fscan:id:#{filename}", fid
      @redis.set "fscan:id2filename:#{fid}",filename
      # Build a hash set used for storing data...
      @redis.hmset "fscan:prop:#{filename}","created",Time.now.to_s()
      return fid
    end

    def loadZip(filename,noReload=false)
      # Explode the zip and process it one by one...
      archive=Zip::ZipFile.new(filename)
      @redis.hset "fscan:prop:#{filename}", "is_zip",true
      
      archive.each_with_index {
        |entry, index|
        if entry.file?()
          virtual_name="zip://"+filename+"/"+entry.name()
          vid=@redis.get "fscan:id:#{virtual_name}"
          if vid==nil 
            vid=build_id(filename)
          else
            # At the moment it is an error...
            # if you request a reload...
            if noReload==false
              raise " Already found... #{virtual_name} as ID= #{vid}"
            else             
              return nil
            end
          end
          puts " * #{virtual_name}"
          @redis.append "fscan:zip:#{filename}",entry.name()
          lines=entry.get_input_stream().readlines()
          trigramScanned=loadLines(lines,vid,filename)
          puts "#{virtual_name}\n\tTrigrams:#{trigramScanned}"            
        end
      }
    end

    def loadPlainFile(filename,noReload=false)
      # Define my redis id...      
      # Already exists?...
      fid=@redis.get "fscan:id:#{filename}"
      if fid==nil 
        fid=build_id(filename)
      else
        if noReload 
          #puts "Already found #{filename} as id:#{fid} and NOT RELOADED"
          return nil
        end
      end      
      # fid is the set key!...
      trigramScanned=0
      File.open(filename,"r") { |f|
        lines=f.readlines()        
        trigramScanned=loadLines(lines,fid,filename)
        
      }

      trigramsOnFile=@redis.scard "fscan:trigramsOnFile:#{fid}"        
      trigramRatio=( (trigramsOnFile*1.0) / trigramScanned )* 100.0
      if trigramRatio < 10 or trigramRatio >75        
        puts "#{filename}\n\tRatio:#{trigramRatio.round}%  Unique Trigrams:#{trigramsOnFile} Total Scanned: #{trigramScanned} ?Binary" if trigramRatio >90 and trigramsOnFile>70
      end

    end


    def load(filename, noReload=false)
      is_zip=false
      SUPPORTED_ARCHIVES.each do  | archiveExtension |
        if filename.end_with?(archiveExtension)
          is_zip=true
          break
        end
      end
      if is_zip==false 
        loadPlainFile(filename,noReload)
      else
        loadZip(filename,noReload)
      end
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
      termLowercase=term.downcase()
      trigramInAnd=split_in_trigrams(termLowercase,"trigram:ci")
      if trigramInAnd.length==0
        return []
      end      
      fileIds=    @redis.sinter(*trigramInAnd)
      return map_ids_to_files(fileIds)      
    end


    # = search
    # Find a list of file candidates to a search string
    # The search string is padded into trigrams    
    def search(term)
      if term.length < GRAM_SIZE
        raise "FATAL: #{term} is shorter then the minimum size of #{GRAM_SIZE} character"
      end
      #puts " ** Searching: #{term}"
      trigramInAnd=split_in_trigrams(term,"trigram")
      #puts "Trigam conversion /#{term}/ into #{trigramInAnd}"
      if trigramInAnd.length==0
        return []
      end      
      fileIds=    @redis.sinter(*trigramInAnd)
      fileNames=map_ids_to_files(fileIds)
      #puts "DEBUG #{fileIds} #{fileNames}"
      return fileNames
    end

    def reindex(fileList)
      #puts "Reindexing... #{fileList.length} files..."
      fileList.each do |current_file |
        self.remove([current_file])        
        self.load(current_file,noReload=false)
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
          @redis.srem "trigram:#{ts}", fid
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
        @redis.del  "fscan:prop:#{filename}"
        @redis.srem "fscan:processedFiles",  filename
      end
      return nil
    end

    private :pushTrigramsSet
    private :split_in_trigrams
    #private :map_ids_to_files


  end
end
