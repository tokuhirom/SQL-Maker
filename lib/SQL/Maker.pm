package SQL::Maker;
use strict;
use warnings;
use 5.008001;
our $VERSION = '1.12';
use Class::Accessor::Lite 0.05 (
    ro => [qw/quote_char name_sep new_line driver select_class/],
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
        %args
    }, $class;
}

sub new_condition {
    my $self = shift;

    SQL::Maker::Condition->new(
        quote_char => $self->{quote_char},
        name_sep   => $self->{name_sep},
    );
}

sub new_select {
    my $self = shift;
    my %args = @_==1 ? %{$_[0]} : @_;

    return $self->select_class->new(
        name_sep   => $self->name_sep,
        quote_char => $self->quote_char,
        new_line   => $self->new_line,
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
    my ($self, $table, $where) = @_;

    my $w = $self->_make_where_clause($where);
    my $quoted_table = $self->_quote($table);
    my $sql = "DELETE FROM $quoted_table" . $w->[0];
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
        if (ref $val eq 'SCALAR') {
            # $builder->update(foo => { created_on => \"NOW()" });
            push @columns, "$quoted_col = " . $$val;
        }
        elsif ( ref $val eq 'REF' && ref $$val eq 'ARRAY' ) {
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
    return (\@columns, \@bind_columns);
}

sub where {
    my ($self, $where) = @_;
    my $cond = $self->_make_where_condition($where);
    return ($cond->as_sql(), $cond->bind());
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
    my $sql = $w->as_sql(1);
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

    $stmt->limit( $opt->{limit} )    if $opt->{limit};
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
    ($sql, @binds) = $builder->delete($table, \%where);

    # UPDATE
    ($sql, @binds) = $builder->update($table, \%set, \%where);
    ($sql, @binds) = $builder->update($table, \@set, \%where);

=head1 DESCRIPTION

SQL::Maker is yet another SQL builder class. It is based on L<DBIx::Skinny>'s SQL generator.

=head1 METHODS

=over 4

=item my $builder = SQL::Maker->new(%args);

Create new instance of SQL::Maker.

Attributes are following:

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

=back

=item my $select = $builder->new_select(%args|\%args);

Create new instance of L<SQL::Maker::Select> from the settings from B<$builder>.

This method returns instance of L<SQL::Maker::Select>.

=item my ($sql, @binds) = $builder->select($table|\@tables, \@fields, \%where|\@where|$where, \%opt);

    my ($sql, @binds) = $builder->select('user', ['*'], {name => 'john'}, {order_by => 'user_id DESC'});
    # =>
    #   SELECT * FROM `user` WHERE (`name` = ?) ORDER BY user_id DESC
    #   ['john']

This method returns SQL string and bind variables for SELECT statement.

=over 4

=item $table

=item \@tables

Table name for B<FROM> clause in scalar or arrayref. You can specify the instance of B<SQL::Maker::Select> for sub-query.

=item \@fields

This is a list for retrieving fields from database.

Each element of the C<@field> is a scalar or a scalar ref of the column name normally.
If you want to specify alias of the field, you can use ArrayRef containing the pair of column
and alias name (e.g. C<< ['foo.id' => 'foo_id'] >>).

=item \%where

=item \@where

=item $where

where clause from hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object.

=item \%opt

This is a options for SELECT statement

=over 4

=item $opt->{prefix}

This is a prefix for SELECT statement.

For example, you can provide the 'SELECT SQL_CALC_FOUND_ROWS '. It's useful for MySQL.

Default Value: 'SELECT '

=item $opt->{limit}

This option makes 'LIMIT $n' clause.

=item $opt->{offset}

This option makes 'OFFSET $n' clause.

=item $opt->{order_by}

This option makes B<ORDER BY> clause

You can write it as following forms:

    $builder->select(..., order_by => 'foo DESC, bar ASC');
    $builder->select(..., order_by => ['foo DESC', 'bar ASC']);
    $builder->select(..., order_by => {foo => 'DESC'});
    $builder->select(..., order_by => [{foo => 'DESC'}, {bar => 'ASC'}]);

=item $opt->{group_by}

This option makes B<GROUP BY> clause

You can write it as following forms:

    $builder->select(..., group_by => 'foo DESC, bar ASC');
    $builder->select(..., group_by => ['foo DESC', 'bar ASC']);
    $builder->select(..., group_by => {foo => 'DESC'});
    $builder->select(..., group_by => [{foo => 'DESC'}, {bar => 'ASC'}]);

=item $opt->{having}

This option makes HAVING clause

=item $opt->{for_update}

This option makes 'FOR UPDATE" clause.

=item $opt->{joins}

This option makes 'JOIN' via L<SQL::Maker::Condition>.

=back

=back

=item my ($sql, @binds) = $builder->insert($table, \%values|\@values, \%opt);

    my ($sql, @binds) = $builder->insert(user => {name => 'john'});
    # =>
    #    INSERT INTO `user` (`name`) VALUES (?)
    #    ['john']

Generate INSERT query.

=over 4

=item $table

Table name in scalar.

=item \%values

This is a values for INSERT statement.

=item \%opt

This is a options for INSERT statement

=over 4

=item $opt->{prefix}

This is a prefix for INSERT statement.

For example, you can provide 'INSERT IGNORE INTO' for MySQL.

Default Value: 'INSERT INTO'

=back

=back

=item my ($sql, @binds) = $builder->delete($table, \%where|\@where|$where);

    my ($sql, @binds) = $builder->delete($table, \%where);
    # =>
    #    DELETE FROM `user` WHERE (`name` = ?)
    #    ['john']

Generate DELETE query.

=over 4

=item $table

Table name in scalar.

=item \%where

=item \@where

=item $where

where clause from hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object.

=back

=item my ($sql, @binds) = $builder->update($table, \%set|@set, \%where|\@where|$where);

Generate UPDATE query.

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

where clause from hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object.

=back

=item $builder->new_condition()

Create new L<SQL::Maker::Condition> object from C< $builder > settings.

=item my ($sql, @binds) = $builder->where(\%where)

=item my ($sql, @binds) = $builder->where(\@where)

=item my ($sql, @binds) = $builder->where(\@where)

Where clause from hashref or arrayref via L<SQL::Maker::Condition>, or L<SQL::Maker::Condition> object.

=back

=head1 PLUGINS

SQL::Maker supports plugin system. Write the code like following.

    package My::SQL::Maker;
    use parent qw/SQL::Maker/;
    __PACKAGE__->load_plugin('InsertMulti');

=head1 FAQ

=over 4

=item Why don't you use  SQL::Abstract?

I need more extensible one.

So, this module contains L<SQL::Maker::Select>, the extensible B<SELECT> clause object.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

L<SQL::Abstract>

Whole code was taken from L<DBIx::Skinny> by nekokak++.

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
