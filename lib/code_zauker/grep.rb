# GG Customized to suite Code Zauker needs
# Refer to https://rubygems.org/gems/grep
# for the original gem/code
# Skeleton module for the 'grep' routine.
#
# Ideally, one would do this in their code to import the "grep" call
# directly into their current namespace:
#
#     require 'grep'
#     include Grep
#     # do something with grep()
#
#
# It is recommended that you look at the documentation for the grep()
# call directly for specific usage.
#
#--
#
# The compilation of software known as grep.rb is distributed under the
# following terms:
# Copyright (C) 2005-2006 Erik Hollensbe. All rights reserved.
#
# Redistribution and use in source form, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
#++

require 'code_zauker'
module Grep

  #
  # Grep works like a shell grep. `file' can be either a string,
  # containing the name of a file to load and handle, or an IO object
  # (such as $stdin) to deal with. `pattern' can be either a string or
  # Regexp object which contains a pattern. Patterns as strings treat
  # no part of the string as `special', such as '.' or '?' in a
  # regex. `pre_context' and `post_context' determine the amount of
  # lines to return that came before or after the content that was
  # matched, respectively. If there are overlaps in the context, no
  # duplicates will be printed.
  #

  def grep(file, pattern, pre_context=0, post_context=0, print_filename=true)
    currentline=0
    if file.kind_of? String
      fileName=file
      file = File.new(file, "r")
    else
      fileName=""
    end

    if ! file.kind_of? IO
      throw IOError.new("File must be the name of an existing file or IO object")
    end

    if pattern.kind_of? String
      pattern = /#{Regexp.escape(pattern)}/
    end

    if ! pattern.kind_of? Regexp
      throw StandardError.new("Pattern must be string or regexp")
    end

    cache = []
    lines = []

    util=CodeZauker::Util.new()

    loop do
      begin
        line = util.ensureUTF8(file.readline)
        
        currentline +=1
        cache.shift unless cache.length < pre_context

        cache.push("#{currentline}:#{line}")
        
        if line =~ pattern
          lines += cache
          cache = []
          if post_context > 0
            post_context.times do
              begin                
                utf8line=util.ensureUTF8(file.readline)
                lines.push("#{currentline}:#{utf8line}")                
                currentline +=1
              rescue IOError => e
                break
              end
            end
          end
        end
      rescue IOError => e
        break
      rescue ArgumentError =>e2
        # Rethrow a probably UTF-8 fatal error
        puts "Pattern Matching failed on \n\t#{fileName}\n\tLine:#{line}"
        puts "Encoding of line:#{line.encoding.name} Valid? #{line.valid_encoding?}"
        #raise e2
      end
    end
    

    file.each_line do |untrustedLine|
      cache.shift unless cache.length < pre_context
      line=util.ensureUTF8(untrustedLine)
      cache.push(line)

      if line =~ pattern
        lines += cache
        if post_context > 0
          post_context.times do
            begin
              utf8line=util.ensureUTF8(file.readline)
              lines.push("#{currentline}:#{utf8line}")  
              currentline +=1
            rescue Exception => e
              break
            end
          end
        end
      end
    end

    return lines
  end
end
