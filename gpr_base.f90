module GPR_BASE
use constants
use io
use math
use linearalgebra
use struct

interface covariance
    module procedure covariance_2B, covariance_MB
end interface covariance
!interface INI_GAP
!    module procedure INI_GAP_2B, INI_GAP_MB
!end interface INI_GAP

real(dp), dimension(:,:), allocatable :: c_subYY_sqrtInverseLambda
real(dp), dimension(:,:), allocatable :: factor_c_subYsubY
real(dp), dimension(:,:), allocatable :: a
real(dp), dimension(:),   allocatable :: globalY
type(LA_Matrix)                       :: LA_c_subYsubY, LA_q_subYsubY
integer                               :: n_globalSparseX , n_globalY
integer                               :: error



contains
SUBROUTINE GPR(cmm, cmo, lamdaobe, alpha)
implicit none
real(dp),intent(in),dimension(:,:)      :: cmm
real(dp),intent(in),dimension(:,:)      :: cmo
real(dp),intent(in),dimension(:)        :: lamdaobe
real(dp),intent(out),dimension(:)       :: alpha
!--- local ---
integer                                 :: i,j
n_globalSparseX = size(cmo, 1)
n_globalY = size(cmo, 2)
!==========================================================================
allocate(factor_c_subYsubY(n_globalSparseX,n_globalSparseX))
allocate(a(n_globalY+n_globalSparseX,n_globalSparseX))
allocate(globalY(n_globalY+n_globalSparseX))

globalY = 0.d0
call LA_Matrix_initialise(LA_c_subYsubY,cmm)
call LA_Matrix_Factorise(LA_c_subYsubY,factor_c_subYsubY,error=error)
call LA_Matrix_finalise(LA_c_subYsubY)


do i = 1, n_globalSparseX-1
   do j = i+1, n_globalSparseX
      factor_c_subYsubY(j,i) = 0.0_qp
   end do
end do

a(1:n_globalY,:) = transpose(cmo(:,:))
a(n_globalY+1:,:) = factor_c_subYsubY
do i = 1, n_globalY
    globalY(i) = lamdaobe(i)
enddo
call LA_matrix_initialise(LA_q_subYsubY,a)
call LA_Matrix_QR_Solve_Vector(LA_q_subYsubY,globalY,alpha)
call LA_matrix_finalise(LA_q_subYsubY)
deallocate(factor_c_subYsubY)
deallocate(a)
deallocate(globalY)
END subroutine

!SUBROUTINE INI_GAP(GAP, nobf)
!type(GAP_type),intent(in) :: GAP
!integer,intent(in)        :: nobf
!!--local--
!!integer                 :: ninteraction
!
!allocate(GAP%cmm(GAP%nsparse, GAP%nsparse))
!allocate(GAP%cmo(GAP%nsparse, nobf, ninteraction))
!allocate(GAP%sparseX(GAP%nsparse. GAP%dd))
!allocate(GAP%obe(nobf))
!allocate(GAP%coeff(GAP%nsparse,ninteraction))
!allocate(GAP%lamda(nobf))
!allocate(GAP%lamdaobe(nobf))
!allocate(GAP%sparsecut(GAP%nsparse))
!END SUBROUTINE

SUBROUTINE INI_GAP_2B(GAP, nsparse, nobf)
type(GAP_type),intent(inout) :: GAP
integer,intent(in)           :: nsparse, nobf

!local
real(DP)                     :: dr3
GAP%dd = 1
GAP%nsparse = nsparse
GAP%nglobalY = nobf

allocate(GAP%cmm(GAP%nsparse, GAP%nsparse))
allocate(GAP%cmo(GAP%nsparse, GAP%nglobalY, ninteraction))
allocate(GAP%sparseX(GAP%nsparse, GAP%dd))
allocate(GAP%obe(GAP%nglobalY))
allocate(GAP%coeff(GAP%nsparse,ninteraction))
allocate(GAP%lamda(GAP%nglobalY))
allocate(GAP%lamdaobe(GAP%nglobalY))
allocate(GAP%sparsecut(GAP%nsparse))

dr3 = (rcut - rmin)/(GAP%nsparse - 1)
do i = 1, GAP%nsparse
    GAP%sparseX(i,1) = rmin + (i - 1)*dr3
