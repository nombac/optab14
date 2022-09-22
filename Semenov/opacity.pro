PRO opacity

  PS_CLOSE
  CLOSE, /all
  COMPILE_OPT idl2

  dir = './'

  IF(1) THEN BEGIN
     OPENR, U, dir+'semenov_ros.data', /GET_LUN, /F77_UNFORMATTED, /SWAP_ENDIAN
     nt = 0
     nd = 0
     READU, U, nt, nd
     t = DBLARR(nt)
     d = DBLARR(nd)
     ros = DBLARR(nt,nd)
     pla = DBLARR(nt,nd)
     READU, U, t, d, ros
     FREE_LUN, U
     OPENR, U, dir+'semenov_pla.data', /GET_LUN, /F77_UNFORMATTED, /SWAP_ENDIAN
     READU, U, nt, nd
     READU, U, t, d, pla
     FREE_LUN, U
  ENDIF

  IF(0) THEN BEGIN
     OPENR, U, dir+'opacity.in', /GET_LUN
     nt = 0
     nd = 0
     READF, U, nt, nd
     READF, U, t0, t1
     READF, U, d0, d1
     t0 = ALOG10(t0)
     t1 = ALOG10(t1)
     d0 = ALOG10(d0)
     d1 = ALOG10(d1)
     depl = 0 
     READF, U, depl
     nogas = 0
     READF, U, nogas
     FREE_LUN, U
     t = DINDGEN(nt) * (t1 - t0) / DOUBLE(nt - 1) + t0
     d = DINDGEN(nd) * (d1 - d0) / DOUBLE(nd - 1) + d0
     ros = DBLARR(nt,nd)
     pla = DBLARR(nt,nd)
     OPENR, U, dir+'kR.out', /GET_LUN, /F77_UNFORMATTED, /SWAP_ENDIAN
     READU, U, ros
     FREE_LUN, U
     OPENR, U, dir+'kP.out', /GET_LUN, /F77_UNFORMATTED, /SWAP_ENDIAN
     READU, U, pla
     FREE_LUN, U
     ros = ALOG10(ros)
     pla = ALOG10(pla)
  ENDIF

; plot
  !p.multi = [0,2,1]
  xsize = 8.5
  ysize = 3.5


  PS_OPEN, 'opacity', /COLOR, PS_FONTS='HELVETICA', /CMYK, /ENCAPSULATED, XSIZE=xsize, YSIZE=ysize, /NOMESSAGE

  ; color
  JHCOLORS

  ; title
  xtitle = TEXTOIDL('log (T / K)')
  ytitle = TEXTOIDL('log (\rho / g cm^{-3})')

  xrange = [MIN(t),MAX(t)]
  yrange = [MIN(d),MAX(d)]
  data_min = -6
  data_max = 7
  
  
  ; Rosseland-meana
  data = ros
  title = TEXTOIDL('log (\kappa_R / cm^2g^{-1})')
  data = (data > data_min) < data_max
  data = BYTE((data - data_min) / (data_max - data_min) * 255)
  p = [0.2, 0.2, 0.9, 0.9]
  CGIMAGE, data, /axes, xr=xrange, yr=yrange, pos=p, chars=1.0, axkey={xtit:xtitle,ytit:ytitle,tit:title}, interp=0
  CGCOLORBAR, /vertical, /right, pos=[p[2]+0.01, p[1], p[2]+0.02, p[3]], maxr=data_max, minr=data_min, chars=0.5

  ;; CGTEXT, 0.01, 0.05, 'nogas='+STRTRIM(STRING(nogas),2), CHARS=0.5, COL='black', /NORMAL
  ;; CGTEXT, 0.01, 0.02, 'depletion='+STRTRIM(STRING(depl),2), CHARS=0.5, COL='black', /NORMAL

  ; Planck-mean
  data = pla
  title = TEXTOIDL('log (\kappa_P / cm^2g^{-1})')
  data = (data > data_min) < data_max
  data = BYTE((data - data_min) / (data_max - data_min) * 255)
  p = [0.2, 0.2, 0.9, 0.9]
  CGIMAGE, data, /axes, xr=xrange, yr=yrange, pos=p, chars=1.0, axkey={xtit:xtitle,ytit:ytitle,tit:title}, interp=0
  CGCOLORBAR, /vertical, /right, pos=[p[2]+0.01, p[1], p[2]+0.02, p[3]], maxr=data_max, minr=data_min, chars=0.5

  PS_CLOSE
;  SPAWN, 'gs -dBATCH -dNOPAUSE -sOutputFile="'+psfile+'.pdf" -sDEVICE=pdfwrite -c "<< /PageSize [792 612] >> setpagedevice" -f "'+psfile+'.eps"'
;  SPAWN, 'open '+psfile+'.pdf'

END
