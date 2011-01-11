package SQL::Maker::SelectSet;
use strict;
use warnings;
use parent qw(SQL::Maker::Select);


sub new_set {
    my ( $class, $operator, $s1, $s2 ) = @_;
    my $set = $class->new( new_line => $s1->new_line );

    if ( ref $s2 eq 'ARRAY' ) { # by SQL::Maker::Select::all
        $s2 = $s2->[1];
        $operator .= ' ALL';
    }

    $set->_expand_select( $s1 );
    $set->add_set_operator( $operator );
    $set->_expand_select( $s2 );

    return $set;
}

sub _expand_select {
    my ( $self, $s ) = @_;
    if ( $s->isa('SQL::Maker::SelectSet') ) {
        for my $select ( @{ $s->{ selects } } ) {
            $self->add_select( $select );
            my $op = shift @{ $s->{ operators } };
            $self->add_set_operator( $op ) if $op;
        }
    }
    else {
        $self->add_select( $s );
    }
}

sub add_select {
    my ( $self, $select ) = @_;
    push @{ $self->{ selects } }, $select;
}

sub add_set_operator {
    my ( $self, $operator ) = @_;
    push @{ $self->{ operators } }, $operator;
}

sub as_sql {
    my ( $self ) = @_;
    my @operators = @{ $self->{ operators } };
    my $sql = '';
    my $new_line = $self->new_line;

    for my $select ( @{ $self->{ selects } } ) {
        my $operator = shift @operators;
        $sql .= $select->as_sql;
        last unless $operator;
        $sql .= $select->new_line . $operator . $select->new_line;
    }

    $sql .= $new_line;
    $sql .= $self->as_sql_where()   if $self->{where};

    $sql .= $self->as_sql_group_by  if $self->{group_by};
    $sql .= $self->as_sql_having    if $self->{having};
    $sql .= $self->as_sql_order_by  if $self->{order_by};

    $sql .= $self->as_sql_limit     if $self->{limit};

    $sql .= $self->as_sql_for_update;
    $sql =~ s/${new_line}+$//;

    return $sql;
}

sub bind {
    my ( $self ) = @_;
    my @binds;
    for my $select ( @{ $self->{ selects } } ) {
        push @binds, $select->bind;
    }
    return @binds;
}


1;
__END__

