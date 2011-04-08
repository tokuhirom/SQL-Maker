use strict;
use warnings;
use Test::More;
use Test::Requires 'DBD::SQLite';
use Data::Dumper;

my $code = compile('lib/SQL/Maker/SQLType.pm');
my $dbh = DBI->connect('dbi:SQLite:', '', '', {RaiseError => 1});
$dbh->do(q{CREATE TABLE foo (id, bar)});
$dbh->do(q{INSERT INTO foo VALUES (1, "oyoyo")});
$dbh->do(q{INSERT INTO foo VALUES (3, "bar")});
my $got = do {
    local *STDOUT;
    open *STDOUT, '>', \my $out;
    $code->();
    $out;
};
is $got, "3\n";

done_testing;exit(0);

sub compile {
    my $module = shift;

    my ($code, $line) = extract_synopsis($module);
    $code   = qq(#line $line "$module"\n sub { $code });
    my $subref = eval $code;
    die Dumper($@, $code) if $@;
    $subref;
}

sub extract_synopsis {
    my $file = shift;

    my $content = do {
        local $/;
        open my $fh, "<", $file or die "$file: $!";
        <$fh>;
    };

    my $code = ( $content =~ m/^=head1\s+SYNOPSIS(.+?)^=head1/ms )[0];
    my $line = ( $` || '' ) =~ tr/\n/\n/;

    return $code, $line - 1,
      ( $content =~ m/^=for\s+test_synopsis\s+(.+?)^=/msg );
}

