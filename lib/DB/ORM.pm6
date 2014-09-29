use DBIish;
use DB::ORM::Model;

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
    my $sql = '';
    my @val;
    for %search.keys -> $key {
      $sql ~= 'WHERE ' if $sql eq '';
      $sql ~= "\"$key\" = ? ";
      @val.push(self!processtosql(%search, $key)); 
    }
    $sql = "SELECT * FROM \"$table\" $sql";
    $sql.say;
    @val.join(", ").say;
  }

  method !processtosql(%search, $key) {
     return %search{$key};
  }
};
