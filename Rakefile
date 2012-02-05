# -*- coding: utf-8 ; mode: ruby; -*-
# rvm use default will save your days
require "bundler/gem_tasks"

# See http://jasonseifer.com/2010/04/06/rake-tutorial
require 'rake/testtask'
# See http://rake.rubyforge.org/classes/Rake/TestTask.html
Rake::TestTask.new do |t|
  # List of directories to added to $LOAD_PATH before running the tests. (default is ‘lib’)
  #t.libs << 'test'
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end


require 'yard'
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']   # optional
  t.options += ['--title', "Code Zauker #{CodeZauker::VERSION} Documentation"]
  #t.options = ['--any', '--extra', '--opts'] # optional
end

desc "Code Zauker default task for generating documentation, running tests and packing gem"
task :default => [ :test, :yard] do
  system('git status')
  puts "Use cz_publish to release your work, Meganiod!"
  puts "                                     Koros"
end


desc "Code Zauker Publisher"
task :cz_publish => [ :test, :yard, :build, :release] do
end
