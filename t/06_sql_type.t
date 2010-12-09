use strict;
use warnings;
use Test::More;
use SQL::Maker::SQLType qw/sql_type/;

my $t = sql_type(\444, 55);
isa_ok $t, 'SQL::Maker::SQLType';
is ${$t->value_ref}, 444;
is $t->type, 55;

done_testing;

