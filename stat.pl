#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;
use List::Util qw(sum);

#Pull from database
my $client = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
my $db = $client->get_database('nbody');
my $col = $db->get_collection('data');

my $ret = $col->distinct("t");

my @ts;
my @std_r;
my @std_v;
my @ave_r;
my @ave_v;

foreach my $t(sort {$b <=> $a} @{$ret->{_docs}}){
	my $d = $col->find({t => $t});

	my @vs;
	my @rs;

	while(my $p = $d->next){
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
	}

	my $ave_v = sum(@vs) / scalar @vs;
	my $ave_r = sum(@rs) / scalar @rs;

	my $ave_sq_v = sum(map { $_**2 } @vs) / scalar @vs;
	my $ave_sq_r = sum(map { $_**2 } @rs) / scalar @rs;

	my $v_std = sqrt($ave_sq_v - $ave_v**2);
	my $r_std = sqrt($ave_sq_r - $ave_r**2);

	print join("\t", (
		$t,
		$ave_v,
		$v_std,
		$ave_r,
		$r_std
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
