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
            $stmt2 = $builder->select_query([$stmt1,'stmt1'] => ['foo', 'bar'], ordered_hashref(bar => 'baz', john => 'man'));
            is $stmt2->as_sql, qq{SELECT "foo", "bar"\nFROM (SELECT "hoge", "fuga"\nFROM "sakura"\nWHERE ("fuga" = ?) AND ("zun" = ?)) "stmt1"\nWHERE ("bar" = ?) AND ("john" = ?)};
            is join(',', $stmt2->bind), 'piyo,doko,baz,man';
        };

        do {
            my $stmt3 = $builder->select_query([$stmt2,'stmt2'] => ['baz'], {'baz'=>'bar'}, {order_by => 'yo'});
            is $stmt3->as_sql, qq{SELECT "baz"\nFROM (SELECT "foo", "bar"\nFROM (SELECT "hoge", "fuga"\nFROM "sakura"\nWHERE ("fuga" = ?) AND ("zun" = ?)) "stmt1"\nWHERE ("bar" = ?) AND ("john" = ?)) "stmt2"\nWHERE ("baz" = ?)\nORDER BY yo};
            is join(',', $stmt3->bind), 'piyo,doko,baz,man,bar';
        };
    };



};

done_testing;
