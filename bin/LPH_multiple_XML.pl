#!/usr/bin/env perl
$|=1;
use strict;

####
#
# This software library computes data fingerprints.
# 
# Copyright 2017 by Gustavo Glusman, Institute for Systems Biology, Seattle, WA, USA.
# It is provided by the Institute for Systems Biology as open source software.
# See the accompanying LICENSE file for information about the governing license.
#
####
#
# The first parameter is the directory where the XML files are located.
# The second parameter is the fingerprint size to be used.
# The third parameter specifies whether fingerprints need to be normalized.
#
# The standard output consists of fingerprints of the XML objects in the directory, one per line.
# The first column is the identifier (filename).
# The second column is the number of 'statements' observed while computing the fingerprint.
# The remaining columns are the fingerprint itself.
#
####

use FindBin qw($Bin);
use lib $Bin;
use LIBLPH;
my $LPH = new LIBLPH;

use XML::Simple qw(:strict);
my($dir, $L, $normalize) = @ARGV;
die "Usage: $0 dir_to_scan id_field L normalize\n" unless $dir && -e $dir;
$L ||= 50;
$LPH->{'L'} = $L;
my(%cache, %cacheCount);
my $decimals = 3;

foreach my $scanfile (fulldirlist($dir)) {
	my $content = XMLin($scanfile, ForceArray => 1, KeyAttr => 1);
	
	$LPH->resetFingerprint();
	$LPH->recurseStructure($content);
	next unless $LPH->{'statements'};
	my $fp;
	if ($normalize) {
		$fp = $LPH->normalize();
	} else {
		$fp = $LPH->{'fp'};
	}
	my @v;
	push @v, @{$fp->{$_}} foreach sort {$a<=>$b} keys %$fp;
	print join("\t", $scanfile, $LPH->{'statements'}, map {sprintf("%.${decimals}f", $_)} @v), "\n";
}
close TB;


sub fulldirlist {
	my($self, $dir) = @_;
	opendir (DIR, $dir);
	my @files = grep /^[^.]/, readdir DIR;
	closedir DIR;
	return @files;
}

