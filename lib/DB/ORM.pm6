
use MiniDBI;
use DB::ORM::Model;

class DB::ORM {
  has $!db;
  has $!driver;
   
  method connect(:$driver, :%options) {
    $!db     = MiniDBI.connect($driver, |%options, :RaiseError<1>);
    $!driver = $driver;
  }

  method create($table) {
    my $sth = $!db.prepare('select 
                              column_name as n, data_type as t, 
                              character_maximum_length as l
                            from 
                              INFORMATION_SCHEMA.COLUMNS 
                            where table_name = ?');
    $sth.execute($table);
    my %columns;
    while (my $row = $sth.fetchrow_hashref) {
      %columns{$row<n>} = $row<t>;
    }
    my $model = DB::ORM::Model.new(:columns(%columns), :dbtype($!driver), :$table, :$!db);
    return $model;
  }
};