enddo
!$OMP parallel do schedule(dynamic) default(shared) private(i,j,fc_i,fc_j)
    do i  = 1, GAP%nsparse
        GAP%cmm(i,i) = delta**2 
        fc_i = fcut_ij(GAP%sparseX(i,1))
        GAP%cmm(i,i) = GAP%cmm(i,i)*fc_i*fc_i + sigma_jitter
        do j = i + 1, GAP%nsparse
            !fc_j = fcutij(sparseX(j))
            GAP%cmm(i,j) = covariance(GAP%sparseX(i,1),GAP%sparseX(j,1))
            !cmm(i,j) = cmm(i,j) * fc_i * fc_j
            GAP%cmm(j,i) = GAP%cmm(i,j)
        enddo
    enddo
call write_array(GAP%cmm,'cmm.dat')
END SUBROUTINE


FUNCTION  covariance_2B(x,y)
implicit none
real(8),intent(in)  :: x
real(8),intent(in)  :: y
real(8)             :: covariance_2B

!integer  i 
REAL(DP)            :: fc_i, fc_j
fc_i = fcut_ij(x)
fc_j = fcut_ij(y)
covariance_2B = 0.d0
covariance_2B = covariance_2B + ((x-y)/theta)**2
covariance_2B = delta**2*exp(-0.5d0*covariance_2B) * fc_i * fc_j
END FUNCTION covariance_2B

FUNCTION  covariance_MB(x,y, theta)
implicit none
real(DP),intent(in)  :: x(:)
real(DP),intent(in)  :: y(:)
real(DP),intent(in)  :: theta(:)
real(DP)             :: covariance_MB

integer  i 
!REAL(DP)            :: fc_i, fc_j
covariance_MB = 0.d0
do i = 1, size(x)
    covariance_MB = covariance_MB + ((x(i)-y(i))/theta(i))**2
enddo
covariance_MB = delta**2*exp(-0.5d0*covariance_MB) 
END FUNCTION covariance_MB

FUNCTION  DcovarianceDx(x,y)
implicit none
real(8),intent(in)  :: x
real(8),intent(in)  :: y
real(8)             :: DcovarianceDx
!integer  i 
REAL(DP)            :: fc_i, fc_j, dfc_i, exp_part

DcovarianceDx = 0.d0
exp_part = 0.d0
fc_i = fcut_ij(x)
fc_j = fcut_ij(y)
dfc_i = dfcut_ij(x)
exp_part = exp_part + ((x-y)/theta)**2
exp_part = delta**2 * exp(-0.5d0 * exp_part)
DcovarianceDx = exp_part * -1.d0 * (x-y)/theta**2
DcovarianceDx = DcovarianceDx * fc_i + exp_part * dfc_i
DcovarianceDx = DcovarianceDx * fc_j
END FUNCTION DcovarianceDx

subroutine matmuldiag(x,y)
real(8),intent(in)   :: x(:)
real(8),intent(inout) :: y(:,:)
do i = 1,size(x)
    y(i,:) = x(i)*y(i,:)
enddo
end subroutine matmuldiag

subroutine matmuldiag_T(y,x)
real(8),intent(in)   :: x(:)
real(8),intent(inout) :: y(:,:)
do i = 1,size(x)
    y(:,i) = x(i)*y(:,i)
enddo
end subroutine matmuldiag_T

SUBROUTINE gp_predict_2B(GAP, at)
implicit none
type(GAP_type),intent(in)              :: GAP
type(Structure),intent(inout)          :: at


! local 
integer                               :: i,j,k, k1, k2, k3, k4
integer                               :: interaction_index
REAL(DP)                              :: rij, fc_ij , dfc_ij
REAL(DP)                              :: ene
REAL(DP),allocatable,dimension(:,:,:) :: stress_i

at%energy_cal = 0.d0
at%force_cal = 0.d0
at%stress = 0.d0
allocate(stress_i(3,3,at%natoms))
stress_i = 0.d0

