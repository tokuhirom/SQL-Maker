use strict;
use warnings;
use Test::More;
use SQL::Maker::SQLType qw/sql_type/;
use SQL::Maker::Condition;
use SQL::QueryMaker;
use DBI qw/:sql_types/;

open my $fh, '<', 'lib/SQL/Maker/Condition.pm' or die "cannot open file: $!";
# skip header
while (<$fh>) {
    last if /=head1 CONDITION CHEAT SHEET/;
}
my ($in, $query, @bind);
while (<$fh>) {
    $in = $1 if /IN:\s*(.+)\s*$/;
    $query = eval $1 if /OUT QUERY:(.+)/;
    if (/OUT BIND:(.+)/) {
        @bind = eval $1;
        test($in, $query, \@bind);
    }
}
done_testing;
exit(0);

sub test {
    my ($in, $expected_term, $expected_bind) = @_;

    subtest $in => sub {
        my $source = do {
            local $@;
            my $source = eval $in;
            die $@ if $@;
            $source;
        };
        my $cond = SQL::Maker::Condition->new(
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


