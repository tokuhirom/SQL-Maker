use strict;
use warnings;
use Test::More;
use SQL::Builder::Part;

sub test {
    my ($source, $expected_term, $expected_bind) = @_;
    my ($term, $bind) = SQL::Builder::Part->make_term(@$source);
    is $term, $expected_term;
    is_deeply $bind, $expected_bind;
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
);
done_testing;

