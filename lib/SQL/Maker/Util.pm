package SQL::Maker::Util;
use strict;
use warnings;
use utf8;

sub quote_identifier {
    my ($label, $quote_char, $name_sep) = @_;

    return $label if $label eq '*';
    return $label unless $name_sep;
    return join $name_sep, map { $_ eq '*' ? $_ : $quote_char . $_ . $quote_char } split /\Q$name_sep\E/, $label;
}

1;

