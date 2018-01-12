	program calc_particles

c Setup variables
	integer n_source, n_test, dt
	real, dimension(:), allocatable :: x, y, z, vx, vy, vz, fx, fy, fz
	real, dimension(:), allocatable :: m, type
	real, dimension(:), allocatable :: test_points
	character(len=32) :: test_file, tmp
	real, parameter :: sp = 10E-11

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

c Read in test points
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
c 	For each test particle i
	do i = 1, n_test
c 		Set force components to 0
		fx(i) = 0
		fy(i) = 0
		fz(i) = 0

		do j = 1, n_source

		if(test_points(i) /= j) then
c 			Calculate force cuased by some source particle j
			fx(i) = m(i) * m(j) / (x(i) - x(j) + sp)**2 * (x(i) - x(j))
			fy(i) = m(i) * m(j) / (y(i) - y(j) + sp)**2 * (y(i) - y(j))
			fz(i) = m(i) * m(j) / (z(i) - z(j) + sp)**2 * (z(i) - z(j))

c 			Calculate new location
			x(i) = fx(i) * (dt)**2 / (2 * m(i)) + dt * vx(i) + x(i)
			y(i) = fy(i) * (dt)**2 / (2 * m(i)) + dt * vy(i) + y(i)
			z(i) = fz(i) * (dt)**2 / (2 * m(i)) + dt * vz(i) + z(i)
c 			Calculate new velocity
			vx(i) = fx(i) * dt / m(i) + vx(i)
			vy(i) = fy(i) * dt / m(i) + vy(i)
			vz(i) = fz(i) * dt / m(i) + vz(i)
		end if

		end do
	end do

c Write to output
	open(unit = 1, file = "output/source_points.dat")
	do i = 1, n_source
		write(1, *) x(i), y(i), z(i), vx(i), vy(i), vz(i), fx(i), fy(i), fz(i), m(i)
	end do
	close(1)

	end