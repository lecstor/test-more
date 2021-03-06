#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Events;
use Test::Builder2::Formatter::TAP;
use Test::Builder2::EventCoordinator;

my $formatter;
my $ec;
sub setup {
    $formatter = Test::Builder2::Formatter::TAP->new(
        streamer_class => 'Test::Builder2::Streamer::Debug'
    );
    $formatter->show_ending_commentary(0);
    isa_ok $formatter, "Test::Builder2::Formatter::TAP";

    $ec = Test::Builder2::EventCoordinator->new(
        formatters => [$formatter],
    );

    return $ec;
}

sub last_output {
    $formatter->streamer->read('out');
}


note "Escape # in test name"; {
    setup;

    my $result = Test::Builder2::Result->new_result(
        pass => 1, name => "foo # bar"
    );

    $ec->post_event(
        Test::Builder2::Event::TestStart->new
    );
    last_output;

    $ec->post_event($result);

    is last_output, "ok 1 - foo \\# bar\n";
}


note "Escape # in directive name"; {
    setup;

    my $result = Test::Builder2::Result->new_result(
        pass => 1, name => "foo # bar", directives => ['todo'], reason => "this # that"
    );

    $ec->post_event(
        Test::Builder2::Event::TestStart->new
    );
    last_output;

    $ec->post_event($result);

    is last_output, "ok 1 - foo \\# bar # TODO this \\# that\n";
}


done_testing;
