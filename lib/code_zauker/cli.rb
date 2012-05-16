module CodeZauker

  class CliUtil

    def doWildSearch(term,fileScanner)
      fileGroup=fileScanner.wsearch(term)
      # Make a simple regexp from the wild stuff...
      finalRegexp=""
      term.split("*").each do |term|
        finalRegexp= finalRegexp+Regexp.escape(term)+".*"
      end
      return {
        :regexp=>finalRegexp,
        :files => fileGroup
      }
      
    end

    def parse_host_options(connection_string)
      #puts "Parsing... #{connection_string}"
      options={}
      options[:redis_host]="127.0.0.1"
      options[:redis_port]=6379
      options[:redis_password]=nil
      r=/(\w+)@([a-zA-Z0-9.]+):([0-9]+)?/
      rNoPass=/([a-zA-Z0-9.]+):([0-9]+)?/
      rHostAndPass=/(\w+)@([a-zA-Z0-9.]+)/
      m=r.match(connection_string)    
      if m                   
        options[:redis_password]=m.captures[0]
        options[:redis_host]=m.captures[1]      
        options[:redis_port]=m.captures[2]
        
      else
        m=rNoPass.match(connection_string)
        if m        
          options[:redis_host]=m.captures[0]      
          options[:redis_port]=m.captures[1]
        else
          # Check the auth@host case right here
          m2=rHostAndPass.match(connection_string)
          if m2
            options[:redis_password]=m2.captures[0]
            options[:redis_host]=m2.captures[1]
          else
            #puts "SERVER ONLY"
            options[:redis_host]=connection_string
          end
        end
      end
      return options
    end

    def do_report(redis)
      puts "Simple Reporting....on #{redis.client.host}"
      id2filename=redis.keys "fscan:id2filename:*"
      puts "File Stored:\t\t#{id2filename.length}"
      processedFiles=redis.scard("fscan:processedFiles")
      puts "Processed Files:\t#{processedFiles}"
      # Complex... compute average "fscan:trigramsOnFile:#{fid}"
      sum=0.0
      max=0
      min=90000000000000000
      fileName2Ids=redis.keys "fscan:id:*"
      count=fileName2Ids.length+0.0
      puts "Finding ids..."   
      ids=redis.mget(*(redis.keys("fscan:id:*")))
      puts "Scanning ids..."      
      ids.each do | fid |
        # Forma fscan:trigramsOnFile:5503
        trigramsOnFile=redis.scard("fscan:trigramsOnFile:#{fid}")
        sum = sum + trigramsOnFile
        # if trigramsOnFile == 0 or trigramsOnFile >=max
        #   fname=redis.get("fscan:id2filename:#{fid}")
        #   puts "Note fscan:trigramsOnFile:#{fid} -> #{trigramsOnFile} #{fname}"
        # end
        max=trigramsOnFile if trigramsOnFile >max
        min=trigramsOnFile if trigramsOnFile <min and trigramsOnFile>0        
      end
      av=sum/count
      puts "Average Trigrams per file:#{av} Min: #{min} Max: #{max}"
      tagCharSize=max/80
      #tagCharSize=max/10 if tagCharSize>80
      puts "Graphic summary... +=#{tagCharSize}"
      ids.each do | fid |
        trigramsOnFile=redis.scard("fscan:trigramsOnFile:#{fid}")
        if trigramsOnFile>= (tagCharSize*3)
          fname=redis.get("fscan:id2filename:#{fid}")
          bar="+"*(trigramsOnFile/tagCharSize)
          puts "#{bar} #{fname}"
        end
      end

    end
  end
end
