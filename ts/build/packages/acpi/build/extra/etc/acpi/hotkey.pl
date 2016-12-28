#!/usr/bin/perl -w
# Hotkey handler v1.0
# Handles hotkey events for Panasonic notebooks
#
# Copyright (C) 2004 David Bronaugh
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

sub get_amixer_control_info {
  my($control) = @_;
  my($cmd) = $config->{'mixer_program'} . " cget name='" . $control . "'";
  my(%info);
  my($fh, $field);
  my($contents) = "";
  if(open($fh, $cmd . "|")) {
    while(<$fh>) {
      chomp;
      $contents .= $_;
    }
  } else {
    print "Couldn't run command " . $cmd . "!\n";
  }

  $contents =~ m/\; ([^\s]*)/;

  foreach(split(/,/, $+)) {
    my(@foo) = split(/=/, $_);
    $info{$foo[0]} = $foo[1];
  }

  $contents =~ m/\: ([^\s]*)/;
  my(@foo) = split(/=/, $+);
  $info{$foo[0]} = [];
  @{$info{$foo[0]}} = split(/,/, $foo[1]);

  return \%info;
}

sub set_amixer_control_info {
  my($control, $values) = @_;
  my($cmd) = $config->{'mixer_program'} . " -q cset name='" . $control . "' " . $values;

  if(system($cmd) == 0) {
    return 1;
  } else {
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

sub get_brightness {
  return (get_pcc_field("brightness_min"), get_pcc_field("brightness_max"), get_pcc_field("brightness"));
}

sub set_brightness {
  my($value) = @_;
  return set_pcc_field("brightness", $value);
}

sub get_mute {
  my($info) = get_amixer_control_info($config->{'mute_switch'});

  if($info->{'values'}[0] eq "on") {
    return 0;
  } elsif($info->{'values'}[0] eq "off") {
    return 1;
  } else {
    print "Error getting mute status!\n";
    return -1;
  }
}

sub set_mute {
  my($value) = @_;
  if($value == 0) {
    $value = "on";
  } elsif($value == 1) {
    $value = "off";
  }

  if(set_amixer_control_info($config->{'mute_switch'}, $value)) {
    return 1;
  } else {
    print "Couldn't set mute status!\n";
    return 0;
  }
}

sub get_volume {
  my($config) = @_;
  my($info) = get_amixer_control_info($config->{'volume_ctl'});

  return ($info->{'min'}, $info->{'max'}, $info->{'values'});
}

sub set_volume {
  my($values) = @_;

  return set_amixer_control_info($config->{'volume_ctl'}, join(",", @{$values}));
}

sub get_power_state {
  my($data) = read_file($config->{"ac_state"});

  if($data =~ /on-line/) {
    return "ac";
  } elsif($data =~ /off-line/) {
    return "dc";
  } else {
    print "Couldn't get power state! (is ACPI enabled?)\n";
    exit(1);
  }
}

sub adjust_brightness { 
  my($adjust) = @_;
  my($min, $max, $bright) = get_brightness($config);
  my($threshold) = $config->{'max_bright_levels'};
  my($divisor) = 1;

  $bright -= $min;

  if($max - $min > $threshold) {
    $divisor = ($max - $min) / $threshold;
  }

  $bright = ceil($bright / $divisor);
  $bright += $adjust;
  $bright = floor($bright * $divisor);

  $bright += $min;

  if($bright < $min) {
    $bright = $min;
  }

  if($bright > $max) {
    $bright = $max;
  }

  if(!set_brightness($bright)) {
    print "Couldn't adjust brightness!\n";
  }

  return;
}

sub adjust_volume {
  my($increment) = @_;
  my($min, $max, $volume) = get_volume($config);

  $volume->[0] += $increment;
  $volume->[1] += $increment;

  $volume->[0] = ($volume->[0] < $min)?$min:$volume->[0];
  $volume->[1] = ($volume->[1] < $min)?$min:$volume->[1];
  $volume->[0] = ($volume->[0] > $max)?$max:$volume->[0];
  $volume->[1] = ($volume->[1] > $max)?$max:$volume->[1];

  if(!set_volume($volume)) {
    print "Couldn't set volume!\n";
  }

  return;
}

# Functions which implement hotkey functions directly
sub down_brightness {
  adjust_brightness(-1);
}

sub up_brightness {
  adjust_brightness(1);
}

sub switch_monitor {
  #STUB
}

sub toggle_mute {
  my($mute) = get_mute();

  if($mute >= 0) {
    set_mute($mute ^ 1);
  }
}

sub volume_up {
  adjust_volume($config->{"volume_increment"})
}

sub volume_down {
  adjust_volume(-1 * $config->{"volume_increment"})
}

sub suspend_to_ram {
  # This space intentionally left blank (because it doesn't work here)
}

sub spin_down_hd {
  if(system("hdparm -q -y /dev/hda") != 0) {
    print "Error running hdparm -- is it installed?\n";
  }
}

sub suspend_to_disk {
  system("hwclock --systohc");
  write_file($config->{'suspend_control'}, "disk");
  system("hwclock --hctosys");
}

my($key) = $ARGV[3];

my(%dispatch) = (
	     "00000081" => \&down_brightness,
	     "00000082" => \&up_brightness,
	     "00000003" => \&switch_monitor,
	     "00000084" => \&toggle_mute,
	     "00000085" => \&volume_down,
	     "00000086" => \&volume_up,
	     "00000007" => \&suspend_to_ram,
	     "00000089" => \&spin_down_hd,
	     "0000000a" => \&suspend_to_disk
	    );

$config = {
	       "pcc_path" => "/proc/acpi/pcc",
	       "mixer_program" => "amixer",
	       "ac_state" => "/proc/acpi/ac_adapter/AC/state",
	       "mute_switch" => "Master Playback Switch",
	       "volume_ctl" => "Master Playback Volume",
	       "max_bright_levels" => 20,
	       "volume_increment" => 2,
	       "suspend_control" => "/sys/power/state"
	      };

$power_state = get_power_state();

$dispatch{$key}();
