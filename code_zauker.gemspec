# -*- encoding: utf-8 ; mode: ruby; -*-
$:.push File.expand_path("../lib", __FILE__)
require "code_zauker/version"

Gem::Specification.new do |s|
  s.name        = "code_zauker"
  s.version     = CodeZauker::VERSION
  s.authors     = ["Giovanni Giorgi"]
  s.email       = ["jj@gioorgi.com"]
  s.homepage    = "http://gioorgi.com/tag/code-zauker/"
  s.summary     = %q{A search engine for programming languages}
  s.description = %q{Code Zauker is based from ideas taken by old Google Code Search and uses Redis as a basic platform}

  s.rubyforge_project = "code_zauker"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_development_dependency "yard", "~>0.7"
  s.add_development_dependency "rubyzip", "~> 0.9"

  s.add_runtime_dependency "hiredis", "~> 0.3"
  s.add_runtime_dependency "redis", "~> 2.2"
  s.add_runtime_dependency "pdf-reader", "~> 1.0.0"
  s.add_runtime_dependency "sinatra", "~> 1.3"
  # thin unable to be installed for missing g++ on my dev platform (shame on debian)
  #s.add_runtime_dependency "thin"
  ## Install and require the hiredis gem before redis-rb for maximum performances.
  #s.add_runtime_dependency "redis", "~> 2.2", :require => ["redis/connection/hiredis", "redis"]
  

end
