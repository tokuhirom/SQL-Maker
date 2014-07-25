use strict;
use warnings;

use SQL::Maker::Select;
use Test::More;

use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'PREFIX' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        subtest 'simple' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_select('*');
            $stmt->add_from('foo');
            is($stmt->as_sql, "SELECT *\nFROM `foo`");
        };

        subtest 'SQL_CALC_FOUND_ROWS' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->prefix('SELECT SQL_CALC_FOUND_ROWS ');
            $stmt->add_select('*');
            $stmt->add_from('foo');
            is($stmt->as_sql, "SELECT SQL_CALC_FOUND_ROWS *\nFROM `foo`");
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        subtest 'simple' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ });
            $stmt->add_select('*');
            $stmt->add_from('foo');
            is($stmt->as_sql, "SELECT * FROM foo");
        };

        subtest 'SQL_CALC_FOUND_ROWS' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->prefix('SELECT SQL_CALC_FOUND_ROWS ');
            $stmt->add_select('*');
            $stmt->add_from('foo');
            is($stmt->as_sql, "SELECT SQL_CALC_FOUND_ROWS * FROM foo");
        };
    };
};

subtest 'FROM' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        subtest 'single' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from('foo');
            is($stmt->as_sql, "FROM `foo`");
        };

        subtest 'multi' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_from( 'bar' );
            is($stmt->as_sql, "FROM `foo`, `bar`");
        };

        subtest 'multi + alias' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' => 'f' );
            $stmt->add_from( 'bar' => 'b' );
            is($stmt->as_sql, "FROM `foo` `f`, `bar` `b`");
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        subtest 'single' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_from('foo');
            is($stmt->as_sql, "FROM foo");
        };

        subtest 'multi' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, , new_line => q{ } );
            $stmt->add_from( 'foo' );
            $stmt->add_from( 'bar' );
            is($stmt->as_sql, "FROM foo, bar");
        };

        subtest 'multi + alias' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, , new_line => q{ } );
            $stmt->add_from( 'foo' => 'f' );
            $stmt->add_from( 'bar' => 'b' );
            is($stmt->as_sql, "FROM foo f, bar b");
        };
    };
};

