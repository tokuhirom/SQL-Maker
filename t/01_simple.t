use strict;
use warnings;
use Test::More;
use SQL::Builder;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'insert' => sub {
    my $builder = SQL::Builder->new(driver => 'sqlite');
    my ($sql, @binds) = $builder->insert('foo' => ordered_hashref(bar => 'baz', john => 'man'));
    is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n";
    is join(',', @binds), 'baz,man';
};

subtest 'delete' => sub {
    subtest 'simple' => sub {
        my $builder = SQL::Builder->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, "DELETE FROM `foo` WHERE (bar = ?) AND (john = ?)";
        is join(',', @binds), 'baz,man';
    };
    subtest 'delete all' => sub {
        my $builder = SQL::Builder->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->delete('foo');
        is $sql, "DELETE FROM `foo`";
        is join(',', @binds), '';
    };
};

subtest 'update' => sub {
    my $builder = SQL::Builder->new(driver => 'sqlite');
    {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), ordered_hashref(yo => 'king'));
        is $sql, "UPDATE `foo` SET `bar` = ?, `john` = ? WHERE (yo = ?)";
        is join(',', @binds), 'baz,man,king';
    }
    {
        # no where
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, "UPDATE `foo` SET `bar` = ?, `john` = ?";
        is join(',', @binds), 'baz,man';
    }
};

subtest 'select' => sub {
    my $builder = SQL::Builder->new(driver => 'sqlite');
    my ($sql, @binds) = $builder->select('foo' => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'), {order_by => 'yo'});
    is $sql, "SELECT foo, bar\nFROM foo\nWHERE (bar = ?) AND (john = ?)\nORDER BY yo\n";
    is join(',', @binds), 'baz,man';
};

done_testing;

