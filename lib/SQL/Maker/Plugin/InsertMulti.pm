package SQL::Maker::Plugin::InsertMulti;
use strict;
use warnings;
use utf8;

our @EXPORT = qw/insert_multi update_multi/;

# for mysql
sub insert_multi {
    # my ($self, $table, $cols, $binds, $opts) = @_;
    # my ($self, $table, $colvals, $opts) = @_;
    my ( $self, $table, @args ) = @_;
    return unless @{$args[0]};

    my (@cols, @bind, $opts);
    my $first_arg = $args[0]->[0];
    my $is_colvals = ( ref $first_arg ) ? 1 : 0;

    if ( $is_colvals ) {
	@cols = keys %{$first_arg};
	@bind = map { @$_{@cols} } @{$args[0]};
	$opts = $args[1] || +{};
    }
    else {
	@cols = @{$args[0]};
	@bind = map { @$_ } @{$args[1]};
	$opts = $args[2] || +{};
    }

    my $prefix = $opts->{prefix} || 'INSERT INTO';
    my $quoted_table = $self->_quote($table);
    my @quoted_cols  = map { $self->_quote($_) } @cols;
    
    my $sql = "$prefix $quoted_table" . $self->new_line;
       $sql .= '(' . join(', ', @quoted_cols) . ')' . $self->new_line . "VALUES ";

    my $values = '(' . join(', ', ('?') x @cols) . ')' . $self->new_line;
    $sql .= join(',', ($values) x (scalar(@bind) / scalar(@cols)));
    $sql =~ s/$self->{new_line}+$//;

    return ($sql, @bind);
}

sub update_multi {
    ### my ( $self, $table, $cols, $values, $sets, $opts ) = @_;
    ### my ( $self, $table, $colvals, $sets, $opts ) = @_;
    my ( $self, $table, @args ) = @_;
    my $is_cols = !ref $args[0]->[1] ? 1 : 0;

    return unless @{$args[0]};

    my (@cols, @bind, $sets, $opts);
    my $first_arg = $args[0]->[0];
    my $is_colvals = ( ref $first_arg ) ? 1 : 0;

    if ( $is_colvals ) {
	@cols = keys %{$first_arg};
	@bind = map { @$_{@cols} } @{$args[0]};
	$sets = $args[1];
	$opts = $args[2] || +{};
    }
    else {
	@cols = @{$args[0]};
	@bind = map { @$_ } @{$args[1]};
	$sets = $args[2];
	$opts = $args[3] || +{};
    }

    my $prefix = $opts->{prefix} || 'INSERT INTO';
    my $quoted_table = $self->_quote($table);
    my @quoted_cols  = map { $self->_quote($_) } @cols;

    my $sql = "$prefix $quoted_table" . $self->new_line;
       $sql .= '(' . join(', ', @quoted_cols) . ')' . $self->new_line . "VALUES ";

    my $values = '(' . join(', ', ('?') x @cols) . ')' . $self->new_line;
    $sql .= join(',', ($values) x (scalar(@bind) / scalar(@cols)));

    my @sets = ref $sets eq 'HASH' ? %$sets : @$sets;
    my @update_sets;
    while (my ($col, $val) = splice @sets, 0, 2) {
	my $quoted_col = $self->_quote($col);
        if ( ref $val eq 'SCALAR' ) {
            # $builder->update(foo => { created_on => \"NOW()" });
            push @update_sets, "$quoted_col = " . $$val;
        }
	elsif ( ref $val eq 'REF' && ref $$val eq 'ARRAY' ) {
	    my ( $stmt, @sub_bind ) = @{$$val};
	    push @update_sets, "$quoted_col = " . $stmt;
	    push @bind, @sub_bind;
	}
	else {
            # normal values
            push @update_sets, "$quoted_col = ?";
            push @bind, $val;
        }
    }

    $sql .= "ON DUPLICATE KEY UPDATE " . join(', ', @update_sets);

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
