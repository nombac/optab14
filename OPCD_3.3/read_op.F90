

! density grid: user defined
! temperature grid: original

#define DRHOMIN

program read_op

  implicit none

  character :: head*70
  integer :: iz(17)
  real(4) :: fa(17)
  integer :: i, ite, ite1, ite2, ite3
  integer :: j, jne, jne1, jne2, jne3, jj
  integer :: n, nel
  real(8), parameter :: rho_min = -22d0, rho_max = 0d0
  real(8) :: drho
  integer, parameter :: kmin = 1, kmax = 256
  real(8), parameter :: tmp_min = 0.5d0, tmp_max = 6.5d0
  real(8), parameter :: dtmp = 0.025d0
  integer, parameter :: jmin = 1
  integer :: jmax
  real(8), allocatable :: rho(:), tmp(:)
  integer :: k
  real(8), allocatable :: opa_pla(:,:), opa_ros(:,:)
  real(8), allocatable :: t(:)
  real(8), allocatable :: rho0(:), pla(:), ros(:)
  integer :: ic, jc, icmax, jcmax
#ifdef DRHOMIN
  real(8) :: drhomin, rhomin, rhomax
#endif
  real(8) :: rho_min0, rho_max0

  ! density array
  drho = (rho_max - rho_min) / (kmax - 1)
  allocate(rho(kmin:kmax))
  do k = kmin, kmax
     rho(k) = rho_min + drho * (k - 1)
  end do
  ! temperature array
  jmax = (tmp_max - tmp_min) / (dtmp*2d0) + 1
  print *, 'jmax=', jmax
  allocate(tmp(jmin:jmax))
  do j = jmin, jmax
     tmp(j) = tmp_min + (dtmp*2d0) * (j - 1)
  end do

  ! open an OP data
  open(55, file='mixv.gs98')

  ! headding (X, Z)
  read(55,70) head

  ! number of elements, indecies of temperature (min, max, skip)
  read(55,*) nel, ite1, ite2, ite3
  print *, ite1, ite2, ite3

  ! number of temperature grids
  icmax = 0
  do i = ite1, ite2, ite3
     icmax = icmax + 1
  end do

  ! temperature array
  allocate(t(icmax))

  ! opacity array
  allocate(opa_pla(jmin:jmax,kmin:kmax), opa_ros(jmin:jmax,kmin:kmax))
  opa_pla = -100d0!!TRANSFER(-1_8, 0d0)!log10(pla(1))
  opa_ros = -100d0!!TRANSFER(-1_8, 0d0)!log10(pla(1))
  ! 
  do n = 1, nel
     read(55,*) iz(n), fa(n)
  end do

  OPEN(88, FILE='border.data')
  WRITE(88,*) (ite2 - ite1)/ite3 + 1
  ic = 0
  ! loop on temperature (T=3.5~6)
  do i = ite1, ite2, ite3
     ic = ic + 1
     t(ic) = dtmp * i
     read(55,*) ite, jne1, jne2, jne3
     jcmax = 0
     do j = jne1, jne2, jne3
        jcmax = jcmax + 1
     end do
     allocate(rho0(jcmax), pla(jcmax), ros(jcmax))
     jc = 0
     ! loop on density
#ifdef DRHOMIN
     rhomin = huge(1d0)
     rhomax = -huge(1d0)
     drhomin = huge(1d0)
#endif
     do j = jne1, jne2, jne3
        jc = jc + 1
        read(55,*) jne, rho0(jc), pla(jc), ros(jc)
        if(j == jne1) rho_min0 = rho0(jc)
        if(j == jne2) rho_max0 = rho0(jc)
#ifdef DRHOMIN
        rhomin = min(rhomin, rho0(jc))
        rhomax = max(rhomax, rho0(jc))
        if(j /= jne1) then
           drhomin = min(drhomin, (rho0(jc)-rho0(jc-1)))
        end if
#endif
     end do
     write(88,*) t(ic), rho_min0, rho_max0
     print *, t(ic), rho_min0, rho_max0
#ifdef DRHOMIN
     print *, 'T=', t(ic), 'drhomin =', drhomin, 'rhomin=', rhomin, 'rhomax=', rhomax
#endif

     do k = kmin, kmax
        jc = 0
        do j = jne1, jne2, jne3
           jc = jc + 1
           if(rho0(jc) > rho(k)) exit
        end do
        opa_pla(i/2-10+1,k) = ((rho(k) - rho0(jc-1)) * log10(pla(jc  )) + &
                         (rho0(jc) -   rho(k)) * log10(pla(jc-1))) / (rho0(jc) - rho0(jc-1))
        opa_ros(i/2-10+1,k) = ((rho(k) - rho0(jc-1)) * log10(ros(jc  )) + &
                         (rho0(jc) -   rho(k)) * log10(ros(jc-1))) / (rho0(jc) - rho0(jc-1))
        if(rho(k) < rho0(    1)) then
           opa_pla(i/2-10+1,k) = log10(pla(1))
           opa_ros(i/2-10+1,k) = log10(ros(1))
        end if
        if(rho(k) > rho0(jcmax)) then
           opa_pla(i/2-10+1,k) = log10(pla(jcmax))
           opa_ros(i/2-10+1,k) = log10(ros(jcmax))
        end if
     end do
     deallocate(rho0, pla, ros)
  end do
  CLOSE(88)

  open(1, file='op_ros.data', form='unformatted')
  write(1) jmax, kmax
  write(1) tmp, rho, opa_ros
  close(1)
  open(1, file='op_pla.data', form='unformatted')
  write(1) jmax, kmax
  write(1) tmp, rho, opa_pla
  close(1)

  close(55)

70 format(a70)
 
end program read_op
