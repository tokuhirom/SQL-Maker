package SQL::Maker::Select;
use strict;
use warnings;
use utf8;
use SQL::Maker::Condition;
use SQL::Maker::Util;
use Class::Accessor::Lite (
    new => 0,
    wo => [qw/distinct for_update/],
    rw => [qw/prefix/],
    ro => [qw/quote_char name_sep new_line strict/],
);
use Scalar::Util ();

sub offset {
    if (@_==1) {
        return $_[0]->{offset};
    } else {
        $_[0]->{offset} = $_[1];
        return $_[0];
    }
}

sub limit {
    if (@_==1) {
        $_[0]->{limit};
    } else {
        $_[0]->{limit} = $_[1];
        return $_[0];
    }
}

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    my $self = bless {
        select             => +[],
        distinct           => 0,
        select_map         => +{},
        select_map_reverse => +{},
        from               => +[],
        joins              => +[],
        index_hint         => +{},
        group_by           => +[],
        order_by           => +[],
        prefix             => 'SELECT ',
        new_line           => "\n",
        strict             => 0,
        %args
    }, $class;

    return $self;
}

sub new_condition {
    my $self = shift;

    SQL::Maker::Condition->new(
        quote_char => $self->{quote_char},
        name_sep   => $self->{name_sep},
        strict     => $self->{strict},
    );
}

sub bind {
    my $self = shift;
    my @bind;
    push @bind, @{$self->{subqueries}} if $self->{subqueries};
    push @bind, $self->{where}->bind  if $self->{where};
    push @bind, $self->{having}->bind if $self->{having};
    return wantarray ? @bind : \@bind;
}

sub add_select {
    my ($self, $term, $col) = @_;

    $col ||= $term;
    push @{ $self->{select} }, $term;
    $self->{select_map}->{$term} = $col;
    $self->{select_map_reverse}->{$col} = $term;
    return $self;
}

sub add_from {
    my ($self, $table, $alias) = @_;
    if ( Scalar::Util::blessed( $table ) and $table->can('as_sql') ) {
        push @{ $self->{subqueries} }, $table->bind;
        push @{$self->{from}}, [ \do{ '(' . $table->as_sql . ')' }, $alias ];
    }
    else {
        push @{$self->{from}}, [$table, $alias];
    }
    return $self;
}

sub add_join {
    my ($self, $table_ref, $joins) = @_;
    my ($table, $alias) = ref($table_ref) eq 'ARRAY' ? @$table_ref : ($table_ref);

    if ( Scalar::Util::blessed( $table ) and $table->can('as_sql') ) {
        push @{ $self->{subqueries} }, $table->bind;
        $table = \do{ '(' . $table->as_sql . ')' };
    }

    push @{ $self->{joins} }, {
        table => [ $table, $alias ],
        joins => $joins,
    };
    return $self;
}

sub add_index_hint {
    my ($self, $table, $hint) = @_;

    my ($type, $list);

    if (ref $hint eq 'HASH') {
        # { type => '...', list => ['foo'] }
        $type = $hint->{type} || 'USE';
        $list = ref($hint->{list}) eq 'ARRAY' ? $hint->{list} : [ $hint->{list} ];
    } else {
        # ['foo, 'bar'] or just 'foo'
        $type = 'USE';
        $list = ref($hint) eq 'ARRAY' ? $hint : [ $hint ];
    }

    $self->{index_hint}->{$table} = {
        type => $type,
        list => $list,
    };

    return $self;
}

sub _quote {
    my ($self, $label) = @_;

    return $$label if ref $label eq 'SCALAR';
    SQL::Maker::Util::quote_identifier($label, $self->{quote_char}, $self->{name_sep})
}

