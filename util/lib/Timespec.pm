# Timespec.pm - Easy time manipulations.
# Copyright (C) 2009-2013 PalominoDB, Inc.
# 
# You may contact the maintainers at eng@palominodb.com.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package Timespec;
use strict;
use warnings FATAL => 'all';
use DateTime;
use DateTime::Format::Strptime;
use Carp;

sub parse {
  my ($class, $str, $ref) = @_;
  # ref is the reference time by which to compare
  # relative timespecs. Normally it can be left blank,
  # but, when testing we need to validate against pre-computed
  # ranges.
  if(not defined $ref) {
    $ref = DateTime->now(time_zone => 'local');
  }
  else {
    $ref = $ref->clone();
  }
  my $fmt_local = DateTime::Format::Strptime->new(pattern => '%F %T',
                                                  time_zone => 'local');
  my $fmt_tz = DateTime::Format::Strptime->new(pattern => '%F %T %O');
  $fmt_tz->parse_datetime($str);
  # $1: op, $2: amt, $3: spec, $4: startof
  if($str =~ /^([-+]?)(\d+)([hdwmqy])(?:(?:\s|\.)(startof))?$/) {
    my ($spec, $amt) = ($3, $2);
    my %cv = ( 'h' => 'hours', 'd' => 'days', 'w' => 'weeks', 'm' => 'months', 'y' => 'years' );
    if($4) {
      if($cv{$spec}) {
        $_ = $cv{$spec};
        s/s$//;
        $ref->truncate(to => $_);
      }
      else { # quarters
        $ref->truncate(to => 'day');
        $ref->subtract(days => $ref->day_of_quarter()-1);
      }
    }

    # for some reason, quarters are not first-class citizens in DateTime
    # so, we have to work around it by doing some math ourselves.
    if($spec eq 'q') {
      $spec = 'm';
      $amt *= 3;
    }

    if($1 eq '-') {
      $ref->subtract($cv{$spec} => $amt);
    }
    if($1 eq '+' or $1 eq '') {
      $ref->add($cv{$spec} => $amt);
    }
    return $ref;
  }
  elsif($str eq 'now') {
    return DateTime->now(time_zone => 'local');
  }
  elsif($str =~ /^(\d+)$/) {
    return DateTime->from_epoch(epoch => $1);
  }
  elsif($_ = $fmt_tz->parse_datetime($str)) {
    return $_;
  }
  elsif($_ = $fmt_local->parse_datetime($str)) {
    return $_;
  }
  else {
    croak("Unknown or invalid Timespec [$str] supplied.");
  }
}

=pod

=head1 NAME

Timespec - Easy time manipulations.

=head1 SYNOPSIS

A timespec is one of:

  A modifier to current local time,
  A unix timestamp (assumed in UTC),
  The string 'now' to refer to current local time,
  An absolute time in 'YYYY-MM-DD HH:MM:SS' format,
  An absolute time in 'YYYY-MD-DD HH:MM:SS TIMEZONE' format.

For the purposes of this module, TIMEZONE refers to zone names
created and maintained by the zoneinfo database.
See L<http://en.wikipedia.org/wiki/Tz_database> for more information.
Commonly used zone names are: Etc/UTC, US/Pacific and US/Eastern.

Since the last four aren't very complicated, this section describes
what the modifiers are.

A modifer is, an optional plus or minus sign followed by a number,
and then one of:

  y = year, q = quarter , m = month, w = week, d = day, h = hour

Followed optionally by a space or a period and 'startof'.
Which is described in the next section.

Some examples (the time is assumed to be 00:00:00):

  -1y         (2010-11-01 -> 2009-11-01)
   5d         (2010-12-10 -> 2010-12-15)
  -1w         (2010-12-13 -> 2010-12-07)
  -1q startof (2010-05-01 -> 2010-01-01)
   1q.startof (2010-05-01 -> 2010-07-01)

=head2 startof

The 'startof' modifier for timespecs is a little confusing,
but, is the only sane way to achieve latching like behavior.
It adjusts the reference time so that it starts at the beginning
of the requested type of interval. So, if you specify C<-1h startof>,
and the current time is: C<2010-12-03 04:33:56>, first the calculation
throws away C<33:56> to get: C<2010-12-03 04:00:00>, and then subtracts
one hour to yield: C<2010-12-03 03:00:00>.

Diagram of the 'startof' operator for timespec C<-1q startof>,
given the date C<2010-05-01 00:00>.

          R P   C
          v v   v
   ---.---.---.---.---.--- Dec 2010
   ^   ^   ^   ^   ^   ^
   Jul Oct Jan Apr Jul Oct
  2009    2010

  . = quarter separator
  C = current quarter
  P = previous quarter
  R = Resultant time (2010-01-01 00:00:00)

=head1 METHODS

Timespec has just one method: C<parse()>.
Which accepts the following arguments: C<$timespec_str>, and C<$ref>.
Where C<$timespec_str> is a timespec as described above. And, C<$ref> is
the base time to modify. The modified time is returned. C<$ref> must be
a DateTime object.

Examples:

  # A time 5 exactly days from now.
  my $r = Timespec->parse("5d");

  # A time 5 days from 2010-11-04 00:00:00
  my $dt = DateTime->new(year => 2010, month => 11,
                         day => 4, hour => 0,
                         minute => 0, second => 0);
  $r = Timespec->parse("5d", $dt);

=cut

1;