!$OMP parallel do schedule(dynamic) default(shared) private(i,j,k,rij, fc_ij, interaction_index, k1, k2, k3, k4, dfc_ij, ene)
do i = 1,at%natoms
    do j = 1, nspecies
        do k = 1, at%atom(i)%count(j)
            rij = at%atom(i)%neighbor(j,k,4)
            fc_ij = fcut_ij(rij)
            dfc_ij = dfcut_ij(rij)
            interaction_index = at%interaction_mat(at%index(i),j)
            ene = 0.d0
            do k1 = 1, GAP%nsparse
!***********  get total energy                   
                ene = ene + covariance(rij, GAP%sparseX(k1, 1)) * fc_ij * GAP%coeff(k1,interaction_index) 

!***********  get atomic force                    
                do k2 = 1,3
                    at%force_cal(i,k2) = at%force_cal(i,k2) + &
                    (dfc_ij * covariance(rij, GAP%sparseX(k1, 1)) + DcovarianceDx(rij, GAP%sparseX(k1, 1)) * fc_ij) * &
                    (at%atom(i)%pos(k2) - at%atom(i)%neighbor(j,k,k2))/rij * GAP%coeff(k1,interaction_index) 

!***********  get atomic cell stress
                    do k3 = 1,3
                        stress_i(k3,k2,i) = stress_i(k3,k2,i) + (at%atom(i)%pos(k3) - at%atom(i)%neighbor(j,k,k3)) * &
                        (dfc_ij * covariance(rij, GAP%sparseX(k1, 1)) + DcovarianceDx(rij, GAP%sparseX(k1, 1)) * fc_ij) * &
                        (at%atom(i)%pos(k2) - at%atom(i)%neighbor(j,k,k2))/rij * GAP%coeff(k1,interaction_index) 

                    enddo ! k3
                enddo ! k2
            enddo ! k1
            at%atomic_energy(i) = at%atomic_energy(i) + ene
        enddo ! k
    enddo ! j
!    print*, at%atomic_energy(i)
enddo
!print*, at%atomic_energy
at%energy_cal = sum(at%atomic_energy) * 0.5d0 + at%natoms * ene_cons
!print*, at%energy_cal
at%force_cal = -1.0 * at%force_cal
at%volume = volume(at%lat)
at%stress = sum(stress_i, dim=3) * -0.5d0
at%stress = at%stress / at%volume * (1.0/GPa2eVPang) 
at%stress_cal(1) = at%stress(1,1)
at%stress_cal(2) = at%stress(1,2)
at%stress_cal(3) = at%stress(1,3)
at%stress_cal(4) = at%stress(2,2)
at%stress_cal(5) = at%stress(2,3)
at%stress_cal(6) = at%stress(3,3)
deallocate(stress_i)
END SUBROUTINE

SUBROUTINE get_cmo_2B(GAP)
type(GAP_type),intent(inout)    ::   GAP
integer   ::   i, j, k1, k2, k3, interaction_index
REAL(DP)  ::   rij

GAP%cmo = 0.d0
!$OMP parallel do schedule(dynamic) default(shared) private(i, j, k1, k2, k3, interaction_index, rij)
do i = 1, GAP%nsparse
    do j = 1, GAP%nglobalY
!***********************************************
        do k1 = 1, at(j)%natoms
            do k2 = 1, nspecies
                do k3 = 1, at(j)%atom(k1)%count(k2)
                    interaction_index = at(j)%interaction_mat(at(j)%index(k1),k2)
                    rij = at(j)%atom(k1)%neighbor(k2,k3,4)
                    GAP%cmo(i,j,interaction_index) = GAP%cmo(i,j,interaction_index) + covariance(GAP%sparseX(i,1), rij) * 0.5d0
                enddo
            enddo
        enddo
    enddo
enddo
!cmo(:,:,2) = cmo(:,:,2)/2.d0
END SUBROUTINE

SUBROUTINE GAP_SET_THETA(x, theta)
implicit none

REAL(DP),intent(in),dimension(:,:)   :: x
REAL(DP),intent(inout),dimension(:)  :: theta
! local
integer                              :: i,j,n,m
REAL(DP),allocatable,dimension(:)    :: t

n = size(x,1)
m = size(x,2)
allocate(t(n))
do i = 1, m
    do j = 1, n
        t(j) = x(j,i)
    enddo
    theta(i) = my_cov(t)
enddo
deallocate(t)
END SUBROUTINE

