use inc::Module::Install;
use Module::Install::AuthorTests;

name 'SQL-Builder';
all_from 'lib/SQL/Builder.pm';

requires 'DBI';
requires 'Class::Accessor::Lite' => 0.05;
requires 'Module::Load';
requires 'parent';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More' => 0.96; # done_testing, subtest
test_requires 'Test::Requires';
author_tests('xt');
WriteAll;
