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
# The first parameter is the file with the JSON objects to be studied.
# The second parameter is the field to be used as identifier.
# The third parameter is the fingerprint size to be used.
# The fourth parameter specifies whether fingerprints need to be normalized.
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
my($scanfile, $idField, $L, $normalize) = @ARGV;
die "Usage: $0 file_to_scan id_field L normalize\n" unless $scanfile && -e $scanfile;
$L ||= 50;
$LPH->{'L'} = $L;
my(%cache, %cacheCount);
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

foreach my $entry (@$content) {
	my $id = $entry->{$idField};
	die "No $idField field found\n" unless defined $id;
	delete $entry->{$idField};
	$LPH->resetFingerprint();
	$LPH->recurseStructure($entry);
	my $fp;
	if ($normalize) {
		$fp = $LPH->normalize();
	} else {
		$fp = $LPH->{'fp'};
	}
	print join("\t", $id, $LPH->{'statements'}, map {sprintf("%.${decimals}f", $fp->[$_])} (0..$L-1)), "\n";
}

