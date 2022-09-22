FC = gfortran
FFLAGS = -fconvert=big-endian -O2 -Wall

a.out: opacity.F opacity.in opacity.inp
	$(FC) $(FFLAGS) opacity.F

clean:
	\rm *~ a.out
