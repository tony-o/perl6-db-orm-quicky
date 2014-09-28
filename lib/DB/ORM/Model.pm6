class DB::ORM::Model {
  has %options;
  has $!dbtype;
  has %!statictypes; 
  has $!db;
  has $!table;
  has %!types;
  has %!data;

  submethod BUILD (:$dbtype, :%columns, :$!db, :$!table) {
    $!dbtype := $dbtype;
    %!statictypes = 
        Pg => {
          In => {
            'double precision' => Num,
            'integer'          => Int,
            'varchar'          => Str,
          },
          Out => {
            Num => 'float',
            Int => 'integer',
            Str => 'varchar',
          },
          Degrade => {
            Num => Num, 
            Int => Int, 
            Str => Str,
          }
       },
    ;
    for %columns.keys -> $k {
      %!types{$k} = %!statictypes{$dbtype}<In>{%columns{$k}};
    }
  }

  method set(%data) {
    %data.say;
    for %data.keys -> $k {
      %!data{"$k"} = %data{$k};
    }
  }

  method save {
    #check types
    my @changes;
    for %!data.keys -> $col {
      "COL $col".say;
      if $col eq any %!types.keys {
        #alter column
        "alter $col".say;

      } else {
        #add column
        my $type;
        for %!statictypes{$!dbtype}<Degrade>.keys -> $what {
          $type = %!statictypes{$!dbtype}<Out>{$what} if %!data{$col}.WHAT ~~ %!statictypes{$!dbtype}<Degrade>{$what};
          last if defined $type;
        }
        $type = 'varchar' if !defined $type;
        $type = "$type\({%!data{$col}.chars}\)" if $type eq 'varchar';
        "add $col ($type);".say;
        @changes.push("ALTER TABLE \`$!table\` ADD COLUMN \`$col\` $type;");
      }
    }
    @changes.perl.say;
    #run table type updates

    #save data
    %!data.say;
  }
};
