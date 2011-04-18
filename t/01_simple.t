use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'select_query' => sub {
    subtest 'driver: sqlite' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');

        do {
            my $stmt = $builder->select_query('foo' => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'), {order_by => 'yo'});
            is $stmt->as_sql, qq{SELECT "foo", "bar"\nFROM "foo"\nWHERE ("bar" = ?) AND ("john" = ?)\nORDER BY yo};
            is join(',', $stmt->bind), 'baz,man';
        };
    };

    subtest 'driver: mysql, quote_char: "", new_line: " "' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');

        do {
            my $stmt = $builder->select_query('foo' => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'), {order_by => 'yo'});
            is $stmt->as_sql, qq{SELECT foo, bar FROM foo WHERE (bar = ?) AND (john = ?) ORDER BY yo};
            is join(',', $stmt->bind), 'baz,man';
        };
    };
};

subtest 'new_condition' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite', quote_char => q{`}, name_sep => q{.});
    my $cond = $builder->new_condition;
    isa_ok $cond, 'SQL::Maker::Condition';
    is $cond->{quote_char}, q{`};
    is $cond->{name_sep}, q{.};
};

subtest 'new_select' => sub {
    subtest 'driver: sqlite, quote_char: "`", name_sep: "."' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite', quote_char => q{`}, name_sep => q{.});
        my $select = $builder->new_select();
        isa_ok $select, 'SQL::Maker::Select';
        is $select->quote_char, q{`};
        is $select->name_sep, q{.};
        is $select->new_line, qq{\n};
    };

    subtest 'driver: mysql, quote_char: "", new_line: " "' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite', quote_char => q{}, name_sep => q{.}, new_line => q{ });
        my $select = $builder->new_select();
        isa_ok $select, 'SQL::Maker::Select';
        is $select->quote_char, q{};
        is $select->name_sep, q{.};
        is $select->new_line, q{ };
    };
};


done_testing;

