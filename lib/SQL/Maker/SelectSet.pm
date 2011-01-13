package SQL::Maker::SelectSet;
use strict;
use warnings;
use parent qw(Exporter SQL::Maker::Select);
use Scalar::Util ();

our @EXPORT_OK = qw(union union_all intersect intersect_all except except_all);

# Class methods

sub union ($$) {
    SQL::Maker::SelectSet->new_set( 'UNION', @_ );
}

sub union_all ($$) {
    SQL::Maker::SelectSet->new_set( 'UNION ALL', @_ );
}

sub intersect ($$) {
    SQL::Maker::SelectSet->new_set( 'INTERSECT', @_ );
}

sub intersect_all ($$) {
    SQL::Maker::SelectSet->new_set( 'INTERSECT ALL', @_ );
}

sub except ($$) {
    SQL::Maker::SelectSet->new_set( 'EXCEPT', @_ );
}

sub except_all ($$) {
    SQL::Maker::SelectSet->new_set( 'EXCEPT ALL', @_ );
}

sub _compose_set {
    return SQL::Maker::SelectSet->new_set( @_ );
}

sub new_set {
    my ( $class, $operator, $s1, $s2 ) = @_;

    for my $s ( $s1, $s2 ) {
        unless ( Scalar::Util::blessed( $s ) and $s->isa('SQL::Maker::Select') ) {
            require Carp;
            Carp::croak( "$s is not an object inherited from SQL::Maker::Select." );
        }
    }

    my $set = $class->new( new_line => $s1->new_line );

    $set->_expand_statement( $s1 );
    $set->add_set_operator( $operator );
    $set->_expand_statement( $s2 );

    return $set;
}

#
# Methods
#

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
    for my $select ( @{ $self->{ statements } } ) {
        push @binds, $select->bind;
    }
    return @binds;
}


1;
__END__

=head1 NAME

SQL::Maker::SelectSet - provides set functions

=head1 SYNOPSIS

    use SQL::Maker::SelectSet qw(union_all except);
    my $s1 = SQL::Maker::Select ->new()
                                ->add_select('foo')
                                ->add_from('t1');
    my $s2 = SQL::Maker::Select ->new()
                                ->add_select('bar')
                                ->add_from('t2');
    union_all( $s1, $s2 )->as_sql;
    # => SQL::Maker::SelectSet->new_set( 'UNION ALL', $s1, $s2 )->as_sql;
    # => "SELECT foo FROM t1 UNION ALL SELECT bar FROM t2"
    except( $s1, $s2 )->as_sql;
    # => SQL::Maker::SelectSet->new_set( 'EXCEPT', $s1, $s2->all )->as_sql;
    # => "SELECT foo FROM t1 EXCEPT SELECT bar FROM t2"

=head1 DESCRIPTION

This module provides some set functions which return a SQL::Maker::SelectSet object
inherited from L<SQL::Maker::Select>.

SQL::Maker::SelectSet can call SQL::Maker::Select methods
except of C<add_select>, C<add_from> and C<add_join>.

=head1 FUNCTION

=over 4

=item union($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet

Tow statements are combined by C<UNION>.

=item union_all($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet

Tow statements are combined by C<UNION ALL>.

=item intersect($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet

Tow statements are combined by C<INTERSECT>.

=item intersect_all($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet

Tow statements are combined by C<INTERSECT ALL>.

=item except($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet

Tow statements are combined by C<EXCEPT>.

=item except($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet

Tow statements are combined by C<EXCEPT ALL>.

=back

=head1 Class Method

=over 4

=item SQL::Maker::SelectSet->new_set( $operator, $one, $another)

$opretaor is a set operator (ex. C<UNION>).
$one and $another are SQL::Maker::Select object or SQL::Maker::SelectSet object.
It returns a SQL::Maker::SelectSet object.

=back

=head1 SEE ALSO

L<SQL::Maker::Select>

