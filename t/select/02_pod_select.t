use strict;
use warnings;
use Test::More;
use SQL::Maker::SQLType qw/sql_type/;
use SQL::Maker::Select;
use Data::Dumper;
use DBI qw/:sql_types/;

open my $fh, '<', 'lib/SQL/Maker/Select.pm' or die "cannot open file: $!";
# skip header
while (<$fh>) {
    last if /=head1/;
}
my ($code, $expected);
while (<$fh>) {
    if (/^[ ]{4,}.*# => (.+)/) {
        note "---------------------- $1";
        $expected = eval $1;
        diag Dumper($@, $1) if $@;
        my $got = eval $code;
        diag Dumper($@, $code) if $@;
        $got =~ s/\n/ /g;
        $got =~ s/ +$//g;
        is $got, $expected;
    } elsif (/^[ ]{4,}(.+)/) {
        $code .= "$1\n";
    } else {
        $code = ''; # clear
    }
}
done_testing;
exit(0);

