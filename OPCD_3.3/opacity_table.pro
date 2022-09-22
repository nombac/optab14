
PRO opacity_table

  COMPILE_OPT IDL2

; initialize
  PS_CLOSE
  CLOSE, /all

  OPENR, 1, 'border.data'
  READF, 1, jmax
  rhomin = DBLARR(jmax)
  rhomax = DBLARR(jmax)
  temper = DBLARR(jmax)
  FOR j = 0, jmax-1 DO BEGIN
     dummy0 = 0d0
     dummy1 = 0d0
     dummy2 = 0d0
     READF, 1, dummy0, dummy1, dummy2
     temper[j] = dummy0
     rhomin[j] = dummy1
     rhomax[j] = dummy2
  ENDFOR
  CLOSE, 1

; component
  component = '7.02'

  OPENR, 1, 'op_ros.data', /F77_UNFORMATTED, /SWAP_ENDIAN
  jrmax = 0L & krmax = 0L
  READU, 1, jrmax, krmax
  tr = DBLARR(jrmax)
  rhor = DBLARR(krmax)
  meanr = DBLARR(jrmax,krmax)
  READU, 1, tr, rhor, meanr
  CLOSE, 1

  OPENR, 1, 'op_pla.data', /F77_UNFORMATTED, /SWAP_ENDIAN
  jpmax = 0L & kpmax = 0L
  READU, 1, jpmax, kpmax
  tp = DBLARR(jpmax)
  rhop = DBLARR(kpmax)
  meanp = DBLARR(jpmax,kpmax)
  READU, 1, tp, rhop, meanp
  CLOSE, 1

; floor and ceiling
  value_max =  7d0
  value_min = -6d0

  meanp >= value_min
  meanp <= value_max
  meanr >= value_min
  meanr <= value_max

; convert from double to byte image
  meanp = BYTE((meanp - value_min) / (value_max - value_min) * 255)
  meanr = BYTE((meanr - value_min) / (value_max - value_min) * 255)

; plot
  !p.multi = [0,2,1]
  psfile = 'opacity_table.'+component
;  PS_START, psfile+'.eps', /ENCAPSULATED, /LANDSCAPE, /NOMATCH, DEFAULT_THICKNESS=0, FONT=1, TT_FONT='helvetica', XSIZE=12, YSIZE=5
  PS_OPEN, psfile, /color, ps_fonts='helvetica', /cmyk, /encapsulated, XSIZE=8.5, YSIZE=3.5

  ; color
  JHCOLORS

  ; title
  xtitle = TEXTOIDL('log T (K)')
  ytitle = TEXTOIDL('log \rho (g cm^{-3})')

  ; Rosseland-mean opacity
  xrange = [MIN(tr),MAX(tr)]
  yrange = [MIN(rhor),MAX(rhor)]
  p = [0.2, 0.2, 0.9, 0.9]
  CGIMAGE, meanr, /axes, xr=xrange, yr=yrange, pos=p, chars=1.0, axkey={xtit:xtitle,ytit:ytitle,tit:TEXTOIDL('log \kappa_R (cm^2g^{-1})')}, interp=0
  CGCOLORBAR, /vertical, /right, pos=[p[2]+0.01, p[1], p[2]+0.02, p[3]], maxr=value_max, minr=value_min, chars=0.75
  CGOPLOT, temper, rhomin, LIN=1, COL='white'
  CGOPLOT, temper, rhomax, LIN=1, COL='white'

  ; Planck-mean opacity
  xrange = [MIN(tp),MAX(tp)]
  yrange = [MIN(rhop),MAX(rhop)]
  p = [0.2, 0.2, 0.9, 0.9]
  CGIMAGE, meanp, /axes, xr=xrange, yr=yrange, pos=p, chars=1.0, axkey={xtit:xtitle,ytit:ytitle,tit:TEXTOIDL('log \kappa_P (cm^2g^{-1})')}, interp=0
  CGCOLORBAR, /vertical, /right, pos=[p[2]+0.01, p[1], p[2]+0.02, p[3]], maxr=value_max, minr=value_min, chars=0.75
  CGOPLOT, temper, rhomin, LIN=1, COL='white'
  CGOPLOT, temper, rhomax, LIN=1, COL='white'

  PS_CLOSE

END
