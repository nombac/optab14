
pro opacity_table

  compile_opt idl2

; initialize
  PS_CLOSE
  CLOSE, /all

; component
  component = ''

; TEMPERATURE BORDER BETWEEN FERGUSON AND OP
  OPENR, 1, 'temp_fe_op.data'
  READF, 1, t_ferguson_max
  CLOSE, 1

  ; READ INPUT RANGES (log10 units) FROM input.dat
  dir = './'
  nidd = 0
  nitt = 0
  OPENR, 1, dir+'input.dat'
  READF, 1, topmin, topmax, dtmp, dopmin, dopmax, drho
  CLOSE, 1
  nitt = FIX((topmax - topmin) / dtmp) + 1
  nidd = FIX((dopmax - dopmin) / drho) + 1
  print, nitt, nidd
  meanp = DBLARR(nitt,nidd)
  meanr = DBLARR(nitt,nidd)
  dust  = DBLARR(nitt,nidd)
  OPENR, 1, dir+'kP.dat'+component, /f77_unformatted, /swap_endian
  READU, 1, meanp
  CLOSE, 1
  OPENR, 1, dir+'kR.dat'+component, /f77_unformatted, /swap_endian
  READU, 1, meanr
  CLOSE, 1
  OPENR, 1, dir+'dust.dat'+component, /f77_unformatted, /swap_endian
  READU, 1, dust
  CLOSE, 1

; linear -> log
  meanp = ALOG10(meanp)
  meanr = ALOG10(meanr)
  topmin = ALOG10(topmin)
  topmax = ALOG10(topmax)
  dopmin = ALOG10(dopmin)
  dopmax = ALOG10(dopmax)

; INDECIES OF SUBLIMATION TEMPERATURES
  isubl = INTARR(nidd)
  FOR i = 0, nidd-1 DO BEGIN
;     FOR j = 0, nitt-1 DO BEGIN
     FOR j = nitt-1, 0, -1 DO BEGIN
        IF(dust[j,i] eq 1) THEN BREAK
     ENDFOR
     isubl[i] = j
  ENDFOR

  ; SLICE
  IF(1) THEN BEGIN
     d_slice = -6.
     j_slice = 0
     t = DBLARR(nitt)
     FOR i = 0, nitt-1 DO BEGIN
        t[i] = topmin + i * (topmax - topmin) / DOUBLE(nitt - 1)  
     ENDFOR
     FOR j = 0, nidd-1 DO BEGIN
        d = dopmin + j * (dopmax - dopmin) / DOUBLE(nidd - 1)  
        j_slice = j
        IF(d GE d_slice) THEN BREAK
     ENDFOR
     !p.multi = [0,1,1]
     PS_OPEN, 'slice', /color, ps_fonts='helvetica', /cmyk, /encapsulated, XSIZE=8.5, YSIZE=8.5/SQRT(2d0)
     CGPLOT, t, t, xrange=[2.7,6.0], xs=1, yrange=[-3,6], ys=1, /NODATA, xtit=TEXTOIDL('log( T / K )'), ytit=TEXTOIDL('log( \kappa / cm^2g^{-1} )')
     CGOPLOT, t, meanp[*,j_slice], thick=10, color='gray'
     CGOPLOT, t, meanr[*,j_slice], thick=10
     CGOPLOT, [3.75,4.1], [1.,1.+9*(4.1-3.75)], li=1, thick=3
     CGOPLOT, [4.5,5.3], [4,4-3.5*(5.3-4.5)], li=1, thick=3
     CGTEXT, 0.02, 0.02, TEXTOIDL('log\rho = '+STRTRIM(STRING(d_slice),2)), /NORM, CHARS=1
     PS_CLOSE
  ENDIF

  
  ; BORDER LINE (SEMENOV)
  tsubl = DBLARR(nidd)
  dsubl = DBLARR(nidd)
  FOR i = 0, nidd-1 DO BEGIN
     tsubl[i] = topmin + (topmax - topmin) / DOUBLE(nitt - 1) * isubl[i]
     dsubl[i] = dopmin + (dopmax - dopmin) / DOUBLE(nidd - 1) * i
  ENDFOR

  ; BORDER LINE (OP)
  OPENR, 1, '../OPCD_3.3/border.data'
  READF, 1, jmax_op
  rhomin_op = DBLARR(jmax_op)
  rhomax_op = DBLARR(jmax_op)
  temper_op = DBLARR(jmax_op)
  FOR j = 0, jmax_op-1 DO BEGIN
     dummy0 = 0d0
     dummy1 = 0d0
     dummy2 = 0d0
     READF, 1, dummy0, dummy1, dummy2
     temper_op[j] = dummy0
     rhomin_op[j] = dummy1
     rhomax_op[j] = dummy2
  ENDFOR
  CLOSE, 1

  ; BORDER LINE (FERGUSON)
  OPENR, 1, '../Ferguson/border.data'
  READF, 1, jmax_fe
  rhomin_fe = DBLARR(jmax_fe)
  rhomax_fe = DBLARR(jmax_fe)
  temper_fe = DBLARR(jmax_fe)
  FOR j = 0, jmax_fe-1 DO BEGIN
     dummy0 = 0d0
     dummy1 = 0d0
     dummy2 = 0d0
     READF, 1, jdummy, dummy0, dummy1, dummy2
     temper_fe[j] = dummy0
     rhomin_fe[j] = dummy1
     rhomax_fe[j] = dummy2
  ENDFOR
  CLOSE, 1

  
  ; xrange and yrange
  xmin = topmin - (topmax - topmin) / FLOAT(nitt - 1) / 2
  xmax = topmax + (topmax - topmin) / FLOAT(nitt - 1) / 2
  ymin = dopmin - (dopmax - dopmin) / FLOAT(nidd - 1) / 2
  ymax = dopmax + (dopmax - dopmin) / FLOAT(nidd - 1) / 2
  xrange = [xmin,xmax]
  yrange = [ymin,ymax]

  imin = 0
  imax = nitt-1
  jmin = 0
  jmax = nidd-1


