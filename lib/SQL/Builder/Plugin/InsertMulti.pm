package SQL::Builder::Plugin::InsertMulti;
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

    my $sql = "INSERT INTO $table\n";
       $sql .= '(' . join(', ', @cols) . ')' . "\nVALUES ";

    my $values = '(' . join(', ', ('?') x @cols) . ')' . "\n";
    $sql .= join(',', ($values) x (scalar(@bind) / scalar(@cols)));

    return ($sql, @bind);
}

1;
__END__

=head1 SYNOPSIS

    SQL::Builder->load_plugin('SQL::Builder::Plugin::InsertMulti');

    my $builder = SQL::Builder->new();
    my ($sql, @binds) = $builder->insert_multi($table, \@rows);

