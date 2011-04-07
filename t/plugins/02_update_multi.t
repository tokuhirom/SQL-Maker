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

subtest 'update_multi( $table, \@colvals, $sets, $opts )' => sub {
    subtest 'ok' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( bar => 'bee', john => 'row' )
	    ],
	    +{ bar => 'test' },
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = ?";
	is join(',', @binds), 'baz,man,bee,row,test';
    };

    subtest 'scalar ref' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( bar => 'bee', john => 'row' )
	    ],
	    +{ bar => \'VALUES(bar)' },
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = VALUES(bar)";
	is join(',', @binds), 'baz,man,bee,row';
    };

    subtest 'array ref' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( bar => 'bee', john => 'row' )
	    ],
	    +{ bar => \[ 'CONCAT(bar, ?)', 'hoge', ] },
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = CONCAT(bar, ?)";
	is join(',', @binds), 'baz,man,bee,row,hoge';
    };

    subtest 'confused' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( john => 'row', bar => 'bee' )
	    ],
	    ordered_hashref( bar => \[ 'CONCAT(bar, ?)', 'hoge', ], john => \'VALUES(john)', updated_on => '2011-04-01 11:12:33', ),
	);
        is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = CONCAT(bar, ?), `john` = VALUES(john), `updated_on` = ?";
	is join(',', @binds), 'baz,man,bee,row,hoge,2011-04-01 11:12:33';
    };

    subtest 'sets as array ref' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo' => [
		ordered_hashref( bar => 'baz', john => 'man' ),
		ordered_hashref( john => 'row', bar => 'bee' )
	    ],
	    [ bar => \[ 'CONCAT(bar, ?)', 'hoge', ], john => \'VALUES(john)', updated_on => '2011-04-01 11:12:33', ],
	);
        is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = CONCAT(bar, ?), `john` = VALUES(john), `updated_on` = ?";
	is join(',', @binds), 'baz,man,bee,row,hoge,2011-04-01 11:12:33';
    };
};

subtest 'update_multi( $table, \@colvals, $sets, $opts )' => sub {
    subtest 'ok' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo',
	    [qw/bar john/],
	    [ [ qw/baz man/ ], [ qw/bee row/ ] ],
	    +{ bar => 'test' },
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = ?";
	is join(',', @binds), 'baz,man,bee,row,test';
    };

    subtest 'scalar ref' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo',
	    [qw/bar john/],
	    [ [ qw/baz man/ ], [ qw/bee row/ ] ],
	    +{ bar => \'VALUES(bar)' },
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = VALUES(bar)";
	is join(',', @binds), 'baz,man,bee,row';
    };

    subtest 'array ref' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo',
	    [qw/bar john/],
	    [ [ qw/baz man/ ], [ qw/bee row/ ] ],
	    +{ bar => \[ 'CONCAT(bar, ?)', 'hoge', ] },
	);
	is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = CONCAT(bar, ?)";
	is join(',', @binds), 'baz,man,bee,row,hoge';
    };

    subtest 'confused' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo',
	    [qw/bar john/],
	    [ [ qw/baz man/ ], [ qw/bee row/ ] ],
	    ordered_hashref( bar => \[ 'CONCAT(bar, ?)', 'hoge', ], john => \'VALUES(john)', updated_on => '2011-04-01 11:12:33', ),
	);
        is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = CONCAT(bar, ?), `john` = VALUES(john), `updated_on` = ?";
	is join(',', @binds), 'baz,man,bee,row,hoge,2011-04-01 11:12:33';
    };

    subtest 'sets as array ref' => sub {
	my $builder = SQL::Maker->new(driver => 'mysql');
	my ( $sql, @binds ) = $builder->update_multi(
	    'foo',
	    [qw/bar john/],
	    [ [ qw/baz man/ ], [ qw/bee row/ ] ],
	    [ bar => \[ 'CONCAT(bar, ?)', 'hoge', ], john => \'VALUES(john)', updated_on => '2011-04-01 11:12:33', ],
	);
        is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\n,(?, ?)\nON DUPLICATE KEY UPDATE `bar` = CONCAT(bar, ?), `john` = VALUES(john), `updated_on` = ?";
	is join(',', @binds), 'baz,man,bee,row,hoge,2011-04-01 11:12:33';
    };
};

done_testing;
