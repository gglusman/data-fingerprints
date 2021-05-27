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
# This script expects as input a file representing a JSON object; this JSON object includes a collection of entities to be fingerprinted, such that the key is used as identifier, and the value is what is fingerprinted.
#
# The first parameter is the file with the JSON objects to be studied.
# The second parameter is the fingerprint size to be used.
# The third parameter specifies whether fingerprints need to be normalized.
# The fourth parameter specifies the level of verbosity for debugging purposes.
#
# The standard output consists of fingerprints of the JSON objects in the file, one per line.
# The first column is the object identifier.
# The second column is the number of 'statements' observed while computing the fingerprint.
# The remaining columns are the fingerprint itself.
#
####

use FindBin qw($Bin);
use lib $Bin;
use LIBLPH;
my $LPH = new LIBLPH;

use JSON;
my($scanfile, $L, $normalize, $debug) = @ARGV;
die "Usage: $0 file_to_scan L [normalize] [debug]\n" unless $scanfile && -e $scanfile;
$L ||= 50;
$LPH->{'L'} = $L;
$LPH->{'debug'} = $debug if $debug;
#my(%cache, %cacheCount);
my $decimals = 3;

if ($scanfile =~ /\.gz$/) {
	open JF, "gunzip -c $scanfile |";
} elsif ($scanfile =~ /\.bz2$/) {
	open JF, "bzcat $scanfile |";
} else {
	open JF, $scanfile;
}
my @jsonContent = <JF>;
close JF;
chomp(@jsonContent);
my $jsonString = join("", @jsonContent);
die "No content in file $scanfile\n" unless $jsonString;
my $content = decode_json($jsonString);

foreach my $id (sort keys %$content) {
	my $entry = $content->{$id};
	next unless ($id || length($id)) && defined $entry;
	$LPH->resetFingerprint();
	$LPH->recurseStructure($entry);
	next unless $LPH->{'statements'};
	my $fp;
	if ($normalize) {
		$fp = $LPH->normalize();
	} else {
		$fp = $LPH->{'fp'};
	}
	my @v;
	push @v, @{$fp->{$_}} foreach sort {$a<=>$b} keys %$fp;
	$id =~ s/[^A-Z0-9_\.\-\=,\+\*:;\@\^\`\|\~]+//gi;
	print join("\t", $id, $LPH->{'statements'}, map {sprintf("%.${decimals}f", $_)} @v), "\n";
}

