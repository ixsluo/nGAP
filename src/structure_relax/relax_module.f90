! this module perform structure optimization task
! 2019.09.19
module relax_module
use gap_module
implicit none


private   struct2relaxv, relaxv2struct, lat2matrix, upper, lower, lat_inv
contains
SUBROUTINE  relax_main(NA, SPECIES, LAT, POS, EXTSTRESS)!{{{
implicit none
INTEGER,          intent(in)                     :: NA
INTEGER,          intent(in),dimension(NA)       :: SPECIES
double precision, intent(inout),dimension(3,3)   :: LAT
double precision, intent(inout),dimension(Na,3)  :: POS
double precision, intent(in),dimension(6)        :: EXTSTRESS

!local
double precision                              :: ENE, VARIANCE
double precision, allocatable,dimension(:,:)  :: FORCE
double precision,             dimension(6)    :: STRESS

!variables for lbfgs
integer                                       :: n, m, iprint
double precision, parameter                   :: factor = 1.0d7
double precision, parameter                   :: pgtol = 1.0d-5
character(len=60)                             :: task, csave
logical                                       :: lsave(4)
integer                                       :: isave(44)
double precision                              :: f
double precision                              :: dsave(29)
integer,  allocatable,dimension(:)            :: nbd, iwa
double precision, allocatable,dimension(:)    :: x, l, u, g, wa

double precision                              :: f_bak, d
integer                                       :: i
double precision, allocatable,dimension(:)    :: x_save, dmax
logical                                       :: lfirst


n = 3*NA + 6
m = 3
iprint = 1
if (.not. allocated(FORCE))  allocate(FORCE(NA, 3))
allocate ( nbd(n), x(n), l(n), u(n), g(n), x_save(n), dmax(n))
allocate ( iwa(3*n) )
allocate ( wa(2*m*n + 5*n + 11*m*m + 8*m) )

do i = 1, 3
    nbd(i) = 1
    l(i) = 0.d0
    dmax(i) = 0.2d0
enddo
do i = 4, 6
    nbd(i) = 2
    l(i) = 0.d0
    u(i) = 360.d0
    dmax(i) = 60.d0
enddo
do i = 7, n
    nbd(i) = 2
    l(i) = 0.d0
    u(i) = 1.d0
    dmax(i) = 0.1d0
enddo

lfirst = .true.
task = 'START'
call  FGAP_INIT()
call  FGAP_CALC(NA, SPECIES, LAT, POS, ENE, FORCE, STRESS, VARIANCE)

f_bak = 0
! begin lbfgs loop
do while(task(1:2).eq.'FG'.or.task.eq.'NEW_X'.or.task.eq.'START') 
 
    call struct2relaxv(NA, LAT, POS, ENE, FORCE, STRESS, EXTSTRESS, n, x, f, g)
    !print*, 'n'
    !print*, n
    print*, 'f'
    print*, f
    print*, 'x'
    print*, x
    print*, 'g'
    print*, g
    x_save = x
    call setulb ( n, m, x, l, u, nbd, f, g, factor, pgtol, &
                       wa, iwa, task, iprint,&
                       csave, lsave, isave, dsave )
    print*, 'new x'
    print *, x
    do i = 1, n
        d = x(i) - x_save(i)
        if (abs(d) > dmax(i))  x(i) = x_save(i) + d/abs(d)*dmax(i)
    enddo
    print*, task(1:2)

    if (task(1:2) .eq. 'FG') then
        call relaxv2struct(n, x, NA, LAT, POS)
        print*, 'lat'
        print*, transpose(LAT)
        print* , 'pos'
        print * , transpose(POS)
        call FGAP_CALC(NA, SPECIES, LAT, POS, ENE, FORCE, STRESS, VARIANCE)
    endif
    if (lfirst) then
        lfirst = .false.
        f_bak = f
    else
        print *, '|DE|:', f, f - f_bak, gnorm(n, g)
        f_bak = f
    endif
    print*, '***************************************************'
enddo
! end of lbfgs loop

END SUBROUTINE!}}}

