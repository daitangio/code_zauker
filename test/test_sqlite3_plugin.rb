# -*- encoding: utf-8 -*-
require 'test/unit'
require 'code_zauker'
require "code_zauker/sqlite3_plugin"

# Setup one-for all...
testdb="/tmp/code-zauker-test-db.sqlite3"
if File.exists?(testdb)
  File.unlink(testdb)
end
$plugin=CodeZauker::SQLite3Store.new(testdb)
$plugin.init_db
$plugin.connect

class Sqlite3PluginBasicApiTest < Test::Unit::TestCase
  def test_sadd
    $plugin.sadd "key","v1"
    elems=$plugin.smembers "key"
    assert elems[0]=="v1", "Simple sadd do not work"
  end

  def test_sadd_duplicates_no_error
    $plugin.sadd "keydup","v1"
    $plugin.sadd "keydup","v1"
    assert ($plugin.smembers "keydup").length == 1, "when inserting one duplicate key, we expect only one insert"
  end

  def test_srem
    $plugin.sadd "keyrem","v1"
    $plugin.sadd "keyrem","v2"
    $plugin.srem "keyrem","v1"
    elems=$plugin.smembers "keyrem"
    assert elems[0]=="v2", "Removal do not work"
  end
  def test_sinter
    $plugin.sadd "key1","a"
    $plugin.sadd "key1","b"
    $plugin.sadd "key1","c"
    $plugin.sadd "key2","c"
    cExpected=$plugin.sinter "key1","key2"
    assert cExpected[0]=="c" and cExpected.length==1
  end

  def test_scard
    $plugin.sadd "keyscard","a"
    $plugin.sadd "keyscard","b"
    $plugin.sadd "keyscard","c"
    scardz=  $plugin.scard("keyscard")
    assert scardz==3, "expected size three, returned instead: #{scardz}"
  end

  def test_smembers1
    assert $plugin.smembers("notesistent").length==0
  end


  def test_smembers2
    $plugin.sadd "smembers2k1","a"
    s=$plugin.smembers("smembers2k1").length
    assert s==1, "Expected one result, got #{s}"
  end


  def test_set_get1
    $plugin.set("test_set","a")
    r=$plugin.get("test_set")
    assert r=="a", "Expected 'a' got:#{r}"
  end

  def test_get_non_existent    
    r=$plugin.get("sarchiapone")
    assert r==nil, "Expected nil for not-existent key got:#{r}"
  end

  def test_del_simple    
    $plugin.set("testx","b")
    $plugin.del("testx")
    r=$plugin.get("testx")
    assert r==nil,  "del is not working. Key was not deleted"
  end

  def test_del_set    
    $plugin.sadd("test_set","b")
    $plugin.del("test_set")
    r=$plugin.get("test_set")
    assert r==nil,  "del is not working on set(s). Key was not deleted"
  end

  def test_keys1
    $plugin.sadd("test_keys1_set","a")
    $plugin.set("test_keys2","b")
    keys=$plugin.keys("test_keys2")
    assert keys.length==1, "Expected one key. Returned keys:#{keys}"
  end

  def test_keys_star
    $plugin.sadd("test_keys1_set","a")
    $plugin.set("test_keys2","b")
    keys=$plugin.keys("test_keys*")
    assert keys.length==2, "Pattern matching with * do not works! Expected two keys.  Returned keys:#{keys}"
  end


  def test_keys_and_del
    keysBefore=$plugin.keys("*")
    $plugin.set("keys_and_del1","test")
    $plugin.sadd("keys_and_del2","test")
    keysAfter=$plugin.keys("*")
    diff=keysAfter.length-keysBefore.length
    assert diff==2, "Not all keys returned: #{keysAfter.length} keys but two more expected (exactly two)"
  end

  def test_add_bad_stuff1
    $plugin.sadd("trigram:'aa","V")
    v=$plugin.smembers("trigram:'aa")
    assert v[0]=="V", " sadd must support very weird string. Got: #{v}"
  end

  def test_add_bad_stuff2
    veryBadKey="trigram:'èé'';\"*?£$%&'%&£"
    $plugin.sadd(veryBadKey,"V2")
    v=$plugin.smembers(veryBadKey)
    assert v[0]=="V2", " sadd must support very weird string. Got: #{v}"
  end


  def test_setnx1
    $plugin.del("nx")
    $plugin.setnx("nx","b")
    v=$plugin.get("nx")
    assert v=="b", "Set Nx does not set"
  end


  def test_setnx2
    $plugin.set("a","b")
    $plugin.setnx("a","c")
    v=$plugin.get("a")
    assert v=="b"
  end


  def test_pipelined
    $plugin.pipelined do 
      $plugin.set("a","?")
      v=$plugin.get("a")
      assert v=="?"
    end
  end

  def test_quit
     $plugin.quit()
  end

end

