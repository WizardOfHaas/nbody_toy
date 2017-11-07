#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;

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
	"baryonic" => 0.05
};

#Field friction/ram pressure params
my $field_density = 0.1;
my $friction_coef = 0.1;

my @particles;

init_particles();
calc_forces();

print Dumper @particles;

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
	foreach my $type(keys %$fract_composition){
		print $type.": ".($num_particles * $fract_composition->{$type})."\n";

		for(my $i = 0; $i < $num_particles * $fract_composition->{$type}; $i++){
			my $x = rand($field_size / 2) - $field_size / 2;
			my $y = rand($field_size / 2) - $field_size / 2;
			my $z = rand($field_size / 2) - $field_size / 2;

			while(grep { [$x, $y, $z] == $_->{location} }  @particles){ #Must be unique location!
				my $x = rand($field_size / 2) - $field_size / 2;
    	 		my $y = rand($field_size / 2) - $field_size / 2;
     			my $z = rand($field_size / 2) - $field_size / 2;
			}

			my @location = ($x, $y, $z);

			push(@particles, {
				location => \@location,
				force => [0, 0, 0],
				velocity => [0, 0, 0],
				type => $type,
				t => 0,
				mass => 1
			});
		}
	}
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

	$f[0] = ($G * $a->{mass} * $b->{mass}) / $r->[0]**2 if $r->[0] > 0;
	$f[1] = ($G * $a->{mass} * $b->{mass}) / $r->[1]**2 if $r->[1] > 0;
	$f[2] = ($G * $a->{mass} * $b->{mass}) / $r->[2]**2 if $r->[2] > 0;

	return \@f;
}

sub calc_forces{
	for(my $i = 0; $i < scalar @particles; $i++){
		for(my $j = 0; $j < scalar @particles; $j++){
			if($j != $i){
				my $f = force($particles[$i], $particles[$j]);
				$particles[$i]->{force}->[0] += $f->[0];
				$particles[$i]->{force}->[1] += $f->[1];
				$particles[$i]->{force}->[2] += $f->[2];
			}
		}
	}
}