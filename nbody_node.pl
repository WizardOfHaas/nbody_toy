#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;

#################################Parameter Set
#Constants
my $G = 1;

#N Body parameter set
my $particle_types = {
	"DM" => {
		mass => 1, #Free parameter
		density => 1 #Free parameter
	},
	"baryon" => {
		mass => 1, #Set to neutron or quark mass
		density => 1 #'' '' '' '' '' density
	}
};

#Initilization parameters
my $field_size = 100;
my $num_density = 0.0001;
my $num_particles = $num_density * ($field_size**3);

my $fract_composition = {
	"DM" => 0.95,
	"baryon" => 0.05
};

#Field friction/ram pressure params
my $field_density = 0.1;
my $friction_coef = 0.1;

#Time parameters
my $dt = 1;
my $t = 0;
#################################Parameter Set

my @particles;

#Pull from database
my $client = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
my $db = $client->get_database('nbody');
my $col = $db->get_collection('data');
my $ret = $col->find(); #Find All Particles

while(my $p = $ret->next){ #Push to array, for easy use later
	push(@particles, $p);
}

#Run timestep
#Get forces
@particles = @{calc_forces(\@particles)};
#Get velocity and locations

# v(t) = F * (t - t0) / m + v0
# x(t) = F * (t - t0)^2 / (2 * m) + t * v0 - t0 * v0 + x0

print Dumper @particles;

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

#Get sign of number
sub sign{
	return 1 if $_[0] >= 0;
	return -1;
}

#Calculate distance between two particle objects
sub distance{
	my ($a, $b) = @_;

	return [
		$a->{location}->[0] - $b->{location}->[0],
		$a->{location}->[1] - $b->{location}->[1],
		$a->{location}->[2] - $b->{location}->[2]
	];
}

#Calculate force between two particle objects
sub force{
	my ($a, $b) = @_;

	my $r = distance($a, $b);
	my @f = (0, 0, 0);

	$f[0] = ($G * $a->{mass} * $b->{mass}) / $r->[0]**2 * sign($r->[0]) if $r->[0] > 0;
	$f[1] = ($G * $a->{mass} * $b->{mass}) / $r->[1]**2 * sign($r->[1]) if $r->[1] > 0;
	$f[2] = ($G * $a->{mass} * $b->{mass}) / $r->[2]**2 * sign($r->[2]) if $r->[2] > 0;

	return \@f;
}

#Calculate force between each particle pair
sub calc_forces{
	my @particls = @{$_[0]};
	my @ret = @particles;

	for(my $i = 0; $i < scalar @particles; $i++){
		for(my $j = 0; $j < scalar @particles; $j++){
			if($j != $i){
				my $f = force($particles[$i], $particles[$j]);
				$ret[$i]->{force}->[0] += $f->[0];
				$ret[$i]->{force}->[1] += $f->[1];
				$ret[$i]->{force}->[2] += $f->[2];
			}
		}

		#Calculate v and x
		# v(t) = F * (t - t0) / m + v0
		# x(t) = F * (t - t0)^2 / (2 * m) + (t - t0) * v0 + x0

		#Get next time
		my $now = $t + $dt;
		$ret[$i]->{t} = $now;

		#Do velocity
		$ret[$i]->{velocity}->[0] = $ret[$i]->{force}->[0] * ($dt) / $ret[$i]->{mass} + $ret[$i]->{velocity}->[0];
		$ret[$i]->{velocity}->[1] = $ret[$i]->{force}->[1] * ($dt) / $ret[$i]->{mass} + $ret[$i]->{velocity}->[1];
		$ret[$i]->{velocity}->[2] = $ret[$i]->{force}->[2] * ($dt) / $ret[$i]->{mass} + $ret[$i]->{velocity}->[2];

		#Do location
		$ret[$i]->{location}->[0] = $ret[$i]->{force}->[0] * ($dt)**2 / (2 * $ret[$i]->{mass}) + $dt * $ret[$i]->{velocity}->[0] + $ret[$i]->{location}->[0];
		$ret[$i]->{location}->[1] = $ret[$i]->{force}->[1] * ($dt)**2 / (2 * $ret[$i]->{mass}) + $dt * $ret[$i]->{velocity}->[1] + $ret[$i]->{location}->[1];
		$ret[$i]->{location}->[2] = $ret[$i]->{force}->[2] * ($dt)**2 / (2 * $ret[$i]->{mass}) + $dt * $ret[$i]->{velocity}->[2] + $ret[$i]->{location}->[2];
	}

	return \@ret;
}