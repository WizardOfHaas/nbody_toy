#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;
use Parallel::ForkManager;

#################################Parameter Set
#Constants
my $G = 6.6*10**-11;
my $sp = 1*10**-1;

#N Body parameter set
my $particle_types = {
	"DM" => {
		mass => 1, #Free parameter
		density => 10 #Free parameter
	},
	"baryon" => {
		mass => 1, #Set to neutron or quark mass
		density => 1 #'' '' '' '' '' density
	}
};

#Initilization parameters
my $field_size = 1000000;
my $num_density = 2;
my $num_particles = $num_density * ($field_size**3);

my $fract_composition = {
	"DM" => 0.95,
	"baryon" => 0.05
};

#Field friction/ram pressure params
my $field_density = 10;
my $friction_coef = 0.1;

#Time parameters
my $dt = 60*60;
my $t = 0;
#################################Parameter Set

#Pull from database
my $client = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
my $db = $client->get_database('nbody');
my $col = $db->get_collection('data');

#Get plot limits
my $r = 100 + 0.1;
my @range = (-$r, $r);

my @x_range = (
	$col->find({}, {location => 1})->sort({'location.0' => -1})->limit(1)->next->{location}->[0],
	$col->find({}, {location => 1})->sort({'location.0' => 1})->limit(1)->next->{location}->[0]
);

my @y_range = (
	$col->find({}, {location => 1})->sort({'location.1' => -1})->limit(1)->next->{location}->[1],
	$col->find({}, {location => 1})->sort({'location.1' => 1})->limit(1)->next->{location}->[1]
);

my @z_range = (
	$col->find({}, {location => 1})->sort({'location.2' => -1})->limit(1)->next->{location}->[2],
	$col->find({}, {location => 1})->sort({'location.2' => 1})->limit(1)->next->{location}->[2]
);

#@x_range = @range; @y_range = @range; @z_range = @range;

my $ret = $col->distinct("t");

my $forks = 4;
my $pm = new Parallel::ForkManager($forks);

`rm -rf plots/*`;

foreach my $t(@{$ret->{_docs}}){
	my $pid = $pm->start and next;
	$client->reconnect;
	
	print "t = $t\n";

	my $t_clean = sprintf "%020d", $t;

	my $chart = Chart::Gnuplot->new(
		title => "t = $t_clean",
		output => "plots/field.$t_clean.ps",
		xrange => \@x_range,
		yrange => \@y_range,
		zrange => \@z_range,
		bg => {
        	color   => "#FFFFFF",
        	density => 0.3,
    	}
	);

	#Read in all particle data from db
	my @plots;
	foreach my $type(("DM", "baryon")){
		my $ret = $col->find({t => $t, type => $type});
	
		my @particles;
	
		while(my $p = $ret->next){ #Push to array, for easy use later
			delete $p->{_id};
			push(@particles, $p);
		}
	
		my @x = map { $_->{location}->[0] } @particles;
		my @y = map { $_->{location}->[1] } @particles;
		my @z = map { $_->{location}->[2] } @particles;	
	
		push(@plots, Chart::Gnuplot::DataSet->new(
	    	xdata => \@x,
	    	ydata => \@y,
	    	zdata => \@z,
	    	style => 'points'
		));
	}

	$chart->plot3d(@plots);

	$pm->finish;
}