FUNCTION  MY_COV(t)
implicit none
real(DP)                          :: my_cov
real(DP),intent(in),dimension(:)  :: t
real(DP),allocatable,dimension(:) :: t2
integer                           :: i,n
n = size(t)
allocate(t2(n))
do i = 1,n
    t2(i) = t(i)*t(i)
enddo
my_cov = sum(t2)/n - (sum(t)/n)**2
my_cov = my_cov + 1.0d0
deallocate(t2)
END FUNCTION

  subroutine cur_decomposition(this, index_out, rank, n_iter)
    ! based on 10.1073/pnas.0803205106

    real(dp), intent(in), dimension(:,:) :: this
    integer, dimension(:), intent(out) :: index_out
    integer, intent(in), optional :: rank, n_iter

    integer :: n
    integer :: expected_columns
    integer :: my_n_iter, my_rank
    type(LA_Matrix) :: LA_this
    real(dp), allocatable, dimension(:) :: p, s, p_minus_ran_uniform
    real(dp), allocatable, dimension(:,:) :: v
    integer :: j, l
    integer, allocatable, dimension(:), target :: p_index
    integer, pointer, dimension(:) :: tmp_index_out => null()
    real(dp), allocatable, dimension(:,:) :: C, Cp
    real(dp) :: err, min_err
    integer :: error

    expected_columns = size(index_out)

    if( expected_columns <= 0 ) then
!       call print_warning("cur_decomposition: called with expected_columns "//expected_columns//", can't be zero or less")
       return
    endif

    call LA_Matrix_initialise(LA_this,this)

    my_n_iter = optional_default(1, n_iter)

    if (present(rank)) then
       call LA_Matrix_SVD_Allocate(LA_this,v=v,error=error)
!       HANDLE_ERROR(error)
       call LA_Matrix_SVD(LA_this,v=v,error=error)
!       HANDLE_ERROR(error)
       my_rank = rank
    else
       call LA_Matrix_SVD_Allocate(LA_this,s=s,v=v,error=error)
!       HANDLE_ERROR(error)
       call LA_Matrix_SVD(LA_this,s=s,v=v,error=error)
!       HANDLE_ERROR(error)
       my_rank = count(s > TOL_SVD) / 2
    endif

    n = size(v,1)
    allocate(p(n), p_minus_ran_uniform(n), p_index(n))
    allocate( C(size(this,1),expected_columns), Cp(expected_columns,size(this,1)) )

    p = sum(v(:,1:my_rank)**2, dim=2)
    p = p * expected_columns
    p = p / my_rank
    p = min(p,1.0_dp)

    if(my_n_iter <= 0) then ! do not do probabilistic selection of columns
       p_index = (/(j, j=1,n )/)
       p_minus_ran_uniform = -p
       call heap_sort(p_minus_ran_uniform,i_data=p_index)
       index_out = p_index(1:expected_columns)
    else
       min_err = huge(1.0_dp)
       do l = 1, my_n_iter

          ! randomly select columns according to the probabilities
          do j = 1, n
             p_minus_ran_uniform(j) = ran_uniform() - p(j)
             p_index(j) = j ! initialise index array
          end do

          call heap_sort(p_minus_ran_uniform,i_data=p_index)
          tmp_index_out => p_index(1:expected_columns)

          C = this(:,tmp_index_out)
          ! pinv: Moore-Penrose pseudo-inverse
          call pseudo_inverse(C,Cp)
          err = sum( (this - ( C .mult. Cp .mult. this))**2 )

!          call print("cur_decomposition: iteration: "//l//", error: "//err)
          if(err < min_err) then        ! this happens at least once
             index_out = tmp_index_out
             min_err = err
          endif

       end do
    endif

    call LA_Matrix_finalise(LA_this)

    tmp_index_out => null()
    if(allocated(s)) deallocate(s)
    if(allocated(v)) deallocate(v)
    if(allocated(p)) deallocate(p)
    if(allocated(p_minus_ran_uniform)) deallocate(p_minus_ran_uniform)
    if(allocated(p_index)) deallocate(p_index)
    if(allocated(C)) deallocate(C)
    if(allocated(Cp)) deallocate(Cp)

  end subroutine cur_decomposition

END module