subtest 'JOIN' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        subtest 'inner join' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                }
            );
            is($stmt->as_sql, "FROM `foo` INNER JOIN `baz`");
        };

        subtest 'inner join with condition' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => 'foo.baz_id = baz.baz_id'
                }
            );
            is($stmt->as_sql, "FROM `foo` INNER JOIN `baz` ON foo.baz_id = baz.baz_id");
        };

        subtest 'from and inner join with condition' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'bar' );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => 'foo.baz_id = baz.baz_id'
                }
            );
            is($stmt->as_sql, "FROM `foo` INNER JOIN `baz` ON foo.baz_id = baz.baz_id, `bar`");
        };

        subtest 'inner join with hash condition' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => {'foo.baz_id' => 'baz.baz_id'},
                }
            );
            is($stmt->as_sql, "FROM `foo` INNER JOIN `baz` ON `foo`.`baz_id` = `baz`.`baz_id`");
        };

        subtest 'inner join with hash condition with multi keys' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => ordered_hashref(
                        'foo.baz_id' => 'baz.baz_id',
                        'foo.status' => 'baz.status',
                    ),
                }
            );
            is($stmt->as_sql, "FROM `foo` INNER JOIN `baz` ON `foo`.`baz_id` = `baz`.`baz_id` AND `foo`.`status` = `baz`.`status`");
        };

        subtest 'test case for bug found where add_join is called twice' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    alias     => 'b1',
                    condition => 'foo.baz_id = b1.baz_id AND b1.quux_id = 1'
                },
            );
            $stmt->add_join(
                foo => {
                    type      => 'left',
                    table     => 'baz',
                    alias     => 'b2',
                    condition => 'foo.baz_id = b2.baz_id AND b2.quux_id = 2'
                },
            );
            is $stmt->as_sql, "FROM `foo` INNER JOIN `baz` `b1` ON foo.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN `baz` `b2` ON foo.baz_id = b2.baz_id AND b2.quux_id = 2";
        };

        subtest 'test case adding another table onto the whole mess' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    alias     => 'b1',
                    condition => 'foo.baz_id = b1.baz_id AND b1.quux_id = 1'
                },
            );
            $stmt->add_join(
                foo => {
                    type      => 'left',
                    table     => 'baz',
                    alias     => 'b2',
                    condition => 'foo.baz_id = b2.baz_id AND b2.quux_id = 2'
                },
            );
            $stmt->add_join(
                quux => {
                    type      => 'inner',
                    table     => 'foo',
                    alias     => 'f1',
                    condition => 'f1.quux_id = quux.q_id'
                }
            );

            is $stmt->as_sql, "FROM `foo` INNER JOIN `baz` `b1` ON foo.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN `baz` `b2` ON foo.baz_id = b2.baz_id AND b2.quux_id = 2 INNER JOIN `foo` `f1` ON f1.quux_id = quux.q_id";
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        subtest 'inner join' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                }
            );
            is($stmt->as_sql, "FROM foo INNER JOIN baz");
        };

        subtest 'inner join with condition' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => 'foo.baz_id = baz.baz_id'
                }
            );
            is($stmt->as_sql, "FROM foo INNER JOIN baz ON foo.baz_id = baz.baz_id");
        };

        subtest 'from and inner join with condition' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_from( 'bar' );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => 'foo.baz_id = baz.baz_id'
                }
            );
            is($stmt->as_sql, "FROM foo INNER JOIN baz ON foo.baz_id = baz.baz_id, bar");
        };

        subtest 'test case for bug found where add_join is called twice' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    alias     => 'b1',
                    condition => 'foo.baz_id = b1.baz_id AND b1.quux_id = 1'
                },
            );
            $stmt->add_join(
                foo => {
                    type      => 'left',
                    table     => 'baz',
                    alias     => 'b2',
                    condition => 'foo.baz_id = b2.baz_id AND b2.quux_id = 2'
                },
            );
            is $stmt->as_sql, "FROM foo INNER JOIN baz b1 ON foo.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN baz b2 ON foo.baz_id = b2.baz_id AND b2.quux_id = 2";
        };

        subtest 'test case adding another table onto the whole mess' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_join(
                foo => {
                    type      => 'inner',
                    table     => 'baz',
                    alias     => 'b1',
                    condition => 'foo.baz_id = b1.baz_id AND b1.quux_id = 1'
                },
            );
            $stmt->add_join(
                foo => {
                    type      => 'left',
                    table     => 'baz',
                    alias     => 'b2',
                    condition => 'foo.baz_id = b2.baz_id AND b2.quux_id = 2'
                },
            );
            $stmt->add_join(
                quux => {
                    type      => 'inner',
                    table     => 'foo',
                    alias     => 'f1',
                    condition => 'f1.quux_id = quux.q_id'
                }
            );

            is $stmt->as_sql, "FROM foo INNER JOIN baz b1 ON foo.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN baz b2 ON foo.baz_id = b2.baz_id AND b2.quux_id = 2 INNER JOIN foo f1 ON f1.quux_id = quux.q_id";
        };
    };
};


subtest 'GROUP BY' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz');
            is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz`", 'single bare group by');
        };

        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz' => 'DESC');
            is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz` DESC", 'single group by with desc');
        };

        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz');
            $stmt->add_group_by('quux');
            is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz`, `quux`", 'multiple group by');
        };

        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz',  'DESC');
            $stmt->add_group_by('quux', 'DESC');
            is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz` DESC, `quux` DESC", 'multiple group by with desc');
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz');
            is($stmt->as_sql, "FROM foo GROUP BY baz", 'single bare group by');
        };

        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz' => 'DESC');
            is($stmt->as_sql, "FROM foo GROUP BY baz DESC", 'single group by with desc');
        };

        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz');
            $stmt->add_group_by('quux');
            is($stmt->as_sql, "FROM foo GROUP BY baz, quux", 'multiple group by');
        };

        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_from( 'foo' );
            $stmt->add_group_by('baz',  'DESC');
            $stmt->add_group_by('quux', 'DESC');
            is($stmt->as_sql, "FROM foo GROUP BY baz DESC, quux DESC", 'multiple group by with desc');
        };
    };
};

