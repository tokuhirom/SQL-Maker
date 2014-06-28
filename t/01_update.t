use strict;
use warnings;
use Test::More;
use SQL::Maker;
use SQL::QueryMaker;
use Test::Requires 'DateTime';
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'driver: sqlite' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite');
    subtest 'arrayref, where cause(hashref)' => sub {
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com', expires => DateTime->new(year => 2025)], {user_id => 3});
        is $sql, qq{UPDATE "user" SET "name" = ?, "email" = ?, "expires" = ? WHERE ("user_id" = ?)};
        is join(',', @binds), 'john,john@example.com,2025-01-01T00:00:00,3';
    };

    subtest 'arrayref, where cause(arrayref)' => sub {
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com', expires => DateTime->new(year => 2025)], [user_id => 3]);
        is $sql, qq{UPDATE "user" SET "name" = ?, "email" = ?, "expires" = ? WHERE ("user_id" = ?)};
        is join(',', @binds), 'john,john@example.com,2025-01-01T00:00:00,3';
    };

    subtest 'arrayref, where cause(condition)' => sub {
        my $cond = $builder->new_condition;
        $cond->add(user_id => 3);
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com'], $cond);
        is $sql, qq{UPDATE "user" SET "name" = ?, "email" = ? WHERE ("user_id" = ?)};
        is join(',', @binds), 'john,john@example.com,3';
    };

    subtest 'ordered hashref, where cause(hashref)' => sub {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), ordered_hashref(yo => 'king'));
        is $sql, qq{UPDATE "foo" SET "bar" = ?, "john" = ? WHERE ("yo" = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref, where cause(arrayref)' => sub {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), [yo => 'king']);
        is $sql, qq{UPDATE "foo" SET "bar" = ?, "john" = ? WHERE ("yo" = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref, where cause(condition)' => sub {
        my $cond = $builder->new_condition;
        $cond->add(yo => 'king');
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), $cond);
        is $sql, qq{UPDATE "foo" SET "bar" = ?, "john" = ? WHERE ("yo" = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref' => sub {
        # no where
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{UPDATE "foo" SET "bar" = ?, "john" = ?};
        is join(',', @binds), 'baz,man';
    };

    subtest 'literal, sub query' => sub {
        my ($sql, @binds) = $builder->update( 'foo', [ user_id => 100, updated_on => \['datetime(?)', 'now'], counter => \'counter + 1' ] );
        is $sql, qq{UPDATE "foo" SET "user_id" = ?, "updated_on" = datetime(?), "counter" = counter + 1};
        is join(',', @binds), '100,now';
    };

    subtest 'literal, sub query using term' => sub {
        my ($sql, @binds) = $builder->update( 'foo', [ user_id => 100, updated_on => sql_raw('datetime(?)', 'now'), counter => sql_raw('counter + 1') ] );
        is $sql, qq{UPDATE "foo" SET "user_id" = ?, "updated_on" = datetime(?), "counter" = counter + 1};
        is join(',', @binds), '100,now';
    };
};

subtest 'driver: mysql' => sub {
    my $builder = SQL::Maker->new(driver => 'mysql');
    subtest 'array ref, where cause(hashref)' => sub {
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com', expires => DateTime->new(year => 2025)], {user_id => 3});
        is $sql, qq{UPDATE `user` SET `name` = ?, `email` = ?, `expires` = ? WHERE (`user_id` = ?)};
        is join(',', @binds), 'john,john@example.com,2025-01-01T00:00:00,3';
    };

    subtest 'array ref, where cause(arrayref)' => sub {
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com', expires => DateTime->new(year => 2025)], [user_id => 3]);
        is $sql, qq{UPDATE `user` SET `name` = ?, `email` = ?, `expires` = ? WHERE (`user_id` = ?)};
        is join(',', @binds), 'john,john@example.com,2025-01-01T00:00:00,3';
    };

    subtest 'array ref, where cause(condition)' => sub {
        my $cond = $builder->new_condition;
        $cond->add(user_id => 3);
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com'], $cond);
        is $sql, qq{UPDATE `user` SET `name` = ?, `email` = ? WHERE (`user_id` = ?)};
        is join(',', @binds), 'john,john@example.com,3';
    };

    subtest 'ordered hashref, where cause(hashref)' => sub {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), ordered_hashref(yo => 'king'));
        is $sql, qq{UPDATE `foo` SET `bar` = ?, `john` = ? WHERE (`yo` = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref, where cause(arrayref)' => sub {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), [yo => 'king']);
        is $sql, qq{UPDATE `foo` SET `bar` = ?, `john` = ? WHERE (`yo` = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref, where cause(condition)' => sub {
        my $cond = $builder->new_condition;
        $cond->add(yo => 'king');
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), $cond);
        is $sql, qq{UPDATE `foo` SET `bar` = ?, `john` = ? WHERE (`yo` = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref' => sub {
        # no where
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{UPDATE `foo` SET `bar` = ?, `john` = ?};
        is join(',', @binds), 'baz,man';
    };

    subtest 'literal, sub query' => sub {
        my ($sql, @binds) = $builder->update( 'foo', [ user_id => 100, updated_on => \['FROM_UNIXTIME(?)', 1302241686], counter => \'counter + 1' ] );
        is $sql, qq{UPDATE `foo` SET `user_id` = ?, `updated_on` = FROM_UNIXTIME(?), `counter` = counter + 1};
        is join(',', @binds), '100,1302241686';
    };

    subtest 'literal, sub query using term' => sub {
        my ($sql, @binds) = $builder->update( 'foo', [ user_id => 100, updated_on => sql_raw('FROM_UNIXTIME(?)', 1302241686), counter => sql_raw('counter + 1') ] );
        is $sql, qq{UPDATE `foo` SET `user_id` = ?, `updated_on` = FROM_UNIXTIME(?), `counter` = counter + 1};
        is join(',', @binds), '100,1302241686';
    };
};

subtest 'driver: mysql, quote_char: "", new_line: " "' => sub {
    my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
    subtest 'array ref, where cause(hashref)' => sub {
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com', expires => DateTime->new(year => 2025)], {user_id => 3});
        is $sql, qq{UPDATE user SET name = ?, email = ?, expires = ? WHERE (user_id = ?)};
        is join(',', @binds), 'john,john@example.com,2025-01-01T00:00:00,3';
    };

    subtest 'array ref, where cause(arrayref)' => sub {
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com', expires => DateTime->new(year => 2025)], [user_id => 3]);
        is $sql, qq{UPDATE user SET name = ?, email = ?, expires = ? WHERE (user_id = ?)};
        is join(',', @binds), 'john,john@example.com,2025-01-01T00:00:00,3';
    };

    subtest 'array ref, where cause(condition)' => sub {
        my $cond = $builder->new_condition;
        $cond->add(user_id => 3);
        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com'], $cond);
        is $sql, qq{UPDATE user SET name = ?, email = ? WHERE (user_id = ?)};
        is join(',', @binds), 'john,john@example.com,3';
    };

    subtest 'ordered hashref, where cause(hashref)' => sub {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), ordered_hashref(yo => 'king'));
        is $sql, qq{UPDATE foo SET bar = ?, john = ? WHERE (yo = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref, where cause(arrayref)' => sub {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), [yo => 'king']);
        is $sql, qq{UPDATE foo SET bar = ?, john = ? WHERE (yo = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref, where cause(condition)' => sub {
        my $cond = $builder->new_condition;
        $cond->add(yo => 'king');
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), $cond);
        is $sql, qq{UPDATE foo SET bar = ?, john = ? WHERE (yo = ?)};
        is join(',', @binds), 'baz,man,king';
    };

    subtest 'ordered hashref' => sub {
        # no where
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{UPDATE foo SET bar = ?, john = ?};
        is join(',', @binds), 'baz,man';
    };

    subtest 'literal, sub query' => sub {
        my ($sql, @binds) = $builder->update( 'foo', [ user_id => 100, updated_on => \['FROM_UNIXTIME(?)', 1302241686], counter => \'counter + 1' ] );
        is $sql, qq{UPDATE foo SET user_id = ?, updated_on = FROM_UNIXTIME(?), counter = counter + 1};
        is join(',', @binds), '100,1302241686';
    };

    subtest 'literal, sub query using term' => sub {
        my ($sql, @binds) = $builder->update( 'foo', [ user_id => 100, updated_on => sql_raw('FROM_UNIXTIME(?)', 1302241686), counter => sql_raw('counter + 1') ] );
        is $sql, qq{UPDATE foo SET user_id = ?, updated_on = FROM_UNIXTIME(?), counter = counter + 1};
        is join(',', @binds), '100,1302241686';
    };
};

done_testing;

