#!/bin/env perl
use strict;
my $version = '180110';
####
#
# This software serializes data fingerprints into a database for efficient searching.
# 
# Copyright 2017 by Gustavo Glusman, Institute for Systems Biology, Seattle, WA, USA.
# It is provided by the Institute for Systems Biology as open source software.
# See the accompanying LICENSE file for information about the governing license.
#
####
#
# The first parameter is the filename base for the database to be created or modified.
# The second parameter is the fingerprint size to be used.
# The third parameter specifies how many columns to ignore.
# The fourth parameter specifies whether fingerprints need to be normalized prior to binarizing.
# The remaining parameters are the files holding the data fingerprints to be collected, or lists of such files.
# If the database already existed, only new fingerprints are added to it.
#
# The output consists of two files: *.fp, a condensed encoding of the fingerprints; and *.id, a companion file with metadata (seek positions in the *.fp file, and any columns that were ignored when binarizing fingerprints).
#
####
#
# Example of usage:
#   serializeLPH.pl lphDB 50 1 0 dataFingerprints.out.gz
#   serializeLPH.pl lphDB 50 3 1 @listOfFiles fingerprints/*.outn.gz
#     --> lphDB.fp
#     --> lphDB.id
#
####

my($outbase, $L, $columnsToIgnore, $normalize, @files) = @ARGV;
die "The second parameter must be a number.\n" unless $L+1-1;

$outbase =~ s/\.(id|fp)$//;

my %done;
if (-e "$outbase.id") {
	open OUTI, "$outbase.id";
	while (<OUTI>) {
		chomp;
		if (/^#/) {
			die "Incompatible fingerprint sizes\n" if /^#L\t(\d+)/ && $1 != $L;
			next;
		}
		my(undef, $name) = split /\t/;
		$done{$name}++;
	}
	close OUTI;
	open OUTI, ">>$outbase.id";
	open OUTF, ">>$outbase.fp";
} else {
	open OUTI, ">$outbase.id";
	print OUTI join("\t", "#created", `date`);
	print OUTI join("\t", "#version", $version), "\n";
	print OUTI join("\t", "#L", $L), "\n";
	
	open OUTF, ">$outbase.fp";
	print OUTF pack('i', $L);
}

my $done;
my @todo;
foreach my $file (@files) {
	next if $done{$file};
	if ($file =~ /^\@(.+)/ && -s $1) {
		open LST, $1;
		while (<LST>) {
			chomp;
			push @todo, $_ if !$done{$_} && -s $_;
		}
		close LST;
	} else {
		push @todo, $file;
	}
}

my $simple = simplifyNames(@todo);

foreach my $file (@todo) {
	next if $done{$simple->{$file}};
	
	if ($file =~ /\.gz$/) {
		open LPH, "gunzip -c $file |";
	} elsif ($file =~ /\.bz2/) {
		open LPH, "bzcat $file |";
	} else {
		open LPH, $file;
	}
	
	while (<LPH>) {
		next if /^#/;
		chomp;
		my($id, @v) = split /\t/;
		my @tv = @v[$columnsToIgnore..$columnsToIgnore+$L-1];
		unless ($L == scalar @tv) {
			die "Fatal: not enough values for $id: ", scalar @tv, "\n";
		}
		normalize(\@tv) if $normalize;
		my $ranked = ranks(\@tv);
		unless ($L == scalar @$ranked) {
			print "Warning: $id yields an incorrect number of values for L=$L\n";
			next;
		}
		print OUTI join("\t", tell OUTF, $id, @v[0..$columnsToIgnore-1]), "\n";
		print OUTF join('', map {pack('i', $_)} @$ranked);
		$done++;
		#print join("\t", $id, @$ranked), "\n";
	}
	
	close LPH;
}
close OUTF;
close OUTI;

$done ||= "zero";
print "Added $done fingerprints to $outbase.fp\n";

###
sub ranks {
	my($v) = @_;
	
	my @ranks;
	my $i;
	foreach (sort {$v->[$a] <=> $v->[$b]} (0..$#$v)) { $ranks[$_] = $i++ }
	return \@ranks;
}

sub simplifyNames {
	my(@names) = @_;
	my %simple;
	my @dict;
	foreach my $name (@names) {
		my @parts = split /[\/\.]/, $name;
		foreach my $i (0..$#parts) {
			$dict[$i]{$parts[$i]}++;
		}
	}
	my $start;
	my $end = $#dict;
	while (1==scalar keys %{$dict[$start]}) { $start++ }
	while (1==scalar keys %{$dict[$end]})   { $end-- }
	return {} if $start>$end;
	#print join("\t", scalar @names, $start, $end), "\n";
	#print join("\t", map {scalar keys %{$dict[$_]}} (0..$#dict)), "\n";
	foreach my $name (@names) {
		my @parts = split /[\/\.]/, $name;
		$simple{$name} = join(".", @parts[$start..$end]), "\n";
		#print join("\t", $simple{$name}, $name), "\n";
	}
	return \%simple;
}



sub normalize {
	my($fp) = @_;
	
	my($avg, $std) = avgstd($fp);
	$std ||= 1;
	foreach (@$fp) {
		$_ = ($_-$avg)/$std;
	}
}

sub avgstd {
	my($values) = @_;
	my($sum, $devsqsum);

	my $n = scalar @$values;
	return unless $n>1;
	foreach (@$values) { $sum += $_ }
	my $avg = $sum / $n;
	foreach (@$values) { $devsqsum += ($_-$avg)**2 }
	my $std = sqrt($devsqsum/($n-1));
	return $avg, $std;
}
