#!/usr/bin/perl -w
# AC Power Handler v1.0
# Handles AC power events for Panasonic notebooks
#
# Copyright (C) 2004 David Bronaugh
#
# Requires pcc_acpi driver
#
# This program is free software; you can redistribute it and/or modify 
# it under the terms of the GNU General Public License version 2 as 
# published by the Free Software Foundation
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use POSIX qw(ceil floor);

our($config);
our($power_state);

sub read_file {
  my($file) = @_;
  my($fh);
  my($contents) = "";
  if(open($fh, $file)) {
    $/ = undef;
    $contents = <$fh>;
    close($fh);
  } else {
    print "Couldn't open file " . $file . "!\n";
  }
  return $contents;
}

sub write_file {
  my($file, $contents) = @_;
  my($fh);

  if(open($fh, ">", $file)) {
    print $fh $contents;
    close($fh);
    return 1;
  } else {
    print "Couldn't open file " . $file . "!\n";
    return 0;
  }
}

sub get_pcc_field {
  my($field) = @_;
  my($file) = $config->{'pcc_path'} . "/" . $power_state . "_" . $field;

  return read_file($file);
}

sub set_pcc_field {
  my($field, $contents) = @_;
  my($file) = $config->{'pcc_path'} . "/" . $power_state . "_" . $field;

  if(!write_file($file, $contents)) {
    print "Couldn't set pcc " . $field . " field (are you root?)\n";
    return 0;
  }
  return 1;
}

sub ac_disconnect {
  $power_state = "dc";
  set_pcc_field("brightness", get_pcc_field("brightness"));
}

sub ac_connect {
  $power_state = "ac";
  set_pcc_field("brightness", get_pcc_field("brightness"));
}

my($key) = $ARGV[3];

my(%dispatch) = (
	     "00000000" => \&ac_disconnect,
	     "00000001" => \&ac_connect,
	    );

$config = {
	       "pcc_path" => "/proc/acpi/pcc",
	      };

$dispatch{$key}();
