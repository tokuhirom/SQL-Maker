use strict;
use warnings;
use Test::More;
use SQL::Maker::Condition;

my $w1 = SQL::Maker::Condition->new();
$w1->add(x => 1);
$w1->add(y => 2);

my $w2 = SQL::Maker::Condition->new();
my $w3 = SQL::Maker::Condition->new();

subtest 'and_before' => sub {
    my $and = ($w1 & $w2);
    is $and->as_sql, '((x = ?) AND (y = ?))';
    is join(', ', $and->bind), '1, 2';

    $and->add(z => 99);
    is $and->as_sql, '((x = ?) AND (y = ?)) AND (z = ?)';
    is join(', ', $and->bind), '1, 2, 99';
};
subtest 'and_after' => sub {
    my $and = ($w2 & $w1);
    is $and->as_sql, '((x = ?) AND (y = ?))';
    is join(', ', $and->bind), '1, 2';

    $and->add(z => 99);
    is $and->as_sql, '((x = ?) AND (y = ?)) AND (z = ?)';
    is join(', ', $and->bind), '1, 2, 99';
};

subtest 'or_before' => sub {
    my $or = ($w1 | $w2);
    is $or->as_sql, '((x = ?) AND (y = ?))';
    is join(', ', $or->bind), '1, 2';

    $or->add(z => 99);
    is $or->as_sql, '((x = ?) AND (y = ?)) AND (z = ?)';
    is join(', ', $or->bind), '1, 2, 99';
};
subtest 'or_after' => sub {
    my $or = ($w2 | $w1);
    is $or->as_sql, '((x = ?) AND (y = ?))';
    is join(', ', $or->bind), '1, 2';

    $or->add(z => 99);
    is $or->as_sql, '((x = ?) AND (y = ?)) AND (z = ?)';
    is join(', ', $or->bind), '1, 2, 99';
};

subtest 'and_both' => sub {
    my $and = ($w2 & $w3);
    is $and->as_sql, '';
    is join(', ', $and->bind), '';

    $and->add(z => 99);
    is $and->as_sql, '(z = ?)';
    is join(', ', $and->bind), '99';
};

subtest 'or_both' => sub {
    my $or = ($w2 | $w3);
    is $or->as_sql, '';
    is join(', ', $or->bind), '';

    $or->add(z => 99);
    is $or->as_sql, '(z = ?)';
    is join(', ', $or->bind), '99';
};

done_testing;

