package LIBLPH;
use strict;
my $version = '200218';
use Scalar::Util qw(looks_like_number);

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
	$obj->{'numeric_encoding'} = 'ME'; # ME, ML, smooth, simple [default if given null option]
	$obj->{'string_encoding'} = 'decay';
	$obj->{'string_encoding_decay'} = 0.1;
	$obj->{'exponent_weight'} = 0.5;
	$obj->{'skip_nulls'} = 1;
	$obj->{'arrays_are_sets'} = 0;
	$obj->{'statements'} = 0;
	$obj->{'debug'} = 0;
	$obj->{'fp'} = {};
	#$obj->{'exclude'}{'keys'} = {'CommentsCorrectionsList' => 1, 'MeshHeadingList' => 1};
	
	bless $obj, $package;
	return $obj;
}

sub resetFingerprint {
	my($self) = @_;

	print "#resetFingerprint()\n" if $self->{'debug'};
	$self->{'fp'} = {};
	$self->{'norm'} = {};
	$self->{'statements'} = 0;
}

sub setLs {
	my($self, $Ls) = @_;
	
	$Ls ||= $self->{'L'};
	print "#setLs($Ls)\n" if $self->{'debug'};
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

sub excludeKey {
	my($self, $key) = @_;
	
	return 1 if $self->{'exclude'}{'all'}{$key} || $self->{'exclude'}{'keys'}{$key};
}



sub recurseStructure {
	my($self, $o, $name, $base) = @_;
	my $skip_nulls = $self->{'skip_nulls'};
	my $null = $self->{'null'};
	$null = $self->setLs() unless defined $null;
	
	$name = $self->{'root'} unless defined $name;
	print "#recursing: $o $name\n" if $self->{'debug'}>1;
	$base = $self->vector_value(0) unless defined $base;
	my $fp = $self->{'fp'};
	if (ref $o eq 'HASH') {
		my $keysUsed;
		while (my($key, $cargo) = each %$o) {
			#next if $key eq 'labels' && $o->{'max_labels_exceeded'}; # bdqc-specific tweak
			
			#test whether $key is acceptable, shortcut if not
			if ($self->excludeKey($key)) {
				print "#skipping excluded key: $key\n" if $self->{'debug'}>6;
				next;
			}
			
			my $vkey;
			#print join("\t", "key-vkey", $key, $vkey), "\n";
			if (ref $cargo) {
				$vkey = $self->vector_value($key);
				$cargo = $self->recurseStructure($cargo, $key, $vkey);
			} elsif (!$cargo && $skip_nulls) {
				next;
			}
			$vkey //= $self->vector_value($key);
			$self->add_vector_values($base, $vkey, $self->vector_value($cargo), "#hash_entry", $name, $key, $cargo);
			$keysUsed++;
		}
		$self->{'statements'} += $keysUsed;
		return $keysUsed;
	} elsif (ref $o eq 'ARRAY') {
		return unless @$o;
		if (1==scalar @$o) {
			# flattening uninformative extra structure layer
			if (ref $o->[0]) {
				return $self->recurseStructure($o->[0], $name, $base);
			} else {
				return $o->[0];
			}
		}
		if ($self->{'arrays_are_sets'}) {
			my $keysUsed;
			foreach my $key (0..$#$o) {
				my $cargo = $o->[$key];
				my $vkey = $self->vector_value(0); # all positions in array get the same key -> a set
				if (ref $cargo) {
					$cargo = $self->recurseStructure($cargo, $key, $vkey);
				} elsif (!$cargo && $skip_nulls) {
					next;
				}
				$self->add_vector_values($base, $vkey, $self->vector_value($cargo), "#set_entry", $name, $key, $cargo);
				$keysUsed++;
			}
			$self->{'statements'} += $keysUsed;
			return $keysUsed;
		} else {
			foreach my $i (0..$#$o) {
				$o->[$i] = $self->recurseStructure($o->[$i], $i, $self->vector_value($i)) if ref $o->[$i];
			}
			# add link to first element in array
			$self->add_vector_values($base, $self->vector_value(0), $self->vector_value($o->[0]), "#array_start", $name, 0, $o->[0]);
			# add links between subsequent pairs of elements in array
			foreach my $i (1..$#$o) {
				$self->add_vector_values($base, $self->vector_value($o->[$i-1]), $self->vector_value($o->[$i]), "#array_pair", $name, $o->[$i-1], $o->[$i]);
			}
			# add link from last element in array
			$self->add_vector_values($base, $self->vector_value($o->[$#$o]), $self->vector_value(scalar @$o), "#array_end", $name, $o->[$#$o], scalar @$o);
			$self->{'statements'} += 1+scalar @$o;
			return scalar @$o;
		}
	} else {
		return $o;
	}
}

sub add_vector_values_average {
	my($self, $v1, $v2, $v3, @stuff) = @_;
	my $Ls = $self->{'_L'};
	my $fp = $self->{'fp'};
	
	print join("\t", "#triple", @stuff), "\n" if $self->{'debug'};
	# adds the three vectors to the fingerprint, rotating v2 by 1 and v3 by 2, both to the left
	### this method yields identical fingerprints when swapping internal items in an ordered array,
	### e.g., a,b,c,d and a,c,b,d end up being identical
	### replaced with value+cos method
	foreach my $L (@$Ls) {
		foreach my $i (0..$L-1) {
			my $v = ($v1->{$L}[$i] + $v2->{$L}[($i+1) % $L] + $v3->{$L}[($i+2) % $L])/3;
			$fp->{$L}[$i] += $v;
		}
	}
	
	if ($self->{'debug'}>2) {
		print join("\t", "#result:", map({sprintf("%.3f", $_)} @{$fp->{$Ls->[0]}})), "\n";
	}
	
}

sub add_vector_values {
	my($self, $v1, $v2, $v3, @stuff) = @_;
	my $Ls = $self->{'_L'};
	my $fp = $self->{'fp'};
	
	print join("\t", "#triple", @stuff), "\n" if $self->{'debug'};
	# combines the three vectors in a triple, and adds the result to the fingerprint
	my($x, $y, $z, $xx, $yy, $zz, $v1l, $v2l, $v3l);
	foreach my $L (@$Ls) {
		my @tmp;
		$v1l = $v1->{$L};
		$v2l = $v2->{$L};
		$v3l = $v3->{$L};
		foreach my $i (0..$L-1) {
			$x = $v1l->[$i];
			$y = $v2l->[$i];
			$z = $v3l->[$i];
			$xx = 1+abs($x * cos(  $x));
			$yy = 1+abs($y * cos(2*$y));
			$zz = 1+abs($z * cos(3*$z));
			$tmp[$i] = ($xx*$yy*$zz)**(1/3) - 1;
		}
		
		#stretch the value and scale to a total of 1
		my($min, $total);
		foreach (@tmp) {
			$min = $_ || 0 if $min>$_ || !defined $min;
			last if $min==0;
		}
		if ($min) { $_ -= $min foreach @tmp }
		$total += $_ foreach @tmp;
		@tmp = map {$_/$total} @tmp if $total;
		$fp->{$L}[$_] += $tmp[$_] foreach (0..$L-1);
	}
	
	if ($self->{'debug'}>2) {
		print join("\t", "#result:", map({sprintf("%.3f", $_)} @{$fp->{$Ls->[0]}})), "\n";
	}
	
}

sub vector_value { #computes the value of the first argument in vector form
	my($self, $o) = @_;
	my $cache = $self->{'cache'};
	if ($self->{'usecache'} && defined $cache->{$o}) {
		#$cacheCount{$o}++; ### could be used to selectively clean the cache as needed
		print "#cached: $o\n" if $self->{'debug'}>3;
		return $cache->{$o};
	}
	my $null = $self->{'null'};
	$null = $self->setLs() unless defined $null;
	my $Ls = $self->{'_L'};
	my $new;
	@{$new->{$_}} = split /,/, $null->{$_} foreach @$Ls;

	print "#computing vector_value($o)\n" if $self->{'debug'}>2;
	
	my $data_type;
	if (looks_like_number($o) && $o !~ /^nan$/i) {
		$data_type = 'number';
		my $encoding = $self->{'numeric_encoding'};
		if (!$o) {
			#just keep the null value
		} elsif ($encoding eq 'ME') { # Mantissa/Exponent
			$_ = sprintf("%e", $o);
			my($mantissa, $exponent) = /(\-?[\d\.]+)e([\+\-]\d+)/;
			$mantissa /= 10;
			my $exp_w = $self->{'exponent_weight'};
			my $man_w = 1-$exp_w;
			foreach my $L (@$Ls) {
				#encode the mantissa - a fraction, range (-1..1)
				$mantissa *= $L;
				if (my $over = abs($mantissa - int($mantissa))) {
					$new->{$L}[$mantissa % $L] += $man_w*(1-$over);
					$new->{$L}[($mantissa+($mantissa>0 ? 1 : -1)) % $L] += $man_w*$over;
				} else {
					$new->{$L}[$mantissa % $L] += $man_w;
				}
				#encode the exponent - an integer, which can be negative
				$new->{$L}[$exponent % $L] += $exp_w;
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
		my $encoding = $self->{'string_encoding'};
		my @chars = split //, $o;
		my @ords = map(ord, @chars);
		#$self->{'hist'}[$_]++ foreach @ords;
		
		if ($encoding eq 'pair_sum') {
			$new->{$_}[$ords[0] % $_]++ foreach @$Ls;
			foreach my $i (1..$#chars) {
				my $v = $ords[$i] + $ords[$i-1];
				$new->{$_}[$v % $_]++ foreach @$Ls;
			}
		} elsif ($encoding eq 'decay') {
			my $decay = $self->{'string_encoding_decay'} || 0.1;
			my $remain = 1-$decay;
			$new->{$_}[$ords[0] % $_]++ foreach @$Ls;
			my $v = $ords[0];
			foreach my $i (1..$#chars) {
				$v = $v*$remain + $ords[$i]*$decay;
				print join("\t", "#decay", $o, $i, $ords[$i], $v), "\n" if $self->{'debug'}>5;
				foreach my $L (@$Ls) {
					my $sv = $v*$L/10;
					my $over = $sv - int($sv);
					$new->{$L}[$sv % $L] += 1-$over;
					$new->{$L}[($sv+1) % $L] += $over if $over;
				}
			}
		}
	}
	
	print join("\t", "#prelim:", map({sprintf("%.3f", $_)} @{$new->{$Ls->[0]}}), "sum:", $self->sum($new->{$Ls->[0]})), "\n" if $self->{'debug'}>2;
	
	#stretch the value and scale to a total of 1
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

	print join("\t", "#final.:", map({sprintf("%.3f", $_)} @{$new->{$Ls->[0]}}), "sum:", $self->sum($new->{$Ls->[0]})), "\n" if $self->{'debug'}>2;

	$cache->{$o} = $new if $self->{'usecache'} && $data_type ne 'number';
	return $new;
}

sub clear_cache {
	my($self) = @_;
	
	print "#clear_cache()\n" if $self->{'debug'};
	$self->{'cache'} = {};
}


sub normalize {
	my($self) = @_;
	print "#normalize()\n" if $self->{'debug'};
	my $Ls = $self->{'_L'};
	my $fp = $self->{'fp'};
	my $null = $self->{'null'};
	my $norm;
	@{$norm->{$_}} = split /,/, $null->{$_} foreach @$Ls;
	foreach my $L (@$Ls) {
		my($avg, $std) = $self->avgstd($fp->{$L});
		foreach (0..$L-1) { $norm->{$L}[$_] = ($fp->{$L}[$_]-$avg)/$std }
	}
	
	#print join("\t", "#normal:", map({sprintf("%.3f", $_)} @{$norm->{$Ls->[0]}}), "sum:", $self->sum($norm->{$Ls->[0]})), "\n" if $self->{'debug'}>2;

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

sub sum {
	my($self, $values) = @_;
	
	my $total;
	$total += $_ foreach @$values;
	return $total;
}



1;

