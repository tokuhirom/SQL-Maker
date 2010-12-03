package SQL::Builder::Part;
use strict;
use warnings;
use utf8;

# TODO: support sub query?
sub make_term {
    my ($class, $col, $val) = @_;

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
                my ( $term, $bind ) = $class->make_term( $col, $v );
                push @terms, "($term)";
                push @bind,  @$bind;
            }
            my $term = join " $logic ", @terms;
            return ($term, \@bind);
        }
        else {
            # make_term(foo => [1,2,3]) => foo IN (1,2,3)
            my $term = "$col IN (" . join( ',', ('?') x scalar @$val ) . ')';
            return ($term, $val);
        }
    }
    elsif ( ref($val) eq 'HASH' ) {
        my ( $op, $v ) = ( %{$val} );
        $op = uc($op);
        if ( ( $op eq 'IN' || $op eq 'NOT IN' ) && ref($v) eq 'ARRAY' ) {
            # make_term(foo => +{ 'IN', [1,2,3] }) => foo IN (1,2,3)
            my $term = "$col $op (" . join( ',', ('?') x scalar @$v ) . ')';
            return ($term, $v);
        }
        elsif ( ( $op eq 'BETWEEN' ) && ref($v) eq 'ARRAY' ) {
            Carp::croak("USAGE: make_term(foo => {BETWEEN => [\$a, \$b]})") if @$v != 2;
            return ("$col BETWEEN ? AND ?", $v);
        }
        else {
            # make_term(foo => +{ '<', 3 }) => foo < 3
            return ("$col $op ?", [$v]);
        }
    }
    elsif ( ref($val) eq 'SCALAR' ) {
        # make_term(foo => \"> 3") => foo > 3
        return ("$col $$val", []);
    }
    elsif ( ref($val) eq 'REF') {
        my ($query, @v) = @{${$val}};
        return ("$col $query", \@v);
    }
    else {
        # make_term(foo => "3") => foo = 3
        return ("$col = ?", [$val]);
    }
}

1;

