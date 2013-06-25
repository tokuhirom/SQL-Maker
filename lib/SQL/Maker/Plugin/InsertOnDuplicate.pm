package SQL::Maker::Plugin::InsertOnDuplicate;
use strict;
use warnings;
use utf8;

our @EXPORT = qw/insert_on_duplicate/;

sub insert_on_duplicate {
    my ( $self, $table_name, $insert_values, $update_values ) = @_;
    my ( $sql, @binds ) = $self->insert( $table_name, $insert_values );
    my ( $update_cols, $update_vals ) = $self->make_set_clause($update_values);
    $sql .= $self->new_line . "ON DUPLICATE KEY UPDATE " . join( ', ', @$update_cols );
    return ( $sql, @binds, @$update_vals );
}

1;
__END__

=for test_synopsis
my ($name);

=head1 NAME

SQL::Maker::Plugin::InsertOnDuplicate - INSERT ... ON DUPLICATE KEY UPDATE

=head1 SYNOPSIS

    package My::QueryBuilder;
    use parent qw/SQL::Maker/;
    __PACKAGE__->load_plugin('InsertOnDuplicate');

    package main;
    my $qb = My::QueryBuilder->new(driver => 'mysql');
    $qb->insert_on_duplicate('member', { email => 'foo@exapmle.com', name => $name }, { name => $name });

=head1 DESCRIPTION

This is a plugin to generate "INSERT ... ON DUPLICATE KEY UPDATE" query for MySQL.

=head1 METHODS

This plugin adds only one method for your query builder class.

=over 4

=item $query_builder->insert_on_duplicate($table_name:Str, $insert_values:HashRef, $update_values:HashRef)

Generate "INSERT ... ON DUPLICATE KEY UPDATE ...".

C<< $table_name >> is table name to operate.

C<< $insert_values >> is values to insert.

$table_name and $insert_values are passing to C<< SQL::Maker#insert >>

C<< $update_values >> is SET part for ON DUPLICATE KEY UPDATE. It's processed by C<< SQL::Maker#make_set_clause >>.

=back

=head1 SEE ALSO

L<http://dev.mysql.com/doc/refman/5.6/en/insert-on-duplicate.html>
