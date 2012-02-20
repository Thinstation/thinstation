# Postprocessor for dsp56k bootstrap code.
#
# Copyright Ben Hutchings 2011.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

use strict;
use warnings;

my @memory;
my %symbol;

# Reconstruct memory image and symbol table
while (<>) {
    if (/^P ([0-9A-F]{4}) ([0-9A-F]{6})\n/) {
	$memory[hex($1)] = hex($2);
    } elsif (/^I ([0-9A-F]{6}) (\w+)\n/) {
	$symbol{$2} = hex($1);
    } else {
	print STDERR "W: did not recognise line $.\n";
    }
}

# Concatenate first and second stage.  Second stage is assembled
# between 'upload' and 'upload_end', but initially loaded at
# 'real' (end of the first stage).
for (0 .. ($symbol{real} - 1), $symbol{upload} .. ($symbol{upload_end} - 1)) {
    my $word = $memory[$_] || 0;
    print pack('CCC', $word / 65536, ($word / 256) % 256, $word % 256);
}
