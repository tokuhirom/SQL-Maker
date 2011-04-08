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
    subtest 'hash column-value' => sub {
	my $builder = SQL::Maker->new(driver => 'sqlite');
	my ($sql, @binds) = $builder->insert('foo' => ordered_hashref(bar => 'baz', john => 'man', created_on => \"datetime('now')" ));
	is $sql, qq{INSERT INTO "foo"\n("bar", "john", "created_on")\nVALUES (?, ?, datetime('now'))};
	is join(',', @binds), 'baz,man';
    };

    subtest 'array column-value' => sub {
	my $builder = SQL::Maker->new(driver => 'sqlite');
	my ($sql, @binds) = $builder->insert('foo' => [ bar => 'baz', john => 'man', created_on => \"datetime('now')" ]);
	is $sql, qq{INSERT INTO "foo"\n("bar", "john", "created_on")\nVALUES (?, ?, datetime('now'))};
	is join(',', @binds), 'baz,man';
    };

    subtest 'insert ignore, hash column-value' => sub {
	my $builder = SQL::Maker->new(driver => 'sqlite');
	my ($sql, @binds) = $builder->insert('foo' => ordered_hashref( bar => 'baz', john => 'man', created_on => \"datetime('now')" ), +{ prefix => 'INSERT IGNORE' });
	is $sql, qq{INSERT IGNORE "foo"\n("bar", "john", "created_on")\nVALUES (?, ?, datetime('now'))};
	is join(',', @binds), 'baz,man';
    };

    subtest 'insert ignore, array column-value' => sub {
	my $builder = SQL::Maker->new(driver => 'sqlite');
	my ($sql, @binds) = $builder->insert('foo' => [ bar => 'baz', john => 'man', created_on => \"datetime('now')" ], +{ prefix => 'INSERT IGNORE' });
	is $sql, qq{INSERT IGNORE "foo"\n("bar", "john", "created_on")\nVALUES (?, ?, datetime('now'))};
	is join(',', @binds), 'baz,man';
    };
};

#subtest 'driver mysql' => sub {
#};

done_testing;
