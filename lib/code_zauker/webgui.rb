#!/usr/bin/env ruby
require 'sinatra'
# See http://www.sinatrarb.com/intro
get '/' do
  # Show the search box...
  'Hello world!'
end

get '/search/:q' do
  # Process the search and show the results...
  "Results for #{params[:q]}..."
end
