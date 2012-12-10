use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

SQL::Maker->load_plugin('InsertOnDuplicate');

subtest 'mysql' => sub {
    subtest 'insert_multi( $table, \@colvals, \%opts )' => sub {
        subtest 'ok' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_on_duplicate(
                'foo',
                ordered_hashref( bar => 'baz', john => 'man' ),
                ordered_hashref( bar => 'bee', john => 'row' )
            );
            is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?)\nON DUPLICATE KEY UPDATE `bar` = ?, `john` = ?";
            is join( ',', @binds ), 'baz,man,bee,row';
        };
    };
};

done_testing;
