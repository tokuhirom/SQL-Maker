use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires qw(
    Tie::IxHash
    DBI
    DBD::SQLite
);

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'new with dbh of SQLite as driver' => sub {
    subtest 'driver: sqlite' => sub {
        my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:", "", "");
        my $builder = SQL::Maker->new(driver => $dbh);

        do {
            my $stmt = $builder->select_query('foo' => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'), {order_by => 'yo'});
            is $stmt->as_sql, qq{SELECT "foo", "bar"\nFROM "foo"\nWHERE ("bar" = ?) AND ("john" = ?)\nORDER BY yo};
            is join(',', $stmt->bind), 'baz,man';
        };
    };
};

done_testing;

