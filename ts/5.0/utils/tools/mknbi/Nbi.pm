# Class to handle tagged images
# Placed under GNU Public License by Ken Yap, April 2000

package Nbi;

use strict;
use IO::Seekable;

use constant;
use constant TFTPBLOCKSIZE => 512;
# This is correct for the current version of the netboot specs
# Note: reverse of the way it is in the specs because of Intel byte order
use constant MAGIC => "\x36\x13\x03\x1B";
# This is needed at the end of the boot block, again byte reversed
use constant MAGIC2 => "\x55\xAA";
# This is defined by the bootrom layout
use constant HEADERSIZE => 512;

use vars qw($libdir $bootseg $bootoff @segdescs);

sub new {
	my $class = shift;
	$libdir = shift;
	my $self = {};
	bless $self, $class;
#	$self->_initialize();
	return $self;
}

sub add_header ($$$$$)
{
	my ($class, $vendorinfo, $headerseg, $bootseg, $bootoff) = @_;
	my ($vilen);

	$vilen = length($vendorinfo);
	$vilen += 4;		# three plus one for null byte
	$vilen &= ~0x3;	# round to multiple of 4
	push(@segdescs, pack("A4V3a$vilen",
		MAGIC,
		($vilen << 2) + 4,
		$headerseg << 16,
		($bootseg << 16) + $bootoff,
		$vendorinfo));
}

sub add_pm_header ($$$$$)
{
	my ($class, $vendorinfo, $headerseg, $bootaddr, $progreturns) = @_;
	my ($vilen);

	$vilen = length($vendorinfo);
	$vilen += 4;		# three plus one for null byte
	$vilen &= ~0x3;	# round to multiple of 4
	push(@segdescs, pack("A4V3a$vilen",
		MAGIC,
		(($vilen << 2) + 4) | (1 << 31) | ($progreturns << 8),
		$headerseg << 16,
		$bootaddr,
		$vendorinfo));
}

sub roundup ($$)
{
# Round up to next multiple of $blocksize, assumes that it's a power of 2
	my ($size, $blocksize) = @_;

	# Default to TFTPBLOCKSIZE if not specified
	$blocksize = TFTPBLOCKSIZE if (!defined($blocksize));
	return ($size + $blocksize - 1) & ~($blocksize - 1);
}

# Grab N bytes from a file
sub peek_file ($$$$)
{
	my ($class, $descriptor, $dataptr, $datalen) = @_;
	my ($file, $fromoff, $status);

	$file = $$descriptor{'file'} if exists $$descriptor{'file'};
	$fromoff = $$descriptor{'fromoff'} if exists $$descriptor{'fromoff'};
	return 0 if !defined($file) or !open(R, "$file");
	binmode(R);
	if (defined($fromoff)) {
		return 0 if !seek(R, $fromoff, SEEK_SET);
	}
	# Read up to $datalen bytes
	$status = read(R, $$dataptr, $datalen);
	close(R);
	return ($status);
}

# Add a segment descriptor from a file or a string
sub add_segment ($$$)
{
	my ($class, $descriptor, $vendorinfo) = @_;
	my ($file, $string, $segment, $len, $maxlen, $fromoff, $align,
		$id, $end, $vilen);

	$end = 0;
	$file = $$descriptor{'file'} if exists $$descriptor{'file'};
	$string = $$descriptor{'string'} if exists $$descriptor{'string'};
	$segment = $$descriptor{'segment'} if exists $$descriptor{'segment'};
	$len = $$descriptor{'len'} if exists $$descriptor{'len'};
	$maxlen = $$descriptor{'maxlen'} if exists $$descriptor{'maxlen'};
	$fromoff = $$descriptor{'fromoff'} if exists $$descriptor{'fromoff'};
	$align = $$descriptor{'align'} if exists $$descriptor{'align'};
	$id = $$descriptor{'id'} if exists $$descriptor{'id'};
	$end = $$descriptor{'end'} if exists $$descriptor{'end'};
	if (!defined($len)) {
		if (defined($string)) {
			$len = length($string);
		} else {
			if (defined($fromoff)) {
				$len = (-s $file) - $fromoff;
			} else {
				$len = -s $file;
			}
			return 0 if !defined($len);		# no such file
		}
	}
	if (defined($align)) {
		$len = &roundup($len, $align);
	} else {
		$len = &roundup($len);
	}
	$maxlen = $len if (!defined($maxlen));
	if (!defined($vendorinfo)) {
		push(@segdescs, pack('V4',
			4 + ($id << 8) + ($end << 26),
			$segment << 4,
			$len,
			$maxlen));
	} else {
		$vilen = length($vendorinfo);
		$vilen += 3;           # three plus one for null byte
		$vilen &= ~0x3;        # round to multiple of 4
		push(@segdescs, pack("V4a$vilen",
			($vilen << 2) + 4 + ($id << 8) + ($end << 26),
			$segment << 4,
			$len,
			$maxlen,
			$vendorinfo));
	}
	return ($len);			# assumes always > 0
}

sub pad_with_nulls ($$)
{
	my ($i, $blocksize) = @_;

	$blocksize = TFTPBLOCKSIZE if (!defined($blocksize));
	# Pad with nulls to next block boundary
	$i %= $blocksize;
	print "\0" x ($blocksize - $i) if ($i != 0);
}

# Copy data from file to stdout
sub copy_file ($$)
{
	my ($class, $descriptor) = @_;
	my ($i, $file, $fromoff, $align, $len, $seglen, $nread, $data, $status);

	$file = $$descriptor{'file'} if exists $$descriptor{'file'};
	$fromoff = $$descriptor{'fromoff'} if exists $$descriptor{'fromoff'};
	$align = $$descriptor{'align'} if exists $$descriptor{'align'};
	$len = $$descriptor{'len'} if exists $$descriptor{'len'};
	return 0 if !open(R, "$file");
	if (defined($fromoff)) {
		return 0 if !seek(R, $fromoff, SEEK_SET);
		$len = (-s $file) - $fromoff if !defined($len);
	} else {
		$len = -s $file if !defined($len);
	}
	binmode(R);
	# Copy file in TFTPBLOCKSIZE chunks
	$nread = 0;
	while ($nread != $len) {
		$status = read(R, $data, TFTPBLOCKSIZE);
		last if (!defined($status) or $status == 0);
		print $data;
		$nread += $status;
	}
	close(R);
	if (defined($align)) {
		&pad_with_nulls($nread, $align);
	} else {
		&pad_with_nulls($nread);
	}
	return ($nread);
}

# Copy data from string to stdout
sub copy_string ($$)
{
	my ($class, $descriptor) = @_;
	my ($i, $string, $len, $align);

	$string = $$descriptor{'string'} if exists $$descriptor{'string'};
	$len = $$descriptor{'len'} if exists $$descriptor{'len'};
	$align = $$descriptor{'align'} if exists $$descriptor{'align'};
	return 0 if !defined($string);
	$len = length($string) if !defined($len);
	print substr($string, 0, $len);
	defined($align) ? &pad_with_nulls($len, $align) : &pad_with_nulls($len);
	return ($len);
}

sub dump_segments {
	my ($s, $len);

	$len = 0;
	while ($s = shift(@segdescs)) {
		$len += length($s);
		print $s;
	}
	print "\0" x (HEADERSIZE - 2 - $len), MAGIC2;
}

# This empty for now, but is available as a hook to do any actions
# before closing the image file

sub finalise_image {
}

@segdescs = ();

1;
