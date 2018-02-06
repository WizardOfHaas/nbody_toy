#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use MongoDB;
use Chart::Gnuplot;
use JSON qw(decode_json);

#Read in config file
open my $fh, "<", $ARGV[0];
my $cfg = decode_json(join("\n", <$fh>));
close $fh;

#################################Parameter Set
#Constants
my $G = 1;
my $v0 = $cfg->{v0};
my $dt = $cfg->{dt};
my $sp = $cfg->{sp};

#N Body parameter set
my $particle_types = $cfg->{particle_types};

#Initilization parameters
my $field_size = $cfg->{field_size};
my $num_particles = $cfg->{num_particles};

my $num_density = $num_particles / $field_size**3;
print "Number Density: ".$num_density."\n";

my $fract_composition = $cfg->{fract_composition};

#Field friction/ram pressure params
my $field_density = 0.1;
my $friction_coef = 0.1;

#################################Parameter Set

my @particles;

init_particles(); #Get initial particle states

#Set some starting params
my $t = 0;
while(1){

	my $t_clean = sprintf("%010d", $t);
	print "t = ".$t_clean."\n";

	write_configs(); #Write out source particles

	my $node_conf_path = "config/params.dat";
	open my $node_conf, ">", $node_conf_path or die $!;

	print $node_conf $num_particles."\n";
	print $node_conf $dt."\n";
	print $node_conf "1\t$num_particles\n";
	print $node_conf $sp."\n";

	die;

	`./nbody_step n0.dat`;

	die;

	`cp output/source_points.dat config/source_points.dat`;
	`mv output/source_points.dat output/source_points.$t_clean.dat`;

	$t += $dt;
}

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

#Write out data for FORTRAN code
sub write_configs{
	#Write out source point data
	open my $out, ">", "config/source_points.dat";

	for(my $i = 0; $i < scalar @particles; $i++){
		my $p = $particles[$i];
		print $out
			$p->{location}->[0]."\t".
			$p->{location}->[1]."\t".
			$p->{location}->[2]."\t".
			$p->{velocity}->[0]."\t".
			$p->{velocity}->[1]."\t".
			$p->{velocity}->[2]."\t".
			$p->{mass}."\n";
	}

	close($out);
}