use strict;
use warnings;
use Test::More;
use Test::Requires 'DBD::SQLite';
use DBI;
use SQL::Builder::Pager;
use SQL::Builder;

my $dbh = DBI->connect('dbi:SQLite:', '', '', {RaiseError => 1});
$dbh->do(q{create table foo (b int)}) or die;
for my $i (1..32) {
    $dbh->do(q{INSERT INTO foo (b) values (?)}, {}, $i++);
}

subtest 'simple' => sub {
    my $builder = SQL::Builder->new(driver => 'SQLite');
    my $stmt = $builder->select_query(foo => [qw/b/], {});
    my ( $rows, $has_next ) = SQL::Builder::Pager->paginate(
        query => $stmt,
        dbh   => $dbh,
        page  => 1,
        rows  => 3,
    );
    is join(',', map { $_->{'b'} } @$rows), '1,2,3';
    ok $has_next, 'has_next';
};

subtest 'last' => sub {
    my $builder = SQL::Builder->new(driver => 'SQLite');
    my $stmt = $builder->select_query(foo => [qw/b/], {});
    my ( $rows, $has_next ) = SQL::Builder::Pager->paginate(
        query => $stmt,
        dbh   => $dbh,
        page  => 11,
        rows  => 3
    );
    is join(',', map { $_->{b} } @$rows), '31,32';
    ok !$has_next, 'has_next';
};

done_testing;

