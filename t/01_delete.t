use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'driver sqlite' => sub {
    subtest 'simple where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{DELETE FROM "foo" WHERE ("bar" = ?) AND ("john" = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'simple where_as_arrayref' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->delete('foo' => [bar => 'baz', john => 'man']);
        is $sql, qq{DELETE FROM "foo" WHERE ("bar" = ?) AND ("john" = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'simple where_as_condition' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my $cond = $builder->new_condition;
        $cond->add(bar => 'baz');
        $cond->add(john => 'man');
        my ($sql, @binds) = $builder->delete('foo' => $cond);
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

subtest 'driver mysql' => sub {
    subtest 'simple where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{DELETE FROM `foo` WHERE (`bar` = ?) AND (`john` = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'simple where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->delete('foo' => [bar => 'baz', john => 'man']);
        is $sql, qq{DELETE FROM `foo` WHERE (`bar` = ?) AND (`john` = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'simple where_as_condition' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my $cond = $builder->new_condition;
        $cond->add(bar => 'baz');
        $cond->add(john => 'man');
        my ($sql, @binds) = $builder->delete('foo' => $cond);
        is $sql, qq{DELETE FROM `foo` WHERE (`bar` = ?) AND (`john` = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'delete all' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->delete('foo');
        is $sql, qq{DELETE FROM `foo`};
        is join(',', @binds), '';
    };

    subtest 'delete using where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->delete('foo', [bar => 'baz', john => 'man'], {using => 'bar'});
        is $sql, qq{DELETE FROM `foo` USING `bar` WHERE (`bar` = ?) AND (`john` = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'delete using array where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->delete('foo', [bar => 'baz', john => 'man'], {using => ['bar', 'qux']});
        is $sql, qq{DELETE FROM `foo` USING `bar`, `qux` WHERE (`bar` = ?) AND (`john` = ?)};
        is join(',', @binds), 'baz,man';
    };
};

subtest 'driver mysql, quote_char: "", new_line: " "' => sub {
    subtest 'simple where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{DELETE FROM foo WHERE (bar = ?) AND (john = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'simple where_as_arrayref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my ($sql, @binds) = $builder->delete('foo' => [bar => 'baz', john => 'man']);
        is $sql, qq{DELETE FROM foo WHERE (bar = ?) AND (john = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'simple where_as_condition' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my $cond = $builder->new_condition;
        $cond->add(bar => 'baz');
        $cond->add(john => 'man');
        my ($sql, @binds) = $builder->delete('foo' => $cond);
        is $sql, qq{DELETE FROM foo WHERE (bar = ?) AND (john = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'delete all' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my ($sql, @binds) = $builder->delete('foo');
        is $sql, qq{DELETE FROM foo};
        is join(',', @binds), '';
    };

    subtest 'delete using where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my ($sql, @binds) = $builder->delete('foo', [bar => 'baz', john => 'man'], {using => 'bar'});
        is $sql, qq{DELETE FROM foo USING bar WHERE (bar = ?) AND (john = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'delete using array where_as_hashref' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my ($sql, @binds) = $builder->delete('foo', [bar => 'baz', john => 'man'], {using => ['bar', 'qux']});
        is $sql, qq{DELETE FROM foo USING bar, qux WHERE (bar = ?) AND (john = ?)};
        is join(',', @binds), 'baz,man';
    };
};

done_testing;

