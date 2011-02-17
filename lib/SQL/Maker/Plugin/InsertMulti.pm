package SQL::Maker::Plugin::InsertMulti;
use strict;
use warnings;
use utf8;

our @EXPORT = qw/insert_multi/;

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

    my $sql = "INSERT INTO $table" . $self->new_line;
       $sql .= '(' . join(', ', @cols) . ')' . $self->new_line . "VALUES ";

    my $values = '(' . join(', ', ('?') x @cols) . ')' . $self->new_line;
    $sql .= join(',', ($values) x (scalar(@bind) / scalar(@cols)));

    return ($sql, @bind);
}

1;
__END__

=for test_synopsis
my ($table, @rows);

=head1 NAME

SQL::Maker::Plugin::InsertMulti - insert multiple rows at once on MySQL

=head1 SYNOPSIS

    use SQL::Maker;

    SQL::Maker->load_plugin('InsertMulti');

    my $builder = SQL::Maker->new();
    my ($sql, @binds) = $builder->insert_multi($table, \@rows);

=head1 DESCRIPTION

This is a plugin to generate MySQL's INSERT-multi statement.
