use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

use SQL::Maker::SelectSet qw(union union_all intersect intersect_all except except_all);

sub ns {
    SQL::Maker::Select->new( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
}

subtest 'basic' => sub {

my $s1 = ns()
    ->add_from( 'table1' )
    ->add_select( 'id' )
    ->add_where( foo => 100 );

my $s2 = ns()
    ->add_from( 'table2' )
    ->add_select( 'id' )
    ->add_where( bar => 200 );

my $s3 = ns()
    ->add_from( 'table3' )
    ->add_select( 'id' )
    ->add_where( baz => 300 );


subtest 'error' => sub {
    eval { union( 1, 2 ) };
    ok( $@ );

    eval { SQL::Maker::SelectSet->union( $s1, $s2 ) };
    ok( $@ );;

    eval { SQL::Maker::SelectSet->union( $s1 ) };
    ok( $@ );
};

subtest 'union' => sub {
    my $set = union( $s1, $s2 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) UNION SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '100, 200';

    $set = union( $set, $s3 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) UNION SELECT id FROM table2 WHERE (bar = ?) UNION SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = union( $s3, union( $s1, $s2 ) );
    is $set->as_sql, qq{SELECT id FROM table3 WHERE (baz = ?) UNION SELECT id FROM table1 WHERE (foo = ?) UNION SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    $set = union_all( $s1, $s2 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) UNION ALL SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '100, 200';

    $set->add_order_by( 'id' );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) UNION ALL SELECT id FROM table2 WHERE (bar = ?) ORDER BY id};
    is join(', ', $set->bind), '100, 200';

    $set = union( union( $s3, $s1 ), $s2 );
    is $set->as_sql, qq{SELECT id FROM table3 WHERE (baz = ?) UNION SELECT id FROM table1 WHERE (foo = ?) UNION SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    $set = union( union( $s1, $s2 ), union( $s2, $s3) );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) UNION SELECT id FROM table2 WHERE (bar = ?) UNION SELECT id FROM table2 WHERE (bar = ?) UNION SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 200, 300';
};

subtest 'intersect' => sub {
    my $set = intersect( $s1, $s2 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) INTERSECT SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '100, 200';

    $set = intersect( $set, $s3);
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) INTERSECT SELECT id FROM table2 WHERE (bar = ?) INTERSECT SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = intersect( $s3, intersect( $s1, $s2 ) );
    is $set->as_sql, qq{SELECT id FROM table3 WHERE (baz = ?) INTERSECT SELECT id FROM table1 WHERE (foo = ?) INTERSECT SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    $set = intersect_all( $s1, $s2 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) INTERSECT ALL SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '100, 200';

    $set->add_order_by( 'id' );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) INTERSECT ALL SELECT id FROM table2 WHERE (bar = ?) ORDER BY id};
    is join(', ', $set->bind), '100, 200';
};