SUBROUTINE  relax_main_conj(NA, SPECIES, LAT, POS, EXTSTRESS)
implicit none
INTEGER,          intent(in)                     :: NA
INTEGER,          intent(in),dimension(NA)       :: SPECIES
double precision, intent(inout),dimension(3,3)   :: LAT
double precision, intent(inout),dimension(Na,3)  :: POS
double precision, intent(in),dimension(6)        :: EXTSTRESS

!local
double precision                              :: ENE, VARIANCE
double precision, allocatable,dimension(:,:)  :: FORCE
double precision,             dimension(6)    :: STRESS

!variables for lbfgs
integer                                       :: n, nmin
double precision, allocatable,dimension(:)    :: x, g, xlast
double precision                              :: f
double precision, allocatable,dimension(:)    :: pvect, gg, glast
double precision                              :: pnorm, gsca, ggg, dggg, gam, pnlast, alp
logical                                       :: okf
integer                                       :: imode, jcyc, iflag

double precision                              :: f_bak, d, volume
integer                                       :: i
double precision, allocatable,dimension(:)    :: x_save, dmax
logical                                       :: lfirst
integer                                       :: tt1, tt2


n = 3*NA + 6
if (.not. allocated(FORCE))  allocate(FORCE(NA, 3))
allocate (x(n), g(n), pvect(n), gg(n), glast(n), xlast(n))
gg = 0.d0

!do i = 1, 3
!    nbd(i) = 1
!    l(i) = 0.d0
!    dmax(i) = 0.2d0
!enddo
!do i = 4, 6
!    nbd(i) = 2
!    l(i) = 0.d0
!    u(i) = 360.d0
!    dmax(i) = 60.d0
!enddo
!do i = 7, n
!    nbd(i) = 2
!    l(i) = 0.d0
!    u(i) = 1.d0
!    dmax(i) = 0.1d0
!enddo
nmin = 1
gsca = 0.001d0
volume = abs(det(lat))
pnorm = 1.d0/volume**(1.d0/3.d0)
pnlast = pnorm
jcyc = 0
alp = 1.d0
imode = 1

lfirst = .true.
call  FGAP_INIT()
call  FGAP_CALC(NA, SPECIES, LAT, POS, ENE, FORCE, STRESS, VARIANCE)
call  struct2relaxv(NA, LAT, POS, ENE, FORCE, STRESS, EXTSTRESS, n, x, f, g)

f_bak = f
! begin lbfgs loop
CALL  SYSTEM_CLOCK(tt1)
print *, pnlast, 'pnlast'
do while(.true.) 
    if (lfirst) then
        do i = 1, n
            xlast(i) = x(i)
            glast(i) = -1.d0 * gsca * g(i)
            pvect(i) = glast(i)
            lfirst = .false.
        enddo
    endif
    ggg = 0.d0
    dggg = 0.d0
    do i = 1, n
        ggg = ggg + glast(i)*glast(i)
        dggg = dggg + (glast(i) + gsca*g(i)) * g(i) * gsca
    enddo
    gam = dggg/ggg
    print*, 'gam',gam
    do i = 1, n
        xlast(i) = x(i)
        glast(i) = -1.d0 * gsca * g(i)
        pvect(i) = glast(i) + gam * pvect(i)
    enddo
    pnorm = gnorm(n, pvect) * n
    if (pnorm > 1.5d0 * pnlast) then
        pvect = pvect * 1.5d0* pnlast/pnorm
        pnorm = 1.5d0 * pnlast
    endif
    pnlast = pnorm
    print *, 'pnorm', pnorm
    print*, 'x'
    print*, x
    !print*, 'pvect', pvect
    call olinmin(x, alp, pvect, n, nmin, f, okf, gg, imode, NA, SPECIES, EXTSTRESS)
    call funct(iflag, n, x, f, g, NA, SPECIES, EXTSTRESS)
    jcyc = jcyc + 1
    CALL  SYSTEM_CLOCK(tt2)
    write(*,'(''  Cycle: '',i6,''  Energy:'',f17.6,'' d E:'', f17.6,''  Gnorm:'',f14.6, '' CPU:'',f8.3)') jcyc,f,f-f_bak, gnorm(n, g), (tt2-tt1)/10000.0
    f_bak = f
    !print*, 'xc best'
    !print *, x
    !print*, 'f'
    !print*, f
    !stop
    if (jcyc == 8) exit
 
