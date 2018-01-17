all:
	gfortran -ffixed-line-length-132 -fopenmp calc_particles.f -o nbody_step