; floor and ceiling
  value_max = 7.
  value_min = -6.

  meanp >= value_min
  meanp <= value_max
  meanr >= value_min
  meanr <= value_max

; convert from double to byte image
  meanp = BYTE((meanp - value_min) / (value_max - value_min) * 255)
  meanr = BYTE((meanr - value_min) / (value_max - value_min) * 255)


; plot
  !p.multi = [0,2,1]
  psfile = 'opacity_table'+component
  PS_OPEN, psfile, /color, ps_fonts='helvetica', /cmyk, /encapsulated, XSIZE=8.5, YSIZE=3.5

  ; color
  JHCOLORS

  ; title
  xtitle = TEXTOIDL('log T (K)')
  ytitle = TEXTOIDL('log \rho (g cm^{-3})')

  ; Rosseland-mean opacity
  p = [0.2, 0.2, 0.9, 0.9]

  CGIMAGE, meanr[imin:imax,jmin:jmax], /axes, xr=xrange, yr=yrange, pos=p, chars=1.0, axkey={xtit:xtitle,ytit:ytitle,tit:TEXTOIDL('log \kappa_R (cm^2g^{-1})')}, interp=0
  CGCOLORBAR, /vertical, /right, pos=[p[2]+0.01, p[1], p[2]+0.02, p[3]], maxr=value_max, minr=value_min, chars=0.75
  CGOPLOT, tsubl, dsubl, THICK=3, COL='WHITE', LIN=2
  CGOPLOT, [t_ferguson_max, t_ferguson_max], [dopmin, dopmax], THICK=3, COL='WHITE', LIN=2
  CGOPLOT, temper_op, rhomin_op, THICK=1, COL='WHITE', LIN=1
  CGOPLOT, temper_op, rhomax_op, THICK=1, COL='WHITE', LIN=1
  CGOPLOT, temper_fe, rhomin_fe, THICK=1, COL='WHITE', LIN=1
  CGOPLOT, temper_fe, rhomax_fe, THICK=1, COL='WHITE', LIN=1
  CGTEXT, 1, -12, 'Semonov', charsize=1, COL='WHITE'
  CGTEXT, 3.5, -15, 'Ferguson', charsize=1, COL='WHITE', ORIEN=90
  CGTEXT, 4.5, -10, 'OP', charsize=1, COL='WHITE'
  
  ; Planck-mean opacity
  p = [0.2, 0.2, 0.9, 0.9]
  CGIMAGE, meanp[imin:imax,jmin:jmax], /axes, xr=xrange, yr=yrange, pos=p, chars=1.0, axkey={xtit:xtitle,ytit:ytitle,tit:TEXTOIDL('log \kappa_P (cm^2g^{-1})')}, interp=0
  CGCOLORBAR, /vertical, /right, pos=[p[2]+0.01, p[1], p[2]+0.02, p[3]], maxr=value_max, minr=value_min, chars=0.75
  CGOPLOT, tsubl, dsubl, THICK=3, COL='WHITE', LIN=2
  CGOPLOT, [t_ferguson_max, t_ferguson_max], [dopmin, dopmax], THICK=3, COL='WHITE', LIN=2
  CGOPLOT, temper_op, rhomin_op, THICK=1, COL='WHITE', LIN=1
  CGOPLOT, temper_op, rhomax_op, THICK=1, COL='WHITE', LIN=1
  CGOPLOT, temper_fe, rhomin_fe, THICK=1, COL='WHITE', LIN=1
  CGOPLOT, temper_fe, rhomax_fe, THICK=1, COL='WHITE', LIN=1
  CGTEXT, 1, -12, 'Semonov', charsize=1, COL='WHITE'
  CGTEXT, 3.5, -15, 'Ferguson', charsize=1, COL='WHITE', ORIEN=90
  CGTEXT, 4.5, -10, 'OP', charsize=1, COL='WHITE'

  PS_CLOSE

END
