# -*- encoding: utf-8 -*-
# To test use 
# rake TEST=test/test_search.rb
require 'test/unit'
#require 'girl_friday'
require 'code_zauker'

# See ri Test::Unit::Assertions
# for assertion documentation
class FileScannerBasicSearch < Test::Unit::TestCase
  def test_benchmark
    require "benchmark"
    fs=CodeZauker::FileScanner.new()
    time = Benchmark.bm(7) do |x|
      x.report ("kurukku.txt") { fs.load("./test/fixture/kurukku.txt") } 
      #x.report ("BigFile") { fs.load("./test/fixture/TEST_LICENSE.txt")}
      x.report("Search common words"){ fs.search("and"); fs.search("terms")  }
    end
    puts "Bench Result..."
    puts time
  end


  def test_scanner_trigram_simple    
    fs=CodeZauker::FileScanner.new()
    fs.load("./readme.org",noReload=true)
    fs.load("./test/fixture/kurukku.txt")
    files=fs.search("kku")
    assert (files[0].include?("fixture/kurukku.txt")==true)
  end

  def test_scanner_long_word
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt")
    files=fs.search("\"Be hungry, be foolish\"")
    assert(files[0].include?("test/fixture/kurukku.txt")==true)
  end

  def test_foolish
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt")
    fs.load("./test/fixture/foolish.txt")
    # foolish is a good example because it is not multiple of 3
    files=fs.search("foolish")
    #puts "GGG #{files}"
    assert(files.include?("./test/fixture/foolish.txt") == true)
    assert(files.include?("./test/fixture/kurukku.txt") ==true)   
  end

  def test_less_then3_must_give_error
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt")    
    assert_raise RuntimeError do
      files=fs.search("di")
    end
    #assert_equal 0, files.length
  end

  def test_small4
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt")    
    # anche
    files=fs.search('anch')
    assert(files.include?("./test/fixture/kurukku.txt") ==true )
  end

  def test_very_big_file
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/TEST_LICENSE.txt",noReload=true)
    files=fs.search('"Commercial Use"')
    assert files.include?("./test/fixture/TEST_LICENSE.txt")==true
  end

  def test_remove
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt", noReload=true)  
    fs.remove(["./test/fixture/kurukku.txt"])
    files=fs.search("\"Be hungry, be foolish\"")    
    assert files.length ==0, 
    "Expected zero search results after removal from index. Found instead:#{files}"
    #assert(files[0].include?("test/fixture/kurukku.txt")==true)
  end

  # def test_removeAll
  #   require 'redis/connection/hiredis'
  #   require 'redis'
  #   redis=Redis.new
  #   fs=CodeZauker::FileScanner.new(redis)
  #   fs.load("./test/fixture/kurukku.txt", noReload=true) 
  #   fs.removeAll()
  #   foundKeys=redis.keys "*"
  #   #puts "Keys at empty db:#{foundKeys}"
  #   assert foundKeys.length==0, "Expected empty db. Found instead #{foundKeys}"
  # end

  # # 2012 Jan 30 New Case Insensitive Test cases
  def test_case_insensitive1
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt", noReload=true)
    flist=fs.isearch("caseinsensitive Search TEST.")
    assert flist.include?("./test/fixture/kurukku.txt"), "Case insensitive search failed. #{flist}"
  end

  def test_case_insensitive2
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt", noReload=true)
    flist=fs.isearch("caSeinsenSitive Search TEST.")
    assert flist.include?("./test/fixture/kurukku.txt"), "Case insensitive search failed. #{flist}"
    assert fs.search("CASeinsenSitivE").include?("./test/fixture/kurukku.txt"), "Search must be always insensitive"
  end

  def test_case_insensitive3
    fs=CodeZauker::FileScanner.new()
    fs.load("./test/fixture/kurukku.txt", noReload=true)
    u=CodeZauker::Util.new()
    (u.mixCase("CaSeinsen")).each { |t|
      #puts "Checking #{t}"
      flist=fs.isearch(t)

      assert  flist.include?("./test/fixture/kurukku.txt"), "Case insensitive search failed for input: #{t}. #{flist}  do not ocntain kurukku.txt"
    }    
  end

  ### Here follows Generic utils test...

  def test_case_mixer1
    u=CodeZauker::Util.new()
    t1=u.mixCase("a")
    puts "test_case_mixer  #{t1}"
    assert t1[0]=="a"
    assert t1[1]=="A"
    w2=u.mixCase("ab")
    puts "#{w2}"
    assert "#{w2}" == '["ab", "aB", "Ab", "AB"]', "Failed expected permutation."
    w3=u.mixCase("abc")
    puts "#{w3}"
    assert "#{w3}" == '["abc", "abC", "aBc", "aBC", "Abc", "AbC", "ABc", "ABC"]', "Failed expected permutation. Got:#{w3}"
  end

  def test_case_mixer1
    u=CodeZauker::Util.new()
    t1=u.mixCase("abcd")
    assert t1.length==16, "Expected permutation is not of the correct size (16). Got:#{t1}"
  end


  def test_zip
    require 'zip/zip'
    require 'pp'
    # /d/ISP/REPS0/extra-sources/repsSRC201201.zip
    zf=Zip::ZipFile.new("test/fixture/testArchive.zip")
    pp(zf)
    zf.each_with_index {
      |entry, index|
      # entry.get_input_stream() get a  fancy Zip::ZipInputStream
      print "#{index} -- #{entry.name} (#{entry.size} bytes):  "
      pp(entry)
      puts "------"
      # puts "'#{zis.gets.chomp}'"
      # entry = zis.get_next_entry
      # print "First line of '#{entry.name} (#{entry.size} bytes):  "
      # puts "'#{zis.gets.chomp}'"
    }
  end

  # BUG Sometimes a trailing nil is returned in the list
  # We try to push a non-existent id and get back an error
  def test_map_ids_to_file()
    fs=CodeZauker::FileScanner.new()
    assert_equal [],fs.map_ids_to_files([1234455677461])
  end

end
 
