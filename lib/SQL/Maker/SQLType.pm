package SQL::Maker::SQLType;
use strict;
use warnings;
use utf8;
use Exporter qw/import/;

our @EXPORT_OK = qw/sql_type/;

sub sql_type {
    my ($value_ref, $type) = @_;
    SQL::Maker::SQLType->new(value_ref => $value_ref, type => $type);
}

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    bless {%args}, $class;
}

sub value_ref { $_[0]->{value_ref} }
sub type      { $_[0]->{type} }

sub as_sql {
    my ($self, $supplied_colname, $quote_cb) = @_;
    my $stmt;
    if (defined $supplied_colname) {
        $stmt = $quote_cb->($supplied_colname) . ' = ?';
    } else {
        $stmt = '?';
    }
    return $stmt;
}

sub bind {
    my $self = shift;
    return $self;
}

1;
__END__

=for test_synopsis
my ($dbh);

=head1 NAME

SQL::Maker::SQLType - SQL Types wrapper

=head1 SYNOPSIS

    use SQL::Maker::SQLType qw/sql_type/;
    use DBI qw/:sql_types/;
    use SQL::Maker::Select;
    
    my $cond = SQL::Maker::Select->new()
                                   ->add_select('id')
                                   ->add_from('foo')
                                   ->add_where(bar => sql_type(\"bar", SQL_VARCHAR));
    my @bind = @{$cond->bind()};
    my $sth = $dbh->prepare($cond->as_sql);
    for my $i (1..scalar(@bind)) {
        $sth->bind_param($i, ${$bind[$i-1]->value_ref}, $bind[$i-1]->type);
    }
    $sth->execute();
    print $sth->fetchrow_array(), "\n";

=head1 DESCRIPTION

This is a wrapper class for SQL types.

=head1 SEE ALSO

L<SQL::Maker::SQLType>, L<http://labs.cybozu.co.jp/blog/kazuho/archives/2007/09/mysql_param_binding.php>

