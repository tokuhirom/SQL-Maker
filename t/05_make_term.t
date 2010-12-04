use strict;
use warnings;
use Test::More;
use SQL::Builder::SQLType qw/sql_type/;
use SQL::Builder::Condition;
use Data::Dumper;
use DBI qw/:sql_types/;

sub test {
    my ($source, $expected_term, $expected_bind) = @_;
    local $Data::Dumper::Terse=1;
    local $Data::Dumper::Indent=0;
    subtest Dumper($source) => sub {
        my ($term, $bind) = SQL::Builder::Condition->_make_term(@$source);
        is $term, $expected_term;
        is_deeply $bind, $expected_bind;
    };
}

test(@{$_}) for (
    [
        ['foo' => 'bar'],
        "foo = ?",
        ['bar']
    ],
    [
        ['foo' => ['bar', 'baz']],
        "foo IN (?,?)",
        ['bar', 'baz']
    ],
    [
        ['foo' => {IN => ['bar', 'baz']}],
        "foo IN (?,?)",
        ['bar', 'baz']
    ],
    [
        ['foo' => {'not IN' => ['bar', 'baz']}],
        "foo NOT IN (?,?)",
        ['bar', 'baz']
    ],
    [
        ['foo' => {'!=' => 'bar'}],
        "foo != ?",
        ['bar']
    ],
    [
        ['foo' => \'IS NOT NULL'],
        "foo IS NOT NULL",
        []
    ],
    [
        ['foo' => {between => [qw/1 2/]}],
        "foo BETWEEN ? AND ?",
        [qw/1 2/]
    ],
    [
        ['foo' => {like => 'xaic%'}],
        "foo LIKE ?",
        [qw/xaic%/]
    ],
    [
        ['foo' => [{'>' => 'bar'}, {'<', => 'baz'}]],
        "(foo > ?) OR (foo < ?)",
        [qw/bar baz/]
    ],
    [
        ['foo' => [-and => {'>' => 'bar'}, {'<', => 'baz'}]],
        "(foo > ?) AND (foo < ?)",
        [qw/bar baz/]
    ],
    [
        ['foo' => [-and => 'foo', 'bar', 'baz']],
        "(foo = ?) AND (foo = ?) AND (foo = ?)",
        [qw/foo bar baz/]
    ],
    [
        ['foo_id' => \['IN (SELECT foo_id FROM bar WHERE t=?)', 44]],
        "foo_id IN (SELECT foo_id FROM bar WHERE t=?)",
        [qw/44/]
    ],
    [
        ['foo_id' => \['MATCH (col1, col2) AGAINST (?)', 'apples']],
        "foo_id MATCH (col1, col2) AGAINST (?)",
        [qw/apples/]
    ],
    [
        ['foo_id' => undef],
        "foo_id IS NULL",
        [qw//]
    ],
    [
        ['foo_id' => {IN => []}],
        "0=1",
        [qw//]
    ],
    [
        ['foo_id' => {"NOT IN" => []}],
        "1=1",
        [qw//]
    ],
    [
        ['foo_id' => sql_type(\3, SQL_INTEGER)],
        "foo_id = ?",
        [sql_type(\3, SQL_INTEGER)]
    ],
);
done_testing;

