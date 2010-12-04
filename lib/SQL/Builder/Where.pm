package SQL::Builder::Where;
use strict;
use warnings;
use utf8;
use parent qw/SQL::Builder::Condition/;

sub as_sql {
    my ($self, $need_prefix) = @_;
    my $sql = join(' AND ', @{$self->{sql}});
    return " WHERE $sql" if $need_prefix && length($sql)>0;
    return $sql;
}

1;
