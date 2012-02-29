use strict;
use warnings;
use Test::More;
use SQL::Maker::Condition;

my $w1 = SQL::Maker::Condition->new();
$w1->add_raw( 'a = ?' => 1 );
$w1->add_raw( 'b = ?' => 2 );

is $w1->as_sql, '(a = ?) AND (b = ?)';
is join(',', $w1->bind), '1,2';

my $w2 = SQL::Maker::Condition->new();
$w2->add_raw( 'b = IF(c > 0, ?, ?)' => [0, 1] );
$w2->add_raw( 'd = ?' => [2]) ;

is $w2->as_sql, '(b = IF(c > 0, ?, ?)) AND (d = ?)';
is join(',', $w2->bind), '0,1,2';

done_testing;
