#!/usr/bin/env perl6

use lib 'lib';
use Test;
use DB::ORM::Quicky;

#plan 12;

my $orm = DB::ORM::Quicky.new;

my $optout;

$orm.connect(
  driver  => 'SQLite', 
  options => %( 
    database => 'local.sqlite3',
  )
) or $optout = 1;

if $optout == 1 { 
  plan 1;
  ok 1==1,'Able to \'use\'';
  exit;
}
plan 12;

my $username = '';

$username = [~] ("a".."z").roll(10);

my $newrow = $orm.create('nickl');

$newrow.set('username' => $username);
$newrow.set('password' => 'tony');
$newrow.set('joined' => time);
$newrow.save;
ok $newrow.id > -1, 'Insert worked correctly';
$newrow.delete;
ok $newrow.id == -1, 'Deleted';
$newrow.save;
ok $newrow.id > -1, 'AAAnnd it\'s back';


my $tests = $orm.search('nickl', { 
  '-and' => [
    '-raw' => ('"joined" > ? - 5000' => 50),
    username => $username,
  ]
});

ok @($tests.all).elems > 0, 'At least one record found';
for @($tests.all) -> $user {
  ok $user.get('username') eq $username, 'Able to search and find username';
}

my $test2 = $orm.search('nickl', { 
  '-and' => [
    joined => ('-gt' => 50 - 5000),
    username => $username
  ]
});

ok @($test2.all).elems > 0, 'At least one record found';
for @($test2.all) -> $user {
  ok $user.get('username') eq $username, 'Able to search and find username';
}

ok @($orm.search('nickl', { '-and' => [ 'username' => $username, joined => ('-gt' => time + 5000) ] }).all).elems == 0, 'Check for nothing.';

my @names;
for 0 .. 10 {
  $username = [~] ("a".."z").roll(10);
  @names.push($username);
  my $row = $orm.create('nickl');
  $row.set({username => $username});
  $newrow.set('joined' => time);
  $row.save;
}
ok $orm.search('nickl', { }).count >= 10, 'Checking count after inserting 10 users';

my $s = $orm.search('nickl', { });
my $fid = $s.first.id;
my $sid = $s.next.id;

ok $sid != $fid, 'Checking second id > first';

ok 0 < $orm.search('nickl', { }).first.id, 'Empty search OK';

$orm.search('nickl', { }).delete;
ok $orm.search('nickl', { }).count == 0, 'Empty table after delete';
