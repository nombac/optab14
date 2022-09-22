FC = gfortran
FFLAGS = -fconvert=big-endian -O2 -Wall

a.out: read.F90
	$(FC) $(FFLAGS) $<

clean:
	\rm a.out *~
