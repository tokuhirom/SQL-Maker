use strict;
use warnings;
use Test::More;
use Clone qw/clone/;

use SQL::Maker;

my $maker = SQL::Maker->new(driver => 'mysql');
my $select = $maker->select_query('test', [
   ['a'  => 'b'],
   'c',
   \'d',
   [\'count(*)' => 'cnt'],
   [\'sum(price)' => 'sum_price'],
]);

my $cloned = clone($select);

my $sql = $select->as_sql();
my $_sql = $sql;
$_sql =~ s{\n}{ }g;
is $cloned->as_sql(), $sql, "cloned object returns same sql: " . $_sql;

done_testing;
