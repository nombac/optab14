# Ferguson opacity

<img src="./opacity_table.png" width="800">

---
- ferguson_pla.data: Planck mean opacity data (Fortran big-endian binary), generated from "g98.pl.7.02.tpon" in the Ferguson's database
- ferguson_ros.data: Rosseland mean opacity data (Fortran big-endian binary), generated from "g98.7.02.tron" in the Ferguson's database
- read.F90: Fortran code to create ferguson_???.data
- Makefile: for compilation of read.F90
- opacity_table.pro: IDL code to create the above plots