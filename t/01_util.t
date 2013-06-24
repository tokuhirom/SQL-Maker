use strict;
use warnings;
use utf8;
use Test::More;
use SQL::Maker::Util;

is SQL::Maker::Util::quote_identifier('foo.*', '`', '.'), '`foo`.*';

done_testing;
