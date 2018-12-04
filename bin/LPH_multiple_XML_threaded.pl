#!/usr/bin/env perl
$|=1;
use strict;

####
#
# This software library computes data fingerprints.
# 
# Copyright 2018 by Gustavo Glusman, Institute for Systems Biology, Seattle, WA, USA.
# It is provided by the Institute for Systems Biology as open source software.
# See the accompanying LICENSE file for information about the governing license.
#
####
#
# The first parameter is the directory where the XML objects are located.
# The second parameter is the fingerprint size to be used.
# The third parameter specifies whether fingerprints need to be normalized.
#
# The output consists of fingerprints of the XML objects in the directory, one per line, but split into files per thread - you'll need to combine them.
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
my($dir, $L, $normalize, $outbase, $threads) = @ARGV;
die "Usage: $0 dir_to_scan L normalize\n" unless $dir && -e $dir;
$L ||= 50;
$LPH->{'L'} = $L;
my(%cache, %cacheCount);
my $decimals = 3;
$outbase ||= $dir;
$threads ||= 4;

#my @filelist = fulldirlist($dir);
my @filelist = recursedirlist($dir);
my $n = scalar @filelist;
print "found $n files\n";
#foreach my $i (0..$n-1) {
#	print $filelist[$i], "\n";
#}

#exit;

foreach my $thread (0..$threads-1) {
	if (fork()) {
		my $done;
		open OUTF, ">$outbase.$thread";
		for (my $i=$thread;$i<$n;$i+=$threads) {
			my $scanfile = $filelist[$i];
			my $content = eval {XMLin("$dir/$scanfile", ForceArray => 0, KeyAttr => 1)};
			next if $@; ## XML parsing failed; should probably say something
			
			$LPH->resetFingerprint();
			$LPH->recurseStructure($content);
			print "$scanfile\n" unless $LPH->{'statements'};
			next unless $LPH->{'statements'};
			my $fp;
			if ($normalize) {
				$fp = $LPH->normalize();
			} else {
				$fp = $LPH->{'fp'};
			}
			my @v;
			push @v, @{$fp->{$_}} foreach sort {$a<=>$b} keys %$fp;
			print OUTF join("\t", $scanfile, $LPH->{'statements'}, map {sprintf("%.${decimals}f", $_)} @v), "\n";
			if ($done && !($done % 500)) {
				print "clearing cache for thread $thread\n";
				$LPH->clear_cache();
			}
			$done++;
		}
		close OUTF;
		print "finished thread $thread having done $done\n";
		exit;
	}
}

sub fulldirlist {
	my($dir) = @_;
	opendir (DIR, $dir);
	my @files = grep /^[^.]/, readdir DIR;
	closedir DIR;
	return @files;
}

sub recursedirlist {
	my($dir) = @_;
	my(@files);
	opendir (DIR, $dir);
	my @items = grep /^[^.]/, readdir DIR;
	closedir DIR;
	foreach my $item (@items) {
		if (-d "$dir/$item") {
			my @subitems = recursedirlist("$dir/$item");
			foreach my $subitem (@subitems) {
				push @files, "$item/$subitem";
				last;
			}
		} else {
			push @files, $item;
		}
	}
	
	return @files;
}


