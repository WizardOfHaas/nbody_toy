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
		mass => 10, #Set to neutron or quark mass
		density => 1 #'' '' '' '' '' density
	}
};

#Initilization parameters
my $field_size = 10000;
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
my $dt = 2*24*60*60;
my $t = 0;
#################################Parameter Set

my @particles;

#Pull from database
my $client = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
my $db = $client->get_database('nbody');
my $col = $db->get_collection('data');
my $ret = $col->find({t => 0}); #Find All Particles
$col->delete_many({t => {'$ne' => 0}});

while(my $p = $ret->next){ #Push to array, for easy use later
	delete $p->{_id};
	push(@particles, $p);
}

print "Initial Energy: ".initila_energy(\@particles)."\n";

#Make batches of test particles
my $forks = 4; #Number of forks == number of batches
my @batches; #Empty, or so you think!

open my $out, ">", "config/source_points.dat";

for(my $i = 0; $i < scalar @particles; $i++){
	$batches[$i % $forks] = [] unless $batches[$i % $forks];
	push(@{$batches[$i % $forks]}, $particles[$i]);
	my $p = $particles[$i];
	print $out
		$p->{location}->[0]."\t".
		$p->{location}->[1]."\t".
		$p->{location}->[2]."\t".
		$p->{velocity}->[0]."\t".
		$p->{velocity}->[1]."\t".
		$p->{velocity}->[2]."\t".
		$p->{force}->[0]."\t".
		$p->{force}->[1]."\t".
		$p->{force}->[2]."\t".
		$p->{mass}."\n";
}

close($out); #die;

my $pm = new Parallel::ForkManager($forks);

#while($t < 10000000){
while(1){
	#print "t = $t\n";
	print $t."\t".initila_energy(\@particles)."\n";

	$t += $dt;

	#Run timestep
	#@particles = @{calc_forces(\@particles)};
	#$col->insert_many(\@particles); #Push back to DB for later use

	foreach my $batch(@batches){ #For each batch
		my $pid = $pm->start and next; #We are in fork land now, suckaaa
		$client->reconnect; #Gotta do it to use the db in fork land, suckaa

		foreach my $p(@{$batch}){
			$p = step_particle($p->{id}, \@particles);
			$col->insert_one($p);
		}

		$pm->finish; #...no we are not in fork land
	}

	$pm->wait_all_children; #Make sure no one else is in fork land

	#Read in all particle data from db
	my $ret = $col->find({t => $t});

	while(my $p = $ret->next){ #Push to array, for easy use later
		delete $p->{_id};
		$particles[$p->{id}] = $p;
	}

	####Sanity Check, make a plot
	my $t_clean = sprintf "%010f", $t;

	#my $chart = Chart::Gnuplot->new(
	#	title => "t = $t_clean",
	#	output => "plots/field.$t_clean.ps",
	#	xrange => [-$field_size / 2, $field_size / 2],
	#	yrange => [-$field_size / 2, $field_size / 2],
	#	zrange => [-$field_size / 2, $field_size / 2],
	#	bg => {
    #    	color   => "#FFFFFF",
    #    	density => 0.3,
    #	}
	#);	

	#my @x = map { $_->{location}->[0] } @particles;
	#my @y = map { $_->{location}->[1] } @particles;
	#my @z = map { $_->{location}->[2] } @particles;	

	#my $data = Chart::Gnuplot::DataSet->new(
	#    xdata => \@x,
	#    ydata => \@y,
	#    zdata => \@z,
	#    style => 'points'
	#);

	#$chart->plot3d($data);
}

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

	$f[0] = ($G * $a->{mass} * $b->{mass}) / ($r->[0] + $sp)**2 * (sign($r->[0])) if $r->[0] != 0;
	$f[1] = ($G * $a->{mass} * $b->{mass}) / ($r->[1] + $sp)**2 * (sign($r->[1])) if $r->[1] != 0;
	$f[2] = ($G * $a->{mass} * $b->{mass}) / ($r->[2] + $sp)**2 * (sign($r->[2])) if $r->[2] != 0;

	return \@f;
}

sub initila_energy{
	my @particls = @{$_[0]};	
	my $E0 = 0;

	for(my $i = 0; $i < scalar @particles; $i++){
		for(my $j = 0; $j < scalar @particles; $j++){
			if($j != $i){
				my $p1 = $particles[$i];
				my $p2 = $particles[$j];

				my $v1 = sqrt($p1->{velocity}->[0]**2 + $p1->{velocity}->[0]**2 + $p1->{velocity}->[0]**2);
				my $cr = sqrt(($p1->{location}->[0] - $p2->{location}->[0])**2 + ($p1->{location}->[1] - $p2->{location}->[1])**2 + ($p1->{location}->[2] - $p2->{location}->[2])**2);
				my $r = sqrt($p1->{location}->[0]**2 + $p1->{location}->[1]**2 + $p1->{location}->[2]**2);
				my $mu = ($p1->{mass} * $p2->{mass}) / ($p1->{mass} + $p2->{mass});

				#$E0 += ($v1**2 * $p1->{mass} * eta($p1, $p2)) / 2 - ($G * $p1->{mass} * $p2->{mass}) / $cr;
				$E0 += $p1->{mass} * ($v1**2 / 2 + ($r**2 * ($p1->{mass} + $p2->{mass}) * $v1**2) / (2 * $mu * $cr**2 * $p2->{mass}) - ($G * $p2->{mass}) / $cr);
			}
		}
	}

	return $E0;
}

sub eta{
	my ($p1, $p2) = @_;

	return (1 + ($p1->{mass} + $p2->{mass}) / $p2->{mass});
}

