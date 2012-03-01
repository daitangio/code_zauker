# -*- mode:ruby ; -*- -*
require "code_zauker/version"
require "sqlite3"

module CodeZauker
  # basic class which re-implements redis api used by code zauker
  # a plug-in replace for code zauker
  class SQLite3Store
    def initialize(dbpath)
      @db = SQLite3::Database.new dbpath   
      
    end

    def connect
      @setinsert = @db.prepare("insert into unordered_set(name,elem) values ( :k, :v )") 
      @smembers_query=@db.prepare("select elem from unordered_set where name=:k ")
    end
    def quit
      # @setinsert.close()
      # @smembers_query.close()
      # @db.close()
    end

    def init_db
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

      @db.execute <<-SIMPLE_KEYS
create table key2value (
     name text,
     value text);
SIMPLE_KEYS

      @db.execute <<-INDEXES
create unique index UX_key2value ON key2value(name);
INDEXES

      
    end
    
    def sadd(key,value)
      begin          
        @setinsert.execute( :k =>key, :v => value)        
      rescue SQLite3::ConstraintException => e
        # ignore SQLite3::ConstraintException: columns name, elem are not unique
        # used for better perfomance
        #puts "#{e.message} Code: #{e.code}"
      end
    end
    def smembers(key)
      r=[]
      @smembers_query.execute(:k =>key ).each do |row|
        r.push row[0]
      end
      return r
    end

    def srem(key,elem)
      @db.execute( "delete from unordered_set where name='#{key}' and  elem='#{elem}'" )
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
      @db.execute( sqls.join(" INTERSECT ")  ) do |row|
        r.push row[0]
      end
      return r
    end
    def scard(key)
      # return first elemenents of first row
      return @db.execute( "select count(*) from unordered_set where name='#{key}'")[0][0]
    end
    # Set key to hold the string value. 
    # If key already holds a value, it is overwritten, regardless of its type
    def set(key,value)
      # Ensure it does not exist...
      @db.execute "delete from key2value where name=?",key
      # push!
      @db.execute "insert into key2value(name,value) values ( ?, ? )",[key,value]
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
      rs=@db.execute "select value from key2value where name=?",key
      if rs[0]!=nil
        return rs[0][0]
      else
        return nil
      end
    end
    
    # Delete a key
    # Work on any key
    # Slow: it should figure when the key is...
    def del(*keys)
      keys.each do |k|
        @db.execute "delete from unordered_set  where name=?",k
        @db.execute "delete from key2value      where name=?",k
      end
    end

    def pipelined(options={})
      begin
        #puts "Pipeline..."
        @db.transaction()
        yield
        #puts "...Pipeline Ended. Committing..."
        @db.commit()
      rescue SQLite3::SQLException =>e        
        puts "FATAL. Rollbacking and re-raising..."
        @db.rollback()
        raise e
      end
    end

    # Returns all keys matching pattern
    # h*llo matches hllo and heeeello
    # Warn: only * is supported ad the meantime, so it is not full
    # redis compliant
    def keys(pattern)
      r=[]      
      if pattern =="*"
        #puts "FULL UNION"
        @db.execute( 
          "select distinct name from key2value union select distinct name from unordered_set")  do |row|
          #puts row[0]
          r.push row[0]
        end
      else
        sqlPattern=pattern.sub("*","%") 
        # use push(*keys to expand push
        @db.execute( 
          "select name from key2value where name like ? union select name from unordered_set where name like ?",
                    [sqlPattern, sqlPattern])  do |row|
          r.push row[0]
        end
      end
      return r
    end


  end
end
