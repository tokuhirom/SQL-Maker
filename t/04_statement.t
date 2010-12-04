use strict;
use warnings;

use SQL::Builder::Select;
use Test::More;

subtest 'PREFIX' => sub {
    subtest 'simple' => sub {
        my $stmt = ns();
        $stmt->add_select('*');
        $stmt->add_from('foo');
        is($stmt->as_sql, "SELECT *\nFROM `foo`\n");
    };

    subtest 'SQL_CALC_FOUND_ROWS' => sub {
        my $stmt = ns();
        $stmt->prefix('SELECT SQL_CALC_FOUND_ROWS ');
        $stmt->add_select('*');
        $stmt->add_from('foo');
        is($stmt->as_sql, "SELECT SQL_CALC_FOUND_ROWS *\nFROM `foo`\n");
    };
};

subtest 'FROM' => sub {
    subtest 'single' => sub {
        my $stmt = ns();
        $stmt->add_from('foo');
        is($stmt->as_sql, "FROM `foo`\n");
    };

    subtest 'multi' => sub {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_from( 'bar' );
        is($stmt->as_sql, "FROM `foo`, `bar`\n");
    };

    subtest 'multi + alias' => sub {
        my $stmt = ns();
        $stmt->add_from( 'foo' => 'f' );
        $stmt->add_from( 'bar' => 'b' );
        is($stmt->as_sql, "FROM `foo` `f`, `bar` `b`\n");
    };
};

subtest 'JOIN' => sub {
    do {
        my $stmt = ns();
        $stmt->add_join(
            foo => {
                type      => 'inner',
                table     => 'baz',
                condition => 'foo.baz_id = baz.baz_id'
            }
        );
        is($stmt->as_sql, "FROM `foo` INNER JOIN `baz` ON foo.baz_id = baz.baz_id\n");
    };

    do {
        my $stmt = ns();
        $stmt->add_from( 'bar' );
        $stmt->add_join(
            foo => {
                type      => 'inner',
                table     => 'baz',
                condition => 'foo.baz_id = baz.baz_id'
            }
        );
        is($stmt->as_sql, "FROM `foo` INNER JOIN `baz` ON foo.baz_id = baz.baz_id, `bar`\n");
    };

    subtest 'test case for bug found where add_join is called twice' => sub {
        my $stmt = ns();
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
        is $stmt->as_sql, "FROM `foo` INNER JOIN `baz` `b1` ON foo.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN `baz` `b2` ON foo.baz_id = b2.baz_id AND b2.quux_id = 2\n";
    };

    subtest 'test case adding another table onto the whole mess' => sub {
        my $stmt = ns();
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

        is $stmt->as_sql, "FROM `foo` INNER JOIN `baz` `b1` ON foo.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN `baz` `b2` ON foo.baz_id = b2.baz_id AND b2.quux_id = 2 INNER JOIN `foo` `f1` ON f1.quux_id = quux.q_id\n";
    };
};


