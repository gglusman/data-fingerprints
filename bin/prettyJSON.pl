#!/usr/bin/env perl
$|=1;
use strict;
use JSON;

my($scanfile) = @ARGV;

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

print to_json($content, {pretty=>1}), "\n";
