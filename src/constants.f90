module constants
INTEGER,  PARAMETER      :: DP = KIND(1.0D0)
INTEGER,  PARAMETER      :: QP = KIND(1.0D0)
!REAL(DP), PARAMETER      :: pi=3.141592653589793238462643383279502884197_DP
REAL(DP), PARAMETER      :: pi=3.141592654d0
REAL(DP), PARAMETER      :: ene_cons = -90.040530764400003
REAL(DP), PARAMETER      :: GPa2eVPang =6.24219D-3
!REAL(DP), PARAMETER      :: ene_cons = -162.0
!REAL(DP), PARAMETER      :: ene_cons = -90.040530764400003
INTEGER, PARAMETER       :: max_mm_len = 4000

!  *************  Parameters of GPR
REAL(DP)                               :: RMSE_ENERGY, RMSE_FORCE, RMSE_STRESS
INTEGER                                :: nforce
logical                                :: ltrain, ltest
INTEGER                                :: tt1, tt2, it1, it2

!
TYPE GAP_type
INTEGER                                 :: nsparse
INTEGER                                 :: ninteraction
INTEGER                                 :: dd   ! the dimension of discriptors
INTEGER                                 :: nglobalY
INTEGER                                 :: sparse_method
REAL(DP)                                :: delta
REAL(DP)                                :: sparse_dis_len, sigma_atom
REAL(DP)                                :: sigma_e, sigma_f, sigma_s
REAL(DP),DIMENSION(:),ALLOCATABLE       :: lamda
REAL(DP),DIMENSION(:,:),ALLOCATABLE     :: lamdaobe
REAL(DP),DIMENSION(:,:),ALLOCATABLE     :: cmm
REAL(DP),DIMENSION(:,:,:),ALLOCATABLE   :: cmo
REAL(DP),DIMENSION(:),ALLOCATABLE       :: sparsecut
REAL(DP),DIMENSION(:,:),ALLOCATABLE     :: sparseX
REAL(DP),DIMENSION(:),ALLOCATABLE       :: obe
REAL(DP),DIMENSION(:,:),ALLOCATABLE     :: coeff
REAL(DP),DIMENSION(:),ALLOCATABLE       :: theta
INTEGER,DIMENSION(:),ALLOCATABLE        :: SparseX_index
REAL(DP),DIMENSION(:,:),ALLOCATABLE     :: DescriptorX, MM

END TYPE GAP_type

!
TYPE SF
INTEGER                                 :: ntype
REAL(DP)                                :: alpha
REAL(DP)                                :: cutoff
END TYPE SF

!
TYPE ACSF_type
INTEGER                                 :: nsf
REAL(DP)                                :: global_cutoff
type(SF),dimension(:),allocatable       :: sf
END TYPE ACSF_type

!
TYPE data_type
!{
integer                                 :: nsparse_2b
REAL(DP)                                :: delta_2b
REAL(DP)                                :: theta_2b
REAL(DP)                                :: sigma_e_2b, sigma_f_2b, sigma_s_2b
logical                                 :: ltrain_2b
!}
!{
integer                                 :: nsparse_mb
REAL(DP)                                :: sparse_dis_len, sigma_atom
integer                                 :: sparse_method
REAL(DP)                                :: sigma_e_mb, sigma_f_mb, sigma_s_mb
REAL(DP)                                :: delta_mb
logical                                 :: ltrain_mb
!}
integer                                 :: nspecies  ! this nspecies is global
integer                                 :: ninteraction
REAL(DP)                                :: sigma_jitter
REAL(DP)                                :: Rcut, Rmin, d_width
character(2),allocatable,dimension(:)   :: elements
INTEGER                                 :: ncross
INTEGER,allocatable,dimension(:,:)      :: interaction_mat

INTEGER                                 :: ne, nf, ns
INTEGER                                 :: natoms
INTEGER                                 :: nob
REAL(DP),dimension(:),allocatable       :: obe, ob
END TYPE data_type

TYPE(ACSF_type)                         :: ACSF
TYPE(GAP_type)                          :: GAP_2B, GAP_MB
TYPE(data_type)                         :: DATA_C

CONTAINS

SUBROUTINE get_ele_weights(cc,nw)
implicit none
character(2),intent(in)          ::  cc
real(DP),intent(inout)           ::  nw
select case(cc)
case ('H')
    nw = -1.0
case ('Li')
    nw = 1.0
case ('B')
    nw = -1.0
case ('C')
    nw = 4.0
case ('O')
    nw = 2.0
case ('Mg')
    nw = -1.0
case ('Al')
    nw = 1.0
case ('P')
    nw = 2.0
case ('S')
    nw = -1.0
case ('Si')
    nw = -2.0
case ('Ca')
    nw = -1.0
case ('Ni')
    nw = -1.0
case ('Y')
    nw = 4.0
case ('Cs')
    nw = 1.0
case ('La')
    nw = 2.0
case ('Pt')
    nw = 3.0
end select
END SUBROUTINE
end module constants