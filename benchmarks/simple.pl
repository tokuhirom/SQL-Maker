#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Benchmark ':all';
use SQL::Abstract;
use SQL::Maker;

my $a = SQL::Abstract->new();
my $b = SQL::Maker->new(driver => 'mysql');

print "insert\n";
cmpthese(
    -1 => {
        'SQL::Abstract' => sub { $a->insert(foo => {a => 1, foo => 4}); },
        'SQL::Maker' => sub { $b->insert(foo => {a => 1, foo => 4}); },
    },
);

print "\n";
print "update\n";
cmpthese(
    -1 => {
        'SQL::Abstract' => sub { $a->update(foo => {a => 1, foo => 4}, {john => 4, man => 3}); },
        'SQL::Maker' => sub { $b->update(foo => {a => 1, foo => 4}, {john => 4, man => 3}); },
    },
);

print "\n";
print "delete\n";
cmpthese(
    -1 => {
        'SQL::Abstract' => sub { $a->delete(foo => {john => 4, man => 3}); },
        'SQL::Maker' => sub { $b->delete(foo => {john => 4, man => 3}); },
    },
);

print "\n";
print "select\n";
cmpthese(
    -1 => {
        'SQL::Abstract' => sub { $a->select(foo => [qw/a b/], {john => 4, man => 3}); },
        'SQL::Maker' => sub { $b->select(foo => [qw/a b/], {john => 4, man => 3}); },
    },
);

