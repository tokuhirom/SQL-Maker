use strict;
use warnings;
use utf8;
use Test::More;
use SQL::Maker;
use SQL::QueryMaker;

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

subtest "maker->select where" => sub {
  my ($sql, @binds) = $maker->select("table", ["*"], sql_eq(id => 1));
  like $sql, qr/WHERE\s+.*id.*\s*=/s;
  is_deeply \@binds, [ 1 ];
};

subtest "maker->update where" => sub {
  my ($sql, @binds) = $maker->update("table", [], sql_eq(id => 1));
  like $sql, qr/WHERE\s+.*id.*\s*=/s;
  is_deeply \@binds, [ 1 ];
};

subtest "maker->delete where" => sub {
  my ($sql, @binds) = $maker->delete("table", sql_eq(id => 1));
  like $sql, qr/WHERE\s+.*id.*\s*=/s;
  is_deeply \@binds, [ 1 ];
};

subtest "maker->where" => sub {
  my ($sql, @binds) = $maker->where(sql_eq(id => 1));
  like $sql, qr/id.*\s*=/s;
  is_deeply \@binds, [ 1 ];
};

subtest "maker->new_condition (err)" => checkerr(sub {
    $maker->new_condition->add(
        foo => [1],
    );
});

{
    my $select = $maker->new_select;
    ok $select->strict, "select->strict";
    subtest "select->new_condition (err)" => checkerr(sub {
        $select->new_condition->add(
            foo => [1],
        );
    });
}

subtest "maker->select (err)" => checkerr(sub {
    $maker->select("user", ['*'], { name => ["John", "Tom" ]});
});

subtest "maker->select (ok)", sub {
    $maker->select("user", ['*'], { name => sql_in(["John", "Tom"]) });
    $maker->select("user", ['*'], $maker->new_condition->add(name => sql_in(["John", "Tom"])));
    $maker->select("user", ['*'], sql_in(name => ["John", "Tom"]));
    ok("run without croaking");
};

subtest "maker->insert (err)" => checkerr(sub {
    $maker->insert(
        user => [ name => "John", created_on => \"datetime(now)" ]
    );
});

subtest "maker->insert (ok)" => sub {
    $maker->insert(user => [name => "John", created_on => sql_raw("datetime(now)")]);
    ok("run without croaking");
};

subtest "maker->delete (err)" => checkerr(sub {
    $maker->delete(user => [ name => ["John", "Tom"]]);
});

subtest "maker->update where (err)" => checkerr(sub {
    $maker->update(user => [name => "John"], { user_id => [1, 2] });
});

subtest "maker->update set (err)" => checkerr(sub {
    $maker->update(user => [name => \"select *"]);
});

done_testing;
