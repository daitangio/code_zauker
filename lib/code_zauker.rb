# -*- mode:ruby ; -*- -*
require "code_zauker/version"
require 'redis/connection/hiredis'
require 'redis'
require 'set'
# This module try to implement a simple reverse indexer 
# based on redis
# The idea is ispired by http://swtch.com/~rsc/regexp/regexp4.html
module CodeZauker
  GRAM_SIZE=3
  SPACE_GUY=" "*GRAM_SIZE
  # Scan a file and push it inside redis...
  # then it can provide handy method to find file scontaining the trigram...
  class FileScanner
    def initialize()
    end
    def load(filename, noReload=false)
      # Define my redis id...
      r=Redis.new
      # Already exists?...
      fid=r.get "fscan:id:#{filename}"
      if fid==nil 
        r.setnx "fscan:nextId",0
        fid=r.incr "fscan:nextId"
        # BUG: Consider storing it at the END of the processing
        r.set "fscan:id:#{filename}", fid
        r.set "fscan:id2filename:#{fid}",filename
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
              puts " >Pushing...#{s.length}"
              s.each do | trigram |
                r.sadd "trigram:#{trigram}",fid
                r.sadd "fscan:trigramsOnFile:#{fid}", trigram
              end
              puts " <Pushed #{s.length}..."
              s=Set.new()             
            end
            trigramScanned += 1
            #puts "#{istart} Trigram fscan:#{trigram}/  FileId: #{fid}"
          end
        end
      end

      if s.length > 0
        s.each do | trigram |
          r.sadd "trigram:#{trigram}",fid
          r.sadd "fscan:trigramsOnFile:#{fid}", trigram
        end
        #puts "Final push of #{s.length}"
      end


      trigramsOnFile=r.scard "fscan:trigramsOnFile:#{fid}"
      r.sadd "fscan:processedFiles", "fscan:id:#{filename}"
      trigramRatio=( (trigramsOnFile*1.0) / trigramScanned )* 100.0
      puts "File processed. Unique Trigrams for #{filename}: #{trigramsOnFile} Total Scanned: #{trigramScanned} Ratio:#{trigramRatio}"
      r.quit
      return nil
    end

    # = search
    # Find a list of file candidates to a search string
    # The search string is padded into trigrams
    def search(term)
      #puts " ** Searching: #{term}"
      # split the term in a padded trigram      
      trigramInAnd=[]
      # Search=> Sea AND ear AND arc AND rch
      for j in 0...term.length
        currentTrigram=term[j,GRAM_SIZE]        
        if currentTrigram.length <GRAM_SIZE
          # We are at the end...
          break
        end
        trigramInAnd.push("trigram:#{currentTrigram}")
      end
      #puts "Trigam conversion /#{term}/ into #{trigramInAnd}"
      if trigramInAnd.length==0
        return []
      end
      r=Redis.new      
      fileIds=    r.sinter(*trigramInAnd)
      filenames=[]
      # fscan:id2filename:#{fid}....
      fileIds.each do | id |
        filenames.push(r.get("fscan:id2filename:#{id}")) 
      end
      r.quit
      #puts " ** Files found:#{filenames} from ids #{fileIds}"
      return filenames
    end
    
    # This function accepts a very simple search query like
    # Gio*
    # will match Giovanni, Giovedi, Giorno...
    # Giova*ni
    # will match Giovanni, Giovani, Giovannini
    def searchSimpleRegexp(termWithStar)
    end
  end
end
