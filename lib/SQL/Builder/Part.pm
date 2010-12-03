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
            # make_term(foo => [1,2,3]) => foo IN (1,2,3)
            $term = "$col IN (" . join( ',', ('?') x scalar @$val ) . ')';
            @bind = @$val;
        }
    }
    elsif ( ref($val) eq 'HASH' ) {
        my ( $op, $v ) = ( %{$val} );
        $op = uc($op);
        if ( ( $op eq 'IN' || $op eq 'NOT IN' ) && ref($v) eq 'ARRAY' ) {
            # make_term(foo => +{ 'IN', [1,2,3] }) => foo IN (1,2,3)
            $term = "$col $op (" . join( ',', ('?') x scalar @$v ) . ')';
            @bind = @$v;
        }
        else {
            # make_term(foo => +{ '<', 3 }) => foo < 3
            $term = "$col $op ?";
            push @bind, $v;
        }
    }
    elsif ( ref($val) eq 'SCALAR' ) {
        # make_term(foo => \"> 3") => foo > 3
        $term = "$col $$val";
    }
    else {
        # make_term(foo => "3") => foo = 3
        $term = "$col = ?";
        push @bind, $val;
    }
    return ( $term, \@bind );
}

1;

