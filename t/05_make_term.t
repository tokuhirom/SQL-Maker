use strict;
use warnings;
use Test::More;
use SQL::Builder::SQLType qw/sql_type/;
use SQL::Builder::Condition;
use Data::Dumper;
use DBI qw/:sql_types/;

open my $fh, '<', 'lib/SQL/Builder.pm' or die "cannot open file: $!";
# skip header
while (<$fh>) {
    last if /=head1 CONDITION CHEAT SHEET/;
}
my ($in, $query, @bind);
while (<$fh>) {
    $in = eval $1 if /IN:(.+)/;
    $query = eval $1 if /OUT QUERY:(.+)/;
    if (/OUT BIND:(.+)/) {
        @bind = eval $1;
        test($in, $query, \@bind);
    }
}
done_testing;
exit(0);

sub test {
    my ($source, $expected_term, $expected_bind) = @_;
    local $Data::Dumper::Terse  = 1;
    local $Data::Dumper::Indent = 0;

    subtest Dumper($source) => sub {
        my $cond = SQL::Builder::Condition->new(
            quote_char => q{`},
            name_sep   => q{.},
        );
        $cond->add(@$source);
        my $sql = $cond->as_sql;
        $sql =~ s/^\(//;
        $sql =~ s/\)$//;
        is $sql, $expected_term;
        is_deeply [$cond->bind], $expected_bind;
    };
}