subtest 'except' => sub {
    my $set = except( $s1, $s2 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '100, 200';

    $set = except( $set, $s3 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT SELECT id FROM table2 WHERE (bar = ?) EXCEPT SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = except( $s3, except( $s1, $s2 ) );
    is $set->as_sql, qq{SELECT id FROM table3 WHERE (baz = ?) EXCEPT SELECT id FROM table1 WHERE (foo = ?) EXCEPT SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    $set = except_all( $s1, $s2 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT ALL SELECT id FROM table2 WHERE (bar = ?)};
    is join(', ', $set->bind), '100, 200';

    $set->add_order_by( 'id' );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT ALL SELECT id FROM table2 WHERE (bar = ?) ORDER BY id};
    is join(', ', $set->bind), '100, 200';
};

subtest 'multiple' => sub {
    my $set = intersect( except($s1, $s2), $s3 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT SELECT id FROM table2 WHERE (bar = ?) INTERSECT SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = intersect_all( except( $s1, $s2 ), $s3 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT SELECT id FROM table2 WHERE (bar = ?) INTERSECT ALL SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = union( except( $s1, $s2), $s3 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT SELECT id FROM table2 WHERE (bar = ?) UNION SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = union( except_all( $s1, $s2 ), $s3 );
    is $set->as_sql, qq{SELECT id FROM table1 WHERE (foo = ?) EXCEPT ALL SELECT id FROM table2 WHERE (bar = ?) UNION SELECT id FROM table3 WHERE (baz = ?)};
    is join(', ', $set->bind), '100, 200, 300';
};

};



sub check_sql {
    my @lines = split/\n/, $_[0];
    my $sql = '';
    for my $line ( @lines ) {
        $line =~ s/^\s+//;
        $line =~ s/^WHERE/ WHERE/;
        $line =~ s/^FROM/ FROM/;
        $line =~ s/^INNER/ INNER/;
        $line =~ s/^EXCEPT/ EXCEPT/;
        $line =~ s/^UNION/ UNION/;
        $sql .= $line;
    }
    return $sql;
}


subtest 'complex' => sub {

    my $s1 = ns ->add_from( 'member' )
                ->add_select('id')
                ->add_select('created_on')
                ->add_where( is_deleted => 'f' );

    my $not_in = ns ->add_from('group_member')
                    ->add_select('member_id')
                    ->add_where( 'is_beginner' => 'f' );

    my $s2 = ns ->add_from( $s1, 'm1' )
                ->add_select('m1.id')
                ->add_select('m1.created_on')
                ->add_where( 'm1.id' => {
                    'NOT IN' => \[ '(' . $not_in->as_sql . ')' , $not_in->bind ]
                } );

    my $s3 = ns ->add_select('mi.id')
                ->add_select( \do{'false'}, 'is_group' )
                ->add_select('mi.created_on')
                ->add_join(
                    [$s2, 'm2'] => {
                        table => 'member_index', alias => 'mi', type => 'inner', condition => 'mi.id = m2.id'
                    }
                )
                ->add_where( 'mi.lang' => 'ja' );

    is( $s3->as_sql, check_sql(<<SQL) );
SELECT mi.id, false AS is_group, mi.created_on
    FROM (
        SELECT m1.id, m1.created_on FROM (
            SELECT id, created_on FROM member WHERE (is_deleted = ?)
        ) m1 WHERE (m1.id NOT IN ((SELECT member_id FROM group_member WHERE (is_beginner = ?))))
    ) m2 INNER JOIN member_index mi ON mi.id = m2.id WHERE (mi.lang = ?)
SQL

    is join(', ', $s3->bind), 'f, f, ja';

    my $s4 = ns ->add_join(
                    ['group', 'g1'] => {
                        table => 'group_member', alias => 'gm1',
                        type => 'inner', condition => 'gm1.member_id = g1.id'
                    }
                )
                ->add_join(
                    ['group', 'g1'] => {
                        table => 'member', alias => 'm3',
                        type => 'inner', condition => 'gm1.member_id = m3.id'
                    }
                )
                ->add_select( 'g1.id' )
                ->add_where( 'g1.type' => 'hoge' );

    my $not_in2 = ns ->add_select('id')
                ->add_from('member')
                ->add_where( 'is_monger' => 't' );

    my $s5 = ns ->add_select( 'g2.id' )
                ->add_join(
                    ['group', 'g2'] => {
                        table => 'group_member', alias => 'gm2',
                        type => 'inner', condition => 'gm2.member_id = g2.id'
                    }
                )
                ->add_where( 'gm2.member_id' => {
                    'NOT IN' => \[ '(' . $not_in2->as_sql . ')' , $not_in2->bind ]
                } )
                ->add_where( 'g2.is_deleted' => 'f' );

    my $set = except( $s4, $s5 );

    my $s6 = ns ->add_join(
                    [$set, 'g'] => {
                        table => 'group_index', alias => 'gi',
                        type => 'inner', condition => 'gi.id = g.id'
                    }
                )
                ->add_select( 'g.id' )
                ->add_select( \do{'true'}, 'is_group' )
                ->add_select( 'gsi.created_on' )
                ->add_where( 'gi.lang' => 'ja' );

    is( $s6->as_sql, check_sql(<<SQL) );
SELECT g.id, true AS is_group, gsi.created_on
    FROM (
    SELECT g1.id FROM group g1
        INNER JOIN group_member gm1 ON gm1.member_id = g1.id
        INNER JOIN member m3 ON gm1.member_id = m3.id
        WHERE (g1.type = ?)
    EXCEPT 
    SELECT g2.id FROM group g2
        INNER JOIN group_member gm2 ON gm2.member_id = g2.id
        WHERE (gm2.member_id NOT IN (
            (SELECT id FROM member WHERE (is_monger = ?))
        )) AND (g2.is_deleted = ?)
    ) g INNER JOIN group_index gi ON gi.id = g.id WHERE (gi.lang = ?)
SQL

    is join(', ', $s6->bind), 'hoge, t, f, ja';

    $set = union( $s3, $s6 );

    my $s7 = ns ->add_select( 'id' )
                ->add_select( 'is_group' )
                ->add_from( $set, 'list_table' )
                ->add_order_by( 'created_on' );


    is( $s7->as_sql, check_sql(<<SQL) );
SELECT id, is_group FROM (
    SELECT mi.id, false AS is_group, mi.created_on
        FROM (
            SELECT m1.id, m1.created_on FROM (
                SELECT id, created_on FROM member WHERE (is_deleted = ?)
            ) m1 WHERE (m1.id NOT IN ((SELECT member_id FROM group_member WHERE (is_beginner = ?))))
        ) m2 INNER JOIN member_index mi ON mi.id = m2.id WHERE (mi.lang = ?)
    UNION 
    SELECT g.id, true AS is_group, gsi.created_on
        FROM (
        SELECT g1.id FROM group g1
            INNER JOIN group_member gm1 ON gm1.member_id = g1.id
            INNER JOIN member m3 ON gm1.member_id = m3.id
            WHERE (g1.type = ?)
        EXCEPT 
            SELECT g2.id FROM group g2
            INNER JOIN group_member gm2 ON gm2.member_id = g2.id
            WHERE (gm2.member_id NOT IN (
                (SELECT id FROM member WHERE (is_monger = ?))
            )) AND (g2.is_deleted = ?)
        ) g INNER JOIN group_index gi ON gi.id = g.id WHERE (gi.lang = ?)
) list_table ORDER BY created_on
SQL

    is join(', ', $s7->bind), 'f, f, ja, hoge, t, f, ja';
};


done_testing;

__END__
