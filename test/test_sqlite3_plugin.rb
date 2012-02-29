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

  def test_smembers
    $plugin.smembers()
  end

  def test_set
    $plugin.set()
  end

  def test_get
    $plugin.get()
  end

  def test_setnx
    $plugin.setnx()
  end

  def test_keys
    $plugin.keys()
  end

  def test_pipelined
    $plugin.pipelined()
  end

  def test_quit
    $plugin.quit()
  end

end

