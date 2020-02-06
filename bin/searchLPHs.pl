#!/bin/env perl
use strict;
my $version = '191018';
use FindBin qw($Bin);
####
#
# This software compares two sets of data fingerprints.
# The method is described in:
#    Glusman G, Mauldin DE, Hood LE, Robinson M. Ultrafast Comparison of Personal
#    Genomes via Precomputed Genome Fingerprints. Front Genet. 2017 Sep 26;8:136. doi:
#    10.3389/fgene.2017.00136. eCollection 2017. PubMed PMID: 29018478; PubMed Central
#    PMCID: PMC5623000.
# 
# Copyright 2019 by Gustavo Glusman, Institute for Systems Biology, Seattle, WA, USA.
# It is provided by the Institute for Systems Biology as open source software,
# free for non-commercial use.
# See the accompanying LICENSE file for information about the governing license.
#
####
#
# The first parameters is the query set. It can include one or more fingerprints in serialized format. If a non-serialized fingerprint is used as query, it is automatically serialized using the fingerprint size of the target set.
# The second parameter (optional) is the target set: a serialized collection of fingerprints. If absent, all-against-all comparisons are performed in the query set.
# The third parameter (optional) is a correlation cutoff: pairs with similarity below this cutoff are not reported. If cutoff>1, it is interpreted as the maximal number of comparisons to report, after sorting by decreasing correlation ('top' correlations).
#
####
#
# Examples of usage:
#   searchLPHs.pl query.fp
#   searchLPHs.pl query.fp target.fp
#   searchLPHs.pl query.fp target.fp 0.5
#   searchLPHs.pl query.fp 0 100000
#
####

my $fpc = "$Bin/fpc";
die "Cannot find fpc (the search engine)\n" unless -s $fpc;
my($query, $target, $cutoff, $histogram_outfile) = @ARGV;
unless ($query) {
	print "Usage: searchLPHs.pl fingerprints/anEntity.outn.gz target-set\n";
	print "       searchLPHs.pl query-set target-set\n";
	print "       searchLPHs.pl query-set target-set 0.5 (will not report correlations under 0.5)\n";
	print "       searchLPHs.pl query-set  (will perform all comparisons within the query data set)\n";
	print "       searchLPHs.pl query-set 0 100000 (will report the top 100000 correlations, within the query data set)\n";
	exit;
}

my $maxSave;
if ($cutoff>1) {
	$maxSave = $cutoff;
	$cutoff = -1;
}

$query  = $_ if $_ = readlink($query);
$target = $_ if $_ = readlink($target);

my($qnames, $tnames, $L);

if (!$target) {
	#will use same as query
} elsif ($target =~ /(.+)\.fp/) {
	$tnames = readIds("$1.id");
} elsif (-e "$target.id") {
	$tnames = readIds("$target.id");
	$target = "$target.fp";
} else {
	die "Couldn't interpret $target as target\n";
}



if ($query =~ /(.+)\.fp$/) {
	$qnames = readIds("$1.id");
} elsif (-e "$query.id") {
	$qnames = readIds("$query.id");
	$query = "$query.fp";
} else {
	`$Bin/serializeLPHs.pl tmp$$ $L $query`; ### draft code, needs testing
	$qnames = readIds("tmp$$.id");
	unless (@$qnames) {
		unlink "tmp$$.fp";
		unlink "tmp$$.id";
		die "Couldn't interpret $query as query\n";
	}
	$query = "tmp$$.fp";
}

my($nqueries, $ntargets, $combinations);
$nqueries = scalar @$qnames;
if ($target) {
	open FPC, "$fpc $query $target |";
	$ntargets = scalar @$tnames;
	$combinations = $nqueries*$ntargets;
} else {
	open FPC, "$fpc $query |";
	$tnames = $qnames;
	$combinations = $nqueries*($nqueries-1)/2;
}

#print "expecting $combinations combinations\n";
my %c;
my $pairs;
my $lines;
my @hist;
while (<FPC>) {
	#print;
	chomp;
	my($q, $t, $c) = split /\t/;
	$lines++;
	$hist[$c*100+100]++;
	next if defined $cutoff && $c<$cutoff;
	$c{join("\t", $qnames->[$q-1], $tnames->[$t-1])} = $c;
	$pairs++;
	unless (!$maxSave || ($pairs % $maxSave)) {
		my @sorted = sort {$c{$b}<=>$c{$a}} keys %c;
		$cutoff = $c{$sorted[$maxSave]};
		for (my $i=$maxSave;$i<scalar @sorted;$i++) {
			delete $c{$sorted[$i]};
		}
	}
}

if ($histogram_outfile) {
	open HIST, ">$histogram_outfile";
	print HIST join("\t", qw/CORR PAIRS/), "\n";
	foreach my $i (0..$#hist) {
		print HIST join("\t", sprintf("%.2f", ($i-100)/100), $hist[$i]), "\n" if defined $hist[$i];
	}
	close HIST;
}

my @sorted = sort {$c{$b}<=>$c{$a}} keys %c;
$maxSave ||= scalar @sorted;
for (my $i=0;$i<$maxSave && $i<=$#sorted;$i++) {
	print join("\t", $sorted[$i], $c{$sorted[$i]}), "\n";
}
close FPC;

unlink "tmp$$.fp";
unlink "tmp$$.id";



sub readIds {
	my($idfile) = @_;
	my @names;
	open ID, "$idfile";
	while (<ID>) {
		if (/^#/) {
			$L = $1 if /^#L\t(\d+)/;
			next;
		}
		chomp;
		my(undef, $id, $file) = split /\t/;
		push @names, $id;
	}
	close ID;
	return \@names;
}


