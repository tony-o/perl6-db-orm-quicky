class DB::ORM::Quicky::Model {
  has %options;
  has $!dbtype;
  has %!statictypes; 
  has $!db;
  has $!table;
  has %!data;
  has @!changed;
  has $.id is rw;

  submethod BUILD (:$!dbtype, :$!db, :$!table) {
    %!statictypes = 
        Pg => {
          In => {
            'double precision'  => Num,
            'integer'           => Int,
            'varchar'           => Str,
            'character varying' => Str,
            'text'              => Str,
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
        SQLite => {
          In => {
            'float'   => Num,
            'integer' => Int,
            'varchar' => Str,
            'text'    => Str,
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

    $!db.do("CREATE TABLE \"$!table\" ( DBORMID integer );") if $!dbtype eq 'Pg' && ! self!pgtableexists;
    $!db.do("CREATE TABLE \"$!table\" ( DBORMID integer );") if $!dbtype eq 'SQLite' && ! self!sqlitetableexists;
  }

  method get($key) {
    return %!data{$key};
  }

  method set(%data) {
    for %data.keys -> $k {
      next if "$k".uc eq 'DBORMID';
      @!changed.push("$k");
      %!data{"$k"} = %data{$k};
    }
  }

  method save {
    return if @!changed.elems == 0;
    my %types;
    %types = self!pggetcols if $!dbtype eq 'Pg';
    %types = self!sqlitegetcols if $!dbtype eq 'SQLite';
    #check types
    my @changes;
    my %modcols;
    for %!data.keys -> $col {
      my ($type, $cflag, $eflag);
      $eflag = $cflag = False;
      $eflag = True if $col eq any %types.keys;
      for %!statictypes{$!dbtype}<Degrade>.values -> $what {
        $type = %!statictypes{$!dbtype}<Out>{%$what.keys[0]} if %!data{$col} ~~ %$what.values[0];
        last if defined $type && $type !~~ Any;
        $cflag = True if %types{$col}<type> ~~ %$what.values[0];
      }
      #check varchar length
      if $eflag && %!statictypes{$!dbtype}<In>{$type} ~~ Str && %!data{$col}.chars > %types{$col}<length> {
        @changes.push("ALTER TABLE \"$!table\" ALTER COLUMN \"$col\" TYPE $type\({%!data{$col}.chars}\)");
        %modcols{$col} = "$type\({%!data{$col}.chars}\)";
      }
 
      $type = 'varchar' if !defined $type;
      $type = "$type\({%!data{$col}.chars}\)" if $type eq 'varchar';
      next if $eflag && !$cflag;
      if $eflag && $cflag {
        @changes.push("ALTER TABLE \"$!table\" ALTER COLUMN \"$col\" TYPE $type;");
        %modcols{$col} = "$type";
      } else {
        @changes.push("ALTER TABLE \"$!table\" ADD COLUMN \"$col\" $type;");
        %modcols{$col} = "$type";
      }
    }
    #run table type updates
    if $!dbtype ne 'SQLite' || %modcols.keys.elems ==  0 {
      for @changes -> $sql {
        try {
          $!db.do($sql);
          CATCH { .say; }
        };
      }
    } else {
      self!sqlitemodcolumns(%types, %modcols);
    }
    #build insert
    if !defined $!id {
      try {
        $!db.do("ALTER TABLE \"$!table\" ADD COLUMN \"DBORMID\" integer;");
      };
      my $idsql = "SELECT MAX(\"DBORMID\") DBORMID FROM \"$!table\" LIMIT 1;";
      my $idsth = $!db.prepare($idsql);
      $idsth.execute();
      my @a = $idsth.fetchrow_array;
      $!id   = (@a[0] ~~ / ^ \d+ $ / ?? @a[0].Int !! 0) + 1; 
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

  method !pgtableexists {
    my $s = $!db.prepare('select count(*) c from pg_tables where schemaname = ? and tablename = ?');
    $s.execute(('public', $!table));
    my $c = ($s.fetchrow_hashref)<c>;
    return $c > 0 ?? True !! False;
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
      %columns{$row<n>} = { type => $row<t>, length => $row<l> ~~ /^ \d+ $/ ?? $row<l>.Int !! -1 };
    }

    for %columns.keys -> $k {
      %types{"$k"} = { type => %!statictypes{$!dbtype}<In>{%columns{$k}<type>}, length => %columns{$k}<length> };
    }
    return %types;
  }

  method !sqlitetableexists {
    my $s = $!db.prepare('select count(sql) c from sqlite_master where tbl_name = ? and type = ?;');
    $s.execute(($!table, 'table'));
    my $c = ($s.fetchrow_hashref)<c>;
    return $c > 0 ?? True !! False;
  }

  method !sqlitegetcols {
    my %types;
    my $sth = $!db.prepare('select
                              sql
                            from
                              sqlite_master
                            where 
                              tbl_name = ? 
                              and type = ?;');
    $sth.execute(($!table, 'table'));
    my $cols = $sth.fetchrow_hashref<sql>;
    $cols ~~ s/ ^ .*? '(' (.*) ')' .*? $ /$<>[0]/;
    my @column = $cols.split(/ \s* ',' \s* /);
    my %columns;
    for @column -> $c {
      my @d = $c.trim.split(/\s+/, 2);
      my $len = -1;
      if @d[1] ~~ / ^ 'varchar' / {
        @d[1].match(/ \d+ /);
        $len  = $<>;
        @d[1] = 'varchar';
      }
      @d[0] ~~ s/ ^ '"' //;
      @d[0] ~~ s/ '"' $ //;
      %types{"{@d[0]}"} = { type => %!statictypes{$!dbtype}<In>{@d[1]}, length => $len.Int }; 
    }
    return %types;
  }

  method !sqlitemodcolumns(%types, %mods) {
    my @cmd;
    my $sql = "CREATE TABLE \"tmp_$!table\" ( ";
    for %types.keys -> $k {
      $sql ~= "\"$k\" ";
      my $type;
      for %!statictypes{$!dbtype}<In>.keys -> $v {
        $type = $v if %!statictypes{$!dbtype}<In>{$v} ~~ %types{$k}<type>;
        last if defined $type;
      }
      $type = 'varchar' if !defined $type;
      $type ~= "({%types{$k}<length>})" if $type eq 'varchar';
      $sql ~= " {$type}, " if $k ne %mods.keys.any;
      $sql ~= " {%mods{$k}}, " if $k eq %mods.keys.any;
    }
    $sql ~~ s/', ' $/);/;

    @cmd.push($sql);

    @cmd.push("INSERT INTO \"tmp_$!table\" SELECT * FROM \"$!table\";");
    @cmd.push("DROP TABLE \"$!table\";");
    @cmd.push("ALTER TABLE \"tmp_$!table\" RENAME TO \"$!table\";");

    for @cmd -> $cmd {
      $!db.do($cmd);
    }
  }
};
