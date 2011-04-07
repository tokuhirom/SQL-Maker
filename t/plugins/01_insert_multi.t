use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

SQL::Maker->load_plugin('InsertMulti');

subtest 'insert_multi( $table, \@colvals, \%opts )' => sub {
    subtest 'ok' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->insert_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( bar => 'bee', john => 'row' )
	    ]
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)";
	is join(',', @binds), 'baz,man,bee,row';
    };

    subtest 'confused' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->insert_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( john => 'row', bar => 'bee' )
	    ]
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)";
	is join(',', @binds), 'baz,man,bee,row';
    };

    subtest 'insert ignore' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->insert_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( bar => 'bee', john => 'row' )
	    ],
	    +{ prefix => 'INSERT IGNORE' },
	);
	is $sql, "INSERT IGNORE `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)";
	is join(',', @binds), 'baz,man,bee,row';
    };
};

subtest 'insert_multi( $table, \@cols, \@values, \%opts )' => sub {
    subtest 'ok' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->insert_multi(
	    'foo' => [ qw/bar john/ ], [ [ qw/baz man/ ], [ qw/bee row/ ], ],
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)";
	is join(',', @binds), 'baz,man,bee,row';
    };

    subtest 'insert ignore' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->insert_multi(
	    'foo' => [ qw/bar john/ ], [ [ qw/baz man/ ], [ qw/bee row/ ], ],
	    +{ prefix => 'INSERT IGNORE' },
	);
	is $sql, "INSERT IGNORE `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)";
	is join(',', @binds), 'baz,man,bee,row';
    };
};

done_testing;