sub as_sql {
    my $self = shift;
    my $sql = '';
    my $new_line = $self->new_line;
    
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
        } @{ $self->{select} }) . $new_line;
    }

    $sql .= 'FROM ';

    ## Add any explicit JOIN statements before the non-joined tables.
    if ($self->{joins} && @{ $self->{joins} }) {
        my $initial_table_written = 0;
        for my $j (@{ $self->{joins} }) {
            my ($table, $join) = map { $j->{$_} } qw( table joins );
            $table = $self->_add_index_hint(@$table); ## index hint handling
            $sql .= $table unless $initial_table_written++;
            $sql .= ' ' . uc($join->{type}) if $join->{type};
            $sql .= ' JOIN ' . $self->_quote($join->{table});
            $sql .= ' ' . $self->_quote($join->{alias}) if $join->{alias};

            if ( defined $join->{condition} ) {
                if (ref $join->{condition} && ref $join->{condition} eq 'ARRAY') {
                    $sql .= ' USING ('. join(', ', map { $self->_quote($_) } @{ $join->{condition} }) . ')';
                }
                elsif (ref $join->{condition} && ref $join->{condition} eq 'HASH') {
                    my @conds;
                    for my $key (keys %{ $join->{condition} }) {
                        push @conds, $self->_quote($key) . ' = ' . $self->_quote($join->{condition}{$key});
                    }
                    $sql .= ' ON ' . join(' AND ', @conds);
                }
                else {
                    $sql .= ' ON ' . $join->{condition};
                }
            }
        }
        $sql .= ', ' if @{ $self->{from} };
    }

    if ($self->{from} && @{ $self->{from} }) {
        $sql .= join ', ',
          map { $self->_add_index_hint($_->[0], $_->[1]) }
             @{ $self->{from} };
    }

    $sql .= $new_line;
    $sql .= $self->as_sql_where()   if $self->{where};

    $sql .= $self->as_sql_group_by  if $self->{group_by};
    $sql .= $self->as_sql_having    if $self->{having};
    $sql .= $self->as_sql_order_by  if $self->{order_by};

    $sql .= $self->as_sql_limit     if defined $self->{limit};

    $sql .= $self->as_sql_for_update;
    $sql =~ s/${new_line}+$//;

    return $sql;
}

sub as_sql_limit {
    my $self = shift;

    my $n = $self->{limit};
    return '' unless defined $n;

    die "Non-numerics in limit clause ($n)" if $n =~ /\D/;
    return sprintf "LIMIT %d%s" . $self->new_line, $n,
           ($self->{offset} ? " OFFSET " . int($self->{offset}) : "");
}

sub add_order_by {
    my ($self, $col, $type) = @_;
    push @{$self->{order_by}}, [$col, $type];
    return $self;
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
           } @attrs)
           . $self->new_line;
}

sub add_group_by {
    my ($self, $group, $order) = @_;
    push @{$self->{group_by}}, $order ? $self->_quote($group) . " $order" : $self->_quote($group);
    return $self;
}

sub as_sql_group_by {
    my ($self,) = @_;

    my $elems = $self->{group_by};

    return '' if @$elems == 0;

    return 'GROUP BY '
           . join(', ', @$elems)
           . $self->new_line;
}

sub set_where {
    my ($self, $where) = @_;
    $self->{where} = $where;
    return $self;
}

sub add_where {
    my ($self, $col, $val) = @_;

    $self->{where} ||= $self->new_condition();
    $self->{where}->add($col, $val);
    return $self;
}

sub add_where_raw {
    my ($self, $term, $bind) = @_;

    $self->{where} ||= $self->new_condition();
    $self->{where}->add_raw($term, $bind);
    return $self;
}

sub as_sql_where {
    my $self = shift;

    my $where = $self->{where}->as_sql(undef, sub { $self->_quote($_[0]) });
    $where ? "WHERE $where" . $self->new_line : '';
}

sub as_sql_having {
    my $self = shift;
    if ($self->{having}) {
        'HAVING ' . $self->{having}->as_sql . $self->new_line;
    } else {
        ''
    }
}

