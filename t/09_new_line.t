use strict;
use warnings;
use Test::More;
use SQL::Maker;

subtest 'empty string' => sub {
    my $builder = SQL::Maker->new(new_line => '', driver => 'mysql');
    is $builder->new_line, '';
};

done_testing;

