module CodeZauker

  class CliUtil
    
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
  end
end