subtest 'ORDER BY' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_order_by('baz' => 'DESC');
            is($stmt->as_sql, "FROM `foo`\nORDER BY `baz` DESC", 'single order by');
        };

        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_order_by( 'baz' => 'DESC' );
            $stmt->add_order_by( 'quux' => 'ASC' );
            is($stmt->as_sql, "FROM `foo`\nORDER BY `baz` DESC, `quux` ASC", 'multiple order by');
        };

        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_from( 'foo' );
            $stmt->add_order_by( \'baz DESC' );
            is($stmt->as_sql, "FROM `foo`\nORDER BY baz DESC", 'scalar ref'); # should not quote
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_from( 'foo' );
            $stmt->add_order_by('baz' => 'DESC');
            is($stmt->as_sql, "FROM foo ORDER BY baz DESC", 'single order by');
        };

        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ });
            $stmt->add_from( 'foo' );
            $stmt->add_order_by( 'baz' => 'DESC' );
            $stmt->add_order_by( 'quux' => 'ASC' );
            is($stmt->as_sql, "FROM foo ORDER BY baz DESC, quux ASC", 'multiple order by');
        };

        subtest 'scalarref' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ });
            $stmt->add_from( 'foo' );
            $stmt->add_order_by( \'baz DESC' );
            is($stmt->as_sql, "FROM foo ORDER BY baz DESC"); # should not quote
        };
    };
};

subtest 'GROUP BY + ORDER BY' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
        $stmt->add_from( 'foo' );
        $stmt->add_group_by('quux');
        $stmt->add_order_by('baz' => 'DESC');
        is($stmt->as_sql, "FROM `foo`\nGROUP BY `quux`\nORDER BY `baz` DESC", 'group by with order by');
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ });
        $stmt->add_from( 'foo' );
        $stmt->add_group_by('quux');
        $stmt->add_order_by('baz' => 'DESC');
        is($stmt->as_sql, "FROM foo GROUP BY quux ORDER BY baz DESC", 'group by with order by');
    };
};

subtest 'LIMIT OFFSET' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
        $stmt->add_from( 'foo' );
        $stmt->limit(5);
        is($stmt->as_sql, "FROM `foo`\nLIMIT 5");
        $stmt->offset(10);
        is($stmt->as_sql, "FROM `foo`\nLIMIT 5 OFFSET 10");
        $stmt->limit(0);
        is($stmt->as_sql, "FROM `foo`\nLIMIT 0 OFFSET 10");
        $stmt->limit("  15g");  ## Non-numerics should cause an error
        {
            my $sql = eval { $stmt->as_sql };
            like($@, qr/Non-numerics/, "bogus limit causes as_sql assertion");
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $stmt->add_from( 'foo' );
        $stmt->limit(5);
        is($stmt->as_sql, "FROM foo LIMIT 5");
        $stmt->offset(10);
        is($stmt->as_sql, "FROM foo LIMIT 5 OFFSET 10");
        $stmt->limit(0);
        is($stmt->as_sql, "FROM foo LIMIT 0 OFFSET 10");
        $stmt->limit("  15g");  ## Non-numerics should cause an error
        {
            my $sql = eval { $stmt->as_sql };
            like($@, qr/Non-numerics/, "bogus limit causes as_sql assertion");
        };
    };
};

