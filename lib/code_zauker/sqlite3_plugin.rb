# -*- mode:ruby ; -*- -*
require "code_zauker/version"
require "rubygems"
require "sequel"
require "sqlite3"
require 'logger'

module CodeZauker
  # basic class which re-implements redis api used by code zauker
  # a plug-in replace for code zauker
  class SQLite3Store
    def initialize(dbpath)
      ## @db = SQLite3::Database.new dbpath   
      @db=Sequel.sqlite(dbpath,:loggers => [Logger.new($stdout)])
    end

    def connect
    end
    def quit
      # @setinsert.close()
      # @smembers_query.close()
      # @db.close()
    end

    def init_db
      # See also http://sequel.rubyforge.org/rdoc/files/doc/cheat_sheet_rdoc.html
      @db.create_table :key2value do
        primary_key :name
        String :name
        String :value
      end

      # SQLite does not impose any length restrictions 
      # (other than the large global SQLITE_MAX_LENGTH limit) on the length of strings, BLOBs or numeric values.
      # So lets start
      @db.execute <<-SQL
create table unordered_set (
    name varchar(30),
    elem text
  );
SQL
      @db.execute <<-INDEXES
create unique index UX_unordered_set ON unordered_set(name,elem);
INDEXES


      @db.execute <<-INDEXES
create unique index UX_key2value ON key2value(name);
INDEXES

      
    end
    
    def sadd(key,value)      
      # insert into unordered_set(name,elem) values ( :k, :v )
      ds=@db[:unordered_set]
      if ds.filter(:name=>key, :elem => value).count()==0
        ds.insert( :name => key, :elem =>value)
      end      
    end
    def smembers(key)
      r=[]
      # select elem from unordered_set where name=:k 
      @db[:unordered_set].filter( :name =>key).each do |row|
        r.push row[:elem]
      end
      return r
    end

    def srem(key,elem)
      @db[:unordered_set].filter(:name => key, :elem => elem).delete();
    end

    # Returns the members of the set resulting from the intersection of all the given sets.
    # uses the sql92 
    # select... intersect select... syntax
    # For Example:
    # key1 = {a,b,c,d}
    # key2 = {c}
    # key3 = {a,c,e}
    # SINTER key1 key2 key3 = {c}
    def sinter(*keys2join)
      # select elem from unordered_set where name="key1" INTERSECT select elem from unordered_set where name="key2";
      sqls=[]
      keys2join.each do |k|
        sqls.push "select elem from unordered_set where name='#{k}'"
      end
      r=[]
      @db.fetch( sqls.join(" INTERSECT ")  ) do |row|
        r.push row[:elem]
      end
      return r
    end
    def scard(key)
      return @db[:unordered_set].filter(:name =>key).count()
    end
    # Set key to hold the string value. 
    # If key already holds a value, it is overwritten, regardless of its type
    def set(key,value)
      ds=@db[:key2value]
      # Ensure it does not exist...
      ds.filter(:name => key).delete()
      ds.insert(:name=>key, :value=>value)

    end

    #Set key to hold string value if key does not exist. In that case, it is equal to SET.
    def setnx(key,value)
      if get(key)==nil
        set(key,value)
      end
    end

    # Get the value of key. If the key does not exist the special value nil is returned. 
    # only strings are supported
    def get(key)
      elems=@db[:key2value].filter(:name=>key).all      
      if elems.length!=0
        return elems[0][:value]
      else
        return nil
      end
    end
    
    # Delete a key
    # Work on any key
    # Slow: it should figure when the key is...
    def del(*keys)
      dso=@db[:unordered_set]
      dsk=@db[:key2value]
      keys.each do |k|
        dso.filter(:name =>k).delete()
        dsk.filter(:name =>k).delete()
      end
    end

    def pipelined(options={})
      #puts "Pipeline..."
      # Sequel manage rollback magically.
      # See http://sequel.rubyforge.org/rdoc/files/doc/cheat_sheet_rdoc.html
      # on Transaction paragprah
      @db.transaction do
        begin          
          yield
          #puts "...Pipeline Ended. Committing..."
        rescue SQLite3::SQLException =>e        
          puts "FATAL. Rollbacking and re-raising..."
          raise e
        end
      end
    end

    #Increments the number stored at key by one. 
    #If the key does not exist, it is set to 0 before performing the operation. 
    def incr(key)
      prev=get(key)
      if prev==nil
        v=1        
      else
        v=prev.to_i()+1
      end
      set(key,v.to_s())
      return v
    end

    # Returns all keys matching pattern
    # h*llo matches hllo and heeeello
    # Warn: only * is supported ad the meantime, so it is not full
    # redis compliant
    def keys(pattern)
      r=[]      
      if pattern =="*"
        #puts "FULL UNION"
        @db.fetch("select distinct name from key2value union select distinct name from unordered_set")  do |row|
          r.push row[:name]
        end
      else
        sqlPattern=pattern.sub("*","%") 
        # use push(*keys to expand push
        @db.fetch( 
          "select name from key2value where name like ? union select name from unordered_set where name like ?",
                    sqlPattern, sqlPattern)  do |row|
          r.push row[:name]
        end
      end
      return r
    end


  end
end
