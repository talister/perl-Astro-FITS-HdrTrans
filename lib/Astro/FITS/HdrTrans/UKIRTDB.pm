package Astro::FITS::HdrTrans::UKIRTDB;

# ---------------------------------------------------------------------------

#+
#  Name:
#    Astro::FITS::HdrTrans::UKIRTDB

#  Purposes:
#    Translates FITS headers into and from generic headers for the
#    UKIRTDB database

#  Language:
#    Perl module

#  Description:
#    This module converts information stored in a FITS header into
#    and from a set of generic headers

#  Authors:
#    Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 2002 Particle Physics and Astronomy Research Council.
#     All Rights Reserved.

#-

# ---------------------------------------------------------------------------

=head1 NAME

Astro::FITS::HdrTrans::UKIRTDB - Translate FITS headers into generic
headers and back again

=head1 SYNOPSIS

  %generic_headers = translate_from_FITS(\%FITS_headers, \@header_array);

  %FITS_headers = transate_to_FITS(\%generic_headers, \@header_array);

=head1 DESCRIPTION

Converts information contained in UKIRTDB FITS headers to and from
generic headers. See Astro::FITS::HdrTrans for a list of generic
headers.

=cut

# L O A D   M O D U L E S --------------------------------------------------

use strict;
use vars qw/ $VERSION /;
use Data::Dumper;
use Time::Piece;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# P R E D E C L A R A T I O N S --------------------------------------------

our %hdr;

# M E T H O D S ------------------------------------------------------------

=head1 REVISION

$Id$

=head1 METHODS

=over 4

=item B<translate_from_FITS>

Converts a hash containing UKIRTDB headers into a hash containing
generic headers.

  %generic_headers = translate_from_FITS(\%FITS_headers, \@header_array);

The C<header_array> argument is used to supply a list of generic
header names.

=back

=cut

sub translate_from_FITS {
  my $FITS_header = shift;
  my $header_array = shift;
  my %generic_header;

  for my $key ( @$header_array ) {

    if(exists($hdr{$key}) ) {
      $generic_header{$key} = $FITS_header->{$hdr{$key}};
    } else {
      my $subname = "to_" . $key;
      if(exists(&$subname) ) {
        no strict 'refs'; # EEP!
        $generic_header{$key} = &$subname($FITS_header);
      }
    }
  }
  return %generic_header;

}

=over 4

=item B<translate_to_FITS>

Converts a hash containing generic headers into a hash containing
FITS headers

  %FITS_headers = translate_to_FITS(\%generic_headers, \@header_array);

The C<header_array> argument is used to supply a list of generic
header names.

=back

=cut

sub translate_to_FITS {
  my $generic_header = shift;
  my $header_array = shift;
  my %FITS_header;

  for my $key ( @$header_array ) {

    if( exists($hdr{$key}) ) {
      $FITS_header{$hdr{$key}} = $generic_header->{$key};
    } else {
      no strict 'refs'; # EEP EEP!
      my $subname = "from_" . $key;
      if(exists(&$subname) ) {
        my %new = &$subname($generic_header);
        for my $newkey ( keys %new ) {
          $FITS_header{$newkey} = $new{$newkey};
        }
      }
    }
  }

  return %FITS_header;

}

=head1 TRANSLATION METHODS

These methods provide many-to-one mappings between FITS headers and
generic headers. An example of a method defined in this section would
be one that converts UT date and UT hour FITS headers into one combined
UT datetime generic header. These mappings can also use calculations,
for example converting a zenith distance to airmass.

These methods are named backwards from the C<translate_from_FITS> and
C<translate_to_FITS> methods in that we are translating to and from
generic headers. As an example, a method to convert to a generic airmass
header would be named C<to_AIRMASS>.

The format of these methods is C<to_HEADER> and C<from_HEADER>.
C<to_> methods accept a hash reference as an argument and return a scalar
value (typically a string). C<from_> methods accept a hash reference
as an argument and return a hash. All UT datetimes should be in
standard ISO 8601 datetime format, which is C<YYYY-MM-DDThh:mm:ss>.
See http://www.cl.cam.ac.uk/~mgk25/iso-time.html for a brief overview
of ISO 8601. Dates should be in YYYY-MM-DD format.

=over 4

=item B<to_COORDINATE_TYPE>

Converts the C<EQUINOX> FITS header into B1950 or J2000, depending
on equinox value, and sets the C<COORDINATE_TYPE> generic header.

=cut

sub to_COORDINATE_TYPE {
  my $FITS_headers = shift;
  my $return;
  if(exists($FITS_headers->{EQUINOX})) {
    if($FITS_headers->{EQUINOX} =~ /1950/) {
      $return = "B1950";
    } elsif ($FITS_headers->{EQUINOX} =~ /2000/) {
      $return = "J2000";
    }
  }
  return $return;
}

=item B<to_COORDINATE_UNITS>

Sets the C<COORDINATE_UNITS> generic header to "degrees".

=cut

sub to_COORDINATE_UNITS {
  "degrees";
}

=item B<to_UTSTART>

Combines the C<UT_DATE> and C<RUTSTART> headers into a unified
C<UTSTART> header.

=cut

