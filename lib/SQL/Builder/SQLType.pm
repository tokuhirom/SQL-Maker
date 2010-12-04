package SQL::Builder::SQLType;
use strict;
use warnings;
use utf8;
use Exporter qw/import/;

our @EXPORT_OK = qw/sql_type/;

sub sql_type {
    my ($value_ref, $type) = @_;
    SQL::Builder::SQLType->new(value_ref => $value_ref, type => $type);
}

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    bless {%args}, $class;
}

sub value_ref { $_[0]->{value_ref} }
sub type      { $_[0]->{type} }

1;

