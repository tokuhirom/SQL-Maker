package SQL::Builder::Select;
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite;
use SQL::Builder::Part;
use SQL::Builder::Where;
use SQL::Builder::Util;

Class::Accessor::Lite->mk_wo_accessors(qw/limit offset distinct for_update/);
Class::Accessor::Lite->mk_accessors( qw(where prefix) );

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    my $self = bless {
        select             => +[],
        distinct           => 0,
        select_map         => +{},
        select_map_reverse => +{},
        having_bind        => +[],
        from               => +[],
        where              => SQL::Builder::Where->new(),
        joins              => +[],
        index_hint         => +{},
        group_by           => +[],
        order_by           => +[],
        prefix             => 'SELECT ',
        %args
    }, $class;

    return $self;
}

sub bind {
    my $self = shift;
    return [$self->where->bind, @{$self->{having_bind}}];
}

sub add_select {
    my ($self, $term, $col) = @_;

    $col ||= $term;
    push @{ $self->{select} }, $term;
    $self->{select_map}->{$term} = $col;
    $self->{select_map_reverse}->{$col} = $term;
}

sub add_from {
    my ($self, $table, $alias) = @_;
    push @{$self->{from}}, [$table, $alias];
}

sub add_join {
    my ($self, $table, $joins) = @_;

    push @{ $self->{joins} }, {
        table => $table,
        joins => $joins,
    };
}

sub add_index_hint {
    my ($self, $table, $hint) = @_;

    $self->{index_hint}->{$table} = {
        type => $hint->{type} || 'USE',
        list => ref($hint->{list}) eq 'ARRAY' ? $hint->{list} : [ $hint->{list} ],
    };
}

sub _quote {
    my ($self, $label) = @_;

    return $$label if ref $label;
    SQL::Builder::Util::quote_identifier($label, $self->{quote_char}, $self->{name_sep})
}

sub as_sql {
    my $self = shift;
    my $sql = '';
    if (@{ $self->{select} }) {
        $sql .= $self->{prefix};
        $sql .= 'DISTINCT ' if $self->{distinct};
        $sql .= join(', ',  map {
            my $alias = $self->{select_map}->{$_};
            if (!$alias) {
                $self->_quote($_)
            } elsif ($alias && $_ =~ /(?:^|\.)\Q$alias\E$/) {
                $self->_quote($_)
            } else {
                $self->_quote($_) . ' AS ' .  $self->_quote($alias)
            }
        } @{ $self->{select} }) . "\n";
    }

    $sql .= 'FROM ';

    ## Add any explicit JOIN statements before the non-joined tables.
    if ($self->{joins} && @{ $self->{joins} }) {
        my $initial_table_written = 0;
        for my $j (@{ $self->{joins} }) {
            my ($table, $join) = map { $j->{$_} } qw( table joins );
            $table = $self->_add_index_hint($table); ## index hint handling
            $sql .= $table unless $initial_table_written++;
            $sql .= ' ' . uc($join->{type}) . ' JOIN ' . $self->_quote($join->{table});
            $sql .= ' ' . $self->_quote($join->{alias}) if $join->{alias};

            if (ref $join->{condition}) {
                $sql .= ' USING ('. join(', ', @{ $join->{condition} }) . ')';
            }
            else {
                $sql .= ' ON ' . $join->{condition};
            }
        }
        $sql .= ', ' if @{ $self->{from} };
    }

    if ($self->{from} && @{ $self->{from} }) {
        $sql .= join ', ',
          map { $self->_add_index_hint($_->[0], $_->[1]) }
             @{ $self->{from} };
    }

    $sql .= "\n";
    $sql .= $self->as_sql_where();

    $sql .= $self->as_sql_group_by  if $self->{group_by};
    $sql .= $self->as_sql_having    if $self->{having};
    $sql .= $self->as_sql_order_by  if $self->{order_by};

    $sql .= $self->as_limit         if $self->{limit};

    $sql .= $self->as_for_update;

    return $sql;
}

sub as_limit {
    my $self = shift;
    my $n = $self->{limit} or
        return '';
    die "Non-numerics in limit clause ($n)" if $n =~ /\D/;
    return sprintf "LIMIT %d%s\n", $n,
           ($self->{offset} ? " OFFSET " . int($self->{offset}) : "");
}

sub add_order_by {
    my ($self, $col, $type) = @_;
    push @{$self->{order_by}}, [$col, $type];
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
                    $col ? $self->_quote($col) . " $type" : $self->_quote($col)
                }
           } @attrs)
           . "\n";
}

sub add_group_by {
    my ($self, $group, $order) = @_;
    push @{$self->{group_by}}, $order ? $self->_quote($group) . " $order" : $self->_quote($group);
}

sub as_sql_group_by {
    my ($self,) = @_;

    my $elems = $self->{group_by};

    return '' if @$elems == 0;

    return 'GROUP BY '
           . join(', ', @$elems)
           . "\n";
}

sub as_sql_where {
    my $self = shift;

    my $where = $self->{where}->as_sql();
    $where ? "WHERE $where\n" : '';
}

sub as_sql_having {
    my $self = shift;
    if ($self->{having} && @{$self->{having}}) {
        'HAVING ' . join(' AND ', @{ $self->{having} }) . "\n";
    } else {
        ''
    }
}

sub add_having {
    my ($self, $col, $val) = @_;

    if (my $orig = $self->{select_map_reverse}->{$col}) {
        $col = $self->_quote($orig);
    }

    my($term, $bind) = SQL::Builder::Part->make_term($col, $val);
    push @{ $self->{having} }, "($term)";
    push @{ $self->{having_bind} }, @$bind;
}

sub as_for_update {
    my $self = shift;
    $self->{for_update} ? ' FOR UPDATE' : '';
}

sub _add_index_hint {
    my ($self, $tbl_name, $alias) = @_;
    my $quoted = $alias ? $self->_quote($tbl_name) . ' ' . $self->_quote($alias) : $self->_quote($tbl_name);
    my $hint = $self->{index_hint}->{$tbl_name};
    return $quoted unless $hint && ref($hint) eq 'HASH';
    if ($hint->{list} && @{ $hint->{list} }) {
        return $quoted . ' ' . uc($hint->{type} || 'USE') . ' INDEX (' . 
                join (',', map { $self->_quote($_) } @{ $hint->{list} }) .
                ')';
    }
    return $quoted;
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

=head1 METHODS

=over 4

=item $stmt->add_order_by('foo');

=item $stmt->add_order_by({'foo' => 'DESC'});

=back

=head1 TODO

    call() for stored procedure

=head1 SEE ALSO

+<Data::ObjectDriver::SQL>

