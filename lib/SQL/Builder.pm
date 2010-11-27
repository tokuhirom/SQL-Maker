package SQL::Builder;
use strict;
use warnings;
use 5.008001;
our $VERSION = '0.01';
use Class::Accessor::Lite;
Class::Accessor::Lite->mk_accessors(qw/quote_char name_sep/);

use SQL::Builder::Select;

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    $args{driver} ||= $args{dbh}->{Driver}->{Name};
    $args{quote_char}  ||= ''; # TODO: detect it by driver name
    $args{name_sep}    ||= '';
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

    my $stmt = SQL::Builder::Select->new( { from => [$table], } );
    $stmt->add_where_ex(%$where);
    my $sql = 'DELETE ' . $stmt->as_sql;
    return ($sql, @{$stmt->bind});
}

sub update {
    my ($class, $table, $args, $where) = @_;

    my ($columns, $bind_columns, undef) = $class->_set_columns($args, 0);

    my $stmt = SQL::Builder::Select->new();
    $stmt->add_where_ex(%$where);
    push @{$bind_columns}, @{$stmt->bind};

    my $sql = "UPDATE $table SET " . join(', ', @$columns) . ' ' . $stmt->as_sql_where;
    return ($sql, @$bind_columns);
}

# TODO: select

1;
__END__

=encoding utf8

=head1 NAME

SQL::Builder -

=head1 SYNOPSIS

  use SQL::Builder;

=head1 DESCRIPTION

SQL::Builder is

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
