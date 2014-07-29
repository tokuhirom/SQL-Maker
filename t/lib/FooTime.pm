package FooTime;

use strict;
use warnings;
use overload ('""' => 'stringify');

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;

    if (!$args{year}) {
        die "Mandatory parameter 'year' missing in call to FooTime::new";
    }
    my $self = {
        year => $args{year},
        month => $args{month} || '01',
        day => $args{day} || '01',
        hour => $args{hour} || '00',
        minute => $args{minute} || '00',
        second => $args{second} || '00'
    };

    return bless($self, $class);
}

sub stringify {
    my $self = shift;

    my $ymd = join('-', $self->{year}, $self->{month}, $self->{day});
    my $hms = join(':', $self->{hour}, $self->{minute}, $self->{'second'});

    return join('T', $ymd, $hms);;
}

1;
