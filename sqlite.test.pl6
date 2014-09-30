#!/usr/bin/env perl6

use lib 'lib';
use DB::ORM::Quicky;

my $driver  = 'SQLite';
my %options = database => 'local.sqlite3';

my $orm = DB::ORM::Quicky.new;

$orm.connect(:$driver, :%options);

my $test = $orm.create('tester');
$test.set({ name => 'peterpan' });

$test.save;

