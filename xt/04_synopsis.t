use strict;
use warnings;
use Test::More;
use Test::Requires 'DBD::SQLite';
eval "use Test::Synopsis";
plan skip_all => "Test::Synopsis required for testing" if $@;
all_synopsis_ok();

done_testing;
