package LIBLPH;
use strict;
my $version = '180215';
####
#
# This software library computes data fingerprints.
# 
# Copyright 2017 by Gustavo Glusman, Institute for Systems Biology, Seattle, WA, USA.
# It is provided by the Institute for Systems Biology as open source software.
# See the accompanying LICENSE file for information about the governing license.
#
####

sub new {
	my $package = shift;

	my $obj = {};
	$obj->{'usecache'} = 1;
	$obj->{'cache'} = {};
	$obj->{'root'} = 'root';
	$obj->{'L'} = 13;
	$obj->{'smooth'} = 1;
	$obj->{'skip_nulls'} = 1;
	$obj->{'statements'} = 0;
	$obj->{'fp'} = [];
	bless $obj, $package;
	return $obj;
}

sub resetFingerprint {
	my($self) = @_;

	$self->{'fp'} = [];
	$self->{'norm'} = [];
	$self->{'statements'} = 0;
}


sub recurseStructure {
	my($self, $o, $name, $base) = @_;
	my $skip_nulls = $self->{'skip_nulls'};
	my $null = $self->{'null'};
	unless ($null) {
		$null = $self->{'null'} = join(",", 1, (0) x ($self->{'L'}-1));
	}
	
	$name = $self->{'root'} unless defined $name;
	$base = $self->vector_value(0) unless defined $base;
	my $fp = $self->{'fp'};
	if (ref $o eq 'HASH') {
		my $keysUsed;
		while (my($key, $cargo) = each %$o) {
			#next if $key eq 'labels' && $o->{'max_labels_exceeded'}; # bdqc-specific tweak
			my $vkey = $self->vector_value($key);
			my $value;
			if (ref $cargo) {
				$value = $self->recurseStructure($cargo, $key, $vkey);
			} elsif ($cargo || !$skip_nulls) {
				$value = $self->vector_value($cargo);
			}
			next if $skip_nulls && (!$cargo || join(",", @$value) eq $null);
			$self->add_vector_values($base, $vkey, $value, "#hash_entry", $name, $key, $cargo);
			$keysUsed++;
		}
		$self->{'statements'} += $keysUsed;
		return $self->vector_value($keysUsed);
	} elsif (ref $o eq 'ARRAY') {
		if (1==scalar @$o && ref $o->[0]) {
			# flattening uninformative extra structure layer
			return $self->recurseStructure($o->[0], $name, $base);
		}
		my @values;
		foreach my $i (0..$#$o) {
			$values[$i] = ref $o->[$i] ? $self->recurseStructure($o->[$i], $i, $self->vector_value($i)) : $self->vector_value($o->[$i]);
		}
		# add link to first element in array
		$self->add_vector_values($base, $self->vector_value(0), $values[0], "#array_start", $name, 0, $o->[0]);
		# add links between subsequent pairs of elements in array
		foreach my $i (1..$#$o) {
			$self->add_vector_values($base, $values[$i-1], $values[$i], "#array_pair", $name, $o->[$i-1], $o->[$i]);
		}
		# add link from last element in array
		$self->add_vector_values($base, $values[$#$o], $self->vector_value(scalar @$o), "#array_end", $name, $o->[$#$o], scalar @$o);
		$self->{'statements'} += 2+scalar @$o;
		return $self->vector_value(scalar @$o);
	} else {
		return $self->vector_value($o);
	}
}

sub add_vector_values {
	my($self, $v1, $v2, $v3, @stuff) = @_;
	my $L = $self->{'L'};
	my $fp = $self->{'fp'};
	
	# adds the three vectors to the fingerprint, rotating v2 by 1 and v3 by 2, both to the left
	foreach my $i (0..$L-1) {
		my $v = ($v1->[$i] + $v2->[($i+1) % $L] + $v3->[($i+2) % $L])/3;
		$fp->[$i] += $v;
	}
}

sub isnumeric ($) {
	no warnings;
	return $_[1] eq ($_[1]+0);
}

sub vector_value { #computes the value of the first argument in vector form
	my($self, $o) = @_;
	my $L = $self->{'L'};
	my $smooth = $self->{'smooth'};
	my $cache = $self->{'cache'};
	if ($self->{'usecache'} && defined $cache->{$o}) {
		#$cacheCount{$o}++; ### could be used to selectively clean the cache as needed
		return $cache->{$o};
	}

	my @new = (0) x $L;

	if ($self->isnumeric($o) && $o !~ /^nan$/i) {
		if ($smooth) {
			my $over = $o - int($o);
			$new[$o % $L] += 1-$over;
			$new[($o+1) % $L] += $over if $over;
		} else {
			$new[$o % $L]++;
		}
	} else {
		my @chars = split //, $o;
		$new[ord($chars[0]) % $L]++;
		foreach my $i (1..$#chars) {
			$new[(ord($chars[$i-1])+ord($chars[$i])) % $L]++;
		}
	}

	my($min, $total);
	foreach (@new) { $min = $_ || 0 if $min>$_ || !defined $min }
	foreach my $i (0..$#new) {
		$new[$i] -= $min if $min;
		$total += $new[$i];
	}
	if ($total) {
		@new = map {$_/$total} @new;
	} else {
		@new = ();
	}

	$cache->{$o} = \@new if $self->{'usecache'};
	
	return \@new;
}

sub normalize {
	my($self) = @_;
	my $fp = $self->{'fp'};
	my @norm;
	my($avg, $std) = $self->avgstd($fp);
	foreach (0..$#$fp) { $norm[$_] = ($fp->[$_]-$avg)/$std }
	return $self->{'norm'} = \@norm;
}

sub avgstd {
	my($self, $values) = @_;
	my($sum, $devsqsum);

	my $n = scalar @$values;
	return unless $n>1;
	foreach (@$values) { $sum += $_ }
	my $avg = $sum / $n;
	foreach (@$values) { $devsqsum += ($_-$avg)**2 }
	my $std = sqrt($devsqsum/($n-1));
	return $avg, $std;
}

1;

