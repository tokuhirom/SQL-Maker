package SQL::Maker;
use strict;
use warnings;
use 5.008001;
our $VERSION = '0.01';
use Class::Accessor::Lite 0.05 (
    ro => [qw/quote_char name_sep driver select_class/],
);

use Carp ();
use SQL::Maker::Select;
use SQL::Maker::Select::Oracle;
use SQL::Maker::Condition;
use SQL::Maker::Util;
use Module::Load ();

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
        Carp::croak("'driver' or 'dbh' is required for creating new instance of $class");
    }
    my $driver = $args{driver};
    $args{quote_char}  ||= do{
        if ($driver eq  'Oracle' || $driver eq 'Pg') {
            q{"}
        } else {
            q{`}
        }
    };
    $args{name_sep}    ||= '.';
    $args{select_class} = $driver eq 'Oracle' ? 'SQL::Maker::Select::Oracle' : 'SQL::Maker::Select';
    bless {%args}, $class;
}

# $builder->insert($table, \%values);
sub insert {
    my ($self, $table, $values, $opt) = @_;
    my $prefix = $opt->{prefix} || 'INSERT';

    my $quoted_table = $self->_quote($table);

    my (@columns, @bind_columns, @quoted_columns);
    while (my ($col, $val) = each %$values) {
        push @quoted_columns, $self->_quote($col);
        if (ref($val) eq 'SCALAR') {
            # $builder->insert(foo => { created_on => \"NOW()" });
            push @columns, $$val;
        } else {
            # normal values
            push @columns, '?';
            push @bind_columns, $val;
        }
    }

    my $sql  = "$prefix INTO $quoted_table\n";
       $sql .= '(' . join(', ', @quoted_columns) .')' . "\n" .
               'VALUES (' . join(', ', @columns) . ')' . "\n";

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

    my (@columns, @bind_columns);
    # make "SET" clause.
    while (my ($col, $val) = each %$args) {
        my $quoted_col = $self->_quote($col);
        if (ref($val) eq 'SCALAR') {
            # $builder->update(foo => { created_on => \"NOW()" });
            push @columns, "$quoted_col = " . $$val;
        } else {
            # normal values
            push @columns, "$quoted_col = ?";
            push @bind_columns, $args->{$col};
        }
    }

    my $w = $self->_make_where_clause($where);
    push @bind_columns, @{$w->[1]};

    my $quoted_table = $self->_quote($table);
    my $sql = "UPDATE $quoted_table SET " . join(', ', @columns) . $w->[0];
    return ($sql, @bind_columns);
}

sub _make_where_clause {
    my ($self, $where) = @_;
    my $w = SQL::Maker::Condition->new(
        quote_char => $self->quote_char,
        name_sep   => $self->name_sep,
    );
    while (my ($col, $val) = each %$where) {
        $w->add($col => $val);
    }
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

    my $stmt = $self->select_class->new(
        name_sep   => $self->name_sep,
        quote_char => $self->quote_char,
        select     => $fields,
    );
    $stmt->add_from($table);
    $stmt->prefix($opt->{prefix}) if $opt->{prefix};

    if ( $where ) {
        my @w = ref $where eq 'ARRAY' ? @$where : %$where;
        while (my ($col, $val) = splice @w, 0, 2) {
            $stmt->add_where($col => $val);
        }
    }

    if (my $o = $opt->{order_by}) {
        if (ref $o) {
            for my $order (@$o) {
                if (ref $order) {
                    # Skinny-ish [{foo => 'DESC'}, {bar => 'ASC'}]
                    $stmt->add_order_by(%$order);
                } else {
                    # just ['foo DESC', 'bar ASC']
                    $stmt->add_order_by(\$order);
                }
            }
        } else {
            # just 'foo DESC, bar ASC'
            $stmt->add_order_by(\$o);
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

my ($table, @fields, %where, %opt, %values, %set, $sql, @binds);

=head1 NAME

SQL::Maker - Yet another SQL builder

=head1 SYNOPSIS

    use SQL::Maker;

    my $builder = SQL::Maker->new();

    # SELECT
    ($sql, @binds) = $builder->select($table, \@fields, \%where, \%opt);

    # INSERT
    ($sql, @binds) = $builder->insert($table, \%values);

    # DELETE
    ($sql, @binds) = $builder->delete($table, \%values);

    # UPDATE
    ($sql, @binds) = $builder->update($table, \%set, \%where);

=head1 DESCRIPTION

SQL::Maker is yet another SQL builder class. It is based on L<DBIx::Skinny>'s SQL generator.

B<THE SOFTWARE IS IT'S IN ALPHA QUALITY. IT MAY CHANGE THE API WITHOUT NOTICE.>

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

=back

=item my ($sql, @binds) = $builder->select($table, \@fields, \%where, \%opt);

This method returns SQL string and bind variables for SELECT statement.

=over 4

=item $table

Table name in scalar.

=item \@fields

This is a list for retrieving fields from database.

=item \%where

SQL::Maker creates where clause from this hashref via L<SQL::Maker::Condition>.

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

=item $opt->{having}

This option makes HAVING clause

=item $opt->{for_update}

This option makes 'FOR UPDATE" clause.

=back

=back

=item my ($sql, @binds) = $builder->insert($table, \%values);

Generate INSERT query.

=over 4

=item $table

Table name in scalar.

=item \%values

This is a values for INSERT statement.

=back

=item my ($sql, @binds) = $builder->delete($table, \%where);

Generate DELETE query.

=over 4

=item $table

Table name in scalar.

=item \%where

SQL::Maker creates where clause from this hashref via L<SQL::Maker::Condition>.

=back

=item my ($sql, @binds) = $builder->update($table, \%set, \%where);

Generate UPDATE query.

=over 4

=item $table

Table name in scalar.

=item \%set

Setting values.

=item \%where

SQL::Maker creates where clause from this hashref via L<SQL::Maker::Condition>.

=back

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

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 SEE ALSO

L<SQL::Abstract>

Whole code was taken from L<DBIx::Skinny> by nekokak++.

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