enddo
! end of lbfgs loop

END SUBROUTINE

SUBROUTINE funct(iflag, n, xc, fc, gc, NA, SPECIES, EXTSTRESS)
implicit none

integer, intent(inout)                       :: iflag
integer, intent(in)                          :: n
integer, intent(in)                          :: NA
integer, intent(in),           dimension(NA) :: SPECIES
double precision,intent(in),   dimension(6)  :: EXTSTRESS
double precision,intent(inout),dimension(n)  :: xc, gc
double precision,intent(inout)               :: fc

! local 
double precision, allocatable, dimension(:,:) :: POS, FORCE
double precision,              dimension(3,3) :: LAT
double precision,              dimension(6)   :: STRESS
double precision                              :: ENE, VARIANCE

if (.not. allocated(POS)) allocate(POS(NA, 3))
if (.not. allocated(FORCE)) allocate(FORCE(NA, 3))
call  relaxv2struct(n, xc, NA, LAT, POS)
call  FGAP_CALC(NA, SPECIES, LAT, POS, ENE, FORCE, STRESS, VARIANCE)
call  struct2relaxv(NA, LAT, POS, ENE, FORCE, STRESS, EXTSTRESS, n, xc, fc, gc)
END SUBROUTINE

SUBROUTINE  struct2relaxv(NA, LAT, POS, ENE, FORCE, STRESS, EXTSTRESS, n, xc, fc, gc)!{{{
implicit none

INTEGER         , intent(in)                           :: NA
double precision,parameter                             :: cfactor = 6.241460893d-3
double precision, intent(inout),dimension(3,3)            :: LAT
double precision, intent(in),dimension(NA,3)           :: POS, FORCE
double precision, intent(in)                           :: ENE
double precision, intent(in),dimension(6)              :: STRESS, EXTSTRESS
INTEGER         , intent(in)                           :: n
double precision, intent(inout),dimension(n)           :: xc, gc
double precision, intent(inout)                        :: fc
! local
integer                                                :: i,j,k
double precision, dimension(6)                         :: cellp, strderv, cellderv
double precision, allocatable, dimension(:,:)          :: POS_FRAC, FORCE_FRAC

if (.not. allocated(FORCE_FRAC)) allocate(FORCE_FRAC(NA, 3))
if (.not. allocated(POS_FRAC)) allocate(POS_FRAC(NA, 3))

CALL LAT2MATRIX(cellp, LAT, 2)
CALL CART2FRAC(NA, LAT, POS, POS_FRAC)
FORCE_FRAC = matmul(FORCE, transpose(LAT))

strderv(1) = STRESS(1)
strderv(2) = STRESS(4)
strderv(3) = STRESS(6)
strderv(4) = STRESS(5)
strderv(5) = STRESS(3)
strderv(6) = STRESS(2)
strderv = strderv - EXTSTRESS
! calculating the dev of strain to cell parameters
CALL CELLDRV(transpose(LAT), cellp, strderv, cellderv)
!print*, 'strderv'
!print*, strderv
!print*, 'cellderv'
!print*, cellderv
k = 0
do i = 1, 6
    k = k + 1
    xc(k) = cellp(i)
    gc(k) = cellderv(i)
enddo
do i = 1, NA
    do j = 1, 3
        k = k + 1
        xc(k) = POS_FRAC(i,j)
        gc(k) = FORCE_FRAC(i,j)
    enddo
enddo
fc = ENE + SUM(EXTSTRESS(1:3))/3.d0 * ABS(DET(LAT)) * cfactor
!gc = gc * -1.d0
!print *, 'fc',fc
!stop
END SUBROUTINE!}}}

