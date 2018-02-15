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

my $forks = 2;
my $pm = new Parallel::ForkManager($forks);

my @ts;
foreach my $file(glob("output/source_points.dat.*")){
	my ($t) = $file =~ m/points\.dat\.([0-9]*)/;
	my $mod = (0+ $t) % (60 * 60);

	if($mod == 0){
		push(@ts, $t);
	}
}

foreach my $t(@ts){
	my $pid = $pm->start and next;
	$client->reconnect;

	print $t."\n";	

	#Parse file
	if($t){
		open my $fh, "<", "output/source_points.dat.$t";
		my @particles;	

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

		$col->insert_many(\@particles);
	}

	$pm->finish;
}