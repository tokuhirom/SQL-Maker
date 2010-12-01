package SQL::Builder::Part;
use strict;
use warnings;
use utf8;

sub make_term {
    my $class = shift;
    my ( $col, $val ) = @_;
    my $term = '';
    my ( @bind, $m );
    if ( ref($val) eq 'ARRAY' ) {
        if ( ref $val->[0] or ( ( $val->[0] || '' ) eq '-and' ) ) {
            my $logic  = 'OR';
            my @values = @$val;
            if ( $val->[0] eq '-and' ) {
                $logic = 'AND';
                shift @values;
            }

            my @terms;
            for my $v (@values) {
                my ( $term, $bind ) = $class->make_term( $col, $v );
                push @terms, "($term)";
                push @bind,  @$bind;
            }
            $term = join " $logic ", @terms;
        }
        else {
            $term = "$col IN (" . join( ',', ('?') x scalar @$val ) . ')';
            @bind = @$val;
        }
    }
    elsif ( ref($val) eq 'HASH' ) {
        my $c = $val->{column} || $col;

        my ( $op, $v ) = ( %{$val} );
        $op = uc($op);
        if ( ( $op eq 'IN' || $op eq 'NOT IN' ) && ref($v) eq 'ARRAY' ) {
            $term = "$c $op (" . join( ',', ('?') x scalar @$v ) . ')';
            @bind = @$v;
        }
        else {
            $term = "$c $op ?";
            push @bind, $v;
        }
    }
    elsif ( ref($val) eq 'SCALAR' ) {
        $term = "$col $$val";
    }
    else {
        $term = "$col = ?";
        push @bind, $val;
    }
    return ( $term, \@bind, $col );
}

1;

