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

    $set->_expand_statement( $s1 );
    $set->add_set_operator( $operator );
    $set->_expand_statement( $s2 );

    return $set;
}

sub _expand_statement {
    my ( $self, $s ) = @_;
    if ( $s->isa('SQL::Maker::SelectSet') ) {
        for my $statement ( @{ $s->{ statements } } ) {
            $self->add_statement( $statement );
            my $op = shift @{ $s->{ operators } };
            $self->add_set_operator( $op ) if $op;
        }
    }
    else {
        $self->add_statement( $s );
    }
}

sub add_statement {
    my ( $self, $statement ) = @_;
    push @{ $self->{ statements } }, $statement;
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

    for my $statement ( @{ $self->{ statements } } ) {
        my $operator = shift @operators;
        $sql .= $statement->as_sql;
        last unless $operator;
        $sql .= $new_line . $operator . $new_line;
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

=head1 NAME

SQL::Maker::SelectSet - SQL::Maker::Select set

=head1 SYNOPSIS

    my $s1 = SQL::Maker::Select ->new()
                                ->add_select('foo')
                                ->add_from('t1');
    my $s2 = SQL::Maker::Select ->new()
                                ->add_select('bar')
                                ->add_from('t2');

    SQL::Maker::SelectSet->new_set( 'UNION', $s1, $s2 )->as_sql;
    # => "SELECT foo FROM t1 UNION SELECT bar FROM t2"
    # => $s1->union( $s2 )->as_sql;
    # => do{ $s1 + $s2 }->as_sql;

    SQL::Maker::SelectSet->new_set( 'EXCEPT', $s1, $s2->all )->as_sql;
    # => "SELECT foo FROM t1 EXCEPT ALL SELECT bar FROM t2"
    # => $s1->except( all $s2 )->as_sql;
    # => do{ $s1 - all $s2 }->as_sql;

=head1 DESCRIPTION

Set representation inherited from L<SQL::Maker::Select>.

=head1 METHODS

Can call SQL::Maker::Select methods except of C<add_select>, C<add_from> and C<add_join>.

=over4

=item SQL::Maker::SelectSet->new_set( $operator, $one, $another)

$opretaor is a set opretaor.
$one and $another are SQL::Maker::Select object or SQL::Maker::SelectSet object.
It returns a SQL::Maker::SelectSet object.

=back

=head1 SEE ALSO

L<SQL::Maker::Select>

