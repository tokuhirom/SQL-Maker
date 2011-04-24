use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'select_subquery' => sub {
    subtest 'driver: sqlite' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');

        my $stmt1;
        my $stmt2;

        do {
            $stmt1 = $builder->select_query('sakura' => ['hoge', 'fuga'], ordered_hashref(fuga => 'piyo', zun => 'doko'));
            is $stmt1->as_sql, qq{SELECT "hoge", "fuga"\nFROM "sakura"\nWHERE ("fuga" = ?) AND ("zun" = ?)};
            is join(',', $stmt1->bind), 'piyo,doko';
        };

        do {
            $stmt2 = $builder->select_query([[$stmt1,'stmt1']] => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'));
            is $stmt2->as_sql, qq{SELECT "foo", "bar"\nFROM (SELECT "hoge", "fuga"\nFROM "sakura"\nWHERE ("fuga" = ?) AND ("zun" = ?)) "stmt1"\nWHERE ("bar" = ?) AND ("john" = ?)};
            is join(',', $stmt2->bind), 'piyo,doko,baz,man';
        };

        do {
            my $stmt3 = $builder->select_query([[$stmt2,'stmt2']] => ['baz'], {'baz'=>'bar'}, {order_by => 'yo'});
            is $stmt3->as_sql, qq{SELECT "baz"\nFROM (SELECT "foo", "bar"\nFROM (SELECT "hoge", "fuga"\nFROM "sakura"\nWHERE ("fuga" = ?) AND ("zun" = ?)) "stmt1"\nWHERE ("bar" = ?) AND ("john" = ?)) "stmt2"\nWHERE ("baz" = ?)\nORDER BY yo};
            is join(',', $stmt3->bind), 'piyo,doko,baz,man,bar';
        };

        do {
            my $stmt = $builder->new_select;
            $stmt->add_select( 'id' );
            $stmt->add_where( 'foo'=>'bar' );
            $stmt->add_from( $stmt, 'itself' );

            is( $stmt->as_sql, qq{SELECT "id"\nFROM (SELECT "id"\nFROM \nWHERE ("foo" = ?)) "itself"\nWHERE ("foo" = ?)} );
            is join(',', $stmt->bind), 'bar,bar';
        };

    };
};

subtest 'subquery_and_join' => sub {
    my $subquery = SQL::Maker::Select->new( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
    $subquery->add_select('*');
    $subquery->add_from( 'foo' );
    $subquery->add_where( 'hoge' => 'fuga' );

    my $stmt = SQL::Maker::Select->new( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
    $stmt->add_join(
        [ $subquery, 'bar' ] => {
            type      => 'inner',
            table     => 'baz',
            alias     => 'b1',
            condition => 'bar.baz_id = b1.baz_id'
        },
    );
    is $stmt->as_sql, "FROM (SELECT * FROM foo WHERE (hoge = ?)) bar INNER JOIN baz b1 ON bar.baz_id = b1.baz_id";
    is join(',', $stmt->bind), 'fuga';
};

subtest 'complex' => sub {
    my $s1 = SQL::Maker::Select->new( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
    $s1->add_select('*');
    $s1->add_from( 'foo' );
    $s1->add_where( 'hoge' => 'fuga' );

    my $s2 = SQL::Maker::Select->new( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
    $s2->add_select('*');
    $s2->add_from( $s1, 'f' );
    $s2->add_where( 'piyo' => 'puyo' );

    my $stmt = SQL::Maker::Select->new( quote_char => q{}, name_sep => q{.}, new_line => q{ } );
    $stmt->add_join(
        [ $s2, 'bar' ] => {
            type      => 'inner',
            table     => 'baz',
            alias     => 'b1',
            condition => 'bar.baz_id = b1.baz_id'
        },
    );
    is $stmt->as_sql, "FROM (SELECT * FROM (SELECT * FROM foo WHERE (hoge = ?)) f WHERE (piyo = ?)) bar INNER JOIN baz b1 ON bar.baz_id = b1.baz_id";
    is join(',', $stmt->bind), 'fuga,puyo';
};

done_testing;
