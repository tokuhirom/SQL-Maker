package SQL::Builder::Select;
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite;
use SQL::Builder::Part;
use SQL::Builder::Where;

Class::Accessor::Lite->mk_accessors(
    qw(
        select distinct select_map select_map_reverse
        _from joins where limit offset group order
        having index_hint
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
        having_bind        => +[],
        _from               => +[],
        where              => SQL::Builder::Where->new(),
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

sub bind {
    my $self = shift;
    return [$self->where->bind, @{$self->{having_bind}}];
}

sub add_select {
    my $self = shift;
    my($term, $col) = @_;
    $col ||= $term;
    push @{ $self->select }, $term;
    $self->select_map->{$term} = $col;
    $self->select_map_reverse->{$col} = $term;
}

sub add_from {
    my ($self, $table, $alias) = @_;
    push @{$self->_from}, [$table, $alias];
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
        $sql .= ', ' if @{ $self->_from };
    }

    if ($self->_from && @{ $self->_from }) {
        $sql .= join ', ', map { $self->_add_index_hint($_) } map { $_->[1] ? "$_->[0] $_->[1]" : $_->[0] } @{ $self->_from };
    }

    $sql .= "\n";
    $sql .= $self->as_sql_where();

    $sql .= $self->as_sql_group_by;
    $sql .= $self->as_sql_having;
    $sql .= $self->as_sql_order_by;

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

sub as_sql_order_by {
    my ($self) = @_;
    my $set = 'order';

    return '' unless my $attribute = $self->order();

    my $ref = ref $attribute;
    if (!$ref) {
        return "ORDER BY $attribute\n";
    }

    if ($ref eq 'ARRAY' && scalar @$attribute == 0) {
        return '';
    }

    my $elements = ($ref eq 'ARRAY') ? $attribute : [ $attribute ];
    return 'ORDER BY '
           . join(', ', map { $_->{column} . ($_->{desc} ? (' ' . $_->{desc}) : '') } @$elements)
           . "\n";
}

sub as_sql_group_by {
    my ($self,) = @_;

    return '' unless my $attribute = $self->group();

    my $ref = ref $attribute;
    if (!$ref) {
        return "GROUP BY $attribute\n";
    }

    if ($ref eq 'ARRAY' && scalar @$attribute == 0) {
        return '';
    }

    my $elements = ($ref eq 'ARRAY') ? $attribute : [ $attribute ];
    return 'GROUP BY '
           . join(', ', map { $_->{column} . ($_->{desc} ? (' ' . $_->{desc}) : '') } @$elements)
           . "\n";
}

sub as_sql_where {
    my $self = shift;

    my $where = $self->where->as_sql();
    $where ? "WHERE $where\n" : '';
}

sub as_sql_having {
    my $self = shift;
    $self->having && @{ $self->having } ?
        'HAVING ' . join(' AND ', @{ $self->having }) . "\n" :
        '';
}

sub add_having {
    my $self = shift;
    my($col, $val) = @_;

    if (my $orig = $self->select_map_reverse->{$col}) {
        $col = $orig;
    }

    my($term, $bind) = SQL::Builder::Part->make_term($col, $val);
    push @{ $self->{having} }, "($term)";
    push @{ $self->{having_bind} }, @$bind;
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

SQL::Builder::Select - dynamic SQL generator

=head1 SYNOPSIS

    my $sql = SQL::Builder::Select->new;
    $sql->select(['foo', 'bar', 'baz']);
    $sql->add_from('table_name');
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name;"

    $sql->where->add('col' => "value");
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name WHERE ( col = ? );"

    $sql->where->add(name => { like => "%value" });
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name WHERE ( col = ? ) AND ( name LIKE ? );"

    $sql->where->add(bar => \"IS NOT NULL");
    $sql->as_sql;
        #=> "SELECT foo, bar, baz FROM table_name WHERE ( col = ? ) AND ( name LIKE ? ) AND ( bar IS NOT NULL );"

    # execute SQL and return DBIx::Skinny::Iterator object.
    my $iter = $sql->retrieve;

    my $sql2 = SQL::Builder::Select->new;
    $sql2->add_join(foo => [
        { table => "bar", type => "inner", condition => "foo.bar_id = bar.id" },
    ]);
    $sql2->select(['*']);
    $sql2->as_sql;
        #=> "SELECT * FROM foo INNER JOIN bar ON foo.bar_id = bar.id;"


=head1 DESCRIPTION

=head1 TODO

    AND/OR support for add_complex_where.
    call() for stored procedure

=head1 SEE ALSO

+<Data::ObjectDriver::SQL>

