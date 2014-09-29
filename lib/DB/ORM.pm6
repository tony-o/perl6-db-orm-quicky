use DBIish;
use DB::ORM::Model;
use DB::ORM::Search;

class DB::ORM {
  has $!db;
  has $!driver;
   
  method connect(:$driver, :%options) {
    $!db     = DBIish.connect($driver, |%options, :RaiseError<1>);
    $!driver = $driver;
  }

  method create($table) {
    my $model = DB::ORM::Model.new(:dbtype($!driver), :$table, :$!db);
    return $model;
  }

  method search($table, %search) {
    my $search = DB::ORM::Search.new(:dbtype($!driver), :$table, :$!db, :%search);
    return $search;
  }
};
