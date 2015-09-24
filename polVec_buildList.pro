;********* Build Vector List ***********
;This script will allow the user to click on the end-points of a vector
;to specify both its location and its orientation in the solved astrometry of the galaxy.

;Get the image file path
imgFile = DIALOG_PICKFILE(TITLE='Select synchrotron map')
imgPath = FILE_DIRNAME(imgFile)

;Figure out what kind of image it is...
queryStatus = QUERY_IMAGE(imgFile, imageInfo)
extension   = (REVERSE(STRSPLIT(imgFile, '.', /EXTRACT)))[0]
fitsFile    = imgPath + PATH_SEP() + FILE_BASENAME(imgFile, extension) + 'astro.fits'
datFile     = imgPath + PATH_SEP() + FILE_BASENAME(imgFile, extension) + 'pols.dat'
fitsTest    = FILE_TEST(fitsFile)

;If the query was successful, then open the image
IF (STRLEN(imgFile) GT 0) AND fitsTest THEN BEGIN
  ;
  ;Open up the image file and determine its size and dimenions
  img       = READ_IMAGE(imgFile, R, G, B)
  imageDims   = imageInfo.dimensions
  imageSize   = SIZE(img, /DIMENSIONS)
  ;
  ;Read in the astrometry header from the previously saved .fits file
  header    = HEADFITS(fitsFile)
  EXTAST, header, astr
  GETROT, header, imgRot, cdelt
  ;
  ;Display the primary image to the user
  SHOW_IMAGE, img, imageInfo.dimensions, YSIZE = 700, WINDOW_ID = 0
  ; 
  ;Check if there is a previously written vector list and read it in...
  polFile     = imgPath + PATH_SEP() + FILE_BASENAME(imgFile, extension) + 'pols.dat'
  polFileTest = FILE_TEST(imgPath + PATH_SEP() + FILE_BASENAME(imgFile, extension) + 'pols.dat')
  IF polFileTest THEN BEGIN
    READCOL, datFile, polRA, polDec, polLen, polPA, COMMENT = ';', FORMAT = 'D,D,D,D'
    ;
    ;Convert (RA, Dec), polLen, and polPA to ((x1, y1), (x2, y2))
    AD2XY, polRA, polDec, astr, polX, polY
    xVec1 = polX - 0.5D*polLen*SIN((polPA + imgRot)*!DTOR)
    xVec2 = polX + 0.5D*polLen*SIN((polPA + imgRot)*!DTOR)
    yVec1 = polY + 0.5D*polLen*COS((polPA + imgRot)*!DTOR)
    yVec2 = polY - 0.5D*polLen*COS((polPA + imgRot)*!DTOR)
    ;
    ;Overplot the polarizations...
    numVecs = N_ELEMENTS(xVec1)
    FOR iVec = 0 , numVecs - 1 DO BEGIN
      PLOTS, [xVec1[iVec], xVec2[iVec]], $
        [yVec1[iVec], yVec2[iVec]], $
        THICK = 2, COLOR = '00ff00'x
    ENDFOR
  ENDIF ELSE BEGIN
    xVec1 = []
    xVec2 = []
    yVec1 = []
    yVec2 = []
  ENDELSE
  ;
  ;Enter a while-loop to extract polarizations
  done = 0
  input = ''  
  WHILE ~done DO BEGIN
    PRINT, 'Select one of the following options'
    PRINT, 'a: add polarization datum, d: delete polarization datum, x: exit loop'
    READ, input, PROMPT = '>> '
    
    CASE STRUPCASE(input) OF
      'A': BEGIN
        ;
        PRINT, 'Click on the approximate line segment location'
        CURSOR, xClick, yClick, /DATA, /DOWN
        ;
        ;Cut out the subarray
        lf = ROUND(xClick - 20) > 0
        rt = (lf + 40) < (imageDims[0] - 1)
        bt = ROUND(yClick - 20) > 0
        tp = (bt + 40) < (imageDims[1] - 1)
        PLOTS, [lf,lf,rt,rt,lf], [bt,tp,tp,bt,bt], COLOR = '00ff00'x
        ;
        ;Make sure the subarray is correct
        IF (numThree NE 0) THEN BEGIN
          CASE interleaving OF
            1: subarray = REBIN(img[*, lf:rt, bt:tp], imageSize[interleaving[0]-1], 410, 410)
            2: subarray = REBIN(img[lf:rt, *, bt:tp], imageSize[interleaving[0]-1], 410, 410)
            3: subarray = REBIN(img[lf:rt, bt:tp, *], imageSize[interleaving[0]-1], 410, 410)
          ENDCASE  
        ENDIF ELSE BEGIN
          subarray = REBIN(img1[lf:rt, bt:tp], 410, 410)
        ENDELSE
        ;
        ;Plot the subarray image
        SHOW_IMAGE, subarray, [410, 410], $
          WINDOW_ID = 1, $
          XSIZE=410, XPOS = 300, YPOS = 200
        ;
        ;Overplot the previously traced vectors
        vecsOnSubArr = WHERE(((xVec1 GT lf) OR (xVec2 GT lf)) AND $
                             ((xVec1 LT rt) OR (xVec2 LT rt)) AND $
                             ((yVec1 GT bt) OR (yVec2 GT bt)) AND $
                             ((yVec1 LT tp) OR (yVec2 LT tp)), numOnSubArr)
        IF numOnSubArr GT 0 THEN BEGIN
          FOR iVec = 0 , numOnSubArr - 1 DO BEGIN
            thisVec = vecsOnSubArr[iVec]
            thisX1  = (xVec1[thisVec] - lf)*10E
            thisX2  = (xVec2[thisVec] - lf)*10E
            thisY1  = (yVec1[thisVec] - bt)*10E
            thisY2  = (yVec2[thisVec] - bt)*10E
            PLOTS, [thisX1, thisX2], $
              [thisY1, thisY2], $
              THICK = 6, COLOR = '00ff00'x
          ENDFOR
        ENDIF
        ;
        ;Get the user to trace the new vector
        PRINT, 'Click on the line segment end points'
        CURSOR, x1, y1, /DATA, /DOWN
        OPLOT, [x1], [y1], PSYM = 4, COLOR = '0000ff'x, THICK = 2
        CURSOR, x2, y2, /DATA, /DOWN
        OPLOT, [x2], [y2], PSYM = 4, COLOR = '0000ff'x, THICK = 2
        PLOTS, [x1, x2], [y1, y2], COLOR = '00ff00'x, THICK = 6
        ;
        ;Adjust plate-scale, shift zero-point,
        ;and concatenate the vector to the list
        xVec1 = [xVec1, (x1/10E + lf)]
        xVec2 = [xVec2, (x2/10E + lf)]
        yVec1 = [yVec1, (y1/10E + bt)]
        yVec2 = [yVec2, (y2/10E + bt)]
        ;
        ;Reset the primary plotting window
        SHOW_IMAGE, img, imageInfo.dimensions, YSIZE = 700, WINDOW_ID = 0
        ;
        ;Overplot the polarizations...
        numVecs = N_ELEMENTS(xVec1)
        FOR iVec = 0 , numVecs - 1 DO BEGIN
          PLOTS, [xVec1[iVec], xVec2[iVec]], $
            [yVec1[iVec], yVec2[iVec]], $
            THICK = 2, COLOR = '00ff00'x
        ENDFOR
        ;
      END
      'D': BEGIN
        ;
        PRINT, 'Click on the line segment to delete'
        CURSOR, xClick, yClick, /DATA, /DOWN
        ;
        ;Compute the line segment locations
        polX = MEAN([[xVec1], [xVec2]], DIMENSION = 2)
        polY = MEAN([[yVec1], [yVec2]], DIMENSION = 2)
        polDist = SQRT((polX - xClick)^2E + (polY - yClick)^2E)
        minDist = MIN(polDist, minDistInd)
        ;
        ;Re-paint the overplotted vectors
        numVecs = N_ELEMENTS(xVec1)
        FOR iVec = 0 , numVecs - 1 DO BEGIN
          PLOTS, [xVec1[iVec], xVec2[iVec]], $
            [yVec1[iVec], yVec2[iVec]], $
            THICK = 2, COLOR = '00ff00'x
        ENDFOR
        ;
        ;Mark the selected vector
        PLOTS, [xVec1[minDistInd], xVec2[minDistInd]], $
          [yVec1[minDistInd], yVec2[minDistInd]], $
          THICK = 2, COLOR = '0000ff'x
        ;
        ;Ask the user to confirm the selection
        ynStr = ''
        PRINT, 'Delete the marked element? ("y" or "n")'
        READ, ynStr, PROMPT = '>> '
        ;
        CASE STRUPCASE(ynStr) OF
          'Y': BEGIN
            keepInds = WHERE(polDist GT minDist, numKeep)
            IF numKeep GT 0 THEN BEGIN
              xVec1 = xVec1[keepInds]
              yVec1 = yVec1[keepInds]
              xVec2 = xVec2[keepInds]
              yVec2 = yVec2[keepInds]
            ENDIF
          END
          ELSE: ynStr = 'N'
        ENDCASE
        ;
        ;Reset the primary plotting window
        SHOW_IMAGE, img, imageInfo.dimensions, YSIZE = 700, WINDOW_ID = 0
        ;
        ;Overplot the polarizations...
        numVecs = N_ELEMENTS(xVec1)
        FOR iVec = 0 , numVecs - 1 DO BEGIN
          PLOTS, [xVec1[iVec], xVec2[iVec]], $
            [yVec1[iVec], yVec2[iVec]], $
            THICK = 2, COLOR = '00ff00'x
        ENDFOR
      END
      'X': BEGIN
        ;
        ;Compute the polarization locations
        polX = MEAN([[xVec1], [xVec2]], DIMENSION = 2)
        polY = MEAN([[yVec1], [yVec2]], DIMENSION = 2)
        XY2AD, polX, polY, astr, polRA, polDec
        ;
        ;Compute polarization length and position angle (accounting for image rotation)
        polLen = SQRT((xVec1 - xVec2)^2E + (yVec1 - yVec2)^2E)
        deltaY = yVec1 - yVec2
        deltaX = xVec1 - xVec2
        polPA  = ((ATAN(deltaY, deltaX)*!RADEG - 90D + 360D) MOD 180D) - imgRot
        ;
        ;Write the results to file
        datFile = imgPath + PATH_SEP() + FILE_BASENAME(imgFile, extension) + 'pols.dat'
        OPENW, lun, datFile, /GET_LUN
        numPols = N_ELEMENTS(polX)
        PRINTF, lun, ';   RA              DEC             polLen          PA'
        FOR i = 0, numPols - 1 DO BEGIN
          PRINTF, lun, ' ' + STRING(polRA[i], polDec[i], polLen[i], polPA[i], $
                              FORMAT = '(4(F16.10))')
        ENDFOR
        FREE_LUN, lun      
        done = 1
      END
      ELSE: PRINT, 'Please enter one of the specified characters.'
    ENDCASE
  ENDWHILE
ENDIF ELSE PRINT, 'Could not query image file'

END