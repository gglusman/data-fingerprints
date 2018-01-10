#!/usr/bin/env perl
$|=1;
use strict;

use lib "/users/gglusman/proj/LPH";
use LIBLPH;
my $LPH = new LIBLPH;

use XML::Simple qw(:strict);
my $table = "study_fields.tsv.gz";
my($dir, $L, $normalize) = @ARGV;
$L ||= 50;
$LPH->{'L'} = $L;
my(%cache, %cacheCount);
my $decimals = 3;

foreach my $scanfile (fulldirlist($dir)) {
	my $xmlref = XMLin($scanfile, ForceArray => 1, KeyAttr => 1);
	
	$LPH->resetFingerprint();
	$LPH->recurseStructure($xmlref);
	my $fp;
	if ($normalize) {
		$fp = $LPH->normalize();
	} else {
		$fp = $LPH->{'fp'};
	}
	print join("\t", $scanfile, $LPH->{'statements'}, map {sprintf("%.${decimals}f", $fp->[$_])} (0..$L-1)), "\n";
}
close TB;


sub fulldirlist {
	my($self, $dir) = @_;
	opendir (DIR, $dir);
	my @files = grep /^[^.]/, readdir DIR;
	closedir DIR;
	return @files;
}

