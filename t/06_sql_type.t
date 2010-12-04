use strict;
use warnings;
use Test::More;
use SQL::Builder::SQLType qw/sql_type/;

my $t = sql_type(\444, 55);
isa_ok $t, 'SQL::Builder::SQLType';
is ${$t->value_ref}, 444;
is $t->type, 55;

done_testing;