sub add_having {
    my ($self, $col, $val) = @_;

    if (my $orig = $self->{select_map_reverse}->{$col}) {
        $col = $orig;
    }

    $self->{having} ||= $self->new_condition();
    $self->{having}->add($col, $val);
    return $self;
}

sub as_sql_for_update {
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

SQL::Maker::Select - dynamic SQL generator

=head1 SYNOPSIS

    my $sql = SQL::Maker::Select->new()
                                  ->add_select('foo')
                                  ->add_select('bar')
                                  ->add_select('baz')
                                  ->add_from('table_name')
                                  ->as_sql;
    # => "SELECT foo, bar, baz FROM table_name"

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item C<< my $sql = $stmt->as_sql(); >>

Render the SQL string.

=item C<< my @bind = $stmt->bind(); >>

Get the bind variables.

=item C<< $stmt->add_select('*') >>

=item C<< $stmt->add_select($col => $alias) >>

=item C<< $stmt->add_select(\'COUNT(*)' => 'cnt') >>

Add a new select term. It's automatically quoted.

=item C<< $stmt->add_from($table :Str | $select :SQL::Maker::Select) : SQL::Maker::Select >>

Add a new FROM clause. You can specify the table name or an instance of L<SQL::Maker::Select> for a sub-query.

I<Return:> $stmt itself.

=item C<< $stmt->add_join(user => {type => 'inner', table => 'config', condition => 'user.user_id = config.user_id'}); >>

=item C<< $stmt->add_join(user => {type => 'inner', table => 'config', condition => {'user.user_id' => 'config.user_id'}); >>

=item C<< $stmt->add_join(user => {type => 'inner', table => 'config', condition => ['user_id']}); >>

Add a new JOIN clause. If you pass an arrayref for 'condition' then it uses 'USING'. If 'type' is omitted
it falls back to plain JOIN.

    my $stmt = SQL::Maker::Select->new();
    $stmt->add_join(
        user => {
            type      => 'inner',
            table     => 'config',
            condition => 'user.user_id = config.user_id',
        }
    );
    $stmt->as_sql();
    # => 'FROM user INNER JOIN config ON user.user_id = config.user_id'

    my $stmt = SQL::Maker::Select->new(quote_char => '`', name_sep => '.');
    $stmt->add_join(
        user => {
            type      => 'inner',
            table     => 'config',
            condition => {'user.user_id' => 'config.user_id'},
        }
    );
    $stmt->as_sql();
    # => 'FROM `user` INNER JOIN `config` ON `user`.`user_id` = `config`.`user_id`'

    my $stmt = SQL::Maker::Select->new();
    $stmt->add_select('name');
    $stmt->add_join(
        user => {
            type      => 'inner',
            table     => 'config',
            condition => ['user_id'],
        }
    );
    $stmt->as_sql();
    # => 'SELECT name FROM user INNER JOIN config USING (user_id)'

    my $subquery = SQL::Maker::Select->new();
    $subquery->add_select('*');
    $subquery->add_from( 'foo' );
    $subquery->add_where( 'hoge' => 'fuga' );
    my $stmt = SQL::Maker::Select->new();
    $stmt->add_join(
        [ $subquery, 'bar' ] => {
            type      => 'inner',
            table     => 'baz',
            alias     => 'b1',
            condition => 'bar.baz_id = b1.baz_id'
        },
    );
    $stmt->as_sql;
    # => "FROM (SELECT * FROM foo WHERE (hoge = ?)) bar INNER JOIN baz b1 ON bar.baz_id = b1.baz_id";

=item C<< $stmt->add_index_hint(foo => {type => 'USE', list => ['index_hint']}); >>

=item C<< $stmt->add_index_hint(foo => 'index_hint'); >>

=item C<< $stmt->add_index_hint(foo => ['index_hint']); >>

    my $stmt = SQL::Maker::Select->new();
    $stmt->add_select('name');
    $stmt->add_from('user');
    $stmt->add_index_hint(user => {type => 'USE', list => ['index_hint']});
    $stmt->as_sql();
    # => "SELECT name FROM user USE INDEX (index_hint)"

=item C<< $stmt->add_where('foo_id' => 'bar'); >>

Add a new WHERE clause.

    my $stmt = SQL::Maker::Select->new()
                                   ->add_select('c')
                                   ->add_from('foo')
                                   ->add_where('name' => 'john')
                                   ->add_where('type' => {IN => [qw/1 2 3/]})
                                   ->as_sql();
    # => "SELECT c FROM foo WHERE (name = ?) AND (type IN (?, ?, ?))"

=item C<< $stmt->add_where_raw('id = ?', [1]) >>

Add a new WHERE clause from raw placeholder string and bind variables.

    my $stmt = SQL::Maker::Select->new()
                                   ->add_select('c')
                                   ->add_from('foo')
                                   ->add_where_raw('EXISTS(SELECT * FROM bar WHERE name = ?)' => ['john'])
                                   ->add_where_raw('type IS NOT NULL')
                                   ->as_sql();
    # => "SELECT c FROM foo WHERE (EXISTS(SELECT * FROM bar WHERE name = ?)) AND (type IS NOT NULL)"


=item C<< $stmt->set_where($condition) >>

Set the WHERE clause.

$condition should be instance of L<SQL::Maker::Condition>.

    my $cond1 = SQL::Maker::Condition->new()
                                       ->add("name" => "john");
    my $cond2 = SQL::Maker::Condition->new()
                                       ->add("type" => {IN => [qw/1 2 3/]});
    my $stmt = SQL::Maker::Select->new()
                                   ->add_select('c')
                                   ->add_from('foo')
                                   ->set_where($cond1 & $cond2)
                                   ->as_sql();
    # => "SELECT c FROM foo WHERE ((name = ?)) AND ((type IN (?, ?, ?)))"

=item C<< $stmt->add_order_by('foo'); >>

=item C<< $stmt->add_order_by({'foo' => 'DESC'}); >>

Add a new ORDER BY clause.

    my $stmt = SQL::Maker::Select->new()
                                   ->add_select('c')
                                   ->add_from('foo')
                                   ->add_order_by('name' => 'DESC')
                                   ->add_order_by('id')
                                   ->as_sql();
    # => "SELECT c FROM foo ORDER BY name DESC, id"

=item C<< $stmt->add_group_by('foo'); >>

Add a new GROUP BY clause.

    my $stmt = SQL::Maker::Select->new()
                                   ->add_select('c')
                                   ->add_from('foo')
                                   ->add_group_by('id')
                                   ->as_sql();
    # => "SELECT c FROM foo GROUP BY id"

    my $stmt = SQL::Maker::Select->new()
                                   ->add_select('c')
                                   ->add_from('foo')
                                   ->add_group_by('id' => 'DESC')
                                   ->as_sql();
    # => "SELECT c FROM foo GROUP BY id DESC"

=item C<< $stmt->limit(30) >>

=item C<< $stmt->offset(5) >>

Add LIMIT and OFFSET.

    my $stmt = SQL::Maker::Select->new()
                                   ->add_select('c')
                                   ->add_from('foo')
                                   ->limit(30)
                                   ->offset(5)
                                   ->as_sql();
    # => "SELECT c FROM foo LIMIT 30 OFFSET 5"

=item C<< $stmt->add_having(cnt => 2) >>

Add a HAVING clause.

    my $stmt = SQL::Maker::Select->new()
                                   ->add_from('foo')
                                   ->add_select(\'COUNT(*)' => 'cnt')
                                   ->add_having(cnt => 2)
                                   ->as_sql();
    # => "SELECT COUNT(*) AS cnt FROM foo HAVING (COUNT(*) = ?)"

=back

=head1 SEE ALSO

L<Data::ObjectDriver::SQL>

