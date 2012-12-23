use strict;
use warnings;
use Test::More;
use SQL::Maker::Condition;

my $w1 = SQL::Maker::Condition->new();
$w1->add(x => 1);
$w1->add(y => 2);

my $w2 = SQL::Maker::Condition->new();
$w2->add(a => 3);
$w2->add(b => 4);

subtest 'and' => sub {
    my $and = ($w1 & $w2);
    is $and->as_sql, '((x = ?) AND (y = ?)) AND ((a = ?) AND (b = ?))';
    is join(', ', $and->bind), '1, 2, 3, 4';

    $and->add(z => 99);
    is $and->as_sql, '((x = ?) AND (y = ?)) AND ((a = ?) AND (b = ?)) AND (z = ?)';
    is join(', ', $and->bind), '1, 2, 3, 4, 99';
};

subtest 'or' => sub {
    my $or = ($w1 | $w2);
    is $or->as_sql, '(((x = ?) AND (y = ?)) OR ((a = ?) AND (b = ?)))';
    is join(', ', $or->bind), '1, 2, 3, 4';

    $or->add(z => 99);
    is $or->as_sql, '(((x = ?) AND (y = ?)) OR ((a = ?) AND (b = ?))) AND (z = ?)';
    is join(', ', $or->bind), '1, 2, 3, 4, 99';
};

done_testing;

