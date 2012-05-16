# -*- encoding: utf-8 -*-
# To test use 
# rake TEST=test/test_wild_search.rb
require 'test/unit'
require 'code_zauker'

# See ri Test::Unit::Assertions
# for assertion documentation
class FileScannerBasicSearch < Test::Unit::TestCase
  #This test can search very uinque things...
  def test_foolish_wild1
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/wildtest.txt")
    files=fs.wsearch("Wild*West")
    assert(files.include?("./test/fixture/wildtest.txt")== true, 
           "Expected file not found. Files found:#{files}")
    
  end

  def test_foolish_wild2
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/wildtest.txt")
    files=fs.wsearch("Wild*West*Movie")
    assert(files.include?("./test/fixture/wildtest.txt")== true, 
           "Expected file not found. Files found:#{files}")    
  end

  # Also unordered match will work
  # So the negative match is difficult
  def test_foolish_wild3
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/wildtest.txt")
    files=fs.wsearch("West*Wild*NotOnTheSameLineForSure")
    assert(files.include?("./test/fixture/wildtest.txt")== false, 
           "Expected not matching wildtest.txt file. Matches:#{files}")    
  end


end
