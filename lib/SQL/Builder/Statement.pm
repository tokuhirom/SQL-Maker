package SQL::Builder::Statement;
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite;
use SQL::Builder::Part;

Class::Accessor::Lite->mk_accessors(
    qw(
        select distinct select_map select_map_reverse
        from joins where bind limit offset group order
        having column_mutator index_hint
        for_update
    )
);

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    my $self = bless {
        select             => +[],
        distinct           => 0,
        select_map         => +{},
        select_map_reverse => +{},
        bind               => +[],
        from               => +[],
        where              => +[],
        having             => +[],
        joins              => +[],
        index_hint         => +{},
        group              => +[],
        order              => +[],
        having             => +[],
        %args
    }, $class;

    return $self;
}

sub add_select {
    my $self = shift;
    my($term, $col) = @_;
    $col ||= $term;
    push @{ $self->select }, $term;
    $self->select_map->{$term} = $col;
    $self->select_map_reverse->{$col} = $term;
}

sub add_join {
    my $self = shift;
    my($table, $joins) = @_;
    push @{ $self->joins }, {
        table => $table,
        joins => ref($joins) eq 'ARRAY' ? $joins : [ $joins ],
    };
}

sub add_index_hint {
    my $self = shift;
    my($table, $hint) = @_;
    $self->index_hint->{$table} = {
        type => $hint->{type} || 'USE',
        list => ref($hint->{list}) eq 'ARRAY' ? $hint->{list} : [ $hint->{list} ],
    };
}

sub as_sql {
    my $self = shift;
    my $sql = '';
    if (@{ $self->select }) {
        $sql .= 'SELECT ';
        $sql .= 'DISTINCT ' if $self->distinct;
        $sql .= join(', ',  map {
            my $alias = $self->select_map->{$_};
            !$alias                         ? $_ :
            $alias && /(?:^|\.)\Q$alias\E$/ ? $_ : "$_ AS $alias";
        } @{ $self->select }) . "\n";
    }

    $sql .= 'FROM ';

    ## Add any explicit JOIN statements before the non-joined tables.
    if ($self->joins && @{ $self->joins }) {
        my $initial_table_written = 0;
        for my $j (@{ $self->joins }) {
            my($table, $joins) = map { $j->{$_} } qw( table joins );
            $table = $self->_add_index_hint($table); ## index hint handling
            $sql .= $table unless $initial_table_written++;
            for my $join (@{ $j->{joins} }) {
                $sql .= ' ' . uc($join->{type}) . ' JOIN ' . $join->{table};
                
                if (ref $join->{condition}) {
                    $sql .= ' USING ('. join(', ', @{ $join->{condition} }) . ')';
                }
                else {
                    $sql .= ' ON ' . $join->{condition};
                }
            }
        }
        $sql .= ', ' if @{ $self->from };
    }

    if ($self->from && @{ $self->from }) {
        $sql .= join ', ', map { $self->_add_index_hint($_) } @{ $self->from };
    }

    $sql .= "\n";
    $sql .= $self->as_sql_where;

    $sql .= $self->as_aggregate('group');
    $sql .= $self->as_sql_having;
    $sql .= $self->as_aggregate('order');

    $sql .= $self->as_limit;

    $sql .= $self->as_for_update;

    return $sql;
}

sub as_limit {
    my $self = shift;
    my $n = $self->limit or
        return '';
    die "Non-numerics in limit clause ($n)" if $n =~ /\D/;
    return sprintf "LIMIT %d%s\n", $n,
           ($self->offset ? " OFFSET " . int($self->offset) : "");
}

sub as_aggregate {
    my ($self, $set) = @_;

    return '' unless my $attribute = $self->$set();

    my $ref = ref $attribute;
    if (!$ref) {
        return uc($set)  . " BY $attribute\n";
    }

    if ($ref eq 'ARRAY' && scalar @$attribute == 0) {
        return '';
    }

    my $elements = ($ref eq 'ARRAY') ? $attribute : [ $attribute ];
    return uc($set)
           . ' BY '
           . join(', ', map { $_->{column} . ($_->{desc} ? (' ' . $_->{desc}) : '') } @$elements)
           . "\n";
}

sub as_sql_where {
    my $self = shift;
    $self->where && @{ $self->where } ?
        'WHERE ' . join(' AND ', @{ $self->where }) . "\n" :
        '';
}

sub as_sql_having {
    my $self = shift;
    $self->having && @{ $self->having } ?
        'HAVING ' . join(' AND ', @{ $self->having }) . "\n" :
        '';
}

