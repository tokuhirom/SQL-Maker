use strict;
use warnings FATAL => 'all';
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    recursive_test_files => 1,
    dynamic_config       => 0,
    build_requires       => {
        'Test::Requires' => '0',
        'Test::More'     => '0.98',
        'Tie::IxHash'    => '0'
    },
    configure_requires => { 'Module::Build' => '0.38' },
    requires           => {
        'perl'                  => '5.008001',
        'parent'                => '0',
        'Module::Load'          => '0',
        'Class::Accessor::Lite' => '0.05',
        'DBI'                   => '0'
    },
    no_index    => { 'directory' => [ 'inc', 't', 'xt' ] },
    name        => 'SQL-Maker',
    module_name => 'SQL::Maker',

    test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',

    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
