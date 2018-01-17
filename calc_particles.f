	program calc_particles

	implicit none

!$    integer OMP_GET_THREAD_NUM
!$    external OMP_GET_THREAD_NUM

c Setup variables
	integer n_source, n_test, dt
	real, dimension(:), allocatable :: x, y, z, vx, vy, vz, fx, fy, fz
	real, dimension(:), allocatable :: m, type
	character(len=128) :: tmp, conf_path
	real, parameter :: sp = 10E-11
	integer, parameter :: threads = 4
	integer :: tid, j, i, batch_size
	integer :: test_point_start, test_point_end

c Read in args
	call getarg(1, tmp)
	conf_path = "config/params." // tmp // ".dat"
	print *, conf_path

c Read in initial parameters
	open(unit = 1, file = conf_path)
	read(1, *) n_source
	read(1, *) dt
	read(1, *) test_point_start, test_point_end
	close(1)

	n_test = test_point_end - test_point_start
	batch_size = n_test / threads + 1

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

c Calculate force/location/velocity in parallel
!$OMP PARALLEL PRIVATE(tid) SHARED(x,y,z,vx,vy,vz,fx,fy,fz) NUM_THREADS(threads)
c 	Get thread ID
	tid = omp_get_thread_num()
	print *, tid
	print *, tid * batch_size + 1, (tid + 1) * batch_size

c 	For each test particle i
	do i = tid * batch_size + 1, (tid + 1) * batch_size
c 		Set force components to 0
		fx(i) = 0
		fy(i) = 0
		fz(i) = 0

		do j = 1, n_source

		if(i /= j) then
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
!$OMP END PARALLEL

c Write to output
	open(unit = 1, file = "output/source_points.dat")
	do i = test_point_start, test_point_end
		write(1, *) x(i), y(i), z(i), vx(i), vy(i), vz(i), fx(i), fy(i), fz(i), m(i)
	end do
	close(1)

	end program