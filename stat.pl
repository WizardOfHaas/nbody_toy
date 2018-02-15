#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;
use List::Util qw(sum);

my @ts;
my @std_r;
my @std_v;
my @ave_r;
my @ave_v;

foreach my $file(sort {$a cmp $b} glob("output/source_points.dat.*")){
	open my $fh, "<", $file;
	my @particles;

	my ($t) = $file =~ m/points\.dat\.([0-9]*)/; #Parse out timestamp

	while(<$fh>){
		my @f = split(/\s+/, $_);
		shift(@f);

		push(@particles, {
			location => [0+ $f[0], 0+ $f[1], 0+ $f[2]],
			velocity => [0+ $f[3], 0+ $f[4], 0+ $f[5]],
			type => "DM",
			t => 0+ $t,
			mass => 0+ $f[6]
		});
	}	

	my @vs;
	my @rs;
	my (@xs, @ys, @zs);

	foreach my $p(@particles){
		my $r = sqrt(
			$p->{location}->[0]**2 +
			$p->{location}->[1]**2 +
			$p->{location}->[2]**2
		);

		my $v = sqrt(
			$p->{velocity}->[0]**2 +
			$p->{velocity}->[1]**2 +
			$p->{velocity}->[2]**2
		);

		push(@rs, $r);	
		push(@vs, $v);

		push(@xs, $p->{location}->[0]);
		push(@ys, $p->{location}-->[1]);
		push(@zs, $p->{location}-->[2]);
	}

	my $ave_v = sum(@vs) / scalar @vs;
	my $ave_r = sum(@rs) / scalar @rs;

	my $ave_x = sum(@xs) / scalar @xs;
	my $ave_y = sum(@ys) / scalar @ys;
	my $ave_z = sum(@zs) / scalar @zs;

	my $ave_sq_v = sum(map { $_**2 } @vs) / scalar @vs;
	my $ave_sq_r = sum(map { $_**2 } @rs) / scalar @rs;

	my $ave_sq_x = sum(map { $_**2 } @xs) / scalar @xs;
	my $ave_sq_y = sum(map { $_**2 } @ys) / scalar @ys;
	my $ave_sq_z = sum(map { $_**2 } @zs) / scalar @zs;

	my $v_std = sqrt($ave_sq_v - $ave_v**2);
	my $r_std = sqrt($ave_sq_r - $ave_r**2);

	my $x_std = sqrt($ave_sq_x - $ave_x**2);
	my $y_std = sqrt($ave_sq_y - $ave_y**2);
	my $z_std = sqrt($ave_sq_z - $ave_z**2);

	print join(",", (
		$t,
		$ave_v,
		$v_std,
		$ave_r,
		$r_std,
		$ave_x,
		$x_std,
		$ave_y,
		$y_std,
		$ave_z,
		$z_std
	))."\n";

	push(@ts, $t);
	push(@std_r, $r_std);
	push(@std_v, $v_std);
	push(@ave_r, $ave_r);
	push(@ave_v, $ave_v);
}

my $chart = Chart::Gnuplot->new(
	output => "std_r.ps"
);

my $data = Chart::Gnuplot::DataSet->new(
	xdata => \@ts,
	ydata => \@std_r
);

$chart->plot2d($data);
