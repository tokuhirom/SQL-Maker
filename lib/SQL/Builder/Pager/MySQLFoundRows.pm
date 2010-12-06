use strict;
use warnings;
use utf8;

package SQL::Builder::Pager::MySQLFoundRows;

sub paginate {
    my ($self, %args) = @_;

    for (qw/query dbh page rows/) {
        unless (exists $args{$_}) {
            Carp::croak("missing mandatory parameter: '$_'");
        }
    }

    my $stmt = $args{query};

    Carp::croak("limit attribute is already set")  if $stmt->limit;
    Carp::croak("offset attribute is already set") if $stmt->offset;

    $stmt->prefix('SELECT SQL_CALC_FOUND_ROWS ');
    $stmt->limit($args{rows});
    $stmt->offset($args{rows}*($args{page}-1));

    my $sth = $args{dbh}->prepare($stmt->as_sql) or Carp::croak $args{dbh}->errstr;
    $sth->execute($stmt->bind());
    my $ret = $sth->fetchall_arrayref(+{});
    my ($total_entries) = $args{dbh}->selectrow_array(q{SELECT FOUND_ROWS()});

    return ($ret, $total_entries);
}

1;
__END__

=for test_synopsis

my ($query, $table, %fields, %where, $dbh, $page, $rows);

=head1 NAME

SQL::Builder::Pager::MySQLFoundRows - Pager for SQL::Builder

=head1 SYNOPSIS

    my $stmt = $query->select($table, \%fields, \%where);
    my ($rows, $total_entries) = SQL::Builder::Pager::MySQLFoundRows->new(query => $stmt, dbh => $dbh, page => $page, rows => $rows);

=head1 DESCRIPTION

This is a pager assistance class for L<SQL::Builder>.

B<THIS CLASS WILL SPLIT FROM CORE DISTRIBUTION. IF YOU WANT TO USE THIS CLASS, DEPEND TO THIS CLASS DIRECTLY>.

=head1 METHODS

=over 4

=item my ($rows, $total_entries) = SQL::Builder::Pager::MySQLFoundRows->paginate(query => $stmt, dbh => $dbh, page => $page, rows => $rows);

Run the query with paginate.

Return values:

=over 4

=item \@rows: ArrayRef[HashRef]

Results of query.

=item $total_entries: Int

Return the total entries for this query without limitation.

=back

=back

=head1 AUTHOR

Tokuhiro Matsuno

=cut
