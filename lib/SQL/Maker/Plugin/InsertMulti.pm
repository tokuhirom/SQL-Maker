package SQL::Maker::Plugin::InsertMulti;
use strict;
use warnings;
use utf8;

our @EXPORT = qw/insert_multi/;

# for mysql
sub insert_multi {
    my ($self, $table, $args, $binds) = @_;
    return unless @$args;

    # setting cols
    my @cols;
    my $first_arg = $args->[0];
    my $is_cols   = ( !ref $first_arg ) ? 1 : 0;

    if ( $is_cols ) {
	@cols = @$args;
    }
    else {
	for my $col (keys %{$first_arg}) {
	    push @cols, $col;
	}
    }

    my @bind;
    if ( $is_cols ) {
	@bind = map { @$_ } @$binds;
    }
    else {
	for my $arg (@{$args}) {
	    for my $col (@cols) {
		push @bind, $arg->{$col};
	    }
	}
    }

    my $sql = "INSERT INTO $table" . $self->new_line;
       $sql .= '(' . join(', ', @cols) . ')' . $self->new_line . "VALUES ";

    my $values = '(' . join(', ', ('?') x @cols) . ')' . $self->new_line;
    $sql .= join(',', ($values) x (scalar(@bind) / scalar(@cols)));
    $sql =~ s/$self->{new_line}+$//;

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

    my $table = 'foo';
    my @rows = ( +{ bar => 'baz', john => 'man' }, +{ bar => 'bee', john => 'row' } );
    my $builder = SQL::Maker->new();
    my ($sql, @binds);
    ( $sql, @binds ) = $builder->insert_multi($table, \@rows);
    ( $sql, @binds ) = $builder->insert_multi($table, [qw/bar john/], [ map { @$_{qw/bar john/} } @rows ]);

=head1 DESCRIPTION

This is a plugin to generate MySQL's INSERT-multi statement.
