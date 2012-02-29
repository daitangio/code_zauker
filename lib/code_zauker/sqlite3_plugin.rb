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
    end
    
    def sadd(key,value)
      begin
      @db.execute "insert into unordered_set(name,elem) values ( ?, ? )",[key,value]
      rescue SQLite3::ConstraintException => e
        # ignore SQLite3::ConstraintException: columns name, elem are not unique
        # used for better perfomance
        #puts "#{e.message} Code: #{e.code}"
      end
    end
    def smembers(key)
      r=[]
      @db.execute( "select elem from unordered_set where name='#{key}' " ) do |row|
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
      keys2join do |k|
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
  end
end
