# Hybrid opacity

<img src="./opacity_table.png" width="800">

---
- kR.data: hybrid Rosseland mean opacity data (Fortran big-endian binary)
- kP.data: hybrid Planck mean opacity data (Fortran big-endian binary)
- dust.data: dust existence data (0: no dust, 1: dust exists)
- hybrid.F90: Fortran code to create the k?.dat and dust.dat
- Makefile: for compilation of read_op.F90
- opacity_table.pro: IDL code to create the above plots