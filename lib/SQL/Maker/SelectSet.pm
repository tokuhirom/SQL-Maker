package SQL::Maker::SelectSet;
use strict;
use warnings;
use parent qw(Exporter);
use Scalar::Util ();
use Carp ();
use SQL::Maker::Util;
use Class::Accessor::Lite (
    ro => [qw/new_line operator/],
);

our @EXPORT_OK = qw(union union_all intersect intersect_all except except_all);

# Functions
BEGIN {
    for (qw/union union_all intersect intersect_all except except_all/) {
        my $method = $_;
        (my $operator = uc $_) =~ s/_/ /;

        no strict 'refs';
        *{__PACKAGE__ . '::' . $method} = sub {
            my $stmt = SQL::Maker::SelectSet->new(
                operator => $operator,
                new_line => $_[0]->new_line,
            );
            $stmt->add_statement($_) for @_;
            return $stmt;
        };
    }
}

#
# Methods
#

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    Carp::croak("Missing mandatory parameter 'operator' for SQL::Maker::SelectSet->new") unless exists $args{operator};

    my $set = bless {
        new_line   => qq{\n},
        %args,
    }, $class;

    return $set;
}

sub add_statement {
    my ($self, $statement) = @_;

    unless ( Scalar::Util::blessed($statement) and $statement->can('as_sql') ) {
        Carp::croak( "'$statement' doesn't have 'as_sql' method.");
    }
    push @{$self->{statements}}, $statement;
    return $self; # method chain
}

sub as_sql_order_by {
    my ($self) = @_;

    my @attrs = @{$self->{order_by}};
    return '' unless @attrs;

    return 'ORDER BY '
           . join(', ', map {
                my ($col, $type) = @$_;
                if (ref $col) {
                    $$col
                } else {
                    $type ? $self->_quote($col) . " $type" : $self->_quote($col)
                }
           } @attrs);
}

sub _quote {
    my ($self, $label) = @_;

    return $$label if ref $label eq 'SCALAR';
    SQL::Maker::Util::quote_identifier($label, $self->{quote_char}, $self->{name_sep})
}

sub as_sql {
    my ($self) = @_;

    my $new_line = $self->new_line;
    my $operator = $self->operator;

    my $sql = join(
        $new_line . $operator . $new_line,
        map { $_->as_sql } @{ $self->{statements} }
    );
    $sql .= ' ' . $self->as_sql_order_by() if $self->{order_by};
    return $sql;
}

sub bind {
    my ($self) = @_;
    my @binds;
    for my $select ( @{ $self->{statements} } ) {
        push @binds, $select->bind;
    }
    return @binds;
}

sub add_order_by {
    my ($self, $col, $type) = @_;
    push @{$self->{order_by}}, [$col, $type];
    return $self;
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
    # =>
    #  SQL::Maker::SelectSet->new_set(
    #      operator => 'UNION ALL',
    #      new_line => $s1->new_line
    #  )->add_statement($s1)
    #   ->add_statement($s2)
    #   ->as_sql;
    # => "SELECT foo FROM t1 UNION ALL SELECT bar FROM t2"
    except( $s1, $s2 )->as_sql;
    # => SQL::Maker::SelectSet->new_set( operator => 'EXCEPT', new_line => $s1->new_line )
    #     ->add_statement( $s1 )
    #     ->add_statement( $s2 )
    #     ->as_sql;
    # => "SELECT foo FROM t1 EXCEPT SELECT bar FROM t2"

=head1 DESCRIPTION

This module provides some set functions which return a SQL::Maker::SelectSet object
inherited from L<SQL::Maker::Select>.

=head1 FUNCTION

=over 4

=item C<< union($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet >>

Tow statements are combined by C<UNION>.

=item C<< union_all($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet >>

Tow statements are combined by C<UNION ALL>.

=item C<< intersect($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet >>

Tow statements are combined by C<INTERSECT>.

=item C<< intersect_all($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet >>

Tow statements are combined by C<INTERSECT ALL>.

=item C<< except($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet >>

Tow statements are combined by C<EXCEPT>.

=item C<< except($select :SQL::Maker::Select | $set :SQL::Maker::SelectSet) : SQL::Maker::SelectSet >>

Tow statements are combined by C<EXCEPT ALL>.

=back

=head1 Class Method

=over 4

=item my $stmt = SQL::Maker::SelectSet->new( %args )

$opretaor is a set operator (ex. C<UNION>).
$one and $another are SQL::Maker::Select object or SQL::Maker::SelectSet object.
It returns a SQL::Maker::SelectSet object.

The parameters are:

=over 4

=item $new_line

Default values is "\n".

=item $operator : Str

The operator. This parameter is required.

=back

=back

=head1 Instance Methods

=over 4

=item C<< my $sql = $set->as_sql() : Str >>

Returns a new select statement.

=item C<< my @binds = $set->bind() : Array[Str] >>

Returns bind variables.

=item C<< $set->add_statement($stmt : $stmt->can('as_sql')) : SQL::Maker::SelectSet >>

This method adds new statement object. C<< $stmt >> must provides 'as_sql' method.

I<Return Value> is the $set itself.

=back

=head1 SEE ALSO

L<SQL::Maker::Select>

