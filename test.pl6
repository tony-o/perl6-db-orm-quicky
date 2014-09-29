#!/usr/bin/env perl6

use lib 'lib';

use DB::ORM;

my $orm = DB::ORM.new;

$orm.connect(
  driver  => 'Pg', 
  options => %( 
    host     => 'localhost',
    port     => 5432,
    database => 'jobs',
    user     => 'tony',
    password => '', 
  )
);

my $nickl = $orm.create('nickl');

$nickl.set({ somenumber => 5 });

$nickl.set({
  someothernumber => 6, 
  somestring => 'str',
  numb => 5,
  play => 'convert to str',
  id   => 5000,
});

$nickl.save;

my $samenickl = $orm.search('nickl', { DBORMID => $nickl.id });
