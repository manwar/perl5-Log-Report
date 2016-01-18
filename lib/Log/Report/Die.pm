use warnings;
use strict;

package Log::Report::Die;
use base 'Exporter';

our @EXPORT = qw/die_decode/;

use POSIX  qw/locale_h/;

=chapter NAME
Log::Report::Die - compatibility routines with Perl's die/croak/confess

=chapter SYNOPSIS

=chapter DESCRIPTION

This module is used internally, to translate output of 'die' and Carp
functions into M<Log::Report::Message> objects.

=chapter FUNCTIONS

=function die_decode STRING
The STRING is the content of C<$@> after an eval() caught a die().
croak(), or confess().  This routine tries to convert this into
parameters for M<Log::Report::report()>.  This is done in a very
smart way, even trying to find the stringifications of C<$!>.

Return are four elements: the error string which is used to trigger
a C<Log::Report> compatible C<die()>, and the options, reason, and
text message.  The options is a HASH which, amongst other things,
may contain a stack trace and location.

Translated components will have exception classes C<perl>, and C<die> or
C<confess>.  On the moment, the C<croak> cannot be distiguished from the
C<confess> (when used in package main) or C<die> (otherwise).

The returned reason depends on whether the translation of the current
C<$!> is found in the STRING, and the presence of a stack trace.  The
following table is used:

  errstr  stack  =>  reason
    no      no       ERROR   (die) application internal problem
    yes     no       FAULT   (die) external problem, think open()
    no      yes      PANIC   (confess) implementation error
    yes     yes      ALERT   (confess) external problem, caught

      = @{$opt{stack}} ? ($opt{errno} ? 'ALERT' : 'PANIC')
      :                  ($opt{errno} ? 'FAULT' : 'ERROR');
=cut

sub die_decode($)
{   my @text   = split /\n/, $_[0];
    @text or return ();
    chomp $text[-1];

    # Try to catch the error directly, to remove it from the error text
    my %opt    = (errno => $! + 0);
    my $err    = "$!";

    my $dietxt = $text[0];
    if($text[0] =~ s/ at (.+) line (\d+)\.?$// )
    {   $opt{location} = [undef, $1, $2, undef];
    }
    elsif(@text > 1 && $text[1] =~ m/^\s*at (.+) line (\d+)\.?$/ )
    {   # sometimes people carp/confess with \n, folding the line
        $opt{location} = [undef, $1, $2, undef];
        splice @text, 1, 1;
    }

    $text[0] =~ s/\s*[.:;]?\s*$err\s*$//  # the $err is translation sensitive
        or delete $opt{errno};

    my @msg = shift @text;
    length $msg[0] or $msg[0] = 'stopped';

    my @stack;
    foreach (@text)
    {   if(m/^\s*(.*?)\s+called at (.*?) line (\d+)\s*$/)
             { push @stack, [ $1, $2, $3 ] }
        else { push @msg, $_ }
    }
    $opt{stack}   = \@stack;
    $opt{classes} = [ 'perl', (@stack ? 'confess' : 'die') ];

    my $reason
      = @{$opt{stack}} ? ($opt{errno} ? 'ALERT' : 'PANIC')
      :                  ($opt{errno} ? 'FAULT' : 'ERROR');

    ($dietxt, \%opt, $reason, join("\n",@msg));
}

"to die or not to die, that's the question";
