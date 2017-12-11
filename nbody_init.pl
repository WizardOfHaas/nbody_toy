#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;

#################################Parameter Set
#Constants
my $G = 1;
my $v0 = 5;

#N Body parameter set
my $particle_types = {
	"DM" => {
		mass => 1, #Free parameter
		density => 1 #Free parameter
	},
	"baryon" => {
		mass => 10, #Set to neutron or quark mass
		density => 1 #'' '' '' '' '' density
	}
};

#Initilization parameters
my $field_size = 10**15;
my $num_density = 2**10^-2;
#my $num_particles = $num_density * ($field_size**3);
my $num_particles = 100;

my $fract_composition = {
	"DM" => 0.95,
	"baryon" => 0.05
};

#Field friction/ram pressure params
my $field_density = 0.1;
my $friction_coef = 0.1;
#################################Parameter Set

my @particles;

init_particles(); #Get initial particle states

#Insert into database
my $client = MongoDB::MongoClient->new(
	host => 'localhost',
	port => 27017,
	connectTimeoutMS => 10**10,
	socketTimeoutMS => 10**10
);

my $db = $client->get_database('nbody');
my $col = $db->get_collection('data');
$col->delete_many({}); #Clear collection
$col->insert_many(\@particles); #Insert all particles

####Sanity Check, make a plot
my $chart = Chart::Gnuplot->new(
	output => "field.ps"
);

my @x = map { $_->{location}->[0] } @particles;
my @y = map { $_->{location}->[1] } @particles;
my @z = map { $_->{location}->[2] } @particles;

my $data = Chart::Gnuplot::DataSet->new(
    xdata => \@x,
    ydata => \@y,
    zdata => \@z,
    style => 'points'
);

$chart->plot3d($data);

#Init particle field
sub init_particles{
	#Do all particle types, one at a time
	my $id = 0;

	foreach my $type(keys %$fract_composition){
		print $type.": ".($num_particles * $fract_composition->{$type})."\n";

		for(my $i = 0; $i < $num_particles * $fract_composition->{$type}; $i++){ #For number of particles of given type
			#Get random location inside field
			my $x = rand($field_size) - $field_size / 2;
			my $y = rand($field_size) - $field_size / 2;
			my $z = rand($field_size) - $field_size / 2;

			while(grep { [$x, $y, $z] == $_->{location} }  @particles){ #Must be unique location!
				#Try again until unique
				my $x = rand($field_size) - $field_size / 2;
    	 		my $y = rand($field_size) - $field_size / 2;
     			my $z = rand($field_size) - $field_size / 2;
			}

			#Set initial v
			my @v = (
				rand($v0) - $v0 / 2,
				rand($v0) - $v0 / 2,
				rand($v0) - $v0 / 2
			);

			#@v = (0, 0, 0);

			my @location = ($x, $y, $z); #Compose location array

			#Push up to particles list
			push(@particles, {
				location => \@location,
				force => [0, 0, 0],
				velocity => \@v,
				type => $type,
				t => 0,
				mass => $particle_types->{$type}->{mass},
				id => $id
			});

			$id++; #Get unique id for each particle
		}
	}
}