SUBROUTINE  relaxv2struct(n, xc, NA, LAT, POS)
implicit none

INTEGER         , intent(in)                           :: n
double precision, intent(in),dimension(n)              :: xc
INTEGER         , intent(in)                           :: NA
double precision, intent(out),dimension(3,3)         :: LAT
double precision, intent(out),dimension(NA,3)        :: POS

! local
integer                                                :: i,j
double precision, dimension(6)                         :: cellp
double precision, allocatable, dimension(:,:)          :: POS_FRAC

if (.not. allocated(POS_FRAC)) allocate(POS_FRAC(NA, 3))
cellp(1:6) = xc(1:6)
CALL LAT2MATRIX(cellp, LAT, 1)
do i = 1, NA
    do j = 1, 3
        POS_FRAC(i,j) = xc(6 + 3*(i - 1) + j)
    enddo
enddo
CALL FRAC2CART(NA, LAT, POS_FRAC, POS)
END SUBROUTINE
    
SUBROUTINE  CART2FRAC(NA, LAT, POS, POS_FRAC)!{{{
implicit none

INTEGER         , intent(in)                           :: NA
double precision, intent(in),dimension(3,3)            :: LAT
double precision, intent(in),dimension(NA,3)           :: POS
double precision, intent(inout),dimension(NA,3)        :: POS_FRAC

! local
integer                                                :: i,j
double precision, dimension(3,3)                       :: INV_LAT
call lat_inv(LAT, INV_LAT)
POS_FRAC = matmul(POS, INV_LAT)
do i = 1, NA
    do j = 1,3
        if (POS_FRAC(i,j) < 0.d0) POS_FRAC(i,j) = POS_FRAC(i,j) + 1.d0
        if (POS_FRAC(i,j) > 1.d0) POS_FRAC(i,j) = POS_FRAC(i,j) - 1.d0
    enddo
enddo
END SUBROUTINE CART2FRAC!}}}

SUBROUTINE  FRAC2CART(NA, LAT, POS_FRAC, POS)!{{{
implicit none

INTEGER         , intent(in)                           :: NA
double precision, intent(in),dimension(3,3)            :: LAT
double precision, intent(inout),dimension(NA,3)        :: POS_FRAC
double precision, intent(inout),dimension(NA,3)        :: POS
! loca
integer                                                :: i,j
do i = 1, NA
    do j = 1,3
        if (POS_FRAC(i,j) < 0.d0) POS_FRAC(i,j) = POS_FRAC(i,j) + 1.d0
        if (POS_FRAC(i,j) > 1.d0) POS_FRAC(i,j) = POS_FRAC(i,j) - 1.d0
    enddo
enddo
POS = matmul(POS_FRAC, LAT)
END SUBROUTINE FRAC2CART!}}}
        

