package LIBLPH;
use strict;
my $version = '180222';
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
	$obj->{'L'} = "11,13";
	$obj->{'numeric_encoding'} = 'smooth'; # ME, ML, smooth, [default]
	$obj->{'skip_nulls'} = 1;
	$obj->{'arrays_are_sets'} = 0;
	$obj->{'statements'} = 0;
	$obj->{'fp'} = {};
	bless $obj, $package;
	return $obj;
}

sub resetFingerprint {
	my($self) = @_;

	$self->{'fp'} = {};
	$self->{'norm'} = {};
	$self->{'statements'} = 0;
}

sub setLs {
	my($self, $Ls) = @_;
	
	$Ls ||= $self->{'L'};
	my %Ls;
	foreach my $L (split /[,\s]+/, $Ls) {
		if ($L =~ /^[0-9]+$/ && $L>1) {
			$Ls{$L}++;
		}
	}
	my @Ls = sort {$a<=>$b} keys %Ls;
	die "Cannot interpret fingerprint lengths in \"$Ls\"\n" unless @Ls;
	$self->{'_L'} = \@Ls;
	
	my %null;
	$null{$_} = join(",", (0) x $_) foreach @Ls;
	return $self->{'null'} = \%null;
}

sub recurseStructure {
	my($self, $o, $name, $base) = @_;
	my $skip_nulls = $self->{'skip_nulls'};
	my $null = $self->{'null'};
	$null = $self->setLs() unless defined $null;
	
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
			} elsif (!$cargo && $skip_nulls) {
				next;
			} else {
				$value = $self->vector_value($cargo);
			}
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
		if ($self->{'arrays_are_sets'}) {
			my $keysUsed;
			foreach my $key (0..$#$o) {
				my $cargo = $o->[$key]; ### not actually correct
				my $vkey = $self->vector_value($key);
				my $value;
				if (ref $cargo) {
					$value = $self->recurseStructure($cargo, $key, $vkey);
				} elsif (!$cargo && $skip_nulls) {
					next;
				} else {
					$value = $self->vector_value($cargo);
				}
				$self->add_vector_values($base, $vkey, $value, "#set_entry", $name, $key, $cargo);
				$keysUsed++;
			}
			$self->{'statements'} += $keysUsed;
			return $self->vector_value($keysUsed);
		} else {
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
		}
	} else {
		return $self->vector_value($o);
	}
}

sub add_vector_values {
	my($self, $v1, $v2, $v3, @stuff) = @_;
	my $Ls = $self->{'_L'};
	my $fp = $self->{'fp'};
	
	# adds the three vectors to the fingerprint, rotating v2 by 1 and v3 by 2, both to the left
	### need to implement a more meaningful method
	foreach my $L (@$Ls) {
		foreach my $i (0..$L-1) {
			my $v = ($v1->{$L}[$i] + $v2->{$L}[($i+1) % $L] + $v3->{$L}[($i+2) % $L])/3;
			$fp->{$L}[$i] += $v;
		}
	}
}

sub isnumeric ($) {
	no warnings;
	my $v = $_[1];
	if (substr($v,0,1) eq '.') {
		return "0$v" eq $v+0;
	} elsif ($v =~ /^([\-\+])\.(.+)/) {
		return "${1}0.$2" eq $v+0;
	} else {
		return $v eq $v+0;
	}
	
	# simplistic version, which fails for representations like .2, -.5:
	#return $_[1] eq ($_[1]+0);
}

