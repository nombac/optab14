FC = gfortran
FFLAGS = -fconvert=big-endian -O2 -Wall -fbounds-check
#SRC = hybrid_old.F90
SRC = hybrid.F90
a.out: $(SRC)
	$(FC) $(FFLAGS) $<
clean:
	-\rm *~ a.out
