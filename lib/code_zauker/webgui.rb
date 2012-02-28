#!/usr/bin/env ruby
require 'sinatra'
require "code_zauker/version"
require "code_zauker"
require "erb"

# See http://www.sinatrarb.com/intro
get '/' do
  # Show the search box...
  erb :search
end

get '/search' do
  # Process the search and show the results...
  fs=CodeZauker::FileScanner.new()
  files=fs.isearch(params[:q])
  erb :show_results, :locals => {:files => files, :q => params[:q] }
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