subtest 'WHERE' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        subtest 'single equals' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_where(foo => 'bar');
            is($stmt->as_sql_where, "WHERE (`foo` = ?)\n");
            is(scalar @{ $stmt->bind }, 1);
            is($stmt->bind->[0], 'bar');
        };

        subtest 'single equals multi values is IN() statement' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_where(foo => [ 'bar', 'baz' ]);
            is($stmt->as_sql_where, "WHERE (`foo` IN (?, ?))\n");
            is(scalar @{ $stmt->bind }, 2);
            is($stmt->bind->[0], 'bar');
            is($stmt->bind->[1], 'baz');
        };

        subtest 'new condition, single equals multi values is IN() statement' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            my $cond =  $stmt->new_condition();
            $cond->add(foo => [ 'bar', 'baz' ]);
            $stmt->set_where($cond);
            is($stmt->as_sql_where, "WHERE (`foo` IN (?, ?))\n");
            is(scalar @{ $stmt->bind }, 2);
            is($stmt->bind->[0], 'bar');
            is($stmt->bind->[1], 'baz');
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        subtest 'single equals' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_where(foo => 'bar');
            is($stmt->as_sql_where, "WHERE (foo = ?) ");
            is(scalar @{ $stmt->bind }, 1);
            is($stmt->bind->[0], 'bar');
        };

        subtest 'single equals multi values is IN() statement' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_where(foo => [ 'bar', 'baz' ]);
            is($stmt->as_sql_where, "WHERE (foo IN (?, ?)) ");
            is(scalar @{ $stmt->bind }, 2);
            is($stmt->bind->[0], 'bar');
            is($stmt->bind->[1], 'baz');
        };

        subtest 'new condition, single equals multi values is IN() statement' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            my $cond =  $stmt->new_condition();
            $cond->add(foo => [ 'bar', 'baz' ]);
            $stmt->set_where($cond);
            is($stmt->as_sql_where, "WHERE (foo IN (?, ?)) ");
            is(scalar @{ $stmt->bind }, 2);
            is($stmt->bind->[0], 'bar');
            is($stmt->bind->[1], 'baz');
        };
    };
};

subtest 'add_select' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        subtest 'simple' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_select(foo => 'foo');
            $stmt->add_select('bar');
            $stmt->add_from( qw( baz ) );
            is($stmt->as_sql, "SELECT `foo`, `bar`\nFROM `baz`");
        };

        subtest 'with scalar ref' => sub {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_select('f.foo' => 'foo');
            $stmt->add_select(\'COUNT(*)' => 'count');
            $stmt->add_from( qw( baz ) );
            is($stmt->as_sql, "SELECT `f`.`foo`, COUNT(*) AS `count`\nFROM `baz`");
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        subtest 'simple' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_select(foo => 'foo');
            $stmt->add_select('bar');
            $stmt->add_from( qw( baz ) );
            is($stmt->as_sql, "SELECT foo, bar FROM baz");
        };

        subtest 'with scalar ref' => sub {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_select('f.foo' => 'foo');
            $stmt->add_select(\'COUNT(*)' => 'count');
            $stmt->add_from( qw( baz ) );
            is($stmt->as_sql, "SELECT f.foo, COUNT(*) AS count FROM baz");
        };
    };
};

# HAVING
subtest 'HAVING' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
        $stmt->add_select(foo => 'foo');
        $stmt->add_select(\'COUNT(*)' => 'count');
        $stmt->add_from( qw(baz) );
        $stmt->add_where(foo => 1);
        $stmt->add_group_by('baz');
        $stmt->add_order_by('foo' => 'DESC');
        $stmt->limit(2);
        $stmt->add_having(count => 2);
        is($stmt->as_sql, "SELECT `foo`, COUNT(*) AS `count`\nFROM `baz`\nWHERE (`foo` = ?)\nGROUP BY `baz`\nHAVING (COUNT(*) = ?)\nORDER BY `foo` DESC\nLIMIT 2");
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $stmt->add_select(foo => 'foo');
        $stmt->add_select(\'COUNT(*)' => 'count');
        $stmt->add_from( qw(baz) );
        $stmt->add_where(foo => 1);
        $stmt->add_group_by('baz');
        $stmt->add_order_by('foo' => 'DESC');
        $stmt->limit(2);
        $stmt->add_having(count => 2);
        is($stmt->as_sql, "SELECT foo, COUNT(*) AS count FROM baz WHERE (foo = ?) GROUP BY baz HAVING (COUNT(*) = ?) ORDER BY foo DESC LIMIT 2");
    };
};

