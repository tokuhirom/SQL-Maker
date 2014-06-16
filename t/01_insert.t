use strict;
use warnings;
use Test::More;
use SQL::Maker;
use SQL::QueryMaker;
use Test::Requires 'DateTime';
use Test::Requires 'Tie::IxHash';

sub ordered_hashref {
    tie my %params, Tie::IxHash::, @_;
    return \%params;
}

subtest 'driver sqlite' => sub {
    subtest 'hash column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->insert('foo' => ordered_hashref(bar => 'baz', john => 'man', created_on => \"datetime('now')", updated_on => \["datetime(?)", "now"], expires => DateTime->new(year => 2025)));
        is $sql, qq{INSERT INTO "foo"\n("bar", "john", "created_on", "updated_on", "expires")\nVALUES (?, ?, datetime('now'), datetime(?), ?)};
        is join(',', @binds), 'baz,man,now,2025-01-01T00:00:00';
    };

    subtest 'array column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->insert('foo' => [ bar => 'baz', john => 'man', created_on => \"datetime('now')", updated_on => \["datetime(?)", "now" ], expires => DateTime->new(year => 2025) ]);
        is $sql, qq{INSERT INTO "foo"\n("bar", "john", "created_on", "updated_on", "expires")\nVALUES (?, ?, datetime('now'), datetime(?), ?)};
        is join(',', @binds), 'baz,man,now,2025-01-01T00:00:00';
    };

    subtest 'insert ignore, hash column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->insert('foo' => ordered_hashref( bar => 'baz', john => 'man', created_on => \"datetime('now')", updated_on => \["datetime(?)", "now"] ), +{ prefix => 'INSERT IGNORE' });
        is $sql, qq{INSERT IGNORE "foo"\n("bar", "john", "created_on", "updated_on")\nVALUES (?, ?, datetime('now'), datetime(?))};
        is join(',', @binds), 'baz,man,now';
    };

    subtest 'insert ignore, array column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->insert('foo' => [ bar => 'baz', john => 'man', created_on => \"datetime('now')", updated_on => \["datetime(?)", "now" ] ], +{ prefix => 'INSERT IGNORE' });
        is $sql, qq{INSERT IGNORE "foo"\n("bar", "john", "created_on", "updated_on")\nVALUES (?, ?, datetime('now'), datetime(?))};
        is join(',', @binds), 'baz,man,now';
    };

    subtest 'term' => sub {
        my $builder = SQL::Maker->new(driver => 'sqlite');
        my ($sql, @binds) = $builder->insert('foo' => ordered_hashref(bar => 'baz', john => 'man', created_on => sql_raw("datetime('now')"), updated_on => sql_raw("datetime(?)", "now")));
        is $sql, qq{INSERT INTO "foo"\n("bar", "john", "created_on", "updated_on")\nVALUES (?, ?, datetime('now'), datetime(?))};
        is join(',', @binds), 'baz,man,now';
    };
};

subtest 'driver mysql' => sub {
    subtest 'hash column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->insert('foo' => ordered_hashref(bar => 'baz', john => 'man', created_on => \"NOW()", updated_on => \["FROM_UNIXTIME(?)", 1302536204 ], expires => DateTime->new(year => 2025) ));
        is $sql, qq{INSERT INTO `foo`\n(`bar`, `john`, `created_on`, `updated_on`, `expires`)\nVALUES (?, ?, NOW(), FROM_UNIXTIME(?), ?)};
        is join(',', @binds), 'baz,man,1302536204,2025-01-01T00:00:00';
    };

    subtest 'array column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->insert('foo' => [ bar => 'baz', john => 'man', created_on => \"NOW()", updated_on => \["FROM_UNIXTIME(?)", 1302536204 ], expires => DateTime->new(year => 2025) ]);
        is $sql, qq{INSERT INTO `foo`\n(`bar`, `john`, `created_on`, `updated_on`, `expires`)\nVALUES (?, ?, NOW(), FROM_UNIXTIME(?), ?)};
        is join(',', @binds), 'baz,man,1302536204,2025-01-01T00:00:00';
    };

    subtest 'insert ignore, hash column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->insert('foo' => ordered_hashref( bar => 'baz', john => 'man', created_on => \"NOW()", updated_on => \["FROM_UNIXTIME(?)", 1302536204 ] ), +{ prefix => 'INSERT IGNORE' });
        is $sql, qq{INSERT IGNORE `foo`\n(`bar`, `john`, `created_on`, `updated_on`)\nVALUES (?, ?, NOW(), FROM_UNIXTIME(?))};
        is join(',', @binds), 'baz,man,1302536204';
    };

    subtest 'insert ignore, array column-value' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->insert('foo' => [ bar => 'baz', john => 'man', created_on => \"NOW()", updated_on => \["FROM_UNIXTIME(?)", 1302536204 ] ], +{ prefix => 'INSERT IGNORE' });
        is $sql, qq{INSERT IGNORE `foo`\n(`bar`, `john`, `created_on`, `updated_on`)\nVALUES (?, ?, NOW(), FROM_UNIXTIME(?))};
        is join(',', @binds), 'baz,man,1302536204';
    };

    subtest 'term' => sub {
        my $builder = SQL::Maker->new(driver => 'mysql');
        my ($sql, @binds) = $builder->insert('foo' => ordered_hashref(bar => 'baz', john => 'man', created_on => sql_raw("NOW()"), updated_on => sql_raw("FROM_UNIXTIME(?)", 1302536204)));
        is $sql, qq{INSERT INTO `foo`\n(`bar`, `john`, `created_on`, `updated_on`)\nVALUES (?, ?, NOW(), FROM_UNIXTIME(?))};
        is join(',', @binds), 'baz,man,1302536204';
    };
};

done_testing;
