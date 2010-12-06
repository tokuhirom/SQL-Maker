use strict;
use warnings;
use Test::More;
use Test::Requires 'DBD::mysql', 'Test::mysqld';
use DBI;
use SQL::Builder::Pager::MySQLFoundRows;
use SQL::Builder;

my $mysqld = Test::mysqld->new(
    my_cnf => {
        'skip-networking' => '',    # no TCP socket
    }
) or plan skip_all => $Test::mysqld::errstr;

my $dbh = DBI->connect($mysqld->dsn);
$dbh->do(q{create table foo (b integer not null) TYPE=InnoDB}) or die;
for my $i (1..32) {
    $dbh->do(q{INSERT INTO foo (b) values (?)}, {}, $i++);
}

subtest 'simple' => sub {
    my $builder = SQL::Builder->new(driver => 'mysql');
    my $stmt = $builder->select_query(foo => [qw/b/], {});
    my ( $rows, $total_entries ) =
      SQL::Builder::Pager::MySQLFoundRows->paginate(
        query => $stmt,
        dbh   => $dbh,
        page  => 1,
        rows  => 3
      );
    is join(',', map { $_->{'b'} } @$rows), '1,2,3';
    is $total_entries, 32;
};

subtest 'last' => sub {
    my $builder = SQL::Builder->new(driver => 'mysql');
    my $stmt = $builder->select_query(foo => [qw/b/], {});
    my ( $rows, $total_entries ) =
      SQL::Builder::Pager::MySQLFoundRows->paginate(
        query => $stmt,
        dbh   => $dbh,
        page  => 11,
        rows  => 3
      );
    is join(',', map { $_->{'b'} } @$rows), '31,32';
    is $total_entries, 32;
};

done_testing;