sub vector_value { #computes the value of the first argument in vector form
	my($self, $o) = @_;
	my $cache = $self->{'cache'};
	if ($self->{'usecache'} && defined $cache->{$o}) {
		#$cacheCount{$o}++; ### could be used to selectively clean the cache as needed
		return $cache->{$o};
	}
	my $null = $self->{'null'};
	$null = $self->setLs() unless defined $null;
	my $Ls = $self->{'_L'};
	my $new;
	@{$new->{$_}} = split /,/, $null->{$_} foreach @$Ls;

	if ($self->isnumeric($o) && $o !~ /^nan$/i) {
		my $encoding = $self->{'numeric_encoding'};
		if (!$o) {
			#just keep the null value
		} elsif ($encoding eq 'ME') { # Mantissa/Exponent
			$_ = sprintf("%e", $o);
			my($mantissa, $exponent) = /(\-?[\d\.]+)e([\+\-]\d+)/;
			$mantissa /= 10;
			
			foreach my $L (@$Ls) {
				#encode the mantissa - a fraction, range (-1..1)
				$mantissa *= $L;
				if (my $over = abs($mantissa - int($mantissa))) {
					$new->{$L}[$mantissa % $L] += 1-$over;
					$new->{$L}[($mantissa+($mantissa>0 ? 1 : -1)) % $L] += $over;
				} else {
					$new->{$L}[$mantissa % $L]++;
				}
				#encode the exponent - an integer, which can be negative
				$new->{$L}[$exponent % $L]++; ##this gives equal weight to the mantissa and the exponent
			}
		} elsif ($encoding eq 'ML') { # Mantissa/Log value
			$_ = sprintf("%e", $o);
			my($mantissa, $exponent) = /(\-?[\d\.]+)e([\+\-]\d+)/;
			$mantissa /= 10;
			
			foreach my $L (@$Ls) {
				#encode the mantissa - a fraction, range (-1..1)
				$mantissa *= $L;
				if (my $over = abs($mantissa - int($mantissa))) {
					$new->{$L}[$mantissa % $L] += 1-$over;
					$new->{$L}[($mantissa+($mantissa>0 ? 1 : -1)) % $L] += $over;
				} else {
					$new->{$L}[$mantissa % $L]++;
				}
			}
			#encode the log absolute value - which can be negative
			if ($o) {
				my $logvalue = log(abs($o));
				foreach my $L (@$Ls) {
					if (my $over = abs($logvalue - int($logvalue))) {
						$new->{$L}[$logvalue % $L] += 1-$over;
						$new->{$L}[($logvalue+($logvalue>0 ? 1 : -1)) % $L] += $over;
					} else {
						$new->{$L}[$logvalue % $L]++;
					}
				}
			}
		} elsif ($encoding eq 'smooth') {
			my $over = $o - int($o);
			foreach (@$Ls) {
				$new->{$_}[$o % $_] += 1-$over;
				$new->{$_}[($o+1) % $_] += $over if $over;
			}
		} else {
			$new->{$_}[$o % $_]++ foreach @$Ls;
		}
	} else {
		my @chars = split //, $o;
		$new->{$_}[ord($chars[0]) % $_]++ foreach @$Ls;
		foreach my $i (1..$#chars) {
			my $v = ord($chars[$i-1])+ord($chars[$i]);
			$new->{$_}[$v % $_]++ foreach @$Ls;
		}
	}
	
	foreach my $L (@$Ls) {
		my($min, $total);
		foreach (@{$new->{$L}}) {
			$min = $_ || 0 if $min>$_ || !defined $min;
			last if $min==0;
		}
		if ($min) { $_ -= $min foreach @{$new->{$L}} }
		$total += $_ foreach @{$new->{$L}};
		@{$new->{$L}} = map {$_/$total} @{$new->{$L}} if $total;
	}

	$cache->{$o} = $new if $self->{'usecache'};
	return $new;
}

sub normalize {
	my($self) = @_;
	my $Ls = $self->{'_L'};
	my $fp = $self->{'fp'};
	my $null = $self->{'null'};
	my $norm;
	@{$norm->{$_}} = split /,/, $null->{$_} foreach @$Ls;
	foreach my $L (@$Ls) {
		my($avg, $std) = $self->avgstd($fp->{$L});
		foreach (0..$L-1) { $norm->{$L}[$_] = ($fp->{$L}[$_]-$avg)/$std }
	}
	
	return $self->{'norm'} = $norm;
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

