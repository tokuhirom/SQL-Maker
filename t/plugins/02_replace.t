use strict;
use warnings;
use Test::More;
use SQL::Builder;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

SQL::Builder->load_plugin('Replace');

subtest 'replace' => sub {
    my $builder = SQL::Builder->new(driver => 'sqlite');
    my ($sql, @binds) = $builder->replace('foo' => ordered_hashref(bar => 'baz', john => 'man'));
    is $sql, "REPLACE INTO foo\n(`bar`, `john`)\nVALUES (?, ?)\n";
    is join(',', @binds), 'baz,man';
};


done_testing;

