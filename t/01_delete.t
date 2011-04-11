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

subtest 'driver mysql' => sub {
    subtest 'simple' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{DELETE FROM `foo` WHERE (`bar` = ?) AND (`john` = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'delete all' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->delete('foo');
        is $sql, qq{DELETE FROM `foo`};
        is join(',', @binds), '';
    };
};

subtest 'driver mysql, quote_char: "", new_line: " "' => sub {
    subtest 'simple' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, qq{DELETE FROM foo WHERE (bar = ?) AND (john = ?)};
        is join(',', @binds), 'baz,man';
    };

    subtest 'delete all' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql', quote_char => '', new_line => ' ');
        my ($sql, @binds) = $builder->delete('foo');
        is $sql, qq{DELETE FROM foo};
        is join(',', @binds), '';
    };
};

done_testing;

