;************ FUNCTIONS ************
PRO SHOW_IMAGE, img, imageDims, GRID_SPACING = grid_spacing, $
  WINDOW_ID = window_id, $
  XSIZE = xsize, YSIZE = ysize, $
  XPOS = xpos, YPOS = ypos
  ;
  ;Handle default values
  IF N_ELEMENTS(window_id) EQ 0 THEN window_id = 0
  IF N_ELEMENTS(xsize) NE 0 THEN forceX = 1 ELSE forceX = 0
  IF N_ELEMENTS(ysize) NE 0 THEN forceY = 1 ELSE forceY = 0
  ;
  ;Use the image information to figure out sizing and interleaving
  imageSize    = SIZE(img, /DIMENSIONS)
  interleaving = WHERE((imageSize NE imageDims[0]) AND $
    (imageSize NE imageDims[1]), numThree) + 1
  ;  
  ;Compute the necessary aspect ratio for the specified "xsize" or "ysize" values
  IF forceX THEN BEGIN
    ysize = FIX(xsize*(FLOAT(imageDims[1])/FLOAT(imageDims[0])))
  ENDIF
  IF forceY THEN BEGIN
    xsize = FIX(ysize*(FLOAT(imageDims[0])/FLOAT(imageDims[1])))
  ENDIF
  ;
  ;Separate each color element of the image
  IF (numThree NE 0) THEN BEGIN
    img1 = FLTARR(3,xsize, ysize)
    img1[0,*,*] = CONGRID(REFORM(img[0,*,*]), xsize, ysize, CUBIC = -0.5)
    img1[1,*,*] = CONGRID(REFORM(img[1,*,*]), xsize, ysize, CUBIC = -0.5)
    img1[2,*,*] = CONGRID(REFORM(img[2,*,*]), xsize, ysize, CUBIC = -0.5)
  ENDIF ELSE BEGIN
    ;If no interleaving was found, then simply do a congrid resizing
    img1 = CONGRID(img, xsize, ysize, CUBIC = -0.5)
  ENDELSE
  ;
  ;Open a window and display the data to the user
  DEVICE, WINDOW_STATE=openWindows
  IF openWindows[window_id] $
    THEN WSET, window_id $
    ELSE WINDOW, window_id, XSIZE = xsize, YSIZE = ysize, XPOS = xpos, YPOS = ypos
  PLOT, [0,imageDims[0]], [0,imageDims[1]], /NODATA, $
    XRANGE = [0,imageDims[0]], XSTYLE = 1, $
    YRANGE = [0,imageDims[1]], YSTYLE = 1, POSITION = [0,0,1,1]
    
  IF (numThree NE 0) $
    THEN TV, img1, TRUE = interleaving[0] $
  ELSE TV, img1
  ;
  ;If the gridspacing variable was set, then show some gridlines.
  IF N_ELEMENTS(grid_spacing) NE 0 THEN BEGIN
    numXLines = FLOOR(imageDims[0]/grid_spacing)
    numYlines = FLOOR(imageDims[1]/grid_spacing)
    xStart    = FLOOR((imageDims[0] - numXLines*grid_spacing)/2E)
    yStart    = FLOOR((imageDims[1] - numYLines*grid_spacing)/2E)
    FOR iX = 0, numXlines DO $
      PLOTS, xStart + [iX*grid_spacing, iX*grid_spacing], [0, imageDims[1]], /DATA, COLOR = '0000ff'x, LINESTYLE = 2
    FOR iY = 0, numYlines DO $
      PLOTS, [0, imageDims[0]], yStart + [iY*grid_spacing, iY*grid_spacing], /DATA, COLOR = '0000ff'x, LINESTYLE = 2
  ENDIF
  ;
  ;Show the created window
  WSHOW, window_id
END
