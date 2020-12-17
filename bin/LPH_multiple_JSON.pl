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
# This script expects as input a directory with one or more files, each file representing a JSON object including a single entity to be fingerprinted. The file name is used as the identifier for that entity.
#
# The first parameter is the directory where the JSON objects are located.
# The second parameter is the fingerprint size to be used.
# The third parameter specifies whether fingerprints need to be normalized.
# The fourth parameter specifies the level of verbosity for debugging purposes.
#
# The standard output consists of fingerprints of the JSON objects in the directory, one per line.
# The first column is the identifier (filename).
# The second column is the number of 'statements' observed while computing the fingerprint.
# The remaining columns are the fingerprint itself.
#
####

use FindBin qw($Bin);
use lib $Bin;
use LIBLPH;
my $LPH = new LIBLPH;

use JSON;
my($dir, $L, $normalize, $debug) = @ARGV;
die "Usage: $0 dir_to_scan L [normalize] [debug]\n" unless $dir && -e $dir;
$L ||= 50;
$LPH->{'L'} = $L;
$LPH->{'debug'} = $debug if $debug;
my(%cache, %cacheCount);
my $decimals = 3;

foreach my $scanfile (fulldirlist($dir)) {
	my $id = $scanfile;
	if ($scanfile =~ /\.gz$/) {
		$id =~ s/\.gz$//;
		open JF, "gunzip -c $dir/$scanfile |";
	} elsif ($scanfile =~ /\.bz2$/) {
		$id =~ s/\.bz2$//;
		open JF, "bzcat $dir/$scanfile |";
	} else {
		open JF, "$dir/$scanfile";
	}
	my @jsonContent = <JF>;
	close JF;
	chomp(@jsonContent);
	my $jsonString = join("", @jsonContent);
	next unless $jsonString;
	my $content = decode_json($jsonString);
	$id =~ s/\.json$//;
	
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
	print join("\t", $id, $LPH->{'statements'}, map {sprintf("%.${decimals}f", $_)} @v), "\n";
}


sub fulldirlist {
	my($dir) = @_;
	opendir (DIR, $dir);
	my @files = grep /^[^.]/, readdir DIR;
	closedir DIR;
	return @files;
}

