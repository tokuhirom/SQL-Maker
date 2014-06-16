use strict;
use warnings;
use Test::More;
use SQL::Maker;
use SQL::QueryMaker;
use Test::Requires 'DateTime';
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

SQL::Maker->load_plugin('InsertMulti');

subtest 'mysql' => sub {
    subtest 'insert_multi( $table, \@colvals, \%opts )' => sub {
        subtest 'ok' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_multi(
                'foo' => [
                    ordered_hashref( bar => 'baz', john => 'man' ),
                    ordered_hashref( bar => 'bee', john => 'row' )
                ]
            );
            is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?),\n(?, ?)";
            is join( ',', @binds ), 'baz,man,bee,row';
        };

        subtest 'confused' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_multi(
                'foo' => [
                    ordered_hashref( bar  => 'baz', john => 'man' ),
                    ordered_hashref( john => 'row', bar  => 'bee' )
                ]
            );
            is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?),\n(?, ?)";
            is join( ',', @binds ), 'baz,man,bee,row';
        };

        subtest 'insert ignore' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_multi(
                'foo' => [
                    ordered_hashref( bar => 'baz', john => 'man' ),
                    ordered_hashref( bar => 'bee', john => 'row' )
                ],
                +{ prefix => 'INSERT IGNORE' },
            );
            is $sql, "INSERT IGNORE `foo`\n(`bar`, `john`)\nVALUES (?, ?),\n(?, ?)";
            is join( ',', @binds ), 'baz,man,bee,row';
        };

        subtest 'on duplicate key update' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_multi(
                'foo' => [
                    ordered_hashref(
                        bar        => 'baz',
                        john       => 'man',
                        created_on => \"UNIX_TIMESTAMP()",
                        updated_on => \[ "UNIX_TIMESTAMP(?)", "2011-04-12" ],
                        expires    => DateTime->new(year => 2024),
                    ),
                    ordered_hashref(
                        bar        => 'bee',
                        john       => 'row',
                        created_on => \"UNIX_TIMESTAMP()",
                        updated_on => \[ "UNIX_TIMESTAMP(?)", "2011-04-13" ],
                        expires    => DateTime->new(year => 2025),
                    ),
                ],
                +{
                    update => ordered_hashref(
                        bar        => \"VALUES(bar)",
                        john       => "john",
                        updated_on => \[ "UNIX_TIMESTAMP(?)", "2011-04-14" ],
                        expires    => DateTime->new(year => 2025),
                    )
                },
            );
            is $sql, substr(<< 'SQL', 0, -1);
INSERT INTO `foo`
(`bar`, `john`, `created_on`, `updated_on`, `expires`)
VALUES (?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(?), ?),
(?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(?), ?)
ON DUPLICATE KEY UPDATE `bar` = VALUES(bar), `john` = ?, `updated_on` = UNIX_TIMESTAMP(?), `expires` = ?
SQL
            is join( ',', @binds ), 'baz,man,2011-04-12,2024-01-01T00:00:00,bee,row,2011-04-13,2025-01-01T00:00:00,john,2011-04-14,2025-01-01T00:00:00';
        };

subtest 'on duplicate key update (term)' => sub {
    my $builder = SQL::Maker->new( driver => 'mysql' );
    my ( $sql, @binds ) = $builder->insert_multi(
        'foo' => [
            ordered_hashref(
                bar        => 'baz',
                john       => 'man',
                created_on => sql_raw("UNIX_TIMESTAMP()"),
                updated_on => sql_raw("UNIX_TIMESTAMP(?)", "2011-04-12"),
            ),
            ordered_hashref(
                bar        => 'bee',
                john       => 'row',
                created_on => sql_raw("UNIX_TIMESTAMP()"),
                updated_on => sql_raw("UNIX_TIMESTAMP(?)", "2011-04-13"),
            ),
        ],
        +{
            update => ordered_hashref(
                bar        => \"VALUES(bar)",
                john       => "john",
                updated_on => sql_raw("UNIX_TIMESTAMP(?)", "2011-04-14"),
            )
        },
    );
    is $sql, substr(<< 'SQL', 0, -1);
INSERT INTO `foo`
(`bar`, `john`, `created_on`, `updated_on`)
VALUES (?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(?)),
(?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(?))
ON DUPLICATE KEY UPDATE `bar` = VALUES(bar), `john` = ?, `updated_on` = UNIX_TIMESTAMP(?)
SQL
    is join( ',', @binds ), 'baz,man,2011-04-12,bee,row,2011-04-13,john,2011-04-14';
};
    };

    subtest 'insert_multi( $table, \@cols, \@values, \%opts )' => sub {
        subtest 'ok' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_multi(
                'foo' => [qw/bar john/],
                [ [qw/baz man/], [qw/bee row/], ],
            );
            is $sql, "INSERT INTO `foo`\n(`bar`, `john`)\nVALUES (?, ?),\n(?, ?)";
            is join( ',', @binds ), 'baz,man,bee,row';
        };

        subtest 'insert ignore' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_multi(
                'foo' => [qw/bar john/],
                [ [qw/baz man/], [qw/bee row/], ],
                +{ prefix => 'INSERT IGNORE' },
            );
            is $sql, "INSERT IGNORE `foo`\n(`bar`, `john`)\nVALUES (?, ?),\n(?, ?)";
            is join( ',', @binds ), 'baz,man,bee,row';
        };

        subtest 'on duplicate key update' => sub {
            my $builder = SQL::Maker->new( driver => 'mysql' );
            my ( $sql, @binds ) = $builder->insert_multi(
                'foo' => [qw/bar john created_on updated_on/],
                [
                    [
                        'baz', 'man', \"UNIX_TIMESTAMP()",
                        \[ "UNIX_TIMESTAMP(?)", "2011-04-12" ]
                    ],
                    [
                        'bee', 'row', \"UNIX_TIMESTAMP()",
                        \[ "UNIX_TIMESTAMP(?)", "2011-04-13" ]
                    ],
                ],
                +{
                    update => [
                        bar        => \"VALUES(bar)",
                        john       => "john",
                        updated_on => \[ "UNIX_TIMESTAMP(?)", "2011-04-14" ],
                    ],
                },
            );
            is $sql, substr( << 'SQL', 0, -1 );
INSERT INTO `foo`
(`bar`, `john`, `created_on`, `updated_on`)
VALUES (?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(?)),
(?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(?))
ON DUPLICATE KEY UPDATE `bar` = VALUES(bar), `john` = ?, `updated_on` = UNIX_TIMESTAMP(?)
SQL
            is join( ',', @binds ),
              'baz,man,2011-04-12,bee,row,2011-04-13,john,2011-04-14';
        };
    };
};

done_testing;

