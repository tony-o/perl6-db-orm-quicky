class DB::ORM::Model {
  has %options;
  has $!dbtype;
  has %!statictypes; 
  has $!db;
  has $!table;
  has %!data;
  has @!changed;
  has $.id;

  submethod BUILD (:$dbtype, :$!db, :$!table) {
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
          Degrade => @(
            Int => Int, 
            Num => Num, 
            Str => Str,
          )
       },
    ;
  }

  method set(%data) {
    for %data.keys -> $k {
      @!changed.push("$k");
      %!data{"$k"} = %data{$k};
    }
  }

  method save {
    return if @!changed.elems == 0;
    my %types;
    %types = self!pggetcols if $!dbtype eq 'Pg';
    #check types
    my @changes;
    for %!data.keys -> $col {
      my ($type, $cflag, $eflag);
      $eflag = $cflag = False;
      $eflag = True if $col eq any %types.keys;
      for %!statictypes{$!dbtype}<Degrade> -> $what {
        $type = %!statictypes{$!dbtype}<Out>{%$what.keys[0]} if %!data{$col} ~~ %$what.values[0];
        last if defined $type;
        $cflag = True if %types{$col} ~~ %$what.values[0];
      }
 
      $type = 'varchar' if !defined $type;
      $type = "$type\({%!data{$col}.chars}\)" if $type eq 'varchar';
      next if $eflag && !$cflag;
      if $eflag && $cflag {
        @changes.push("ALTER TABLE \"$!table\" ALTER COLUMN \"$col\" TYPE $type;");
      } else {
        @changes.push("ALTER TABLE \"$!table\" ADD COLUMN \"$col\" $type;");
      }
    }
    #run table type updates
    for @changes -> $sql {
      try {
        $!db.do($sql);
        CATCH { .say; }
      };
    }
    #build insert
    if !defined $!id {
      try {
        $!db.do("ALTER TABLE \"$!table\" ADD COLUMN \"DBORMID\" integer;");
      };
      my $idsql = "SELECT MAX(\"DBORMID\") DBORMID FROM \"$!table\" LIMIT 1;";
      my $idsth = $!db.prepare($idsql);
      $idsth.execute();
      $!id = ($idsth.fetchrow_array)[0] + 1; 
      $idsql = "INSERT INTO \"$!table\" (\"DBORMID\") VALUES (?)";
      $idsth = $!db.do($idsql, $!id); 
    }
    my @insert = map { %!data{"$_"} }, @!changed;
    my @column = map { "\"$_\""     }, @!changed;
    #save data
    my $sql = "UPDATE \"$!table\" SET {@column.join(' = ?, ')} = ? WHERE \"DBORMID\" = ?;";
    my $sth = $!db.prepare($sql);
    my $r   = $sth.execute(@(@insert, $!id));
    
    @!changed = ();
  }

  method !pggetcols {
    my %types;
    my $sth = $!db.prepare('select 
                              column_name as n, data_type as t, 
                              character_maximum_length as l
                            from 
                              INFORMATION_SCHEMA.COLUMNS 
                            where table_name = ?');
    $sth.execute($!table);
    my %columns;
    while (my $row = $sth.fetchrow_hashref) {
      %columns{$row<n>} = $row<t>;
    }

    for %columns.keys -> $k {
      %types{"$k"} = %!statictypes{$!dbtype}<In>{%columns{$k}};
    }
    return %types;
  }
};
