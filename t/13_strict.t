use strict;
use warnings;
use utf8;
use Test::More;
use SQL::Maker;

sub checkerr {
    my $code = shift;
    return sub {
        local $@;
        my $query = eval {
            $code->();
        };
        ok ! defined $query, "does not return anything";
        like $@, qr/cannot pass in an unblessed ref/, "error is thrown";
    };
}

my $maker = SQL::Maker->new(
    driver => 'SQLite',
    strict => 1,
);

ok $maker->strict, "maker->strict";

subtest "maker->new_condition" => checkerr(sub {
    $maker->new_condition->add(
        foo => [1],
    );
});

{
    my $select = $maker->new_select;
    ok $select->strict, "select->strict";
    subtest "select->new_condition" => checkerr(sub {
        $select->new_condition->add(
            foo => [1],
        );
    });
}

subtest "maker->select" => checkerr(sub {
    $maker->select("user", ['*'], { name => ["John", "Tom" ]});
});

subtest "maker->insert" => checkerr(sub {
    $maker->insert(
        user => [ name => "John", created_on => \"datetime(now)" ]
    );
});

subtest "maker->delete" => checkerr(sub {
    $maker->delete(user => [ name => ["John", "Tom"]]);
});

subtest "maker->update where" => checkerr(sub {
    $maker->update(user => [name => "John"], { user_id => [1, 2] });
});

subtest "maker->update set" => checkerr(sub {
    $maker->update(user => [name => \"select *"]);
});

done_testing;
