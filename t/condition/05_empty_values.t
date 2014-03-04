use strict;
use warnings;
use Test::More;
use SQL::Maker::Condition;

subtest '[]' => sub {
    my $w = SQL::Maker::Condition->new();
    $w->add(x => []);
    is $w->as_sql, '(0=1)';
    is join(', ', $w->bind), '';
};

subtest 'in' => sub {
    my $w = SQL::Maker::Condition->new();
    $w->add(x => { 'IN' => [] });
    is $w->as_sql, '(0=1)';
    is join(', ', $w->bind), '';
};

subtest 'not in' => sub {
    my $w2 = SQL::Maker::Condition->new();
    $w2->add(x => { 'NOT IN' => [] });
    is $w2->as_sql, '(1=1)';
    is join(', ', $w2->bind), '';
};

done_testing;

