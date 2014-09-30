use DB::ORM::Quicky::Model;

class DB::ORM::Quicky::Search {
  has $.sth is rw;
  has %.params;
  has $.table;
  has $.db;
  has $.dbtype;
  has $.error is rw;
  has $!quote = '';

  method all {
    self.search if !defined $!sth;
    return Nil if $.error !~~ Any;
    my @rows;
    while my $row = $!sth.fetchrow_hashref {
      my $n = DB::ORM::Quicky::Model.new(:$.table, :$.db, :$.dbtype, :skipcreate(True));
      $n.set(%($row));
      $n.id = $row<DBORMID>;
      @rows.push($n);
    }
    $.sth.finish if $.sth.^can('finish');

    return @rows;
  }

  method !fquote($str) { return $!quote ~ $str ~ $!quote; }

  method search() {
    $!quote = '`' if $!quote eq '' && $!dbtype eq 'mysql';
    $!quote = '"' if $!quote eq '';
    my $sql = '';
    my @val;
    for %!params.keys -> $key {
      if $sql eq '' {
        $sql ~= 'WHERE ';
      } else {
        $sql ~= ' AND ';
      }
      my %ret = %(self!processtosql($key));
      $sql ~= %ret<sql>;
      @val.push($_) for @(%ret<val>); 
    }
    $sql = "SELECT * FROM {self!fquote($.table)} $sql";
    DB::ORM::Quicky::Model.new(:$.table, :$.db, :$.dbtype);
    my $rval = False;
    try {
      $.sth = $.db.prepare($sql);
      $.sth.execute(@val);
      $rval = True;
      $.error = Any;
      CATCH { .say; }
    };
    $.error = $!db.errstr if not $rval;
    return $rval;
  }

  method !processtosql($key, %params = %.params) {
    my $str = '';
    my @val;
    if $key.lc eq '-and' || $key.lc eq '-or' {
      my $ao = $key.lc eq '-and' ?? 'AND ' !! 'OR ';
      $str ~= '(';
      for @(%params{$key}) -> $next {
        if $next.value ~~ Hash|Array {
          my %t = %(self!processtosql($next.key, $next));
          $str ~= %t<sql> ~ " $ao";
          @val.push($_) for @(%t<val>);
        } elsif $next ~~ Pair {
          my %t = %(self!processtosql($next.key, %($next)));
          $str ~= %t<sql> ~ " $ao";
          @val.push($_) for @(%t<val>);
        } elsif $next ~~ Hash {
          my %t = %(self!processtosql($next, %params{$key}));
          $str ~= %t<sql> ~ " $ao";
          @val.push($_) for @(%t<val>);
        } 
      }
      $str ~~ s/[ 'OR ' | 'AND ']$/)/;
    } elsif %params{$key} ~~ Array {
      $str ~= '(';
      for @(%params{$key}) -> $v {
        $str ~= "{self!fquote($key)} = ? OR ";
        @val.push($v);
      }
      $str ~~ s/'OR ' $/)/;
    } else {
      if $key.lc eq '-raw' {
        if %params{$key} ~~ Pair {
          $str ~= %params{$key}.key;
          if %params{$key} ~~ Array {
            @val.push($_) for @(%params{$key}.value);
          } else {
            @val.push(%params{$key}.value);
          }
        } else {
          $str ~= %params{$key};
        }
      } elsif %params{$key} ~~ Pair && %params{$key}.key.lc eq ('-gt','-lt','-eq').any {
        my $op = %params{$key}.key.lc;
        $op = $op eq '-gt' ?? '>' !! $op eq '-lt' ?? '<' !! '=';
        $str ~= "{self!fquote($key)} $op ?"; 
        @val.push(%params{$key}.value);
      } else { 
        $str ~= "{self!fquote($key)} = ? ";
        @val.push(%params{$key});
      }
    }
    return { sql => $str, val => @val };
  }
};
