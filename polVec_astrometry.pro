;************ Get Astrometry *************
;This script allows the user to click on location in the image where astrometric coordinates are provided.
;These locations will be used to compute the astrometry of the image, and the astrometry will be written to disk...

;Get the image file path
imgFile = DIALOG_PICKFILE(TITLE='Select synchrotron map')
imgPath = FILE_DIRNAME(imgFile)

;Figure out what kind of image it is...
queryStatus = QUERY_IMAGE(imgFile, imageInfo)

;If the query was successful, then open the image
IF STRLEN(imgFile) GT 0 THEN BEGIN
  extension    = (REVERSE(STRSPLIT(imgFile, '.', /EXTRACT)))[0]
  img          = READ_IMAGE(imgFile, R, G, B)
  imageSize    = SIZE(img, /DIMENSIONS)
  interleaving = WHERE((imageSize NE imageInfo.dimensions[0]) AND $
                       (imageSize NE imageInfo.dimensions[1]), numThree) + 1
  ;
  ;Get ready to show the image
  SHOW_IMAGE, img, imageInfo.dimensions, YSIZE = 700, WINDOW_ID = 0
  ;
  ;Query about the epoch (B1950 or J2000)
  epoch = ''
  epochDone = 0
  WHILE ~epochDone DO BEGIN
    PRINT, 'What is the epoch of the coordinates? (B1950 or J2000)'
    READ, epoch, PROMPT = '>> '
    epoch = STRTRIM(epoch, 2)
    CASE STRUPCASE(epoch) OF
      'B1950': epochDone = 1
      'J2000': epochDone = 1
      ELSE: PRINT, 'Please enter either "B1950" or "J2000"'
    ENDCASE
  ENDWHILE
  ;
  done = 0
  input = ''
  RAclickStr = ''
  DECclickStr = ''
  xClicks  = []
  yClicks  = []
  RAclicks = []
  DECclicks = []
  WHILE ~done DO BEGIN
    PRINT, 'Select one of the following options'
    PRINT, 'a: astrometry point, x: exit loop '
    READ, input, PROMPT = '>> '
    
    CASE STRUPCASE(input) OF
      'A': BEGIN
        PRINT, 'Click on the astrometry point'
        CURSOR, xClick, yClick, /DATA, /DOWN
        OPLOT, [xClick], [yClick], PSYM = 6, COLOR = 'FF00FF'x
        ;
        ;Concatenate them to the array
        xClicks = [xClicks, xClick]
        yClicks = [yClicks, yClick]
        PRINT, xClick, yClick, FORMAT = '("X: ",F6.1, ", Y: ",F6.1)'
        PRINT, ''
        ;
        ;Prompt for the astrometric coordinates of the clicked location
        coordDone = 0
        WHILE ~coordDone DO BEGIN
          PRINT, 'Enter the astrometric coordinates of the clicked point.'
          READ, RAclickStr, PROMPT = 'RA (HH MM SS): '
          READ, DECclickStr, PROMPT = 'DEC (DD MM SS): '
          ;
          RAclick  = STRSPLIT(RAclickStr, ' ', /EXTRACT, COUNT = RAcount)
          DECclick = STRSPLIT(DECclickStr, ' ', /EXTRACT, COUNT = DECcount)
          ;
          IF (RAcount EQ 3) or (DECcount EQ 3) THEN BEGIN
            RAclick   = 15D*TEN(RAclick)
            DECclick  = TEN(DECclick)
            RAclicks  = [RAclicks, RAclick]
            DECclicks = [DECclicks, DECclick]
            coordDone = 1
          ENDIF
        ENDWHILE
      END
      'X': BEGIN
        IF N_ELEMENTS(RAclicks) LT 3 $
          THEN PRINT, 'You must specify at least three positions.' $
          ELSE done = 1
      END
      ELSE: PRINT, 'Please enter one of the specified characters.'
    ENDCASE
  ENDWHILE
  ;
  ;Precess the astrometry points if necessary
  IF STRUPCASE(epoch) EQ 'B1950' THEN BEGIN
    RAclicks1 = RAclicks & DECclicks1 = DECclicks
    JPRECESS, RAclicks1, DECclicks1, RAclicks, DECclicks
  ENDIF
  ;
  ;Count the nember of triangles to be formed with the specified points
  numPts = N_ELEMENTS(RAclicks)
  numTri = (numPts)*(numPts - 1)*(numPts - 2)/6
  IF numTri GT 1 THEN BEGIN
    astrMatrix = DBLARR(2,2, numTri)
    ;
    ;Loop through each triangle and create the CDmatrix for each pairing
    triCount = 0
    FOR i = 0, numPts - 1 DO BEGIN
      FOR j = i + 1, numPts - 1 DO BEGIN
        FOR k = j + 1, numPts - 1 DO BEGIN
          ;
          ;Specify the coordinates for this triangle
          theseRAs  = [RAclicks[i],  RAclicks[j],  RAclicks[k]]
          theseDECs = [DECclicks[i], DECclicks[j], DECclicks[k]]
          theseXs   = [Xclicks[i],   Xclicks[j],   Xclicks[k]]
          theseYs   = [Yclicks[i],   Yclicks[j],   Yclicks[k]]
          ;
          ;Compute the astrometry for this individual triangle
          STARAST, theseRAs, theseDecs, theseXs, theseYs, CDmat
          ;
          ;Add the CDmatrix to the total set of CD arrays
          astrMatrix[*,*,triCount] = CDmat
          triCount++
        ENDFOR
      ENDFOR
    ENDFOR
    ;
    ;Now compute the median CD matrix
    CDmat = MEDIAN(astrMatrix, DIMENSION = 3)
  ENDIF ELSE BEGIN
    ;If only one triangle can be specified, then only one triangle is used...
    STARAST, RAclicks, DECclicks, Xclicks, Yclicks, CDmat
  ENDELSE
  ;
  ;Create a preliminary header with astrometry...
;  crpix = [Xclicks[0]+1, Yclicks[0]+1]
  crpix = [Xclicks[0], Yclicks[0]]
  crval = [RAclicks[0], DECclicks[0]]
  MKHDR, header, img2
  MAKE_ASTR, astr, CD = CDmat, CRPIX = crpix, CRVAL = crval
  PUTAST, header, astr
  ;
  ;Recombine the zoomed image into a grayscale image
  IF (numThree NE 0) THEN img2 = SQRT(TOTAL(img^2E, interleaving[0]))
  fitsFile = imgPath + PATH_SEP() + FILE_BASENAME(imgFile, extension) + 'astro.fits'
  WRITEFITS, fitsFile, img2, header

ENDIF ELSE PRINT, 'Could not query image file'
WDELETE, 0

END