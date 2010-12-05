package SQL::Builder;
use strict;
use warnings;
use 5.008001;
our $VERSION = '0.01';
use Class::Accessor::Lite;

Class::Accessor::Lite->mk_ro_accessors(qw/quote_char name_sep driver statement_class/);

use Carp ();
use SQL::Builder::Select;
use SQL::Builder::Select::Oracle;
use SQL::Builder::Condition;
use SQL::Builder::Util;
use Module::Load ();

sub load_plugin {
    my ($class, $role) = @_;
    $role = $role =~ s/^\+// ? $role : "SQL::Builder::Plugin::$role";
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
    $args{statement_class} = $driver eq 'Oracle' ? 'SQL::Builder::Select::Oracle' : 'SQL::Builder::Select';
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

    SQL::Builder::Util::quote_identifier($label, $self->quote_char(), $self->name_sep());
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
    my $w = SQL::Builder::Condition->new(
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
    my ($self, $table, $fields, $where, $opt) = @_;

    my $stmt = $self->statement_class->new(
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
    return ($stmt->as_sql,@{$stmt->bind});
}

1;
__END__

=encoding utf8

=head1 NAME

SQL::Builder - Yet another SQL builder

=head1 SYNOPSIS

    use SQL::Builder;

    my $builder = SQL::Builder->new();

    # SELECT
    my ($sql, @binds) = $builder->select($table, \@fields, \%where, \%opt);

    # INSERT
    my ($sql, @binds) = $builder->insert($table, \%values);

    # DELETE
    my ($sql, @binds) = $builder->delete($table, \%values);

    # UPDATE
    my ($sql, @binds) = $builder->update($table, \%set, \%where);

=head1 DESCRIPTION

SQL::Builder is yet another SQL builder class. It is based on L<DBIx::Skinny>'s SQL generator.

=head1 METHODS

=over 4

=item my $builder = SQL::Builder->new(%args);

Create new instance of SQL::Builder.

Attribuetes are following:

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

Generates SELECT query.

=item my ($sql, @binds) = $builder->insert($table, \%values);

Generate INSERT query.

=item my ($sql, @binds) = $builder->delete($table, \%values);

Generate DELETE query.

=item my ($sql, @binds) = $builder->update($table, \%set, \%where);

Generate UPDATE query.

=back

=head1 PLUGINS

SQL::Builder supports plugin system. Write the code like following.

    package My::SQL::Builder;
    use parent qw/SQL::Builder/;
    __PACKAGE__->load_plugin('InsertMulti');

=head1 CONDITION CHEAT SHEET

Here is a cheat sheet for conditions.

    IN:        ['foo','bar']
    OUT QUERY: '`foo` = ?'
    OUT BIND:  ('bar')

    IN:        ['foo',['bar','baz']]
    OUT QUERY: '`foo` IN (?,?)'
    OUT BIND:  ('bar','baz')

    IN:        ['foo',{'IN' => ['bar','baz']}]
    OUT QUERY: '`foo` IN (?,?)'
    OUT BIND:  ('bar','baz')

    IN:        ['foo',{'not IN' => ['bar','baz']}]
    OUT QUERY: '`foo` NOT IN (?,?)'
    OUT BIND:  ('bar','baz')

    IN:        ['foo',{'!=' => 'bar'}]
    OUT QUERY: '`foo` != ?'
    OUT BIND:  ('bar')

    IN:        ['foo',\'IS NOT NULL']
    OUT QUERY: '`foo` IS NOT NULL'
    OUT BIND:  ()

    IN:        ['foo',{'between' => ['1','2']}]
    OUT QUERY: '`foo` BETWEEN ? AND ?'
    OUT BIND:  ('1','2')

    IN:        ['foo',{'like' => 'xaic%'}]
    OUT QUERY: '`foo` LIKE ?'
    OUT BIND:  ('xaic%')

    IN:        ['foo',[{'>' => 'bar'},{'<' => 'baz'}]]
    OUT QUERY: '(`foo` > ?) OR (`foo` < ?)'
    OUT BIND:  ('bar','baz')

    IN:        ['foo',['-and',{'>' => 'bar'},{'<' => 'baz'}]]
    OUT QUERY: '(`foo` > ?) AND (`foo` < ?)'
    OUT BIND:  ('bar','baz')

    IN:        ['foo',['-and','foo','bar','baz']]
    OUT QUERY: '(`foo` = ?) AND (`foo` = ?) AND (`foo` = ?)'
    OUT BIND:  ('foo','bar','baz')

    IN:        ['foo_id',\['IN (SELECT foo_id FROM bar WHERE t=?)',44]]
    OUT QUERY: '`foo_id` IN (SELECT foo_id FROM bar WHERE t=?)'
    OUT BIND:  ('44')

    IN:        ['foo_id', {IN => \['SELECT foo_id FROM bar WHERE t=?',44]}]
    OUT QUERY: '`foo_id` IN (SELECT foo_id FROM bar WHERE t=?)'
    OUT BIND:  ('44')

    IN:        ['foo_id',\['MATCH (col1, col2) AGAINST (?)','apples']]
    OUT QUERY: '`foo_id` MATCH (col1, col2) AGAINST (?)'
    OUT BIND:  ('apples')

    IN:        ['foo_id',undef]
    OUT QUERY: '`foo_id` IS NULL'
    OUT BIND:  ()

    IN:        ['foo_id',{'IN' => []}]
    OUT QUERY: '0=1'
    OUT BIND:  ()

    IN:        ['foo_id',{'NOT IN' => []}]
    OUT QUERY: '1=1'
    OUT BIND:  ()

    IN:        ['foo_id', sql_type(\3, SQL_INTEGER)]
    OUT QUERY: '`foo_id` = ?'
    OUT BIND:  sql_type(\3, SQL_INTEGER)

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
