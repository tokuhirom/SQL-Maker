package SQL::Builder::Where;
use strict;
use warnings;
use utf8;
use SQL::Builder::Part;
use overload
    '&' => sub { $_[0]->compose_and($_[1]) },
    '|' => sub { $_[0]->compose_or($_[1]) },
    fallback => 1;

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    bless {sql => [], bind => [], %args}, $class;
}

sub add {
    my ( $self, $col, $val ) = @_;

    my ( $term, $bind ) = SQL::Builder::Part->make_term( $col, $val );
    push @{ $self->{sql} }, "($term)";
    push @{ $self->{bind} },  @$bind;

    return $self; # for influent interface
}

sub compose_and {
    my ($self, $other) = @_;

    return SQL::Builder::Where->new(
        sql => ['(' . $self->as_sql() . ') AND (' . $other->as_sql() . ')'],
        bind => [@{$self->{bind}}, @{$other->{bind}}],
    );
}

sub compose_or {
    my ($self, $other) = @_;

    return SQL::Builder::Where->new(
        sql => ['(' . $self->as_sql() . ') OR (' . $other->as_sql() . ')'],
        bind => [@{$self->{bind}}, @{$other->{bind}}],
    );
}

sub as_sql {
    my ($self, $need_prefix) = @_;
    my $sql = join(' AND ', @{$self->{sql}});
    $sql = " WHERE $sql" if $need_prefix && length($sql)>0;
    return $sql;
}

sub bind {
    my $self = shift;
    return @{$self->{bind}};
}

1;