sub add_where {
    my $self = shift;
    ## xxx Need to support old range and transform behaviors.
    my($col, $val) = @_;
    # XXX; DATE_FORMAT(member.created_at,'%Y-%m') 
#    Carp::croak("Invalid/unsafe column name $col") unless $col =~ /^[\w\.]+$/;
    my($term, $bind, $tcol) = SQL::Builder::Part->make_term($col, $val);
    push @{ $self->{where} }, "($term)";
    push @{ $self->{bind} }, @$bind;
}

sub add_complex_where {
    my $self = shift;
    my ($terms) = @_;
    my ($where, $bind) = $self->_parse_array_terms($terms);
    push @{ $self->{where} }, $where;
    push @{ $self->{bind} }, @$bind;
}

sub _parse_array_terms {
    my $self = shift;
    my ($term_list) = @_;

    my @out;
    my $logic = 'AND';
    my @bind;
    foreach my $t ( @$term_list ) {
        if (! ref $t ) {
            $logic = $1 if uc($t) =~ m/^-?(OR|AND|OR_NOT|AND_NOT)$/;
            $logic =~ s/_/ /;
            next;
        }
        my $out;
        if (ref $t eq 'HASH') {
            # bag of terms to apply $logic with
            my @out;
            foreach my $t2 ( keys %$t ) {
                my ($term, $bind, $col) = SQL::Builder::Part->make_term($t2, $t->{$t2});
                push @out, $term;
                push @bind, @$bind;
            }
            $out .= '(' . join(" AND ", @out) . ")";
        }
        elsif (ref $t eq 'ARRAY') {
            # another array of terms to process!
            my ($where, $bind) = $self->_parse_array_terms( $t );
            push @bind, @$bind;
            $out = '(' . $where . ')';
        }
        push @out, (@out ? ' ' . $logic . ' ' : '') . $out;
    }
    return (join("", @out), \@bind);
}

sub add_having {
    my $self = shift;
    my($col, $val) = @_;

    if (my $orig = $self->select_map_reverse->{$col}) {
        $col = $orig;
    }

    my($term, $bind) = SQL::Builder::Part->make_term($col, $val);
    push @{ $self->{having} }, "($term)";
    push @{ $self->{bind} }, @$bind;
}

sub as_for_update {
    my $self = shift;
    $self->for_update ? ' FOR UPDATE' : '';
}

sub _add_index_hint {
    my $self = shift;
    my ($tbl_name) = @_;
    my $hint = $self->index_hint->{$tbl_name};
    return $tbl_name unless $hint && ref($hint) eq 'HASH';
    if ($hint->{list} && @{ $hint->{list} }) {
        return $tbl_name . ' ' . uc($hint->{type} || 'USE') . ' INDEX (' . 
                join (',', @{ $hint->{list} }) .
                ')';
    }
    return $tbl_name;
}

1;
__END__

=head1 NAME

SQL::Builder::Statement - dynamic SQL generator

=head1 SYNOPSIS

    my $sql = SQL::Builder::Statement->new;
    $sql->select(['foo', 'bar', 'baz']);
    $sql->from(['table_name']);
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name;"

    $sql->add_where('col' => "value");
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name WHERE ( col = ? );"

    $sql->add_where(name => { like => "%value" });
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name WHERE ( col = ? ) AND ( name LIKE ? );"

    $sql->add_where(bar => \"IS NOT NULL");
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name WHERE ( col = ? ) AND ( name LIKE ? ) AND ( bar IS NOT NULL );"

    # execute SQL and return DBIx::Skinny::Iterator object.
    my $iter = $sql->retrieve;

    my $sql2 = SQL::Builder::Statement->new;
    $sql2->from([]);
    $sql2->add_join(foo => [
        { table => "bar", type => "inner", condition => "foo.bar_id = bar.id" },
    ]);
    $sql2->select(['*']);
    $sql2->as_sql;
        #=> "SELECT * FROM foo INNER JOIN bar ON foo.bar_id = bar.id;"

    $sql2->add_complex_where([[ -or => { foo => "bar" }, { foo => "baz" } ]]);
    $sql2->as_sql;
        #=> "SELECT * FROM foo INNER JOIN bar ON foo.bar_id = bar.id WHERE ( ( foo = ? ) OR ( foo = ? ) )"

=head1 DESCRIPTION

=head1 SEE ALSO

+<Data::ObjectDriver::SQL>