subtest 'DISTINCT' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from( qw(baz) );
        is($stmt->as_sql, "SELECT `foo`\nFROM `baz`", "DISTINCT is absent by default");
        $stmt->distinct(1);
        is($stmt->as_sql, "SELECT DISTINCT `foo`\nFROM `baz`", "we can turn on DISTINCT");
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from( qw(baz) );
        is($stmt->as_sql, "SELECT foo FROM baz", "DISTINCT is absent by default");
        $stmt->distinct(1);
        is($stmt->as_sql, "SELECT DISTINCT foo FROM baz", "we can turn on DISTINCT");
    };
};

subtest 'index hint' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from( qw(baz) );
        is($stmt->as_sql, "SELECT `foo`\nFROM `baz`", "index hint is absent by default");
        $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
        is($stmt->as_sql, "SELECT `foo`\nFROM `baz` USE INDEX (`index_hint`)", "we can turn on USE INDEX");
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from( qw(baz) );
        is($stmt->as_sql, "SELECT foo FROM baz", "index hint is absent by default");
        $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
        is($stmt->as_sql, "SELECT foo FROM baz USE INDEX (index_hint)", "we can turn on USE INDEX");
    };

    subtest 'hint as scalar' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from( qw(baz) );
        $stmt->add_index_hint('baz' => 'index_hint');
        is($stmt->as_sql, "SELECT foo FROM baz USE INDEX (index_hint)", "we can turn on USE INDEX");
    };

    subtest 'hint as array ref' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from( qw(baz) );
        $stmt->add_index_hint('baz' => ['index_hint']);
        is($stmt->as_sql, "SELECT foo FROM baz USE INDEX (index_hint)", "we can turn on USE INDEX");
    };
};

subtest 'index hint with joins' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_select(foo => 'foo');
            $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
            $stmt->add_join(
                baz => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => 'baz.baz_id = foo.baz_id'
                }
            );
            is($stmt->as_sql, "SELECT `foo`\nFROM `baz` USE INDEX (`index_hint`) INNER JOIN `baz` ON baz.baz_id = foo.baz_id", 'USE INDEX with JOIN');
        };

        do {
            my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
            $stmt->add_select(foo => 'foo');
            $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
            $stmt->add_join(
                baz => {
                    type      => 'inner',
                    table     => 'baz',
                    alias     => 'b1',
                    condition => 'baz.baz_id = b1.baz_id AND b1.quux_id = 1'
                },
            );
            $stmt->add_join(
                baz => {
                    type      => 'left',
                    table     => 'baz',
                    alias     => 'b2',
                    condition => 'baz.baz_id = b2.baz_id AND b2.quux_id = 2'
                },
            );
            is($stmt->as_sql, "SELECT `foo`\nFROM `baz` USE INDEX (`index_hint`) INNER JOIN `baz` `b1` ON baz.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN `baz` `b2` ON baz.baz_id = b2.baz_id AND b2.quux_id = 2", 'USE INDEX with JOINs');
        };
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_select(foo => 'foo');
            $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
            $stmt->add_join(
                baz => {
                    type      => 'inner',
                    table     => 'baz',
                    condition => 'baz.baz_id = foo.baz_id'
                }
            );
            is($stmt->as_sql, "SELECT foo FROM baz USE INDEX (index_hint) INNER JOIN baz ON baz.baz_id = foo.baz_id", 'USE INDEX with JOIN');
        };

        do {
            my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
            $stmt->add_select(foo => 'foo');
            $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
            $stmt->add_join(
                baz => {
                    type      => 'inner',
                    table     => 'baz',
                    alias     => 'b1',
                    condition => 'baz.baz_id = b1.baz_id AND b1.quux_id = 1'
                },
            );
            $stmt->add_join(
                baz => {
                    type      => 'left',
                    table     => 'baz',
                    alias     => 'b2',
                    condition => 'baz.baz_id = b2.baz_id AND b2.quux_id = 2'
                },
            );
            is($stmt->as_sql, "SELECT foo FROM baz USE INDEX (index_hint) INNER JOIN baz b1 ON baz.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN baz b2 ON baz.baz_id = b2.baz_id AND b2.quux_id = 2", 'USE INDEX with JOINs');
        };
    };
};

