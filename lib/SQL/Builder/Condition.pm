package SQL::Builder::Condition;
use strict;
use warnings;
use utf8;
use SQL::Builder::Part;
use SQL::Builder::Util;
use overload
    '&' => sub { $_[0]->compose_and($_[1]) },
    '|' => sub { $_[0]->compose_or($_[1]) },
    fallback => 1;

sub _quote {
    my ($self, $label) = @_;

    return $$label if ref $label;
    SQL::Builder::Util::quote_identifier($label, $self->{quote_char}, $self->{name_sep})
}

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    bless {sql => [], bind => [], %args}, $class;
}

sub _make_term {
    my ($self, $col, $val) = @_;

    if ( ref($val) eq 'ARRAY' ) {
        # make_term(foo => {-and => [1,2,3]}) => (foo = 1) AND (foo = 2) AND (foo = 3)
        if ( ref $val->[0] or ( ( $val->[0] || '' ) eq '-and' ) ) {
            my $logic  = 'OR';
            my @values = @$val;
            if ( $val->[0] eq '-and' ) {
                $logic = 'AND';
                shift @values;
            }

            my @bind;
            my @terms;
            for my $v (@values) {
                my ( $term, $bind ) = $self->_make_term( $col, $v );
                push @terms, "($term)";
                push @bind,  @$bind;
            }
            my $term = join " $logic ", @terms;
            return ($term, \@bind);
        }
        else {
            # make_term(foo => [1,2,3]) => foo IN (1,2,3)
            my $term = $self->_quote($col) . " IN (" . join( ',', ('?') x scalar @$val ) . ')';
            return ($term, $val);
        }
    }
    elsif ( ref($val) eq 'HASH' ) {
        my ( $op, $v ) = ( %{$val} );
        $op = uc($op);
        if ( ( $op eq 'IN' || $op eq 'NOT IN' ) && ref($v) eq 'ARRAY' ) {
            if (@$v == 0) {
                if ($op eq 'IN') {
                    # make_term(foo => +{'IN' => []}) => 0=1
                    return ('0=1', []);
                } else {
                    # make_term(foo => +{'NOT IN' => []}) => 1=1
                    return ('1=1', []);
                }
            } else {
                # make_term(foo => +{ 'IN', [1,2,3] }) => foo IN (1,2,3)
                my $term = $self->_quote($col) . " $op (" . join( ',', ('?') x scalar @$v ) . ')';
                return ($term, $v);
            }
        }
        elsif ( ( $op eq 'IN' || $op eq 'NOT IN' ) && ref($v) eq 'REF' ) {
            # make_term(foo => +{ 'IN', \['SELECT foo FROM bar'] }) => foo IN (SELECT foo FROM bar)
            my @values = @{$$v};
            my $term = $self->_quote($col) . " $op (" . shift(@values) . ')';
            return ($term, \@values);
        }
        elsif ( ( $op eq 'BETWEEN' ) && ref($v) eq 'ARRAY' ) {
            Carp::croak("USAGE: make_term(foo => {BETWEEN => [\$a, \$b]})") if @$v != 2;
            return ($self->_quote($col) . " BETWEEN ? AND ?", $v);
        }
        else {
            # make_term(foo => +{ '<', 3 }) => foo < 3
            return ($self->_quote($col) . " $op ?", [$v]);
        }
    }
    elsif ( ref($val) eq 'SCALAR' ) {
        # make_term(foo => \"> 3") => foo > 3
        return ($self->_quote($col) . " $$val", []);
    }
    elsif ( ref($val) eq 'REF') {
        my ($query, @v) = @{${$val}};
        return ($self->_quote($col) . " $query", \@v);
    }
    else {
        if (defined $val) {
            # make_term(foo => "3") => foo = 3
            return ($self->_quote($col) . " = ?", [$val]);
        } else {
            # make_term(foo => undef) => foo IS NULL
            return ($self->_quote($col) . " IS NULL", []);
        }
    }
}

sub add {
    my ( $self, $col, $val ) = @_;

    my ( $term, $bind ) = $self->_make_term( $col, $val );
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
    my ($self) = @_;
    return join(' AND ', @{$self->{sql}});
}

sub bind {
    my $self = shift;
    return wantarray ? @{$self->{bind}} : $self->{bind};
}

1;
__END__

=head1 NAME

SQL::Builder::Condition - condition object for SQL::Builder

=head1 SYNOPSIS

    my $condition = SQL::Builder::Condition->new(
        name_sep   => '.',
        quote_char => '`',
    );
    $condition->add('foo_id' => 3);
    $condition->add('bar_id' => 4);
    my $sql = $condition->as_sql(); # (`foo_id`=?) AND (`bar_id`=?)
    my @bind = $condition->bind();  # (3, 4)

    # composite and
    my $other = SQL::Builder::Condition->new(
        name_sep => '.',
        quote_char => '`',
    );
    $other->add('name' => 'john');
    my $comp_and = $condition & $other;
    my $sql = $comp_and->as_sql(); # ((`foo_id`=?) AND (`bar_id`=?)) AND (`name`=?)
    my @bind = $comp_and->bind();  # (3, 4, 'john')

    # composite or
    my $comp_or = $condition | $other;
    my $sql = $comp_and->as_sql(); # ((`foo_id`=?) AND (`bar_id`=?)) OR (`name`=?)
    my @bind = $comp_and->bind();  # (3, 4, 'john')

