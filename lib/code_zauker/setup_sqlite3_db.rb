# -*- mode:ruby ; -*- -*
require "code_zauker/version"
require "sqlite3"

db = SQLite3::Database.new "/tmp/code-zauker-sqlite-test.db"
# Create a database
rows = db.execute <<-SQL
  create table numbers (
    name varchar(30),
    val int
  );
SQL

# Execute a few inserts
{
  "one" => 1,
  "two" => 2,
}.each do |pair|
  db.execute "insert into numbers values ( ?, ? )", pair
end

# Find a few rows
db.execute( "select * from numbers" ) do |row|
  p row
end
