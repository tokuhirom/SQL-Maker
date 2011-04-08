use strict;
use warnings;
use Test::More;
use SQL::Maker::Select::Oracle;

my $sel = SQL::Maker::Select::Oracle->new( new_line => q{ } )
                                      ->add_select('foo')
                                      ->add_from('user')
                                      ->limit(10)
                                      ->offset(20);

is $sel->as_sql, 'SELECT * FROM ( SELECT foo, ROW_NUMBER() OVER (ORDER BY 1) R FROM user LIMIT 10 OFFSET 20 ) WHERE  R BETWEEN 20 + 1 AND 10 + 20';

done_testing;