sub xi{
	my ($p1, $p2) = @_;
	my @r = (0, 0, 0);

	for(my $i = 0; $i < 3; $i++){
		$r[$i] = $G * $p1->{mass} * $dt / 2 * ($p1->{location}->[$i] - $p2->{location}->[$i])**2 + $p2->{velocity}->[$i] * $dt + $p2->{location}->[$i];
	}

	return @r;
}

#Calculate new data for one particle from all other particles
sub step_particle{
	my $i = $_[0];
	my @particles = @{$_[1]};

	my $p = $particles[$i];

	$p->{force}->[0] = 0;
	$p->{force}->[1] = 0;
	$p->{force}->[2] = 0;

	my $n = scalar @particles - 1;

	for(my $j = 0; $j < scalar @particles; $j++){
		if($i != $j){
			my $f = force($particles[$i], $particles[$j]);
			$p->{force}->[0] += $f->[0];
			$p->{force}->[1] += $f->[1];
			$p->{force}->[2] += $f->[2];
		}

		my $now = $t + $dt;
		$p->{t} = $now;

		#Do location
		$p->{location}->[0] = $p->{force}->[0] * ($dt)**2 / (2 * $p->{mass}) + $dt * $p->{velocity}->[0] + $p->{location}->[0];
		$p->{location}->[1] = $p->{force}->[1] * ($dt)**2 / (2 * $p->{mass}) + $dt * $p->{velocity}->[1] + $p->{location}->[1];
		$p->{location}->[2] = $p->{force}->[2] * ($dt)**2 / (2 * $p->{mass}) + $dt * $p->{velocity}->[2] + $p->{location}->[2];

		#Do velocity
		$p->{velocity}->[0] = $p->{force}->[0] * ($dt) / $p->{mass} + $p->{velocity}->[0];
		$p->{velocity}->[1] = $p->{force}->[1] * ($dt) / $p->{mass} + $p->{velocity}->[1];
		$p->{velocity}->[2] = $p->{force}->[2] * ($dt) / $p->{mass} + $p->{velocity}->[2];
	}

	return $p;
}

#Calculate force between each particle pair
sub calc_forces{
	my @particls = @{$_[0]};
	my @ret = @particles;

	my $n = scalar @particles - 1;

	for(my $i = 0; $i < scalar @particles; $i++){
		my @xi = [0, 0, 0];
		my $mo = 0;

		for(my $j = 0; $j < scalar @particles; $j++){
			if($j != $i){
				my $f = force($particles[$i], $particles[$j]);
				$ret[$i]->{force}->[0] += $f->[0];
				$ret[$i]->{force}->[1] += $f->[1];
				$ret[$i]->{force}->[2] += $f->[2];

				$xi[0] += $ret[$j]->{location}->[0];
				$xi[1] += $ret[$j]->{location}->[1];
				$xi[2] += $ret[$j]->{location}->[2];

				$mo += $ret[$j]->{mass};
			}
		}

		#Do drag if baryon
		#if($ret[$i]->{type} ne "DM"){
		#	$ret[$i]->{force}->[0] += $field_density * $ret[$i]->{velocity}->[0]**2 * (- sign($ret[$i]->{velocity}->[0]));
		#	$ret[$i]->{force}->[1] += $field_density * $ret[$i]->{velocity}->[1]**2 * (- sign($ret[$i]->{velocity}->[1]));
		#	$ret[$i]->{force}->[2] += $field_density * $ret[$i]->{velocity}->[2]**2 * (- sign($ret[$i]->{velocity}->[2]));
		#}

		#Calculate v and x
		# v(t) = F * (t - t0) / m + v0
		# x(t) = F * (t - t0)^2 / (2 * m) + (t - t0) * v0 + x0

		#Get next time
		my $now = $t + $dt;
		$ret[$i]->{t} = $now;

		#Do location
		$ret[$i]->{location}->[0] = $ret[$i]->{force}->[0] * ($dt)**2 / (2 * $ret[$i]->{mass}) + $dt * $ret[$i]->{velocity}->[0] + $ret[$i]->{location}->[0];
		$ret[$i]->{location}->[1] = $ret[$i]->{force}->[1] * ($dt)**2 / (2 * $ret[$i]->{mass}) + $dt * $ret[$i]->{velocity}->[1] + $ret[$i]->{location}->[1];
		$ret[$i]->{location}->[2] = $ret[$i]->{force}->[2] * ($dt)**2 / (2 * $ret[$i]->{mass}) + $dt * $ret[$i]->{velocity}->[2] + $ret[$i]->{location}->[2];

		#Using combined energy + kinematic solution
		#for(my $x = 0; $x <= 2; $x++){
		#	if($n * $ret[$i]->{location}->[$x] != $xi[$x]){
		#		$ret[$i]->{location}->[$x] = 1 / $n * (($ret[$i]->{force}->[$x] * $dt / (2 * $G * $ret[$i]->{mass} * $mo) + 1 / ($n * $ret[$i]->{location}->[$x] - $xi[$x]))**-1 + $xi[$x]);
		#	}else{
		#		$ret[$i]->{location}->[$x] = $xi[$x] / $n;
		#	}
		#}

		#Do velocity
		$ret[$i]->{velocity}->[0] = $ret[$i]->{force}->[0] * ($dt) / $ret[$i]->{mass} + $ret[$i]->{velocity}->[0];
		$ret[$i]->{velocity}->[1] = $ret[$i]->{force}->[1] * ($dt) / $ret[$i]->{mass} + $ret[$i]->{velocity}->[1];
		$ret[$i]->{velocity}->[2] = $ret[$i]->{force}->[2] * ($dt) / $ret[$i]->{mass} + $ret[$i]->{velocity}->[2];
	}

	return \@ret;
}