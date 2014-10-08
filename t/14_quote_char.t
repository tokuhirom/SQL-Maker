use strict;
use warnings;
use utf8;
use Test::More;
use SQL::Maker;
use SQL::QueryMaker qw(sql_eq);

my $maker = SQL::Maker->new(
    driver => 'SQLite',
    quote_char => ':',
    name_sep => '-',
    new_line => ' ',
);

my @condition_cases = (
    {
        label => 'Condition',
        cond_maker => sub {
            my $cond = $maker->new_condition;
            $cond->add('foo-bar' => 'buzz');
            return $cond;
        },
    },
    {
        label => 'QueryMaker',
        cond_maker => sub {
            return sql_eq('foo-bar', 'buzz');
        },
    },
    {
        label => 'QueryMaker in Condition',
        cond_maker => sub {
            my $cond = $maker->new_condition;
            $cond->add('foo-bar' => sql_eq('buzz'));
            return $cond;
        },
    },
);

foreach my $cond_case (@condition_cases) {
    subtest "select: $cond_case->{label}" => sub {
        my $cond = $cond_case->{cond_maker}();
        my ($sql, @binds) = $maker->select("table", ["*"], $cond);
        like $sql, qr/:foo:-:bar:/;
    };
    
    subtest "update: $cond_case->{label}" => sub {
        my $cond = $cond_case->{cond_maker}();
        my ($sql, @binds) = $maker->update("table", ["a" => "A"], $cond);
        like $sql, qr/:foo:-:bar:/;
    };

    subtest "delete: $cond_case->{label}" => sub {
        my $cond = $cond_case->{cond_maker}();
        my ($sql, @binds) = $maker->delete("table", $cond);
        like $sql, qr/:foo:-:bar:/;
    };

    subtest "where: $cond_case->{label}" => sub {
        my $cond = $cond_case->{cond_maker}();
        my ($sql, @binds) = $maker->where($cond);
        like $sql, qr/:foo:-:bar:/;
    };
}

done_testing;
