#!/usr/bin/perl -w

use strict;
use lib 't/lib';
BEGIN { require 't/test.pl' }

use MyEventCoordinator;
use Test::Builder2::Events;

use_ok 'Test::Builder2::Formatter::Multi';
use_ok 'Test::Builder2::Formatter::PlusMinus';
use_ok 'Test::Builder2::Formatter::POSIX';

my $pm    = Test::Builder2::Formatter::PlusMinus->new(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);
my $posix = Test::Builder2::Formatter::POSIX->new(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);
my $multi = Test::Builder2::Formatter::Multi->new;
is_deeply $multi->formatters, [];

$multi->add_formatters($pm, $posix);
is_deeply $multi->formatters, [$pm, $posix];

my $ec = MyEventCoordinator->new(
    formatters => [$multi]
);

# Begin
{
    $ec->post_event( Test::Builder2::Event::TestStart->new );
    is $pm->streamer->read, "";
    is $posix->streamer->read, "Running $0\n";
}


# Pass
{
    my $result = Test::Builder2::Result->new_result(
        pass     => 1,
        name     => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is($pm->streamer->read, "+", "passing test" );
    is($posix->streamer->read, "PASS: basset hounds got long ears\n", "passing test" );
}


# Fail
{
    my $result = Test::Builder2::Result->new_result(
        pass     => 0,
        name     => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is($pm->streamer->read, "-", "fail" );
    is($posix->streamer->read, "FAIL: basset hounds got long ears\n", "POSIX fail" );
}


# Skip
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
        name            => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is($pm->streamer->read, "+", "skip" );
    is($posix->streamer->read, "UNTESTED: basset hounds got long ears\n" );
}


# End
{
    $ec->post_event(
        Test::Builder2::Event::TestEnd->new
    );
    is $pm->streamer->read, "\n";
    is $posix->streamer->read, "";
}

done_testing();
