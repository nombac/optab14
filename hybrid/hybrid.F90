  
#define OPACITY_DUST 0d0
#define TMP_DUST 2.7d0

#define SEMENOV_ROS '../Semenov/semenov_ros.data'
#define SEMENOV_PLA '../Semenov/semenov_pla.data'
#define FERGUSON_ROS '../Ferguson/ferguson_ros.data'
#define FERGUSON_PLA '../Ferguson/ferguson_pla.data'
#define OP_ROS '../OPCD_3.3/op_ros.data'
#define OP_PLA '../OPCD_3.3/op_pla.data'
#define DEPLETION 1d0

  program hybrid
    
    implicit none
    
    real(8), parameter :: PI = acos(-1d0)
    real(8), parameter :: RGAS = 8.31447d7
    real(8), parameter :: MMW = 0.61d0
    real(8), parameter :: GAMMA = 5d0/3d0

    real(8) :: tmp, dtmp, tmp_min, tmp_max
    real(8) :: tmp_ser, tmp_fer, tmp_sep, tmp_fep, tmp_opr, tmp_opp
    real(8) :: tmpdsr, tmpdsp, tmpdfr, tmpdfp, tmpdor, tmpdop
    real(8) :: rho, drho, rho_min, rho_max
    real(8), allocatable :: opa_ros(:,:), opa_pla(:,:), dust(:,:)
    real(8) :: opa_ros0, opa_pla0, f0r, f0p
    real(8) :: opa_ros1, opa_pla1, f1r, f1p
    real(8) :: opa_ros2, opa_pla2, f2r, f2p
    real(8) :: opa_ros3, opa_pla3, f3r, f3p
    integer :: i, imax
    integer :: j, jmax
    integer :: nt_ser, nd_ser, nt_sep, nd_sep
    integer :: nt_fer, nd_fer, nt_fep, nd_fep
    integer :: nt_opr, nd_opr, nt_opp, nd_opp
    real(8), allocatable :: t_ser(:), d_ser(:), t_sep(:), d_sep(:)
    real(8), allocatable :: ros_se(:,:), pla_se(:,:)
    real(8), allocatable :: t_fer(:), d_fer(:), t_fep(:), d_fep(:)
    real(8), allocatable :: ros_fe(:,:), pla_fe(:,:)
    real(8), allocatable :: t_opr(:), d_opr(:), t_opp(:), d_opp(:)
    real(8), allocatable :: ros_op(:,:), pla_op(:,:)
    real(8) :: egas
    logical :: use_dust, has_use_dust_file
    integer :: use_dust_int
    REAL*8, PARAMETER :: temp_fe_op = 3.7d0
    
! READ SEMENOV OPACITIES
    open(7, file=SEMENOV_ROS, form='unformatted', status='old')
    read(7) nt_ser, nd_ser
    allocate(t_ser(nt_ser), d_ser(nd_ser), ros_se(nt_ser,nd_ser))
    read(7) t_ser, d_ser, ros_se
    close(7)
!    DO j = 1, nd_ser
!       DO i = 1, nt_ser
!          IF(ros_se(i,j)*0d0 .ne. 0d0 .and. t_ser(i) .lt. 2.9) THEN
!             PRINT *, i,j, ros_se(i,j), t_ser(i)
!          END IF
!       END DO
!    END DO
!    stop
    open(7, file=SEMENOV_PLA, form='unformatted', status='old')
    read(7) nt_sep, nd_sep
    allocate(t_sep(nt_sep), d_sep(nd_sep), pla_se(nt_sep,nd_sep))
    read(7) t_sep, d_sep, pla_se
    close(7)

    ! Read runtime parameter for dust usage (default: enabled)
    use_dust = .true.
    inquire(file='use_dust.in', exist=has_use_dust_file)
    if (has_use_dust_file) then
       open(11, file='use_dust.in', status='old', action='read')
       read(11, *, end=100, err=100) use_dust_int
       if (use_dust_int == 0) use_dust = .false.
100    close(11)
    end if

! READ FERGUSON OPACITIES    
    open(7, file=FERGUSON_ROS, form='unformatted', status='old')
    read(7) nt_fer, nd_fer
    allocate(t_fer(nt_fer), d_fer(nd_fer), ros_fe(nt_fer,nd_fer))
    read(7) t_fer, d_fer, ros_fe
    close(7)
    open(7, file=FERGUSON_PLA, form='unformatted', status='old')
    read(7) nt_fep, nd_fep
    allocate(t_fep(nt_fep), d_fep(nd_fep), pla_fe(nt_fep,nd_fep))
    read(7) t_fep, d_fep, pla_fe
    close(7)

