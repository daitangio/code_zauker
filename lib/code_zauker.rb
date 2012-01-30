# -*- mode:ruby ; -*- -*
require "code_zauker/version"
require "code_zauker/constants"
require 'redis/connection/hiredis'
require 'redis'
require 'set'
# This module implements a simple reverse indexer 
# based on Redis
# The idea is ispired by http://swtch.com/~rsc/regexp/regexp4.html
module CodeZauker
  GRAM_SIZE=3
  SPACE_GUY=" "*GRAM_SIZE
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
      error=false
      if s.length > 5000
        puts " >Pushing...#{s.length} for id #{fid}=#{filename}"
      end
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
      if s.length > 5000
        puts " <Pushed #{s.length}..."
        puts "WARN: Some invalid UTF-8  char on #{filename} Case insensitive search will be compromised" if error
      end
    end


    def load(filename, noReload=false)
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
        if noReload 
          puts "Already found #{filename} as id:#{fid} and NOT RELOADED"
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
      File.open(filename,"r") do |f|
        lines=f.readlines()        
        adaptiveSize= 6000
        lines.each do  |l|
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
        puts "#{filename}\n\tRatio:#{trigramRatio.round}%  Unique Trigrams:#{trigramsOnFile} Total Scanned: #{trigramScanned} "      
      end
      return nil
    end

    def split_in_trigrams(term, prefix)
      trigramInAnd=[]
      # Search=> Sea AND ear AND arc AND rch
      for j in 0...term.length
        currentTrigram=term[j,GRAM_SIZE]        
        if currentTrigram.length <GRAM_SIZE
          # We are at the end...
          break
        end
        trigramInAnd.push("#{prefix}:#{currentTrigram}")
      end
      return trigramInAnd
    end

    def map_ids_to_files(fileIds)
      filenames=[]
      # fscan:id2filename:#{fid}....
      fileIds.each do | id |
        filenames.push(@redis.get("fscan:id2filename:#{id}")) 
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
      trigramInAnd=self.split_in_trigrams(termLowercase,"trigram:ci")
      if trigramInAnd.length==0
        return []
      end      
      fileIds=    @redis.sinter(*trigramInAnd)
      return self.map_ids_to_files(fileIds)      
    end


    # = search
    # Find a list of file candidates to a search string
    # The search string is padded into trigrams
    def search(term)
      if term.length < GRAM_SIZE
        raise "FATAL: #{term} is shorter then the minimum size of #{GRAM_SIZE} character"
      end
      #puts " ** Searching: #{term}"
      trigramInAnd=self.split_in_trigrams(term,"trigram")
      #puts "Trigam conversion /#{term}/ into #{trigramInAnd}"
      if trigramInAnd.length==0
        return []
      end      
      fileIds=    @redis.sinter(*trigramInAnd)
      return self.map_ids_to_files(fileIds)
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
      self.remove(nil)
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
        
        @redis.del "fscan:id:#{filename}", "fscan:trigramsOnFile:#{fid}", "fscan:id2filename:#{fid}"
        @redis.srem "fscan:processedFiles",  filename
      end
      return nil
    end

    private :pushTrigramsSet
    #private :split_in_trigrams
    #private :map_ids_to_files


  end
end
