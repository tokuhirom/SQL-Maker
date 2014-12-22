package SQL::Maker;
use strict;
use warnings;
use 5.008001;
our $VERSION = '1.21';
use Class::Accessor::Lite 0.05 (
    ro => [qw/quote_char name_sep new_line strict driver select_class/],
);

use Carp ();
use SQL::Maker::Select;
use SQL::Maker::Select::Oracle;
use SQL::Maker::Condition;
use SQL::Maker::Util;
use Module::Load ();
use Scalar::Util ();

sub load_plugin {
    my ($class, $role) = @_;
    $role = $role =~ s/^\+// ? $role : "SQL::Maker::Plugin::$role";
    Module::Load::load($role);

    no strict 'refs';
    for (@{"${role}::EXPORT"}) {
        *{"${class}::$_"} = *{"${role}::$_"};
    }
}

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    unless ($args{driver}) {
        Carp::croak("'driver' is required for creating new instance of $class");
    }
    my $driver = $args{driver};
    unless ( defined $args{quote_char} ) {
    $args{quote_char} = do{
        if ($driver eq  'mysql') {
        q{`}
        } else {
        q{"}
        }
    };
    }
    $args{select_class} = $driver eq 'Oracle' ? 'SQL::Maker::Select::Oracle' : 'SQL::Maker::Select';

    return bless {
        name_sep => '.',
        new_line => "\n",
        strict   => 0,
        %args
    }, $class;
}

sub new_condition {
    my $self = shift;

    SQL::Maker::Condition->new(
        quote_char => $self->{quote_char},
        name_sep   => $self->{name_sep},
        strict     => $self->{strict},
    );
}

sub new_select {
    my $self = shift;
    my %args = @_==1 ? %{$_[0]} : @_;

    return $self->select_class->new(
        name_sep   => $self->name_sep,
        quote_char => $self->quote_char,
        new_line   => $self->new_line,
        strict     => $self->strict,
        %args,
    );
}

# $builder->insert($table, \%values, \%opt);
# $builder->insert($table, \@values, \%opt);
sub insert {
    my ($self, $table, $values, $opt) = @_;
    my $prefix = $opt->{prefix} || 'INSERT INTO';

    my $quoted_table = $self->_quote($table);

    my (@columns, @bind_columns, @quoted_columns, @values);
    @values = ref $values eq 'HASH' ? %$values : @$values;
    while (my ($col, $val) = splice(@values, 0, 2)) {
        push @quoted_columns, $self->_quote($col);
        if (Scalar::Util::blessed($val)) {
            if ($val->can('as_sql')) {
                push @columns, $val->as_sql(undef, sub { $self->_quote($_[0]) });
                push @bind_columns, $val->bind();
            } else {
                push @columns, '?';
                push @bind_columns, $val;
            }
        } else {
            Carp::croak("cannot pass in an unblessed ref as an argument in strict mode")
                if ref($val) && $self->strict;
            if (ref($val) eq 'SCALAR') {
                # $builder->insert(foo => { created_on => \"NOW()" });
                push @columns, $$val;
            }
            elsif (ref($val) eq 'REF' && ref($$val) eq 'ARRAY') {
                # $builder->insert( foo => \[ 'UNIX_TIMESTAMP(?)', '2011-04-12 00:34:12' ] );
                my ( $stmt, @sub_bind ) = @{$$val};
                push @columns, $stmt;
                push @bind_columns, @sub_bind;
            }
            else {
                # normal values
                push @columns, '?';
                push @bind_columns, $val;
            }
        }
    }

    # Insert an empty record in SQLite.
    # ref. https://github.com/tokuhirom/SQL-Maker/issues/11
    if ($self->driver eq 'SQLite' && @columns==0) {
        my $sql  = "$prefix $quoted_table" . $self->new_line . 'DEFAULT VALUES';
        return ($sql);
    }

    my $sql  = "$prefix $quoted_table" . $self->new_line;
       $sql .= '(' . join(', ', @quoted_columns) .')' . $self->new_line .
               'VALUES (' . join(', ', @columns) . ')';

    return ($sql, @bind_columns);
}

sub _quote {
    my ($self, $label) = @_;

    SQL::Maker::Util::quote_identifier($label, $self->quote_char(), $self->name_sep());
}

sub delete {
    my ($self, $table, $where, $opt) = @_;

    my $w = $self->_make_where_clause($where);
    my $quoted_table = $self->_quote($table);
    my $sql = "DELETE FROM $quoted_table";
    if ($opt->{using}) {
        # $bulder->delete('foo', \%where, { using => 'bar' });
        # $bulder->delete('foo', \%where, { using => ['bar', 'qux'] });
        my $tables = ref($opt->{using}) eq 'ARRAY' ? $opt->{using} : [$opt->{using}];
        my $using = join(', ', map { $self->_quote($_) } @$tables);
        $sql .= " USING " . $using;
    }
    $sql .= $w->[0];
    return ($sql, @{$w->[1]});
}

sub update {
    my ($self, $table, $args, $where) = @_;

    my ($columns, $bind_columns) = $self->make_set_clause($args);

    my $w = $self->_make_where_clause($where);
    push @$bind_columns, @{$w->[1]};

    my $quoted_table = $self->_quote($table);
    my $sql = "UPDATE $quoted_table SET " . join(', ', @$columns) . $w->[0];
    return ($sql, @$bind_columns);
}

# make "SET" clause.
sub make_set_clause {
    my ($self, $args) = @_;

    my (@columns, @bind_columns);
    my @args = ref $args eq 'HASH' ? %$args : @$args;
    while (my ($col, $val) = splice @args, 0, 2) {
        my $quoted_col = $self->_quote($col);
        if (Scalar::Util::blessed($val)) {
            if ($val->can('as_sql')) {
                push @columns, "$quoted_col = " . $val->as_sql(undef, sub { $self->_quote($_[0]) });
                push @bind_columns, $val->bind();
            } else {
                push @columns, "$quoted_col = ?";
                push @bind_columns, $val;
            }
        } else {
            Carp::croak("cannot pass in an unblessed ref as an argument in strict mode")
                if ref($val) && $self->strict;
            if (ref $val eq 'SCALAR') {
                # $builder->update(foo => { created_on => \"NOW()" });
                push @columns, "$quoted_col = " . $$val;
            }
            elsif (ref $val eq 'REF' && ref $$val eq 'ARRAY' ) {
                # $builder->update( foo => \[ 'VALUES(foo) + ?', 10 ] );
                my ( $stmt, @sub_bind ) = @{$$val};
                push @columns, "$quoted_col = " . $stmt;
                push @bind_columns, @sub_bind;
            }
            else {
                # normal values
                push @columns, "$quoted_col = ?";
                push @bind_columns, $val;
            }
        }
    }
    return (\@columns, \@bind_columns);
}

sub where {
    my ($self, $where) = @_;
    my $cond = $self->_make_where_condition($where);
    return ($cond->as_sql(undef, sub { $self->_quote($_[0]) }), $cond->bind());
}

sub _make_where_condition {
    my ($self, $where) = @_;

    return $self->new_condition unless $where;
    if ( Scalar::Util::blessed( $where ) and $where->can('as_sql') ) {
        return $where;
    }

    my $w = $self->new_condition;
    my @w = ref $where eq 'ARRAY' ? @$where : %$where;
    while (my ($col, $val) = splice @w, 0, 2) {
        $w->add($col => $val);
    }
    return $w;
}

sub _make_where_clause {
    my ($self, $where) = @_;

    return ['', []] unless $where;

    my $w = $self->_make_where_condition($where);
    my $sql = $w->as_sql(undef, sub { $self->_quote($_[0]) });
    return [$sql ? " WHERE $sql" : '', [$w->bind]];
}

# my($stmt, @bind) = $sql−>select($table, \@fields, \%where, \%opt);
sub select {
    my $stmt = shift->select_query(@_);
    return ($stmt->as_sql,@{$stmt->bind});
}

sub select_query {
    my ($self, $table, $fields, $where, $opt) = @_;

    unless (ref $fields eq 'ARRAY') {
        Carp::croak("SQL::Maker::select_query: \$fields should be ArrayRef[Str]");
    }

    my $stmt = $self->new_select;
    for my $field (@$fields) {
        $stmt->add_select(ref $field eq 'ARRAY' ? @$field : $field);
    }

    if ( defined $table ) {
        unless ( ref $table ) {
            # $table = 'foo'
            $stmt->add_from( $table );
        }
        else {
            # $table = [ 'foo', [ bar => 'b' ] ]
            for ( @$table ) {
                $stmt->add_from( ref $_ eq 'ARRAY' ? @$_ : $_ );
            }
        }
    }

    $stmt->prefix($opt->{prefix}) if $opt->{prefix};

    if ( $where ) {
        $stmt->set_where($self->_make_where_condition($where));
    }

    if ( my $joins = $opt->{joins} ) {
        for my $join ( @$joins ) {
            $stmt->add_join(ref $join eq 'ARRAY' ? @$join : $join);
        }
    }

    if (my $o = $opt->{order_by}) {
        if (ref $o eq 'ARRAY') {
            for my $order (@$o) {
                if (ref $order eq 'HASH') {
                    # Skinny-ish [{foo => 'DESC'}, {bar => 'ASC'}]
                    $stmt->add_order_by(%$order);
                } else {
                    # just ['foo DESC', 'bar ASC']
                    $stmt->add_order_by(\$order);
                }
            }
        } elsif (ref $o eq 'HASH') {
            # Skinny-ish {foo => 'DESC'}
            $stmt->add_order_by(%$o);
        } else {
            # just 'foo DESC, bar ASC'
            $stmt->add_order_by(\$o);
        }
    }
    if (my $o = $opt->{group_by}) {
        if (ref $o eq 'ARRAY') {
            for my $group (@$o) {
                if (ref $group eq 'HASH') {
                    # Skinny-ish [{foo => 'DESC'}, {bar => 'ASC'}]
                    $stmt->add_group_by(%$group);
                } else {
                    # just ['foo DESC', 'bar ASC']
                    $stmt->add_group_by(\$group);
                }
            }
        } elsif (ref $o eq 'HASH') {
            # Skinny-ish {foo => 'DESC'}
            $stmt->add_group_by(%$o);
        } else {
            # just 'foo DESC, bar ASC'
            $stmt->add_group_by(\$o);
        }
    }
    if (my $o = $opt->{index_hint}) {
        $stmt->add_index_hint($table, $o);
    }

    $stmt->limit( $opt->{limit} )    if defined $opt->{limit};
    $stmt->offset( $opt->{offset} )  if $opt->{offset};

    if (my $terms = $opt->{having}) {
        while (my ($col, $val) = each %$terms) {
            $stmt->add_having($col => $val);
        }
    }

    $stmt->for_update(1) if $opt->{for_update};
    return $stmt;
}

1;
__END__

=encoding utf8

=for test_synopsis
my ($table, @fields, %where, %opt, %values, %set, $sql, @binds, @set);

=head1 NAME

SQL::Maker - Yet another SQL builder

=head1 SYNOPSIS

    use SQL::Maker;

    my $builder = SQL::Maker->new(
        driver => 'SQLite', # or your favorite driver
    );

    # SELECT
    ($sql, @binds) = $builder->select($table, \@fields, \%where, \%opt);

    # INSERT
    ($sql, @binds) = $builder->insert($table, \%values, \%opt);

    # DELETE
    ($sql, @binds) = $builder->delete($table, \%where, \%opt);

    # UPDATE
    ($sql, @binds) = $builder->update($table, \%set, \%where);
    ($sql, @binds) = $builder->update($table, \@set, \%where);

=head1 DESCRIPTION

SQL::Maker is yet another SQL builder class. It is based on L<DBIx::Skinny>'s SQL generator.

=head1 METHODS

=over 4

=item C<< my $builder = SQL::Maker->new(%args); >>

Create new instance of SQL::Maker.

Attributes are the following:

=over 4

=item driver: Str

Driver name is required. The driver type is needed to create SQL string.

=item quote_char: Str

This is the character that a table or column name will be quoted with.

Default: auto detect from $driver.

=item name_sep: Str

This is the character that separates a table and column name.

Default: '.'

=item new_line: Str

This is the character that separates a part of statements.

Default: '\n'

=item strict: Bool

Whether or not the use of unblessed references are prohibited for defining the SQL expressions.

In strict mode, all the expressions must be declared by using blessed references that export C<as_sql> and C<bind> methods like L<SQL::QueryMaker>.
See L</STRICT MODE> for detail.

Default: undef

=back

=item C<< my $select = $builder->new_select(%args|\%args); >>

Create new instance of L<SQL::Maker::Select> using the settings from B<$builder>.

This method returns an instance of L<SQL::Maker::Select>.

=item C<< my ($sql, @binds) = $builder->select($table|\@tables, \@fields, \%where|\@where|$where, \%opt); >>

    my ($sql, @binds) = $builder->select('user', ['*'], {name => 'john'}, {order_by => 'user_id DESC'});
    # =>
    #   SELECT * FROM `user` WHERE (`name` = ?) ORDER BY user_id DESC
    #   ['john']

This method returns the SQL string and bind variables for a SELECT statement.

=over 4

=item C<< $table >>

=item C<< \@tables >>

Table name for the B<FROM> clause as scalar or arrayref. You can specify the instance of B<SQL::Maker::Select> for a sub-query.

If you are using C<< $opt->{joins} >> this should be I<< undef >> since it's passed via the first join.

=item C<< \@fields >>

This is a list for retrieving fields from database.

Each element of the C<@fields> is normally a scalar or a scalar ref containing the column name.
If you want to specify an alias of the field, you can use an arrayref containing a pair
of column and alias names (e.g. C<< ['foo.id' => 'foo_id'] >>).

=item C<< \%where >>

=item C<< \@where >>

=item C<< $where >>

where clause from hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object, or L<SQL::QueryMaker> object.

=item C<< \%opt >>

These are the options for the SELECT statement

=over 4

=item C<< $opt->{prefix} >>

This is a prefix for the SELECT statement.

For example, you can provide the 'SELECT SQL_CALC_FOUND_ROWS '. It's useful for MySQL.

Default Value: 'SELECT '

=item C<< $opt->{limit} >>

This option adds a 'LIMIT $n' clause.

=item C<< $opt->{offset} >>

This option adds an 'OFFSET $n' clause.

=item C<< $opt->{order_by} >>

This option adds an B<ORDER BY> clause

You can write it in any of the following forms:

    $builder->select(..., {order_by => 'foo DESC, bar ASC'});
    $builder->select(..., {order_by => ['foo DESC', 'bar ASC']});
    $builder->select(..., {order_by => {foo => 'DESC'}});
    $builder->select(..., {order_by => [{foo => 'DESC'}, {bar => 'ASC'}]});

=item C<< $opt->{group_by} >>

This option adds a B<GROUP BY> clause

You can write it in any of the following forms:

    $builder->select(..., {group_by => 'foo DESC, bar ASC'});
    $builder->select(..., {group_by => ['foo DESC', 'bar ASC']});
    $builder->select(..., {group_by => {foo => 'DESC'}});
    $builder->select(..., {group_by => [{foo => 'DESC'}, {bar => 'ASC'}]});

=item C<< $opt->{having} >>

This option adds a HAVING clause

=item C<< $opt->{for_update} >>

This option adds a 'FOR UPDATE" clause.

=item C<< $opt->{joins} >>

This option adds a 'JOIN' via L<SQL::Maker::Select>.

You can write it as follows:

    $builder->select(undef, ..., {joins => [[user => {table => 'group', condition => 'user.gid = group.gid'}], ...]});

=item C<< $opt->{index_hint} >>

This option adds an INDEX HINT like as 'USE INDEX' clause for MySQL via L<SQL::Maker::Select>.

You can write it as follows:

    $builder->select(..., { index_hint => 'foo' });
    $builder->select(..., { index_hint => ['foo', 'bar'] });
    $builder->select(..., { index_hint => { list => 'foo' });
    $builder->select(..., { index_hint => { type => 'FORCE', list => ['foo', 'bar'] });

=back

=back

=item C<< my ($sql, @binds) = $builder->insert($table, \%values|\@values, \%opt); >>

    my ($sql, @binds) = $builder->insert(user => {name => 'john'});
    # =>
    #    INSERT INTO `user` (`name`) VALUES (?)
    #    ['john']

Generate an INSERT query.

=over 4

=item C<< $table >>

Table name in scalar.

=item C<< \%values >>

These are the values for the INSERT statement.

=item C<< \%opt >>

These are the options for the INSERT statement

=over 4

=item C<< $opt->{prefix} >>

This is a prefix for the INSERT statement.

For example, you can provide 'INSERT IGNORE INTO' for MySQL.

Default Value: 'INSERT INTO'

=back

=back

=item C<< my ($sql, @binds) = $builder->delete($table, \%where|\@where|$where, \%opt); >>

    my ($sql, @binds) = $builder->delete($table, \%where);
    # =>
    #    DELETE FROM `user` WHERE (`name` = ?)
    #    ['john']

Generate a DELETE query.

=over 4

=item C<< $table >>

Table name in scalar.

=item C<< \%where >>

=item C<< \@where >>

=item C<< $where >>

where clause from hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object, or L<SQL::QueryMaker> object.

=item C<< \%opt >>

These are the options for the DELETE statement

=over 4

=item C<< $opt->{using} >>

This option adds a USING clause. It takes a scalar or an arrayref of table names as argument:

    my ($sql, $binds) = $bulder->delete($table, \%where, { using => 'group' });
    # =>
    #    DELETE FROM `user` USING `group` WHERE (`group`.`name` = ?)
    #    ['doe']
    $bulder->delete(..., { using => ['bar', 'qux'] });

=back

=back

=item C<< my ($sql, @binds) = $builder->update($table, \%set|@set, \%where|\@where|$where); >>

Generate a UPDATE query.

    my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com'], {user_id => 3});
    # =>
    #    'UPDATE `user` SET `name` = ?, `email` = ? WHERE (`user_id` = ?)'
    #    ['john','john@example.com',3]

=over 4

=item $table

Table name in scalar.

=item \%set

Setting values.

=item \%where

=item \@where

=item $where

where clause from a hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object, or L<SQL::QueryMaker> object.

=back

=item C<< $builder->new_condition() >>

Create new L<SQL::Maker::Condition> object from C< $builder > settings.

=item C<< my ($sql, @binds) = $builder->where(\%where) >>

=item C<< my ($sql, @binds) = $builder->where(\@where) >>

=item C<< my ($sql, @binds) = $builder->where(\@where) >>

Where clause from a hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object, or L<SQL::QueryMaker> object.

=back

=head1 PLUGINS

SQL::Maker features a plugin system. Write the code as follows:

    package My::SQL::Maker;
    use parent qw/SQL::Maker/;
    __PACKAGE__->load_plugin('InsertMulti');

=head1 STRICT MODE

See L<http://blog.kazuhooku.com/2014/07/the-json-sql-injection-vulnerability.html> for why
do we need the strict mode in the first place.

In strict mode, the following parameters must be blessed references implementing C<as_sql> and C<bind> methods
if they are NOT simple scalars (i.e. if they are references of any kind).

=over

=item *

Values in C<$where> parameter for C<select>, C<update>, C<delete> methods.

=item *

Values in C<%values> and C<%set> parameter for C<insert> and C<update> methods, respectively.

=back

You can use L<SQL::QueryMaker> objects for those parameters.

Example:

    use SQL::QueryMaker qw(sql_in sql_raw);
    
    ## NG: Use array-ref for values.
    $maker->select("user", ['*'], { name => ["John", "Tom"] });
    
    ## OK: Use SQL::QueryMaker
    $maker->select("user", ['*'], { name => sql_in(["John", "Tom"]) });
    
    ## Also OK: $where parameter itself is a blessed object.
    $maker->select("user", ['*'], $maker->new_condition->add(name => sql_in(["John", "Tom"])));
    $maker->select("user", ['*'], sql_in(name => ["John", "Tom"]));
    
    
    ## NG: Use scalar-ref for a raw value.
    $maker->insert(user => [ name => "John", created_on => \"datetime(now)" ]);
    
    ## OK: Use SQL::QueryMaker
    $maker->insert(user => [name => "John", created_on => sql_raw("datetime(now)")]);


=head1 FAQ

=over 4

=item Why don't you use SQL::Abstract?

I need a more extensible one.

So, this module contains L<SQL::Maker::Select>, the extensible B<SELECT> clause object.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

L<SQL::Abstract>
L<SQL::QueryMaker>

The whole code was taken from L<DBIx::Skinny> by nekokak++.

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