! READ OP OPACITIES    
    open(7, file=OP_ROS, form='unformatted', status='old')
    read(7) nt_opr, nd_opr
    allocate(t_opr(nt_opr), d_opr(nd_opr), ros_op(nt_opr,nd_opr))
    read(7) t_opr, d_opr, ros_op
    close(7)
    open(7, file=OP_PLA, form='unformatted', status='old')
    read(7) nt_opp, nd_opp
    allocate(t_opp(nt_opp), d_opp(nd_opp), pla_op(nt_opp,nd_opp))
    read(7) t_opp, d_opp, pla_op
    close(7)
    
    OPEN(55, FILE='temp_fe_op.data')
    WRITE(55,*) temp_fe_op
    CLOSE(55)

    ! Rosseland mean
    tmpdsr = 0.01d0
    tmpdfr = 0.01d0
    tmpdor = 0.02d0
    tmp_ser = 2.0d0
    tmp_fer = temp_fe_op
    tmp_opr = 7.0d0

    ! Planck mean
    tmpdsp = 0.01d0
    tmpdfp = 0.01d0
    tmpdop = 0.02d0
    tmp_sep = 2.0d0
    tmp_fep = temp_fe_op
    tmp_opp = 7.0d0

    ! Read ranges from input.dat (log10 units): tmp_min tmp_max dtmp rho_min rho_max drho
    open(9, file='input.dat', status='old', action='read')
    read(9, *) tmp_min, tmp_max, dtmp, rho_min, rho_max, drho
    close(9)

    ! Guard: if dust is enabled and lower temp bound is below Semenov grid min, abort
    if (use_dust) then
       if (tmp_min < t_ser(1)) then
          write(*,*) 'ERROR: tmp_min (log10T=', tmp_min, ') is below Semenov dust table min (log10T=', t_ser(1), ').'
          write(*,*) 'Please raise tmp_min or disable dust via use_dust.in (set 0).'
          stop 1
       end if
    end if

    imax = int((tmp_max - tmp_min) / dtmp) + 1
    jmax = int((rho_max - rho_min) / drho) + 1
    allocate(opa_ros(imax,jmax), opa_pla(imax,jmax), dust(imax,jmax))

    do j = 1, jmax
       rho = rho_min + drho * (j - 1)
       do i = 1, imax
          tmp = tmp_min + dtmp * (i - 1)
          if(tmp < tmp_ser - tmpdsr) then
             f0r = 1d0
          else if(tmp < tmp_ser + tmpdsr) then
             f0r = rightdown(tmp, tmp_ser, tmpdsr)
          else
             f0r = 0d0
          end if
          if(tmp < tmp_ser - tmpdsr) then
             f1r = 0d0
          else if(tmp < tmp_ser + tmpdsr) then
             f1r = rightup(tmp, tmp_ser, tmpdsr)
          else if(tmp < tmp_fer - tmpdfr) then
             f1r = 1d0
          else if(tmp < tmp_fer + tmpdfr) then
             f1r = rightdown(tmp, tmp_fer, tmpdfr)
          else
             f1r = 0d0
          end if
          if(tmp < tmp_fer - tmpdfr) then
             f2r = 0d0
          else if(tmp < tmp_fer + tmpdfr) then
             f2r = rightup(tmp, tmp_fer, tmpdfr)
          else if(tmp < tmp_opr - tmpdor) then
             f2r = 1d0
          else if(tmp < tmp_opr + tmpdor) then
             f2r = rightdown(tmp, tmp_opr, tmpdor)
          else
             f2r = 0d0
          end if
          if(tmp < tmp_opr - tmpdor) then
             f3r = 0d0
          else if(tmp < tmp_opr + tmpdor) then
             f3r = rightup(tmp, tmp_opr, tmpdor)
          else
             f3r = 1d0
          end if
          
          if(tmp < tmp_sep - tmpdsp) then
             f0p = 1d0
          else if(tmp < tmp_sep + tmpdsp) then
             f0p = rightdown(tmp, tmp_sep, tmpdsp)
          else
             f0p = 0d0
          end if
          if(tmp < tmp_sep - tmpdsp) then
             f1p = 0d0
          else if(tmp < tmp_sep + tmpdsp) then
             f1p = rightup(tmp, tmp_sep, tmpdsp)
          else if(tmp < tmp_fep - tmpdfp) then
             f1p = 1d0
          else if(tmp < tmp_fep + tmpdfp) then
             f1p = rightdown(tmp, tmp_fep, tmpdfp)
          else
             f1p = 0d0
          end if
          if(tmp < tmp_fep - tmpdfp) then
             f2p = 0d0
          else if(tmp < tmp_fep + tmpdfp) then
             f2p = rightup(tmp, tmp_fep, tmpdfp)
          else if(tmp < tmp_opp - tmpdop) then
             f2p = 1d0
          else if(tmp < tmp_opp + tmpdop) then
             f2p = rightdown(tmp, tmp_opp, tmpdop)
          else
             f2p = 0d0
          end if
          if(tmp < tmp_opp - tmpdop) then
             f3p = 0d0
          else if(tmp < tmp_opp + tmpdop) then
             f3p = rightup(tmp, tmp_opp, tmpdop)
          else
             f3p = 1d0
          end if
          opa_ros0 = opacity(tmp, rho, ros_se, t_ser, d_ser)
          opa_ros1 = opacity(tmp, rho, ros_fe, t_fer, d_fer)
          opa_ros2 = opacity(tmp, rho, ros_op, t_opr, d_opr)
          opa_pla0 = opacity(tmp, rho, pla_se, t_sep, d_sep)
          opa_pla1 = opacity(tmp, rho, pla_fe, t_fep, d_fep)
          opa_pla2 = opacity(tmp, rho, pla_op, t_opp, d_opp)
          
          if(opa_ros0 > (OPACITY_DUST)) opa_ros1 = 0d0
          if(opa_pla0 > (OPACITY_DUST)) opa_pla1 = 0d0

          ! analytical expression for f-f + electron scattering
          egas = RGAS/MMW/(GAMMA-1d0) * (10d0**rho) * (10d0**tmp)
          opa_ros3 = log10(0.33d0 +10d52 * sqrt((10d0**rho)**9 / egas**7))
          opa_pla3 = log10(        37d52 * sqrt((10d0**rho)**9 / egas**7))
          
          ! Dust usage controlled by runtime flag; treat low T as dusty as well
          if(use_dust .and. (opa_ros0 > (OPACITY_DUST) .or. tmp < TMP_DUST)) then
             dust(i,j) = 1 ! DUST GRAINS EXIST
             opa_ros(i,j) = opa_ros0
             opa_pla(i,j) = opa_pla0
          else
             dust(i,j) = 0 ! DUST GRAINS SUBLIMATED or dust disabled
             ! Gas-only composition; use correct weights for Rosseland/Planck
             IF(opa_ros1*0d0 == 0d0 .and. opa_ros2*0d0 == 0d0) THEN
                opa_ros(i,j) = opa_ros1 * f1r + opa_ros2 * f2r
             ELSE IF(opa_ros1*0d0 == 0d0 .and. opa_ros2*0d0 /= 0d0) THEN
                opa_ros(i,j) = opa_ros1
             ELSE IF(opa_ros1*0d0 /= 0d0 .and. opa_ros2*0d0 == 0d0) THEN
                opa_ros(i,j) = opa_ros2
             ELSE
                opa_ros(i,j) = TRANSFER(-1_8, 0d0)
             ENDIF
             IF(opa_pla1*0d0 == 0d0 .and. opa_pla2*0d0 == 0d0) THEN
                opa_pla(i,j) = opa_pla1 * f1p + opa_pla2 * f2p
             ELSE IF(opa_pla1*0d0 == 0d0 .and. opa_pla2*0d0 /= 0d0) THEN
                opa_pla(i,j) = opa_pla1
             ELSE IF(opa_pla1*0d0 /= 0d0 .and. opa_pla2*0d0 == 0d0) THEN
                opa_pla(i,j) = opa_pla2
             ELSE
                opa_pla(i,j) = TRANSFER(-1_8, 0d0)
             ENDIF

             ! If dust is disabled, and gas weights both zero, mark as NaN
             if(.not. use_dust) then
                if(f1r == 0d0 .and. f2r == 0d0) opa_ros(i,j) = TRANSFER(-1_8, 0d0)
                if(f1p == 0d0 .and. f2p == 0d0) opa_pla(i,j) = TRANSFER(-1_8, 0d0)
             end if
          end if
