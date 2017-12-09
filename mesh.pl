#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;

my @ps;
my $mesh;
my $m = 1;
my $L = 5;
my $sp = 10**-11;
my $G = 6.6*10^-11;
my $N = 100;
my $field_r = 10;

for(my $n = 0; $n < $N; $n++){
	push(@ps,[
		rand($field_r) - rand($field_r),
		rand($field_r) - rand($field_r),
		rand($field_r) - rand($field_r)
	]);
}

foreach my $p(@ps){
	my ($x, $y, $z) = (
		round($p->[0] / $L) * $L,
		round($p->[1] / $L) * $L,
		round($p->[2] / $L) * $L
	);

	my $id = $x.",".$y.",".$z;

	$mesh->{$id} = 0 if !$mesh-{$id};
	$mesh->{$id} += $m;
}

foreach my $id(keys %$mesh){
	$mesh->{$id} = $G * $mesh->{$id};
}

#print Dumper $mesh; die;

my @coords = keys %$mesh;
foreach my $p(@ps){
	my @p1 = (
		round($p->[0] / $L) * $L,
		round($p->[1] / $L) * $L,
		round($p->[2] / $L) * $L
	);
	my $p_id = join(",", @p1);

	my @F = (0, 0, 0);
	foreach my $coord(@coords){
		if($coord ne $p_id){
			my @p2 = split(",", $coord);

			for(my $i = 0; $i < 3; $i++){
				$F[$i] += $m**2 * $mesh->{$coord} / ($p1[$i] - $p2[$i] + $sp)**2 * sign($p1[$i] - $p2[$i]);
			}
		}
	}

	print join(",", @F)."\n";
}

sub round{
	my $float = $_[0];
	return int($float + $float/abs($float*2 || 1));
}

sub sign{
	return -1 if $_[0] < 0;
	return 1;
}
