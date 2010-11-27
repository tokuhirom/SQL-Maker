package SQL::Builder;
use strict;
use warnings;
use 5.008001;
our $VERSION = '0.01';
use Class::Accessor::Lite;
Class::Accessor::Lite->mk_accessors(qw/quote_char name_sep driver/);

use Carp ();
use SQL::Builder::Statement;

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    unless ($args{driver}) {
        $args{driver} = $args{dbh}->{Driver}->{Name};
    }
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
    bless {%args}, $class;
}

# $builder->insert($table, \%values);
sub insert {
    my ($self, $table, $values) = @_;
    return $self->_insert_or_replace($table, $values, 'INSERT');
}

sub replace {
    my ($self, $table, $values) = @_;
    return $self->_insert_or_replace($table, $values, 'REPLACE');
}

# for mysql
sub insert_multi {
    my ($self, $table, $args) = @_;

    my (@cols, @bind);
    for my $arg (@{$args}) {
        if (scalar(@cols)==0) {
            for my $col (keys %{$arg}) {
                push @cols, $col;
            }
        }

        for my $col (keys %{$arg}) {
            push @bind, $arg->{$col};
        }
    }

    my $sql = "INSERT INTO $table\n";
       $sql .= '(' . join(', ', @cols) . ')' . "\nVALUES ";

    my $values = '(' . join(', ', ('?') x @cols) . ')' . "\n";
    $sql .= join(',', ($values) x (scalar(@bind) / scalar(@cols)));

    return ($sql, @bind);
}

sub _insert_or_replace {
    my ($self, $table, $args, $prefix) = @_;

    my ($columns, $bind_columns, $quoted_columns) = $self->_set_columns($args, 1);

    my $sql  = "$prefix INTO $table\n";
       $sql .= '(' . join(', ', @$quoted_columns) .')' . "\n" .
               'VALUES (' . join(', ', @$columns) . ')' . "\n";

    return ($sql, @$bind_columns);
}

sub _set_columns {
    my ($self, $args, $insert) = @_;

    my (@columns, @bind_columns, @quoted_columns);
    for my $col (keys %{ $args }) {
        my $quoted_col = _quote($col, $self->quote_char, $self->name_sep);
        if (ref($args->{$col}) eq 'SCALAR') {
            push @columns, ($insert ? ${ $args->{$col} } :"$quoted_col = " . ${ $args->{$col} });
        } else {
            push @columns, ($insert ? '?' : "$quoted_col = ?");
            push @bind_columns, $args->{$col};
        }
        push @quoted_columns, $quoted_col;
    }

    return (\@columns, \@bind_columns, \@quoted_columns);
}

sub _quote {
    my ($label, $quote, $name_sep) = @_;

    return $label if $label eq '*';
    return $quote . $label . $quote if !defined $name_sep;
    return join $name_sep, map { $quote . $_ . $quote } split /\Q$name_sep\E/, $label;
}

sub delete {
    my ($self, $table, $where) = @_;

    my $stmt = SQL::Builder::Statement->new( { from => [$table], } );
    $stmt->add_where_ex(%$where);
    my $sql = 'DELETE ' . $stmt->as_sql;
    return ($sql, @{$stmt->bind});
}

sub update {
    my ($class, $table, $args, $where) = @_;

    my ($columns, $bind_columns, undef) = $class->_set_columns($args, 0);

    my $stmt = SQL::Builder::Statement->new();
    $stmt->add_where_ex(%$where);
    push @{$bind_columns}, @{$stmt->bind};

    my $sql = "UPDATE $table SET " . join(', ', @$columns) . ' ' . $stmt->as_sql_where;
    return ($sql, @$bind_columns);
}

# my($stmt, @bind) = $sql−>select($table, \@fields, \%where, \@order);
sub select {
    my ($self, $table, $fields, $where, $opt) = @_;

    my $stmt = SQL::Builder::Statement->new(
        select => $fields,
        from   => [$table],
    );

    if ( $where ) {
        $stmt->add_where_ex(%$where);
    }

    $stmt->limit(  $opt->{limit}  ) if $opt->{limit};
    $stmt->offset( $opt->{offset} ) if $opt->{offset};

    if (my $terms = $opt->{order_by}) {
        $terms = [$terms] unless ref($terms) eq 'ARRAY';
        my @orders;
        for my $term (@{$terms}) {
            my ($col, $case);
            if (ref($term) eq 'HASH') {
                ($col, $case) = each %$term;
            } else {
                $col  = $term;
                $case = 'ASC';
            }
            push @orders, { column => $col, desc => $case };
        }
        $stmt->order(\@orders);
    }

    if (my $terms = $opt->{having}) {
        for my $col (keys %$terms) {
            $stmt->add_having($col => $terms->{$col});
        }
    }

    $stmt->for_update(1) if $opt->{for_update};
    return ($stmt->as_sql,@{$stmt->bind});
}

1;
__END__

=encoding utf8

=head1 NAME

SQL::Builder - SQL builder class

=head1 SYNOPSIS

    use SQL::Builder;

    my $builder = SQL::Builder->new();

    # SELECT
    my ($sql, @binds) = $builder->select($table, \@fields, \%where, \%opt);

    # INSERT
    my ($sql, @binds) = $builder->insert($table, \%values);

    # REPLACE(mysql)
    my ($sql, @binds) = $builder->replace($table, \%values);

    # DELETE
    my ($sql, @binds) = $builder->delete($table, \%values);

    # UPDATE
    my ($sql, @binds) = $builder->update($table, \%set, \%where);

=head1 DESCRIPTION

SQL::Builder is SQL builder class. It is based on L<DBDIx::Skinny>'s SQL generator.

=head1 METHODS

=over 4

=item my $builder = SQL::Builder->new(%args);

Create new instance of SQL::Builder.

Attribuetes are following:

=over 4

=item driver: Str

=item dbh: Object

Driver or dbh is required. The driver type is needed to create SQL string.

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

=item my ($sql, @binds) = $builder->replace($table, \%values);

Generate REPLACE query.

=item my ($sql, @binds) = $builder->delete($table, \%values);

Generate DELETE query.

=item my ($sql, @binds) = $builder->update($table, \%set, \%where);

Generate UPDATE query.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 SEE ALSO

L<SQL::Abstract>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