!!$          opa_ros(i,j) = opa_ros0
!!$          opa_pla(i,j) = opa_pla0
       end do
    end do
    
    ! Write human-readable table (text) with header and per-cell values
    call write_text_table('opacity_table.txt', imax, jmax, tmp_min, dtmp, rho_min, drho, opa_ros, opa_pla, dust)
    
    open(8, file='kP.dat', form='unformatted')
    write(8) 10d0**opa_pla
    close(8)
    open(8, file='kR.dat', form='unformatted')
    write(8) 10d0**opa_ros
    close(8)

    open(8, file='dust.dat', form='unformatted')
    write(8) dust
    close(8)
    
  contains

    subroutine write_text_table(filename, imax, jmax, tmp_min, dtmp, rho_min, drho, opa_ros, opa_pla, dust)
      implicit none
      character(len=*), intent(in) :: filename
      integer, intent(in) :: imax, jmax
      real(8), intent(in) :: tmp_min, dtmp, rho_min, drho
      real(8), intent(in) :: opa_ros(imax,jmax), opa_pla(imax,jmax), dust(imax,jmax)
      integer :: i, j, u
      real(8) :: tlog, rlog, kR, kP

      u = 99
      open(u, file=filename, status='replace', action='write', form='formatted')
      write(u,'(A)') 'log10T[K], log10rho[g/cm^3], kR[cm^2/g], kP[cm^2/g], dust'
      do j = 1, jmax
         rlog = rho_min + drho * (j - 1)
         do i = 1, imax
            tlog = tmp_min + dtmp * (i - 1)
            kR = 10d0**opa_ros(i,j)
            kP = 10d0**opa_pla(i,j)
            write(u,'(1X, F8.3, 1X, F9.3, 1X, ES14.6, 1X, ES14.6, 1X, I1)') tlog, rlog, kR, kP, int(dust(i,j))
         end do
      end do
      close(u)
    end subroutine write_text_table

    real(8) function opacity(tmp, rho, opa, tmp0, rho0)
      real(8), intent(in) :: tmp
      real(8), intent(in) :: rho
      real(8), intent(in) :: opa(:,:)
      real(8), intent(in) :: tmp0(:)
      real(8), intent(in) :: rho0(:)
      
      integer :: nt, nd
      integer :: it, id, it0, id0
      real(8) :: op0, op1
      
      nt = size(tmp0)
      nd = size(rho0)
      
      if(tmp <= tmp0(1)) then
         opacity = -100d0
         return
      end if
      if(tmp >= tmp0(nt)) then
         opacity = -100d0
         return
      end if
      
      do it = 1, nt
         if(tmp0(it) >= tmp) exit
      end do
      it0 = it

      do id = 1, nd
         if(rho0(id) >= rho) exit
      end do
      id0 = id

      if(id0 == 1) then
         op0 = opa(it0-1,1)
         op1 = opa(it0  ,1)
      else if(id0 == nd+1) then
         op0 = opa(it0-1,nd)
         op1 = opa(it0  ,nd)
      else
         op0 = ((rho - rho0(id0-1)) * opa(it0-1, id0) + (rho0(id0) - rho) * opa(it0-1, id0-1)) / (rho0(id0) - rho0(id0-1))
         op1 = ((rho - rho0(id0-1)) * opa(it0  , id0) + (rho0(id0) - rho) * opa(it0  , id0-1)) / (rho0(id0) - rho0(id0-1))
      end if
      
      opacity = ((tmp - tmp0(it0-1)) * op1 + (tmp0(it0) - tmp) * op0) /  (tmp0(it0) - tmp0(it0-1))

      
      return    
    end function opacity
    
    real(8) function rightup(x, x0, d)
      real(8), intent(in) :: x
      real(8), intent(in) :: x0
      real(8), intent(in) :: d
      
      rightup = 0.5d0 * (1d0 + sin(0.5d0 * PI * (x - x0) / d))
      
      return
    end function rightup
    
    real(8) function rightdown(x, x0, d)
      real(8), intent(in) :: x
      real(8), intent(in) :: x0
      real(8), intent(in) :: d
      
      rightdown = 0.5d0 * (1d0 - sin(0.5d0 * PI * (x - x0) / d))
      
      return
    end function rightdown
    
  end program hybrid
  
