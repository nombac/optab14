!#define NONE TRANSFER(-1_8, 0d0)
#define NONE -100d0
#define COMPONENT '7.02'
#define MODEL 'g98'
#define RES_LOGR 19
#define RES_LOGT_ROS 85
#define RES_LOGT_PLA 55

!#define COMPONENT '7.00'
!#define RES_LOGR 19
!#define RES_LOGT_ROS 85
!#define RES_LOGT_PLA 55

!#define COMPONENT '7.00'
!#define RES_LOGT_ROS 23
!#define RES_LOGT_PLA 23
!#define RES_LOGR 21

!#define RHO_MAX -4d0
!#define RHO_MIN -14d0
#define RHO_MAX 0d0
#define RHO_MIN -22d0
#define DRHO 0.1d0
#define T_MAX 6.5d0
#define T_MIN 0.5d0
#define DT 0.025d0

! density grid: user defined
! temperature grid: original


program read

  
  implicit none
  
  real(8), parameter :: rho_min = RHO_MIN, rho_max = RHO_MAX, drho = DRHO
  real(8), parameter :: tmp_min = T_MIN, tmp_max = T_MAX, dt = DT
  integer, parameter :: kmin = 1, lmin = 1
  real(8), allocatable :: rho(:), tmp(:)
  integer :: kmax, lmax
  integer :: k, l
  
  ! density array
  kmax = (rho_max - rho_min) / drho + 1
  allocate(rho(kmin:kmax))
  do k = kmin, kmax
     rho(k) = rho_min + drho * (k - 1)
  end do

  ! temperature array
  lmax = (tmp_max - tmp_min) / dt   + 1
  allocate(tmp(lmin:lmax))
  do l = lmin, lmax
     tmp(l) = tmp_min + dt   * (l - 1)
  end do
  
  ! Rosseland mean opacity
  call convert('ros',RES_LOGT_ROS) ! resolution of temperature in the original Rosseland mean opacity
  call convert('pla',RES_LOGT_PLA) ! resolution of temperature in the original Planck mean opacity
  
  stop
  
contains
  
  
  
  subroutine convert(mean, jmax)
    character :: mean*3
    integer, intent(in) :: jmax
    
    integer, parameter :: imin = 1, imax = RES_LOGR ! resolution of LOG(R) in the original mean opacities
    integer, parameter :: jmin = 1
    real(8) :: r(imin:imax), r0
    integer :: i, j, k
    real(8), allocatable :: op(:,:)
    real(8), allocatable :: opa(:,:)
    real(8), allocatable :: t(:)
    REAL(8) :: opal, opah
    character*64 :: fname
    character :: dum1*3, dum2*1

    IF(mean .eq. 'ros') then
       fname = MODEL//'.'//COMPONENT//'.tron'
    ELSE
       fname = MODEL//'.pl.'//COMPONENT//'.tpon'
    END IF

    
    open(1, file=TRIM(fname), status='old')
    read(1,*)
    read(1,*)
    read(1,*)
    allocate(op(imin:imax, jmin:jmax), opa(lmin:lmax, kmin:kmax), t(jmin:jmax))
    read(1,*) dum1, dum2, (r(i), i = imin, imax)
    do j = jmax, jmin, -1
       read(1,*) t(j), (op(i,j), i = imin, imax)
    end do
    close(1)

    OPEN(1, FILE='border.data')
    write(1,*) jmax
    DO j = jmin, jmax
       write(1,*) j, t(j), r(imin)+3d0*(t(j)-6d0), r(imax)+3d0*(t(j)-6d0)
    END DO
    CLOSE(1)
    
    do l = lmin, lmax ! 温度Tのループ

       IF(tmp(l) < MINVAL(t) .OR. tmp(l) > MAXVAL(t)) THEN
          opa(l,kmin:kmax) = NONE
          CYCLE
       END IF
       
       DO j = jmin, jmax
          IF(t(j) >= tmp(l)) EXIT
       END DO
       
       do k = kmin, kmax ! 密度ρのループ
          r0 = rho(k) - 3d0 * (tmp(l) - 6d0)

          do i = imin, imax
             if(r(i) > r0) EXIT
          end do

          IF(r0 < MINVAL(r)) THEN
             opa(l,k) = (op(imin,j)*(tmp(l)-t(j-1)) + op(imin,j-1)*(t(j)-tmp(l))) / (t(j)-t(j-1))
          ELSE IF(r0 > MAXVAL(r)) THEN
             opa(l,k) = (op(imax,j)*(tmp(l)-t(j-1)) + op(imax,j-1)*(t(j)-tmp(l))) / (t(j)-t(j-1))
          ELSE
             opah = (op(i  ,j)*(tmp(l)-t(j-1)) + op(i  ,j-1)*(t(j)-tmp(l))) / (t(j)-t(j-1))
             opal = (op(i-1,j)*(tmp(l)-t(j-1)) + op(i-1,j-1)*(t(j)-tmp(l))) / (t(j)-t(j-1))
             opa(l,k) = ((r(i) - r0) * opal + (r0 - r(i-1)) * opah) / (r(i) - r(i-1))
          END IF
       end do
    end do
    
    open(1, file='ferguson_'//mean//'.data', form='unformatted')
    write(1) lmax, kmax
    write(1) tmp, rho, opa
    close(1)
    deallocate(op, opa, t)
    
    return
  end subroutine convert
  
  
  
end program read