subroutine lat2matrix(lat,matrix,iflag)!{{{
implicit none

! if iflag==1, abc2matrix; iflag==2. matrix2abc
integer,          intent(in)        :: iflag 
double precision, intent(inout)     :: lat(6),matrix(3,3)

!local parameters
double precision                    :: ra,rb,rc,&
                                       cosinea, cosineb,cosinec,&
                                       anglea,angleb,anglec
double precision, parameter         :: radtodeg = 57.29577951d0
double precision, parameter         :: degtorad = 1.0/radtodeg

if (iflag==1) then
   lat(4:6) = lat(4:6) * degtorad
   matrix=0.0
   matrix(1,1) = lat(1)
   matrix(2,1) = lat(2)*cos(lat(6))
   matrix(2,2) = lat(2)*sin(lat(6))
   matrix(3,1) = lat(3)*cos(lat(5))
   matrix(3,2) = lat(3)*cos(lat(4))*sin(lat(6))-((lat(3)*cos(lat(5))&
   -lat(3)*cos(lat(4))*cos(lat(6)))/tan(lat(6)))
   matrix(3,3) = sqrt(lat(3)**2 -matrix(3,1)**2 - matrix(3,2)**2)
else
   lat=0.0
   ra=sqrt(matrix(1,1)**2+matrix(1,2)**2+matrix(1,3)**2)
   rb=sqrt(matrix(2,1)**2+matrix(2,2)**2+matrix(2,3)**2)
   rc=sqrt(matrix(3,1)**2+matrix(3,2)**2+matrix(3,3)**2)
   cosinea=(matrix(2,1)*matrix(3,1)+matrix(2,2)*matrix(3,2)+matrix(2,3)*matrix(3,3))/rb/rc
   cosineb=(matrix(1,1)*matrix(3,1)+matrix(1,2)*matrix(3,2)+matrix(1,3)*matrix(3,3))/ra/rc
   cosinec=(matrix(1,1)*matrix(2,1)+matrix(1,2)*matrix(2,2)+matrix(1,3)*matrix(2,3))/ra/rb
   anglea=acos(cosinea)
   angleb=acos(cosineb)
   anglec=acos(cosinec)
   lat(1)=ra
   lat(2)=rb
   lat(3)=rc
   lat(4)=anglea * radtodeg
   lat(5)=angleb * radtodeg
   lat(6)=anglec * radtodeg
endif
end subroutine lat2matrix!}}}

subroutine upper(matrix1,matrix2)!{{{
implicit none
real(8) :: matrix1(:,:)
real(8) :: matrix2(:,:)
integer :: i,j,m,n
real :: a 
m=size(matrix1,1)
n=size(matrix1,2)
do i=1,n
   do j=i+1,n
	  a=matrix1(j,i)/matrix1(i,i)
	  matrix1(j,:)=matrix1(j,:)-a*matrix1(i,:)
	  matrix2(j,:)=matrix2(j,:)-a*matrix2(i,:)
   end do
end do 
end subroutine upper!}}}

subroutine lower(matrix1,matrix2)!{{{
implicit none

real(8) :: matrix1(:,:)
real(8) :: matrix2(:,:)
integer :: i,j,m,n
real :: a
m=size(matrix1,1)
n=size(matrix1,2)
do i=n,2,-1
   do j=i-1,1,-1
	  a=matrix1(j,i)/matrix1(i,i)
	  matrix1(j,:)=matrix1(j,:)-a*matrix1(i,:)
	  matrix2(j,:)=matrix2(j,:)-a*matrix2(i,:)
   end do
end do 
end subroutine!}}}

subroutine lat_inv(matrix3,matrix2)!{{{
implicit none

real(8) :: matrix1(3,3)
real(8) :: matrix2(3,3),matrix3(3,3)
integer :: i,j
matrix1=matrix3
do i=1,3
   do j=1,3
	  if(i==j)then
		 matrix2(i,j)=1
	  else
		 matrix2(i,j)=0
	  end if
   end do 
end do
call upper(matrix1,matrix2)
call lower(matrix1,matrix2)
do i=1,3
   matrix2(i,:)=matrix2(i,:)/matrix1(i,i)
end do
end subroutine!}}}

function gnorm(n,x)!{{{
implicit none

integer, intent(in)                        :: n
double precision, intent(in), dimension(n) :: x
double precision                           :: gnorm

! local 
integer                                    :: i
gnorm = 0.d0
do i = 1, n
    gnorm = gnorm + x(i)**2
enddo
gnorm = dsqrt(gnorm)/n
end function gnorm!}}}

END MODULE