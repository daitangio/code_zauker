#!/usr/bin/env ruby
require 'set'
require 'code_zauker'
require 'code_zauker/grep'
require 'code_zauker/cli'
require 'redis/connection/hiredis'
require 'redis'
require 'tempfile'
require 'pdf/reader'

puts "Redis Code Zauker Report"
require 'optparse'
options={}
optparse= OptionParser.new do  |opts|
  opts.banner="Usage: report [options] "

  options[:redis_host]="127.0.0.1"
  options[:redis_port]=6379
  options[:redis_password]=nil

  opts.on('-h','--redis-server pass@SERVER:port', String,
          'Specify the alternate redis server to use')do |server|
    myoptions=CodeZauker::CliUtil.new().parse_host_options(server)
    options[:redis_host]=myoptions[:redis_host]
    options[:redis_port]=myoptions[:redis_port]
    options[:redis_password]=myoptions[:redis_password]
    
    if options[:redis_password]
      puts "Server: #{options[:redis_host]} Port:#{options[:redis_port]} WithPassword"
    else
      puts "Server: #{options[:redis_host]} Port:#{options[:redis_port]}"
    end
  end
end
optparse.parse!

util=CodeZauker::CliUtil.new()
redisConnection=Redis.new(:host => options[:redis_host], :port => options[:redis_port], :password=> options[:redis_password])
util.do_report(redisConnection)

