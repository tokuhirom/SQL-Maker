use strict;
use warnings;
use Test::More;
use SQL::Maker;
use Test::Requires 'Tie::IxHash';

my $builder = SQL::Maker->new(driver => 'sqlite');

my $s1 = $builder->new_select();
$s1->add_from( 'table1' );
$s1->add_select( 'id' );
$s1->add_where( foo => 100 );

my $s2 = $builder->new_select();
$s2->add_from( 'table2' );
$s2->add_select( 'id' );
$s2->add_where( bar => 200 );

my $s3 = $builder->new_select();
$s3->add_from( 'table3' );
$s3->add_select( 'id' );
$s3->add_where( baz => 300 );

subtest 'union' => sub {
    my $set = $s1 + $s2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '100, 200';

    $set = $set + $s3;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nUNION\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = $s1 + $s2;
    $set = $s3 + $set;
    is $set->as_sql, qq{SELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)\nUNION\nSELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    $set = $s1 + all $s2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '100, 200';

    $set->add_order_by( 'id' );
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nORDER BY id};
    is join(', ', $set->bind), '100, 200';

    $set = $s3 + $s1 + $s2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)\nUNION\nSELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    my $set1 = $s1 + $s2;
    my $set2 = $s2 + $s3;
    $set = $set1 + $set2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nUNION\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nUNION\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 200, 300';
};

subtest 'intersect' => sub {
    my $set = $s1 * $s2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nINTERSECT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '100, 200';

    $set = $set * $s3;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nINTERSECT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nINTERSECT\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = $s1 * $s2;
    $set = $s3 * $set;
    is $set->as_sql, qq{SELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)\nINTERSECT\nSELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nINTERSECT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    $set = $s1 * all $s2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nINTERSECT ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '100, 200';

    $set->add_order_by( 'id' );
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nINTERSECT ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nORDER BY id};
    is join(', ', $set->bind), '100, 200';
};

subtest 'except' => sub {
    my $set = $s1 - $s2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '100, 200';

    $set = $set - $s3;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nEXCEPT\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = $s1 - $s2;
    $set = $s3 - $set;
    is $set->as_sql, qq{SELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)\nEXCEPT\nSELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '300, 100, 200';

    $set = $s1 - all $s2;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '100, 200';

    $set->add_order_by( 'id' );
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nORDER BY id};
    is join(', ', $set->bind), '100, 200';
};

subtest 'complex' => sub {
    my $set = ($s1 - $s2) * $s3;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nINTERSECT\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = ($s1 - $s2) * all $s3;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nINTERSECT ALL\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = $s1 - $s2 + $s3;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nUNION\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = $s1 - all $s2 + $s3;
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nEXCEPT ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nUNION\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';

    $set = $s1->union( $s2 );
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)};
    is join(', ', $set->bind), '100, 200';

    $set = $s1->union( all $s2 )->intersect( $s3 );
    is $set->as_sql, qq{SELECT "id"\nFROM "table1"\nWHERE ("foo" = ?)\nUNION ALL\nSELECT "id"\nFROM "table2"\nWHERE ("bar" = ?)\nINTERSECT\nSELECT "id"\nFROM "table3"\nWHERE ("baz" = ?)};
    is join(', ', $set->bind), '100, 200, 300';
};


done_testing;