subtest 'select + from' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $stmt = ns( quote_char => q{`}, name_sep => q{.}, );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from(qw(baz));
        is($stmt->as_sql, "SELECT `foo`\nFROM `baz`");
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $stmt = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $stmt->add_select(foo => 'foo');
        $stmt->add_from(qw(baz));
        is($stmt->as_sql, "SELECT foo FROM baz");
    };
};


subtest join_with_using => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $sql = ns( quote_char => q{`}, name_sep => q{.}, );
        $sql->add_join(
            foo => {
                type      => 'inner',
                table     => 'baz',
                condition => [qw/ hoge_id fuga_id /],
            },
        );

        is $sql->as_sql, "FROM `foo` INNER JOIN `baz` USING (`hoge_id`, `fuga_id`)";
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $sql = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $sql->add_join(
            foo => {
                type      => 'inner',
                table     => 'baz',
                condition => [qw/ hoge_id fuga_id /],
            },
        );

        is $sql->as_sql, "FROM foo INNER JOIN baz USING (hoge_id, fuga_id)";
    };
};

subtest 'add_where_raw' => sub {
    subtest 'quote_char: "`", name_sep: "."' => sub {
        my $sql = ns( quote_char => q{`}, name_sep => q{.}, );
        $sql->add_select( foo => 'foo' );
        $sql->add_from( 'baz' );
        $sql->add_where_raw( 'MATCH(foo) AGAINST (?)' => 'hoge' );

        is $sql->as_sql, "SELECT `foo`\nFROM `baz`\nWHERE (MATCH(foo) AGAINST (?))";
        is $sql->bind->[0], 'hoge';
    };

    subtest 'quote_char: "", name_sep: ".", new_line: " "' => sub {
        my $sql = ns( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
        $sql->add_select( foo => 'foo' );
        $sql->add_from( 'baz' );
        $sql->add_where_raw( 'MATCH(foo) AGAINST (?)' => 'hoge' );

        is $sql->as_sql, "SELECT foo FROM baz WHERE (MATCH(foo) AGAINST (?))";
        is $sql->bind->[0], 'hoge';
    };

    subtest 'multi values' => sub {
        my $sql = ns( quote_char => q{}, name_sep => q{.} );
        $sql->add_select( foo => 'foo' );
        $sql->add_from( 'baz' );
        $sql->add_where_raw( 'foo = IF(bar = ?, ?, ?)' => ['hoge', 'fuga', 'piyo'] );

        is $sql->as_sql, "SELECT foo\nFROM baz\nWHERE (foo = IF(bar = ?, ?, ?))";
        is $sql->bind->[0], 'hoge';
        is $sql->bind->[1], 'fuga';
        is $sql->bind->[2], 'piyo';
    };

    subtest 'without value' => sub {
        my $sql = ns( quote_char => q{}, name_sep => q{.} );
        $sql->add_select( foo => 'foo' );
        $sql->add_from( 'baz' );
        $sql->add_where_raw( 'foo IS NOT NULL' );

        is $sql->as_sql, "SELECT foo\nFROM baz\nWHERE (foo IS NOT NULL)";
        is scalar(@{$sql->bind}), 0;
    };
};

sub ns { SQL::Maker::Select->new(@_) }

done_testing;
