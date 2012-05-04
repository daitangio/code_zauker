#!/usr/bin/env ruby
require 'sinatra'
require "code_zauker/version"
require "code_zauker"
require "erb"
require 'code_zauker/grep'
include Grep

# See http://www.sinatrarb.com/intro
get '/' do
  # Show the search box...
  erb :search
end

get '/search' do
  # Process the search and show the results...
  fs=CodeZauker::FileScanner.new()
  files=fs.isearch(params[:q])
  util=CodeZauker::Util.new()
  abstracts=[]
  files.each do |f|
    if util.is_pdf?(f)==false
      askedQuery=params[:q]
      pattern=/#{Regexp.escape(askedQuery)}/i
      lines=grep(f,pattern, pre_context=2, post_context=2);
      desc=""
      lines.each do |l |
        hilighted=l.gsub(/(#{Regexp.escape(askedQuery)})/i){ "<b>#{$1}</b>"}
        desc=desc+ "#{f}:#{hilighted}\n"
      end
      abstracts.push(desc)
    end
  end
  erb :show_results, :locals => {:files => abstracts, :q => params[:q] }
end

configure do
  staticDir=File.dirname(__FILE__)+ '/../../htdocs'
  templateDir=settings.root + '/../../templates'
  puts "Static files: #{staticDir}"
  puts "Templates: #{templateDir}"
  set :public_folder, staticDir
  set :views, templateDir

end

# INLINE Template Follows: unused at the moment
__END__

@@ indexUnused
<html>
<head>
<title> CodeZauker v<%= CodeZauker::VERSION %> </title>
</head>
<body>
  <div align="left" style="background:url(/CodeZauker.gif) no-repeat; width:489; height:110;" title="CodeZauker">
  Code Zauker
  </div>  
  <form method="get" action="/search">
   <input type="text" name="q" />
  </form>
</body>

</html>
