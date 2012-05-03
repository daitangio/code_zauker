module CodeZauker

  class CliUtil
    def parse_host_options(server)
      options={}
      options[:redis_host]="127.0.0.1"
      options[:redis_port]=6379
      options[:redis_password]=nil
      r=/(\w+)@([a-zA-Z0-9]+):([0-9]+)?/
      rNoPass=/([a-zA-Z0-9]+):([0-9]+)?/
      m=r.match(server)    
      if m                   
        options[:redis_password]=m.captures[0]
        options[:redis_host]=m.captures[1]      
        options[:redis_port]=m.captures[2]
        
      else
        m=rNoPass.match(server)
        if m        
          options[:redis_host]=m.captures[0]      
          options[:redis_port]=m.captures[1]
        else
           #puts "SERVER ONLY"
          options[:redis_host]=server
        end
      end
      return options
    end
  end
end
