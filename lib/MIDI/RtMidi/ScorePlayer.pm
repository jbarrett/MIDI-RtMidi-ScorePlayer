package MIDI::RtMidi::ScorePlayer;

# ABSTRACT: Play a MIDI score in real-time

our $VERSION = '0.0111';

use strict;
use warnings;

use File::Basename qw(fileparse);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(get_microseconds score2events);
use Path::Tiny qw(path);
use Time::HiRes qw(time usleep);

=head1 SYNOPSIS

  use MIDI::RtMidi::ScorePlayer ();
  use MIDI::Util qw(setup_score);

  my $score = setup_score();

  my %common = (score => $score, seen => {}, etc => '...',);

  sub treble {
      my (%args) = @_;
      ...; # Setup things
      my $treble = sub {
          if ($args{_part} % 2) {
              $args{score}->n('...');
          }
          else {
              $args{score}->r('...');
          }
      };
      return $treble;
  }
  sub bass {
      ...; # As above but different!
  }

  MIDI::RtMidi::ScorePlayer->new(
      score    => $score, # required MIDI score object
      parts    => [ \&treble, \&bass ], # required part functions
      common   => \%common, # arguments given to the part functions
      repeats  => 4, # number of repeated synched parts (default: 1)
      sleep    => 2, # number of seconds to sleep between loops (default: 1)
      loop     => 4, # loop limit if finite (default: 1)
      infinite => 0, # loop infinitely (default: 1)
      deposit  => 'path/prefix-', # optionally make a file after each loop
			vebose   => 0, # show our progress (default: 1)
  )->play;

=head1 DESCRIPTION

C<MIDI::RtMidi::ScorePlayer> plays a MIDI score in real-time.

In order to use this module, create subroutines for simultaneous MIDI
B<parts> that take a B<common> hash of named arguments. These parts
each return an anonymous subroutine that tells MIDI-perl to build up a
B<score>, by adding notes (C<n()>) and rests (C<r()>), etc. These
musical operations are described in the L<MIDI> modules, like
L<MIDI::Simple>.

Besides being handed the B<common> arguments, each B<part> function
gets a handy, increasing B<_part> number, starting at one, which can
be used in the part functions. These parts are synch'd together, given
the B<new> parameters that are described in the example above.

=head2 Hints

B<Linux>: If your distro does not install a service, you can use
timidity in daemon mode: C<timidity -iAD>. Also, FluidSynth is an
alternative.

B<MacOS>: You can get General MIDI via DLSMusicDevice within Logic or
Garageband. You will need a soundfont containing drum patches in
'~/Library/Audio/Sounds/Banks/' and DLSMusicDevice open in Garageband
or Logic with this soundfont selected. See the
L<MIDI::RtMidi::FFI::Device> docs for more info. Alternatively you can
use FluidSynth:
C<fluidsynth -a coreaudio -m coremidi -g 1.0 ~/Music/some-soundfont.sf2>.
Also, you can use C<timidity> too.

For B<Windows>, this should I<just work> out of the box.

=head1 METHODS

=head2 new

Instantiate a new C<MIDI::RtMidi::ScorePlayer> object.

=cut

sub new {
    my ($class, %opts) = @_;

    die 'A MIDI score object is required' unless $opts{score};
    die 'A list of parts is required' unless $opts{parts} && @{ $opts{parts} };

    $opts{common}   ||= {};
    $opts{repeats}  ||= 1;
    $opts{sleep}    //= 1;
    $opts{loop}     ||= 1;
    $opts{infinite} //= 1;
    $opts{verbose}  //= 1;
    $opts{deposit}  ||= '';
    if ($opts{deposit}) {
        ($opts{prefix}, $opts{path}) = fileparse($opts{deposit});
        die "Invalid path: $opts{path}\n" unless -d $opts{path};
    }

    $opts{device} = RtMidiOut->new;

    $opts{port} //= qr/wavetable|loopmidi|timidity|fluid/i;

    # For MacOS, DLSMusicDevice should receive input from this virtual port:
    $opts{device}->open_virtual_port('dummy') if $^O eq 'darwin';

    $opts{device}->open_port_by_name($opts{port});

    bless \%opts, $class;
}

=head2 play

Play a given MIDI score in real-time.

=cut

sub play {
    my ($self) = @_;
    if ($self->{infinite}) {
        while (1) {
            $self->_play;
        }
    }
    else {
        $self->_play for 1 .. $self->{loop};
    }
}

sub _play {
    my ($self) = @_;
    $self->_sync_parts;
    my $micros = get_microseconds($self->{score});
    my $events = score2events($self->{score});
    for my $event (@$events) {
        next if $event->[0] =~ /set_tempo|time_signature/;
        if ( $event->[0] eq 'text_event' ) {
            printf "%s\n", $event->[-1] if $self->{verbose};
            next;
        }
        my $useconds = $micros * $event->[1];
        usleep($useconds) if $useconds > 0 && $useconds < 1_000_000;
        $self->{device}->send_event( $event->[0] => @{ $event }[ 2 .. $#$event ] );
    }
    if ($self->{deposit}) {
        my $filename = path($self->{path}, $self->{prefix} . time() . '.midi');
        $self->{score}->write_score("$filename");
    }
    sleep($self->{sleep});
    $self->_reset_score;
}

# This manipulates internals of MIDI::Score things and doing this isn't a good idea
sub _reset_score {
    my ($self) = @_;
    # sorry
    $self->{score}{Score} = [
        grep { $_->[0] !~ /^note/ && $_->[0] !~ /^patch/ }
        @{ $self->{score}{Score} }
    ];
    ${ $self->{score}{Time} } = 0;
    $self->{common}{seen} = {}
        if exists $self->{common}{seen};
}

# Build the code-ref MIDI of all parts to be played
sub _sync_parts {
    my ($self) = @_;
    my @parts;
    my $n = 1;
    push @parts, $_->(%{ $self->{common} }, _part => $n++)
        for @{ $self->{parts} };
    $self->{score}->synch(@parts) # Play the parts simultaneously
        for 1 .. $self->{repeats};
}

1;
__END__

=head1 SEE ALSO

Examples are the F<eg/*> files in this distribution.

L<MIDI::RtMidi::FFI::Device>

L<MIDI::Util>

L<Time::HiRes>

=cut
