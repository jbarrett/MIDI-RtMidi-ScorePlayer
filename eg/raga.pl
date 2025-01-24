#!/usr/bin/env perl

# I use this code to test control with a system virtual driver...

use strict;
use warnings;

use MIDI::RtMidi::ScorePlayer ();
use MIDI::Util qw(setup_score set_chan_patch);

my $score = setup_score(lead_in => 0);
my %common = (score => $score);
MIDI::RtMidi::ScorePlayer->new(
    score    => $score,
    parts    => [ \&part ],
    common   => \%common,
    sleep    => 0,
    infinite => 1,
)->play;

sub part {
    my (%args) = @_;
    my $part = sub {
        set_chan_patch($args{score}, 0, 0);
        $args{score}->n('en', 'C4');
        $args{score}->n('en', 'D4');
        $args{score}->n('en', 'D4');

        $args{score}->n('en', 'C4');
        $args{score}->n('en', 'D4');
        $args{score}->n('en', 'D4');

        $args{score}->n('en', 'C4');
        $args{score}->n('en', 'D4');
        $args{score}->n('en', 'D4');

        $args{score}->n('en', 'C4');
        $args{score}->n('en', 'D4');
        $args{score}->n('en', 'D4');
        $args{score}->n('en', 'D4');
        $args{score}->n('en', 'C4');
    };

    return $part;
}
