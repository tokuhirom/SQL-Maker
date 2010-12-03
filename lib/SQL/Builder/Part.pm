package SQL::Builder::Part;
use strict;
use warnings;
use utf8;

sub make_term {
    my ($class, $col, $val) = @_;

    if ( ref($val) eq 'ARRAY' ) {
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
        else {
            # make_term(foo => +{ '<', 3 }) => foo < 3
            return ("$col $op ?", [$v]);
        }
    }
    elsif ( ref($val) eq 'SCALAR' ) {
        # make_term(foo => \"> 3") => foo > 3
        return ("$col $$val", []);
    }
    else {
        # make_term(foo => "3") => foo = 3
        return ("$col = ?", [$val]);
    }
}

1;

