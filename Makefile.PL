use inc::Module::Install;
use Module::Install::AuthorTests;

name 'SQL-Maker';
all_from 'lib/SQL/Maker.pm';

requires 'DBI';
requires 'Class::Accessor::Lite' => 0.05;
requires 'Module::Load';
requires 'parent';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More' => 0.96; # done_testing, subtest
test_requires 'Test::Requires';
test_requires 'Tie::IxHash';
author_tests('xt');
WriteAll;
