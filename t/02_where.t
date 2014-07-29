use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

require_ok("FooTime");

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'driver: sqlite' => sub {
    my $builder = SQL::Maker->new(driver => 'sqlite');

    subtest 'none' => sub {
        my ($sql, @binds) = $builder->where( {} );
        is $sql, qq{};
        is join(',', @binds), '';
    };

    subtest 'simple' => sub {
        my ($sql, @binds) = $builder->where( {x => 3} );
        is $sql, qq{("x" = ?)};
        is join(',', @binds), '3';
    };

    subtest 'array' => sub {
        my ($sql, @binds) = $builder->where( [x => 3] );
        is $sql, qq{("x" = ?)};
        is join(',', @binds), '3';
    };

    subtest 'hash-stringify' => sub {
        my ($sql, @binds) = $builder->where({ x => FooTime->new(year => 2025) });
        is $sql, qq{("x" = ?)};
        is join(',', @binds), '2025-01-01T00:00:00';
    };

    subtest 'hash-stringify' => sub {
        my ($sql, @binds) = $builder->where([x => FooTime->new(year => 2025)]);
        is $sql, qq{("x" = ?)};
        is join(',', @binds), '2025-01-01T00:00:00';
    };
};

done_testing;
