requires 'perl', '5.008001';

requires 'Class::Accessor::Lite', '0.05';
requires 'DBI';
requires 'Module::Load';
requires 'parent';
requires 'Scalar::Util';
requires 'SQL::QueryMaker';

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Requires';
    suggests 'DateTime';
    requires 'Tie::IxHash';
};
