use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'insert' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite');
    my ($sql, @binds) = $builder->insert('foo' => ordered_hashref(bar => 'baz', john => 'man'));
    is $sql, qq{INSERT INTO "foo"\n("bar", "john")\nVALUES (?, ?)};
    is join(',', @binds), 'baz,man';
};

subtest 'delete' => sub {
    subtest 'simple' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{DELETE FROM "foo" WHERE ("bar" = ?) AND ("john" = ?)};
        is join(',', @binds), 'baz,man';
    };
    subtest 'delete all' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->delete('foo');
        is $sql, qq{DELETE FROM "foo"};
        is join(',', @binds), '';
    };
};

subtest 'update' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite');
    {
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com'], {user_id => 3});
        is $sql, qq{UPDATE "user" SET "name" = ?, "email" = ? WHERE ("user_id" = ?)};
        is join(',', @binds), 'john,john@example.com,3';
    }
    {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), ordered_hashref(yo => 'king'));
        is $sql, qq{UPDATE "foo" SET "bar" = ?, "john" = ? WHERE ("yo" = ?)};
        is join(',', @binds), 'baz,man,king';
    }
    {
        # no where
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{UPDATE "foo" SET "bar" = ?, "john" = ?};
        is join(',', @binds), 'baz,man';
    }
};

subtest 'select_query' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite');

    do {
        my $stmt = $builder->select_query('foo' => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'), {order_by => 'yo'});
        is $stmt->as_sql, qq{SELECT "foo", "bar"\nFROM "foo"\nWHERE ("bar" = ?) AND ("john" = ?)\nORDER BY yo\n};
        is join(',', $stmt->bind), 'baz,man';
    };
};

subtest 'new_select' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite', quote_char => q{`}, name_sep => q{.});
    my $select = $builder->new_select();
    isa_ok $select, 'SQL::Maker::Select';
    is $select->quote_char, q{`};
    is $select->name_sep, q{.};
};

subtest 'select' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite');
    do {
        my ($sql, @binds) = $builder->select('foo' => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'), {order_by => 'yo'});
        is $sql, qq{SELECT "foo", "bar"\nFROM "foo"\nWHERE ("bar" = ?) AND ("john" = ?)\nORDER BY yo\n};
        is join(',', @binds), 'baz,man';
    };
    do {
        my ($sql, @binds) = $builder->select('foo' => ['foo', 'bar'], [bar => 'baz', john => 'man'], {order_by => 'yo'});
        is $sql, qq{SELECT "foo", "bar"\nFROM "foo"\nWHERE ("bar" = ?) AND ("john" = ?)\nORDER BY yo\n};
        is join(',', @binds), 'baz,man';
    };
    do {
        my ($sql, @binds) = $builder->select('foo' => ['foo', 'bar'], [bar => 'baz', john => 'man'], {order_by => 'yo', limit => 1, offset => 3});
        is $sql, qq{SELECT "foo", "bar"\nFROM "foo"\nWHERE ("bar" = ?) AND ("john" = ?)\nORDER BY yo\nLIMIT 1 OFFSET 3\n};
        is join(',', @binds), 'baz,man';
    };
    do {
        my ($sql, @binds) = $builder->select('foo' => ['foo', 'bar'], [], {prefix => 'SELECT SQL_CALC_FOUND_ROWS '});
        is $sql, qq{SELECT SQL_CALC_FOUND_ROWS "foo", "bar"\nFROM "foo"\n};
        is join(',', @binds), '';
    };
    subtest 'order_by' => sub {
        do {
            my ($sql, @binds) = $builder->select('foo' => ['*'], +{}, {order_by => 'yo'});
            is $sql, qq{SELECT *\nFROM "foo"\nORDER BY yo\n};
            is join(',', @binds), '';
        };
        do {
            my ($sql, @binds) = $builder->select('foo' => ['*'], +{}, {order_by => ['yo', 'ya']});
            is $sql, qq{SELECT *\nFROM "foo"\nORDER BY yo, ya\n};
            is join(',', @binds), '';
        };
        do {
            my ($sql, @binds) = $builder->select('foo' => ['*'], +{}, {order_by => [{'yo' => 'DESC'}, 'ya']});
            is $sql, qq{SELECT *\nFROM "foo"\nORDER BY "yo" DESC, ya\n};
            is join(',', @binds), '';
        };
    };
};

done_testing;

