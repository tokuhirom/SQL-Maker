package SQL::Builder::Plugin::Replace;
use strict;
use warnings;
use utf8;

our @EXPORT = qw/replace/;

sub replace {
    my ($self, $table, $values) = @_;
    return $self->insert($table, $values, +{prefix => 'REPLACE'});
}


1;