subtest 'GROUP BY' => sub {
    do {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_group_by('baz');
        is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz`\n", 'single bare group by');
    };

    do {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_group_by('baz' => 'DESC');
        is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz` DESC\n", 'single group by with desc');
    };

    do {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_group_by('baz');
        $stmt->add_group_by('quux');
        is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz`, `quux`\n", 'multiple group by');
    };

    do {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_group_by('baz',  'DESC');
        $stmt->add_group_by('quux', 'DESC');
        is($stmt->as_sql, "FROM `foo`\nGROUP BY `baz` DESC, `quux` DESC\n", 'multiple group by with desc');
    };
};

subtest 'ORDER BY' => sub {
    do {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_order_by('baz' => 'DESC');
        is($stmt->as_sql, "FROM `foo`\nORDER BY `baz` DESC\n", 'single order by');
    };

    do {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_order_by( 'baz' => 'DESC' );
        $stmt->add_order_by( 'quux' => 'ASC' );
        is($stmt->as_sql, "FROM `foo`\nORDER BY `baz` DESC, `quux` ASC\n", 'multiple order by');
    };

    subtest 'scalarref' => sub {
        my $stmt = ns();
        $stmt->add_from( 'foo' );
        $stmt->add_order_by( \'baz DESC' );
        is($stmt->as_sql, "FROM `foo`\nORDER BY baz DESC\n"); # should not quote
    };
};

subtest 'GROUP BY + ORDER BY' => sub {
    my $stmt = ns();
    $stmt->add_from( 'foo' );
    $stmt->add_group_by('quux');
    $stmt->add_order_by('baz' => 'DESC');
    is($stmt->as_sql, "FROM `foo`\nGROUP BY `quux`\nORDER BY `baz` DESC\n", 'group by with order by');
};

subtest 'LIMIT OFFSET' => sub {
    my $stmt = ns();
    $stmt->add_from( 'foo' );
    $stmt->limit(5);
    is($stmt->as_sql, "FROM `foo`\nLIMIT 5\n");
    $stmt->offset(10);
    is($stmt->as_sql, "FROM `foo`\nLIMIT 5 OFFSET 10\n");
    $stmt->limit("  15g");  ## Non-numerics should cause an error
    {
        my $sql = eval { $stmt->as_sql };
        like($@, qr/Non-numerics/, "bogus limit causes as_sql assertion");
    }
};

subtest 'WHERE' => sub {
    do {
        my $stmt = ns();
        $stmt->where->add(foo => 'bar');
        is($stmt->as_sql_where, "WHERE (foo = ?)\n");
        is(scalar @{ $stmt->bind }, 1);
        is($stmt->bind->[0], 'bar');
    };

    do {
        my $stmt = ns(); $stmt->where->add(foo => [ 'bar', 'baz' ]);
        is($stmt->as_sql_where, "WHERE (foo IN (?,?))\n");
        is(scalar @{ $stmt->bind }, 2);
        is($stmt->bind->[0], 'bar');
        is($stmt->bind->[1], 'baz');
    };

    do {
        my $stmt = ns(); $stmt->where->add(foo => { in => [ 'bar', 'baz' ]});
        is($stmt->as_sql_where, "WHERE (foo IN (?,?))\n");
        is(scalar @{ $stmt->bind }, 2);
        is($stmt->bind->[0], 'bar');
        is($stmt->bind->[1], 'baz');
    };

    do {
        my $stmt = ns(); $stmt->where->add(foo => { 'not in' => [ 'bar', 'baz' ]});
        is($stmt->as_sql_where, "WHERE (foo NOT IN (?,?))\n");
        is(scalar @{ $stmt->bind }, 2);
        is($stmt->bind->[0], 'bar');
        is($stmt->bind->[1], 'baz');
    };

    do {
        my $stmt = ns(); $stmt->where->add(foo => { '!=' => 'bar' });
        is($stmt->as_sql_where, "WHERE (foo != ?)\n");
        is(scalar @{ $stmt->bind }, 1);
        is($stmt->bind->[0], 'bar');
    };

    do {
        my $stmt = ns(); $stmt->where->add(foo => \'IS NOT NULL');
        is($stmt->as_sql_where, "WHERE (foo IS NOT NULL)\n");
        is(scalar @{ $stmt->bind }, 0);
    };

    do {
        my $stmt = ns(); $stmt->where->add(foo => {between => [1, 2]});
        is($stmt->as_sql_where, "WHERE (foo BETWEEN ? AND ?)\n");
        is(join(',', @{ $stmt->bind }), '1,2');
    };

    do {
        my $stmt = ns(); $stmt->where->add(foo => {like => 'xaic%'});
        is($stmt->as_sql_where, "WHERE (foo LIKE ?)\n");
        is(join(',', @{ $stmt->bind }), 'xaic%');
    };

    do {
        my $stmt = ns();
        $stmt->where->add(foo => 'bar');
        $stmt->where->add(baz => 'quux');
        is($stmt->as_sql_where, "WHERE (foo = ?) AND (baz = ?)\n");
        is(scalar @{ $stmt->bind }, 2);
        is($stmt->bind->[0], 'bar');
        is($stmt->bind->[1], 'quux');
    };

    do {
        my $stmt = ns();
        $stmt->where->add(foo => [ { '>' => 'bar' },
                                { '<' => 'baz' } ]);
        is($stmt->as_sql_where, "WHERE ((foo > ?) OR (foo < ?))\n");
        is(scalar @{ $stmt->bind }, 2);
        is($stmt->bind->[0], 'bar');
        is($stmt->bind->[1], 'baz');
    };

    do {
        my $stmt = ns();
        $stmt->where->add(foo => [ -and => { '>' => 'bar' },
                                        { '<' => 'baz' } ]);
        is($stmt->as_sql_where, "WHERE ((foo > ?) AND (foo < ?))\n");
        is(scalar @{ $stmt->bind }, 2);
        is($stmt->bind->[0], 'bar');
        is($stmt->bind->[1], 'baz');
    };

    do {
        my $stmt = ns();
        $stmt->where->add(foo => [ -and => 'foo', 'bar', 'baz']);
        is($stmt->as_sql_where, "WHERE ((foo = ?) AND (foo = ?) AND (foo = ?))\n");
        is(scalar @{ $stmt->bind }, 3);
        is($stmt->bind->[0], 'foo');
        is($stmt->bind->[1], 'bar');
        is($stmt->bind->[2], 'baz');
    };

    ## regression bug. modified parameters
    do {
        my %terms = ( foo => [-and => 'foo', 'bar', 'baz']);
        my $stmt = ns();
        $stmt->where->add(%terms);
        is($stmt->as_sql_where, "WHERE ((foo = ?) AND (foo = ?) AND (foo = ?))\n");
        $stmt->where->add(%terms);
        is($stmt->as_sql_where, "WHERE ((foo = ?) AND (foo = ?) AND (foo = ?)) AND ((foo = ?) AND (foo = ?) AND (foo = ?))\n");
    };
};

subtest 'add_select' => sub {
    do {
        my $stmt = ns();
        $stmt->add_select(foo => 'foo');
        $stmt->add_select('bar');
        $stmt->add_from( qw( baz ) );
        is($stmt->as_sql, "SELECT `foo`, `bar`\nFROM `baz`\n");
    };

    do {
        my $stmt = ns();
        $stmt->add_select('f.foo' => 'foo');
        $stmt->add_select(\'COUNT(*)' => 'count');
        $stmt->add_from( qw( baz ) );
        is($stmt->as_sql, "SELECT `f`.`foo`, COUNT(*) AS `count`\nFROM `baz`\n");
    };
};

# HAVING
subtest 'HAVING' => sub {
    my $stmt = ns();
    $stmt->add_select(foo => 'foo');
    $stmt->add_select(\'COUNT(*)' => 'count');
    $stmt->add_from( qw(baz) );
    $stmt->where->add(foo => 1);
    $stmt->add_group_by('baz');
    $stmt->add_order_by('foo' => 'DESC');
    $stmt->limit(2);
    $stmt->add_having(count => 2);

    is($stmt->as_sql, <<SQL);
SELECT `foo`, COUNT(*) AS `count`
FROM `baz`
WHERE (foo = ?)
GROUP BY `baz`
HAVING (COUNT(*) = ?)
ORDER BY `foo` DESC
LIMIT 2
SQL
};

subtest 'DISTINCT' => sub {
    my $stmt = ns();
    $stmt->add_select(foo => 'foo');
    $stmt->add_from( qw(baz) );
    is($stmt->as_sql, "SELECT `foo`\nFROM `baz`\n", "DISTINCT is absent by default");
    $stmt->distinct(1);
    is($stmt->as_sql, "SELECT DISTINCT `foo`\nFROM `baz`\n", "we can turn on DISTINCT");
};

subtest 'index hint' => sub {
    my $stmt = ns();
    $stmt->add_select(foo => 'foo');
    $stmt->add_from( qw(baz) );
    is($stmt->as_sql, "SELECT `foo`\nFROM `baz`\n", "index hint is absent by default");
    $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
    is($stmt->as_sql, "SELECT `foo`\nFROM `baz` USE INDEX (`index_hint`)\n", "we can turn on USE INDEX");
};

subtest 'index hint with joins' => sub {
    do {
        my $stmt = ns();
        $stmt->add_select(foo => 'foo');
        $stmt->add_index_hint('baz' => { type => 'USE', list => ['index_hint']});
        $stmt->add_join(
            baz => {
                type      => 'inner',
                table     => 'baz',
                condition => 'baz.baz_id = foo.baz_id'
            }
        );
        is($stmt->as_sql, "SELECT `foo`\nFROM `baz` USE INDEX (`index_hint`) INNER JOIN `baz` ON baz.baz_id = foo.baz_id\n", 'USE INDEX with JOIN');
    };
    do {
        my $stmt = ns();
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
        is($stmt->as_sql, "SELECT `foo`\nFROM `baz` USE INDEX (`index_hint`) INNER JOIN `baz` `b1` ON baz.baz_id = b1.baz_id AND b1.quux_id = 1 LEFT JOIN `baz` `b2` ON baz.baz_id = b2.baz_id AND b2.quux_id = 2\n", 'USE INDEX with JOINs');
    };
};

subtest 'select + from' => sub {
    my $stmt = ns();
    $stmt->add_select(foo => 'foo');
    $stmt->add_from(qw(baz));
    is($stmt->as_sql, "SELECT `foo`\nFROM `baz`\n");
};


subtest join_with_using => sub {
    my $sql = ns();
    $sql->add_join(
        foo => {
            type      => 'inner',
            table     => 'baz',
            condition => [qw/ hoge_id fuga_id /],
        },
    );

    is $sql->as_sql, "FROM `foo` INNER JOIN `baz` USING (hoge_id, fuga_id)\n";
};

sub ns { SQL::Builder::Select->new(quote_char => q{`}, name_sep => q{.}) }

done_testing;
