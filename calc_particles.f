	program calc_particles

c Setup variables
	integer n_source, n_test, dt
	real, dimension(:), allocatable :: x, y, z, vx, vy, vz, fx, fy, fz
	real, dimension(:), allocatable :: m, type
	real, dimension(:), allocatable :: test_points
	character(len=32) :: test_file, tmp

c Read in initial parameters
	open(unit = 1, file = "config/params.dat")
	read(1, *) n_source
	read(1, *) dt
	close(1)

c Deal with stupid fortran arrays
	allocate(x(n_source), y(n_source), z(n_source))
	allocate(vx(n_source), vy(n_source), vz(n_source))
	allocate(fx(n_source), fy(n_source), fz(n_source))
	allocate(m(n_source), type(n_source))

c Read in source points
	open(unit = 1, file = "config/source_points.dat")
	do i = 1, n_source
		read(1, *) x(i), y(i), z(i), vx(i), vy(i), vz(i), fx(i), fy(i), fz(i), m(i)
	end do
	close(1)

c Read in testr points
	call getarg(1, test_file)
	call getarg(2, tmp)
	read(tmp, *) n_test
	allocate(test_points(n_test))

	open(unit = 1, file = test_file)
	do i = 1, n_test
		read(1, *) test_points(n_test)
	end do
	close(1)

c Calculate force/location/velocity

c Write to output

	end