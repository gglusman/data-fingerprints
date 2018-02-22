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
# The first parameter is the file with the XML objects to be studied.
# The second parameter is the field to be used as identifier.
# The third parameter is the fingerprint size to be used.
# The fourth parameter specifies whether fingerprints need to be normalized.
#
# The standard output consists of fingerprints of the XML objects in the file, one per line.
# The first column is the object identifier.
# The second column is the number of 'statements' observed while computing the fingerprint.
# The remaining columns are the fingerprint itself.
#
####

use FindBin qw($Bin);
use lib $Bin;
use LIBLPH;
my $LPH = new LIBLPH;

use XML::Simple qw(:strict);
my($scanfile, $idField, $L, $normalize) = @ARGV;
die "Usage: $0 file_to_scan id_field L normalize\n" unless $scanfile && -e $scanfile;
$L ||= 50;
$LPH->{'L'} = $L;
my(%cache, %cacheCount);
my $decimals = 3;

my $content = XMLin($scanfile, ForceArray => 1, KeyAttr => 1);

foreach my $entry (@$content) {
	my $id = $entry->{$idField};
	die "No $idField field found\n" unless defined $id;
	delete $entry->{$idField};
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

