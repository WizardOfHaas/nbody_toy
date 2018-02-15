	program calc_particles

	implicit none

!$    integer OMP_GET_THREAD_NUM
!$    external OMP_GET_THREAD_NUM

c Setup variables
	integer n_source, n_test, dt
	integer(kind=8) :: t
	real, dimension(:), allocatable :: x, y, z, vx, vy, vz, fx, fy, fz
	real, dimension(:), allocatable :: delta_e
	real, dimension(:), allocatable :: x_new, y_new, z_new
	real, dimension(:), allocatable :: m, type, energy
	character(len=128) :: tmp, conf_path
	integer, parameter :: threads = 1
	integer :: tid, j, i, batch_size, k
	integer :: test_point_start, test_point_end
	real :: sp, Cd, ri, rf

c Read in args
	call getarg(1, tmp)
	conf_path = "config/params.dat"
	print *, conf_path

	Cd = 0.01

c Read in initial parameters
	open(unit = 1, file = conf_path)
	read(1, *) n_source
	read(1, *) dt
	read(1, *) test_point_start, test_point_end
	read(1, *) sp
	close(1)

	n_test = test_point_end - test_point_start
	batch_size = n_test / threads + 1

c Deal with stupid fortran arrays
	allocate(x(n_source), y(n_source), z(n_source))
	allocate(x_new(n_source), y_new(n_source), z_new(n_source))
	allocate(vx(n_source), vy(n_source), vz(n_source))
	allocate(fx(n_source), fy(n_source), fz(n_source))
	allocate(m(n_source), type(n_source), energy(n_source))
	allocate(delta_e(n_source))

c Read in source points
	open(unit = 1, file = "config/source_points.dat")
	do i = 1, n_source
		read(1, *) x(i), y(i), z(i), vx(i), vy(i), vz(i), m(i), type(i), energy(i)
	end do
	close(1)

	t = 0

	do
c 	Calculate force/location/velocity in parallel
	
		print *, t / 3.15E7

!$OMP PARALLEL PRIVATE(tid) SHARED(x,y,z,x_new,y_new,z_new,vx,vy,vz,delta_e) NUM_THREADS(threads)
c 		Get thread ID
		tid = omp_get_thread_num()
c		print *, tid
c		print *, tid * batch_size + 1, (tid + 1) * batch_size	

c 		For each test particle i
		do i = tid * batch_size + 1, (tid + 1) * batch_size
c 			Calculate new location
			x_new(i) = dt * vx(i) + x(i)
			y_new(i) = dt * vy(i) + y(i)
			z_new(i) = dt * vz(i) + z(i)

c 			Calculate the Goon tensor for particle i
			vx(i) = 0
			vy(i) = 0
			vz(i) = 0

			do j = 1, n_source	

				if(i /= j) then
c 					Calculate velocity cuased by some source particle j
					vx(i) = sqrt(m(i) * 1 / abs((x(j) - x(i)))) * sign(1.0, x(j) - x(i)) + vx(i)
					vy(i) = sqrt(m(i) * 1 / abs((y(j) - y(i)))) * sign(1.0, y(j) - y(i)) + vy(i)
					vz(i) = sqrt(m(i) * 1 / abs((z(j) - z(i)))) * sign(1.0, z(j) - z(i)) + vz(i)
				end if

			end do

c 			Do some kind of drag if i is a baryon
			if(type(i) /= 1) then
				if(Cd * vx(i)**2 / m(i) > vx(i)) then
					vx(i) = 0
				else
					vx(i) = vx(i) - Cd * vx(i)**2 / m(i) * (sign(1.0, vx(i)))
				end if

				if(Cd * vy(i)**2 / m(i) > vy(i)) then
					vy(i) = 0
				else
					vy(i) = vy(i) - Cd * vy(i)**2 / m(i) * (sign(1.0, vy(i)))
				end if

				if(Cd * vz(i)**2 / m(i) > vz(i)) then
					vz(i) = 0
				else
					vz(i) = vz(i) - Cd * vz(i)**2 / m(i) * (sign(1.0, vz(i)))
				end if
			end if

		end do

		do i = tid * batch_size + 1, (tid + 1) * batch_size
c 			Calculate delta_e fron drag
			if(type(i) /= 1) then
				do j = 0, n_source
					if(i /= j) then
						ri = sqrt((x(i) - x(j))**2 + (y(i) - y(j))**2 + (z(i) - z(j))**2)
						rf = sqrt((x_new(i) - x(j))**2 + (y_new(i) - y(j))**2 + (z_new(i) - z(j))**2)

						delta_e(i) = m(j) * log(rf / ri)
					end if
				end do
			end if
			

			x(i) = x_new(i)
			y(i) = y_new(i)
			z(i) = z_new(i)
		end do
!$OMP END PARALLEL	

c 		Write to output
		write(tmp, '(A,I20.20)') "output/source_points.dat.", t 
		open(unit = 1, file = tmp)
		do i = test_point_start, test_point_end
			write(1, *) x(i), y(i), z(i), vx(i), vy(i), vz(i), m(i), delta_e(i)
		end do
		close(1)

	t = t + dt

	end do

	end program