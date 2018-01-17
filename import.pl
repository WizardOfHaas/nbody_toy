#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;
use Parallel::ForkManager;

#Connect to database
my $client = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
my $db = $client->get_database('nbody');
my $col = $db->get_collection('data');
$col->delete_many({});

my $forks = 4;
my $pm = new Parallel::ForkManager($forks);

foreach my $file(glob("output/source_points.*.dat")){
	my $pid = $pm->start and next;
	$client->reconnect;

	my ($t) = $file =~ m/points\.([0-9]*)\.dat/; #Parse out timestamp

	print $t."\n";

	#Parse file
	if($t){
		open my $fh, "<", $file;
		my @particles;

		while(<$fh>){
			my @f = split(/\s+/, $_);
			shift(@f);

			push(@particles, {
				location => [0+ $f[0], 0+ $f[1], 0+ $f[2]],
				force => [0+ $f[3], 0+ $f[4], 0+ $f[5]],
				velocity => [0+ $f[6], 0+ $f[7], 0+ $f[8]],
				type => "DM",
				t => 0+ $t,
				mass => 0+ $f[9]
			});
		}

		$col->insert_many(\@particles);
	}

	$pm->finish;
}