sub to_UTSTART {
  my $FITS_headers = shift;
  my $return;
  if(exists($FITS_headers->{'UT_DATE'}) &&
     exists($FITS_headers->{'RUTSTART'}) ) {
    # The UT_DATE is returned in the form "mmm dd yyyy hh:mm(am|pm)"
    my $t = Time::Piece->strptime($FITS_headers->{'UT_DATE'}, "%b %d %Y %I:%M%p");
    my $hour = int($FITS_headers->{'RUTSTART'});
    my $minute = int( ( $FITS_headers->{'RUTSTART'} - $hour ) * 60 );
    my $second = int( ( ( ( $FITS_headers->{'RUTSTART'} - $hour ) * 60) - $minute ) * 60 );
    $return = $t->ymd . "T" . $hour . ":" . $minute . ":" . $second;
  }
  return $return;
}

=item B<from_UTSTART>

Converts the C<UTSTART> generic header into C<UT_DATE> and C<RUTSTART>
database headers.

=cut

sub from_UTSTART {
  my $generic_headers = shift;
  my %return_hash;
  if(exists($generic_headers->{UTSTART})) {
    my $t = ORAC::General->parse_date( $generic_headers->{'UTSTART'} );
    my $month = $t->month;
    $month =~ /^(.{3})/;
    $month = $1;
    $return_hash{'UT_DATE'} = $month . " " . $t->mday . " " . $t->year;
    $return_hash{'RUTSTART'} = $t->hour + ($t->min / 60) + ($t->sec / 3600);
  }
  return %return_hash;
}

=item B<to_UTEND>

Combines the C<UT_DATE> and C<RUTEND> headers into a unified
C<UTEND> header.

=cut

sub to_UTEND {
  my $FITS_headers = shift;
  my $return;
  if(exists($FITS_headers->{'UT_DATE'}) &&
     exists($FITS_headers->{'RUTEND'}) ) {
    # The UT_DATE is returned in the form "mmm dd yyyy hh:mm(am|pm)"
    my $t = Time::Piece->strptime($FITS_headers->{'UT_DATE'}, "%b %d %Y %I:%M%p");
    my $hour = int($FITS_headers->{'RUTEND'});
    my $minute = int( ( $FITS_headers->{'RUTEND'} - $hour ) * 60 );
    my $second = int( ( ( ( $FITS_headers->{'RUTEND'} - $hour ) * 60) - $minute ) * 60 );
    $return = $t->ymd . "T" . $hour . ":" . $minute . ":" . $second;
  }
  return $return;
}

=item B<from_UTEND>

Converts the C<UTSTART> generic header into C<UT_DATE> and C<RUTSTART>
database headers.

=cut

sub from_UTEND {
  my $generic_headers = shift;
  my %return_hash;
  if(exists($generic_headers->{UTEND})) {
    my $t = ORAC::General->parse_date( $generic_headers->{'UTEND'} );
    my $month = $t->month;
    $month =~ /^(.{3})/;
    $month = $1;
    $return_hash{'UT_DATE'} = $month . " " . $t->mday . " " . $t->year;
    $return_hash{'RUTEND'} = $t->hour + ($t->min / 60) + ($t->sec / 3600);
  }
  return %return_hash;
}

=item B<to_X_BASE>

Converts the decimal hours in the FITS header C<RABASE> into
decimal degrees for the generic header C<X_BASE>.

=cut

sub to_X_BASE {
  my $FITS_headers = shift;
  my $return;
  if(exists($FITS_headers->{RABASE})) {
    $return = $FITS_headers * 15;
  }
  return $return;
}

=item B<from_X_BASE>

Converts the decimal degrees in the generic header C<X_BASE>
into decimal hours for the FITS header C<RABASE>.

=cut

sub from_X_BASE {
  my $generic_headers = shift;
  my %return_hash;
  if(exists($generic_headers->{X_BASE})) {
    $return_hash{'RABASE'} = $generic_headers->{X_BASE} / 15;
  }
  return %return_hash;
}

=back

=head1 VARIABLES

=over 4

=item B<%hdr>

Contains one-to-one mappings between FITS headers and generic headers.
Keys are generic headers, values are FITS headers.

=cut

%hdr = (
            AIRMASS_START        => "AMSTART",
            AIRMASS_END          => "AMEND",
            CONFIGURATION_INDEX  => "CNFINDEX",
            DEC_BASE             => "DECBASE",
            DEC_SCALE            => "PIXELSIZ",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            DETECTOR_READ_TYPE   => "MODE",
            EQUINOX              => "EQUINOX",
            EXPOSURE_TIME        => "EXPOSED",
            FILTER               => "FILTER",
            INSTRUMENT           => "INSTRUME",
            MSBID                => "MSBID",
            NUMBER_OF_EXPOSURES  => "NEXP",
            OBJECT               => "OBJECT",
            OBSERVATION_NUMBER   => "RUN",
            OBSERVATION_TYPE     => "OBSTYPE",
            PROJECT              => "PROJECT",
            RA_BASE              => "RABASE",
            RA_SCALE             => "PIXELSIZ",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            TELESCOPE            => "TELESCOP",
            UTDATE               => "UT_DATE",
            WAVEPLATE_ANGLE      => "WPLANGLE",
            Y_BASE               => "DECBASE",
            X_OFFSET             => "RAOFF",
            Y_OFFSET             => "DECOFF",
            X_SCALE              => "PIXELSIZ",
            Y_SCALE              => "PIXELSIZ",
            X_LOWER_BOUND        => "RDOUT_X1",
            X_UPPER_BOUND        => "RDOUT_X2",
            Y_LOWER_BOUND        => "RDOUT_Y1",
            Y_LOWER_BOUND        => "RDOUT_Y2"
          );

=back

=head1 AUTHOR

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2002 Particle Physics and Astronomy Research Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;