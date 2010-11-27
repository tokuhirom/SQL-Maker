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
    is $sql, "INSERT INTO foo\n(bar, john)\nVALUES (?, ?)\n";
    is join(',', @binds), 'baz,man';
};

subtest 'replace' => sub {
    my $builder = SQL::Builder->new(driver => 'sqlite');
    my ($sql, @binds) = $builder->replace('foo' => ordered_hashref(bar => 'baz', john => 'man'));
    is $sql, "REPLACE INTO foo\n(bar, john)\nVALUES (?, ?)\n";
    is join(',', @binds), 'baz,man';
};

subtest 'delete' => sub {
    my $builder = SQL::Builder->new(driver => 'sqlite');
    my ($sql, @binds) = $builder->delete('foo' => ordered_hashref(bar => 'baz', john => 'man'));
    is $sql, "DELETE FROM foo\nWHERE (bar = ?) AND (john = ?)\n";
    is join(',', @binds), 'baz,man';
};

subtest 'update' => sub {
    my $builder = SQL::Builder->new(driver => 'sqlite');
    {
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'), ordered_hashref(yo => 'king'));
        is $sql, "UPDATE foo SET bar = ?, john = ? WHERE (yo = ?)\n";
        is join(',', @binds), 'baz,man,king';
    }
    {
        # no where
        my ($sql, @binds) = $builder->update('foo' => ordered_hashref(bar => 'baz', john => 'man'));
        is $sql, "UPDATE foo SET bar = ?, john = ? ";
        is join(',', @binds), 'baz,man';
    }
};

done_testing;

