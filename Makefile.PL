use inc::Module::Install;
use Module::Install::AuthorTests;
use Module::Install::ReadmeMarkdownFromPod;

name 'SQL-Builder';
all_from 'lib/SQL/Builder.pm';
readme_markdown_from 'lib/SQL/Builder.pm';

# requires '';
# requires 'Exporter' => 5.63; # use Exporter 'import';
# requires 'Plack' =>  0.9949;



tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More' => 0.96; # done_testing, subtest
# test_requires 'Test::Requires';
author_tests('xt');
# test_requires 'YAML'; # required for use_test_base.
# use_test_base;
WriteAll;
