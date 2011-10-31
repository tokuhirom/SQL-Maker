use strict;
use warnings;
use utf8;
use Test::More;
use SQL::Maker;

# see https://github.com/tokuhirom/SQL-Maker/issues/11
subtest 'sqlite' => sub {
    my $maker = SQL::Maker->new(driver => 'SQLite');
    my ($sql, @binds) = $maker->insert('foo', {});
    is(normalize($sql), 'INSERT INTO "foo" DEFAULT VALUES');
    is(0+@binds, 0);
};

subtest 'mysql' => sub {
    my $maker = SQL::Maker->new(driver => 'mysql');
    my ($sql, @binds) = $maker->insert('foo', {});
    is(normalize($sql), 'INSERT INTO `foo` () VALUES ()');
    is(0+@binds, 0);
};

done_testing;

sub normalize {
    local $_ = shift;
    s/\n/ /g;
    $_;
}
