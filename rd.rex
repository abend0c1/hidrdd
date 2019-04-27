/*REXX*/
/* RDD! HID Report Descriptor Decoder v1.1.27

Copyright (c) 2011-2018, Andrew J. Armstrong
All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Author:
Andrew J. Armstrong <androidarmstrong@gmail.com> 
*/

trace off
  parse arg sCommandLine

  numeric digits 16
  
  g. = '' /* global variables */
  k. = '' /* global constants */
  o. = '' /* global options   */
  f. = '' /* global field names */

  call Prolog sCommandLine

  if getOption('--version')
  then do
    say getVersion()
    return
  end

  if getOption('--codes')
  then do
    call showCodes
    return
  end

  o.0HELP      = getOption('--help')
  if o.0HELP | sCommandLine = ''
  then do
    parse source . . sThis .
    say getVersion()
    say
    say 'This will read a USB Human Interface Device (HID) report descriptor from the'
    say 'specified input file then attempt to decode it and, optionally, create a'
    say 'C language header file from it. It also does some minimal sanity checks'
    say 'to verify that the report descriptor is valid.  The input file can be a'
    say 'binary file or a text file (for example, an existing C header file). If'
    say 'it is a text file, it will concatenate all the printable-hex-like text'
    say 'that it finds on each line (until the first non-hex sequence is found)'
    say 'into a single string of hex digits, and then attempt to decode that string.'
    say 'You can feed it an existing C header file and it will decode it as long'
    say 'as you have all the hex strings (e.g. 0x0F, 0x0Fb2) at the beginning of'
    say 'each line. Commas (,) and semicolons (;) are ignored. Specify the --right'
    say 'command line option if the hex strings are on the rightmost part of each line.'
    say 
    say 'Usage:'
    say '      rexx' sThis '[-h format] [-i fileinc] [-o fileout] [-dsvxOrb] -f filein'
    say '   or:'
    say '      rexx' sThis '[-h format] [-i fileinc] [-o fileout] [-dsvxO]  -c hex'
    say
    say 'Where:'
    say '      filein           = Input file path to be decoded'
    say '      fileout          = Output file (default is console)'
    say '      fileinc          = Include file of PAGE/USAGE definitions'
    say '      hex              = Printable hex to be decoded from command line'
    say '      format           = Type of output C header file format:'
    say '                         AVR    - AVR style'
    say '                         MIKROC - MikroElektronika mikroC Pro for PIC style'
    say '                         MCHIP  - Microchip C18 style'
    do i = 1 to g.0OPTION_INDEX.0
      say '      'left(strip(g.0OPTION_SHORT.i g.0OPTION_LONG.i),16) '=' g.0OPTION_DESC.i
    end
    say '      -vv              = Modifies --all so that even array field indices that'
    say '                         have blank usage descriptions are listed'
    say
    say 'Prerequisites:'
    say '      You need a REXX interpreter installed, such as'
    say '      1. Regina REXX      (http://regina-rexx.sourceforge.net)'
    say '      2. Open Object REXX (http://www.oorexx.org/)'
    say 
    say 'Examples:'
    say '      rexx' sThis '-d --hex 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0'
    say '      ...decodes the given hex string. Spaces are not significant'
    say
    say '      rexx' sThis '-sc 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0'
    say '      ...generates C structure declarations for the given hex string'
    say
    say '      rexx' sThis '-d -f myinputfile.h -o myoutputfile.txt'
    say '      ...decodes the hex strings found in myinputfile.h into myoutputfile.txt'
    say
    say '      rexx' sThis 'myinputfile.h'
    say '      ...generates C structure declarations for the hex strings found in myinputfile.h'
    say
    say '      rexx' sThis '--include mybuttonmap.txt myinputfile.h'
    say '      ...generates C structure declarations for the hex strings found in myinputfile.h'
    say '      using vendor-defined usages defined in mybuttonmap.txt'
    say
    say '      rexx' sThis '-dr usblyzer.txt'
    say '      ...decodes the hex strings found on the rightmost side of each line of the'
    say '      usblyzer.txt input file'
    return
  end

  o.0BINARY    = getOption('--binary')
  o.0VERBOSITY = getOption('--verbose')
  o.0STRUCT    = getOption('--struct')
  o.0DECODE    = getOption('--decode')
  o.0HEADER    = toUpper(getOption('--header',1))
  o.0DUMP      = getOption('--dump')
  o.0OUTPUT    = getOption('--output',1)
  o.0RIGHT     = getOption('--right')
  o.0ALL       = getOption('--all')
  o.0OPT       = getOption('--opt')

  if o.0OUTPUT <> ''
  then do
    if \openFile(o.0OUTPUT,'WRITE REPLACE')
    then do
      say 'Could not open output file:' sFileOut'. Using console'
      o.0OUTPUT = '' /* console */
    end 
  end

  if \(o.0DECODE | o.0STRUCT | o.0DUMP) /* If neither --decode nor --struct nor --dump was specified */
  then o.0STRUCT = 1          /* then assume --struct was specified */

  sData = ''
  select
    when getOptionCount('--file') > 0 then sFile = getOption('--file',1)
    when getOptionCount('--hex') > 0  then sData = getOption('--hex',1)
    otherwise sFile = g.0REST /* assume command line is the name of the input file */
  end

  xData = readDescriptor(sFile,sData)
  if xData = ''
  then do /* try reading hex values from the rightmost end of each line */
    o.0RIGHT = 1 /* force the --right option */
    xData = readDescriptor(sFile,sData)
  end

  if o.0DUMP
  then do
    call emitHeading 'Report descriptor data in hex (length' length(xData)/2 'bytes)'
    call say
    call dumpHex xData
    call say
  end

  featureField.0 = 0
  inputField.0 = 0
  outputField.0 = 0
  sCollectionStack = ''
  g.0INDENT = 0
  sData = x2c(xData)
  nIndent = 0
  nByte = 1
  do while nByte <= length(sData)
    sItem = getNext(1)
    sTag  = bitand(sItem,'11110000'b)
    sType = bitand(sItem,'00001100'b)
    sSize = bitand(sItem,'00000011'b)
    nSize = c2d(sSize)
    if nSize = 3 then nSize = 4
    select
      when sSize = '00000000'b then sParm = ''
      when sSize = '00000001'b then sParm = getNext(1)
      when sSize = '00000010'b then sParm = getNext(2)
      otherwise                     sParm = getNext(4)
    end
    xItem = c2x(sItem)
    xParm = c2x(sParm)
    sValue = reverse(sParm) /* 0xllhh --> 0xhhll */
    sMeaning = ''
    select
      when sType = k.0TYPE.MAIN   then call processMAIN
      when sType = k.0TYPE.GLOBAL then call processGLOBAL
      when sType = k.0TYPE.LOCAL  then call processLOCAL
      otherwise call emitDecode xItem,xParm,'ERROR',,,'<-- Error: Item ('xItem') is not a MAIN, GLOBAL or LOCAL item'
    end
  end
  if sCollectionStack <> ''
  then say 'Error: Missing END_COLLECTION MAIN tag (0xC0)'
  call Epilog
return

getVersion: procedure
  parse value sourceline(2) with . sVersion
return sVersion

readDescriptor: procedure expose g. k. o.
  parse arg sFile,sData
  if sData <> ''
  then do
    xData = space(sData,0)
    if \isHex(xData)
    then do
      say 'Expecting printable hexadecimal data. Found:' sData
      xData = ''
    end
  end
  else do
    xData = ''
    if openFile(sFile)
    then do
      if o.0BINARY
      then do
        sData = charin(sFile, 1, chars(sFile))
        xData = c2x(sData)
      end
      else do
        do while chars(sFile) > 0
          sLine = linein(sFile)
          sLine = translate(sLine,'',',;${}') /* Ignore some special chars */
          if o.0RIGHT
          then do /* scan from right to left for hex */
            xLine = ''
            do i = words(sLine) to 1 by -1
              sWord = word(sLine,i)
              select
                when left(sWord,2) = '0x' then sWord = substr(sWord,3)
                when left(sWord,1) = "'" then do
                  sWord = strip(sWord,'BOTH',"'")
                  if isHex(sWord)
                  then sWord = c2x(sWord)
                end
                otherwise nop
              end
              if isHex(sWord)
              then xLine = sWord || xLine /* prepend any hex data found */
              else leave /* stop when the first non-hexadecimal value is found */
            end
            xData = xData || xLine
          end
          else do /* scan from left to right for hex */
            parse var sLine sDefine sIdentifier sValue .
            if sDefine = '#define' & isIdentifier(sIdentifier) 
            then select
              when left(sValue,2) = '0x' then g.0DEFINE.sIdentifier = substr(sValue,3)               /* 0xYYYY  */
              when isDec(sValue)         then g.0DEFINE.sIdentifier = d2x(sValue,2)                  /* YYY     */
              when isChar(sValue)        then g.0DEFINE.sIdentifier = c2x(substr(sValue,2,1))        /* 'Y'     */
              when isString(sValue)      then g.0DEFINE.sIdentifier = strip(sValue,'BOTH','"')       /* "YYYY"  */
              otherwise nop 
            end
            else do i = 1 to words(sLine)
              sWord = strip(word(sLine,i),'TRAILING',',')
              select
                when g.0DEFINE.sWord <> '' then sWord = g.0DEFINE.sWord
                when left(sWord,2) = '0x' then sWord = substr(sWord,3)
                when left(sWord,1) = "'" then do
                  sWord = strip(sWord,'BOTH',"'")
                  if isHex(sWord)
                  then sWord = c2x(sWord)
                end
                otherwise nop
              end
              if isHex(sWord)
              then xData = xData || sWord /* append any hex data found */
              else leave /* stop when the first non-hexadecimal value is found */
            end
          end
        end
      end
      rc = closeFile(sFile)  
    end
    else say 'Could not open file' sFile
  end
return xData

isIdentifier: procedure
  arg firstletter +1 0 name
  bIsIdentifier = verify(firstletter,'ABCDEFGHIJKLMNOPQRSTUVWXYZ_','NOMATCH') = 0,
                & verify(name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789','NOMATCH') = 0
return bIsIdentifier

processMAIN:
  xValue = right(c2x(sValue),8,'0')
  select
    when sTag = k.0MAIN.INPUT then do
      sFlags = getInputFlags()
      call emitDecode xItem,xParm,'MAIN','INPUT',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sFlags getSanity(sValue)
      if g.0IN_NAMED_ARRAY_COLLECTION = 1
      then g.0USAGE = g.0NAMED_ARRAY_USAGE
      n = inputField.0 + 1
      inputField.n = xValue getGlobals()','getLocals()','g.0USAGES','sFlags','f.0COLLECTION_NAME
      inputField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.OUTPUT then do
      sFlags = getOutputFlags()
      call emitDecode xItem,xParm,'MAIN','OUTPUT',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sFlags getSanity(sValue)
      if g.0IN_NAMED_ARRAY_COLLECTION = 1
      then g.0USAGE = g.0NAMED_ARRAY_USAGE
      n = outputField.0 + 1
      outputField.n = xValue getGlobals()','getLocals()','g.0USAGES','sFlags','f.0COLLECTION_NAME
      outputField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.FEATURE then do
      sFlags = getFeatureFlags()
      call emitDecode xItem,xParm,'MAIN','FEATURE',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sFlags getSanity(sValue)
      if g.0IN_NAMED_ARRAY_COLLECTION = 1
      then g.0USAGE = g.0NAMED_ARRAY_USAGE
      n = featureField.0 + 1
      featureField.n = xValue getGlobals()','getLocals()','g.0USAGES','sFlags','f.0COLLECTION_NAME
      featureField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.COLLECTION then do
      g.0EXPECTED_COLLECTION_USAGE = ''
      xExtendedUsage = g.0USAGE
      sCollectionName = getUsageDesc(xExtendedUsage)
      sCollectionType = getCollectionType(xValue)
      f.0COLLECTION_NAME = strip(f.0COLLECTION_NAME sCollectionType':'space(sCollectionName,0))
      nValue = c2d(sValue)
      sCollectionStack = nValue sCollectionStack /* push onto collection stack */
      select 
        when nValue > 127 then sMeaning = 'Vendor Defined'
        when nValue > 6   then sMeaning = 'Reserved'
        otherwise do
          sUsageTypeCode = getUsageTypeCode(xExtendedUsage)
          sMeaning = getCollectionDesc(xValue) '(Usage=0x'xExtendedUsage':',
                                           'Page='getPageDesc(xExtendedUsage)',',
                                           'Usage='getUsageDesc(xExtendedUsage)',',
                                           'Type='getUsageType(xExtendedUsage)')'
          if sUsageTypeCode = ''
          then do
            sMeaning = sMeaning '<-- Error: COLLECTION must be preceded by a USAGE'
          end
          if left(xExtendedUsage,2) <> 'FF' & pos(sCollectionType,sUsageTypeCode) = 0
          then sMeaning = sMeaning '<-- Warning: USAGE type should be' sCollectionType '('getCollectionDesc(xValue)' Collection)'
        end
      end
      if sCollectionType = 'CA' 
      then g.0IN_APP_COLLECTION = 1
      else do
        if \g.0IN_APP_COLLECTION 
        then sMeaning = sMeaning '<-- Error: No enclosing Application Collection'
      end
      if sCollectionType = 'NA'
      then do
        g.0IN_NAMED_ARRAY_COLLECTION = 1
        g.0NAMED_ARRAY_USAGE = xExtendedUsage /* remember so a field name can be generated later */
      end
      if g.0IN_DELIMITER
      then sMeaning = sMeaning '<-- Error: DELIMITER set has not been closed'
      call emitDecode xItem,xParm,'MAIN','COLLECTION',right(xValue,2),sMeaning
      g.0INDENT = g.0INDENT + 2
      call clearLocals
    end
    when sTag = k.0MAIN.END_COLLECTION then do
      g.0IN_NAMED_ARRAY_COLLECTION = 0
      if length(sValue) <> 0
      then sMeaning = '<-- Error: Data ('c2x(sValue)') is not applicable to END_COLLECTION items'
      parse var sCollectionStack nCollectionType sCollectionStack /* pop the collection stack */
      if nCollectionType = ''
      then do 
        call emitDecode xItem,xParm,'MAIN','END_COLLECTION',,sMeaning '<-- Error: Superfluous END_COLLECTION'
      end
      else do
        /* This is a reasonable place to warn if physical units are still being applied.
           If physical units are not reset to 0 after they are needed, then they will be
           applied to ALL subsequent LOGICAL_MINIMUM and LOGICAL_MAXIMUM values.
        */
        if isSpecified(g.0PHYSICAL_MINIMUM) | isSpecified(g.0PHYSICAL_MAXIMUM) | isSpecified(g.0UNIT) | isSpecified(g.0UNIT_EXPONENT)
        then do 
          sMeaning = sMeaning '<-- Warning: Physical units are still in effect' getFormattedPhysicalUnits()
        end
        g.0INDENT = g.0INDENT - 2
        xCollectionType = d2x(nCollectionType,2)
        if g.0IN_DELIMITER
        then sMeaning = sMeaning '<-- Error: DELIMITER set has not been closed'
        call emitDecode xItem,xParm,'MAIN','END_COLLECTION',,getCollectionDesc(xCollectionType) sMeaning
      end
      n = words(f.0COLLECTION_NAME)
      if n > 0
      then do
        f.0COLLECTION_NAME = subword(f.0COLLECTION_NAME,1,n-1)
      end
      if nCollectionType = 1 /* Application Collection */
      then do
        if o.0DECODE
        then do
          call emitCloseDecode
        end
        if o.0STRUCT 
        then do
          if featureField.0 > 0 then call emitFeatureFields
          if inputField.0 > 0   then call emitInputFields
          if outputField.0 > 0  then call emitOutputFields
        end
        featureField.0 = 0
        inputField.0 = 0
        outputField.0 = 0
      end
      call clearLocals
    end
    otherwise call emitDecode xItem,xParm,'MAIN',,,'<-- Error: Item ('xItem') is not a MAIN item. Expected INPUT(8x) OUTPUT(9x) FEATURE(Bx) COLLECTION(Ax) or END_COLLECTION(Cx) (where x = 0,1,2,3).'
  end
return

processGLOBAL:
  xValue = c2x(sValue)
  nValue = x2d(xValue,2*length(sValue))
  select
    when sTag = k.0GLOBAL.USAGE_PAGE then do
      select
        when nValue = 0     then sMeaning = '<-- Error: USAGE_PAGE must not be 0'
        when nValue > 65535 then sMeaning = '<-- Error: USAGE_PAGE must be in the range 0x0001 to 0xFFFF'
        otherwise do
          xPage = right(xValue,4,'0')
          call loadPage xPage
          xValue = xPage 
          sMeaning = getPageDesc(xPage) updateHexValue('USAGE_PAGE',xValue)
        end
      end
    end
    when sTag = k.0GLOBAL.LOGICAL_MINIMUM then do
      sMeaning = '('nValue')' updateValue('LOGICAL_MINIMUM',nValue) recommendedSize()
    end
    when sTag = k.0GLOBAL.LOGICAL_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('LOGICAL_MAXIMUM',nValue) recommendedSize()
    end
    when sTag = k.0GLOBAL.PHYSICAL_MINIMUM then do
      sMeaning = '('nValue')' updateValue('PHYSICAL_MINIMUM',nValue) recommendedSize()
    end
    when sTag = k.0GLOBAL.PHYSICAL_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('PHYSICAL_MAXIMUM',nValue) recommendedSize()
    end
    when sTag = k.0GLOBAL.UNIT_EXPONENT then do
      nUnitExponent = getUnitExponent(nValue) 
      sMeaning = '(Unit Value x 10'getSuperscript(nUnitExponent)')' updateValue('UNIT_EXPONENT',nUnitExponent) recommendedSize()
    end
    when sTag = k.0GLOBAL.UNIT then do
      xValue8 = right(xValue,8,'0')
      nValue = x2d(xValue8)
      parse var k.0UNIT.xValue8 sUnitDesc','
      sMeaning = sUnitDesc '('getUnit(xValue8)')' updateHexValue('UNIT',xValue8) recommendedSize()
    end
    when sTag = k.0GLOBAL.REPORT_SIZE then do
      nValue = x2d(xValue) /* REPORT_SIZE is an unsigned value */
      sMeaning = '('nValue') Number of bits per field' updateValue('REPORT_SIZE',nValue) recommendedSize()
      if nValue = 0
      then sMeaning = sMeaning '<-- Error: REPORT_SIZE must be > 0'
    end
    when sTag = k.0GLOBAL.REPORT_ID then do
      nValue = x2d(xValue) /* REPORT_ID is an unsigned value */
      c = x2c(xValue)
      if isAlphanumeric(c)
      then sMeaning = '('x2d(xValue)')' "'"c"'" updateHexValue('REPORT_ID',xValue) recommendedSize()
      else sMeaning = '('x2d(xValue)')'         updateHexValue('REPORT_ID',xValue) recommendedSize()
      if nValue = 0 then sMeaning = sMeaning '<-- Error: REPORT_ID 0x00 is reserved'
      if nValue > 255 then sMeaning = sMeaning '<-- Error: REPORT_ID must be in the range 0x01 to 0xFF'
    end
    when sTag = k.0GLOBAL.REPORT_COUNT then do
      nValue = x2d(xValue) /* REPORT_COUNT is an unsigned value */
      sMeaning = '('nValue') Number of fields' updateValue('REPORT_COUNT',nValue) recommendedSize()
      if nValue = 0
      then sMeaning = sMeaning '<-- Error: REPORT_COUNT must be > 0'
    end
    when sTag = k.0GLOBAL.PUSH then do
      call pushStack getGlobals()
      sMeaning = getFormattedGlobalsLong()
      if nSize <> 0
      then sMeaning = sMeaning '<-- Error: PUSH data field size must be 0 (0x'xValue 'ignored)'
      xValue = ''
    end
    when sTag = k.0GLOBAL.POP then do
      if nSize <> 0
      then sMeaning = sMeaning '<-- Error: POP data field size must be 0 (0x'xValue 'ignored)'
      if isStackEmpty()
      then sMeaning = sMeaning '<-- Error: No preceding PUSH'
      else do
        call setGlobals popStack()
        sMeaning = getFormattedGlobalsLong() sMeaning
      end
      xValue = ''
    end
    otherwise sMeaning = '<-- Error:  Item ('xItem') is not a GLOBAL item. Expected 0x, 1x, 2x, 3x, 4x, 5x, 6x, 7x, 8x, 9x, Ax or Bx (where x = 4,5,6,7)'
  end
  call emitDecode xItem,xParm,'GLOBAL',k.0GLOBAL.sTag,xValue,sMeaning
return

addUsage: procedure expose g. k.
  parse arg xUsage
  g.0USAGES = g.0USAGES xUsage
return  

processLOCAL:
  xValue = c2x(sValue)
  nValue = x2d(xValue,2*length(sValue))
  xPage = right(g.0USAGE_PAGE,4,'0')
  bIndent = 0
  select
    when sTag = k.0LOCAL.USAGE then do
      if length(sValue) = 4 & left(sValue,2) <> '0000'x 
      then do /* Both page and usage are specified: ppppuuuu */
        xExtendedUsage = xValue
        xPage = left(xValue,4)
        call loadPage xPage
        sUsageMeaning = getPageAndUsageMeaning(xValue)
        sMeaning =  sUsageMeaning updateHexValue('USAGE',xValue)
      end
      else do /* Only usage is specified: uuuu */
        xUsage = right(xValue,4,'0')
        xValue = xPage || xUsage
        xExtendedUsage = xValue
        sUsageMeaning = getUsageMeaning(xValue)
        sMeaning =  sUsageMeaning updateHexValue('USAGE',xValue) recommendedUnsignedSize()
        if xPage = '0000'
        then sMeaning = sMeaning '<-- Error: USAGE_PAGE must not be 0'
      end
      if sMeaning = '' 
      then sMeaning = undocumentedUsage(xValue)
      if g.0IN_DELIMITER
      then do /* only use the first usage in the delimited set */
        if g.0FIRST_USAGE
        then call addUsage xValue
        g.0FIRST_USAGE = 0 
      end
      else call addUsage xValue
      sUsageTypeCode = getUsageTypeCode(xExtendedUsage)
      if isInSet(sUsageTypeCode,"CP CA CL CACL CACP CLCP CR NAry UM US") /* If this is a USAGE for a COLLECTION */
      then do
        g.0EXPECTED_COLLECTION_USAGE = '0x'xExtendedUsage sUsageMeaning
        g.0EXPECTED_COLLECTION_ITEM  = 'A1' getCollectionCode(sUsageTypeCode)
      end
      else do /* This USAGE is not for a COLLECTION */
        if g.0EXPECTED_COLLECTION_USAGE <> ''
        then do
          parse var g.0EXPECTED_COLLECTION_ITEM . xCollectionType 
          sCollectionType = getCollectionDesc(xCollectionType)
          sMeaning = sMeaning '<-- Error:' sCollectionType 'COLLECTION item ('g.0EXPECTED_COLLECTION_ITEM') expected for USAGE' g.0EXPECTED_COLLECTION_USAGE
        end
        else do 
          if g.0IN_NAMED_ARRAY_COLLECTION & \isInSet(sUsageTypeCode,'Sel MULTI SFDFSEL')
          then sMeaning = sMeaning '<-- Error: A Named Array Collection must only contain Selector USAGEs'
        end
        g.0EXPECTED_COLLECTION_USAGE = '' /* stops further nagging */
      end
    end
    when sTag = k.0LOCAL.USAGE_MINIMUM then do
      if length(sValue) = 4 & left(sValue,2) <> '0000'x
      then do /* Both page and usage are specified: ppppuuuu */
        xPage = left(xValue,4)
        call loadPage xPage
        sMeaning = getPageAndUsageMeaning(xValue) updateHexValue('USAGE_MINIMUM',xValue)
      end
      else do /* Only usage is specified: uuuu */
        xUsage = right(xValue,4,'0')
        xValue = xPage || xUsage
        sMeaning = getUsageMeaning(xValue) updateHexValue('USAGE_MINIMUM',xValue) recommendedUnsignedSize()
        if xPage = '0000'
        then sMeaning = sMeaning '<-- Error: USAGE_PAGE must not be 0'
      end
      if sMeaning = '' 
      then sMeaning = undocumentedUsage(xValue)
      if isSpecified(g.0USAGE_MAXIMUM)
      then call appendRangeOfUsages
    end
    when sTag = k.0LOCAL.USAGE_MAXIMUM then do
      if length(sValue) = 4 & left(sValue,2) <> '0000'x
      then do /* Both page and usage are specified: ppppuuuu */
        xPage = left(xValue,4)
        call loadPage xPage
        sMeaning = getPageAndUsageMeaning(xValue) updateHexValue('USAGE_MAXIMUM',xValue)
      end
      else do /* Only usage is specified: uuuu */
        xUsage = right(xValue,4,'0')
        xValue = xPage || xUsage
        sMeaning = getUsageMeaning(xValue) updateHexValue('USAGE_MAXIMUM',xValue) recommendedUnsignedSize()
        if xPage = '0000'
        then sMeaning = sMeaning '<-- Error: USAGE_PAGE must not be 0'
      end
      if sMeaning = '' 
      then sMeaning = undocumentedUsage(xValue)
      if isSpecified(g.0USAGE_MINIMUM)
      then call appendRangeOfUsages
    end
    when sTag = k.0LOCAL.DESIGNATOR_INDEX then do
      sMeaning = '('nValue')' updateValue('DESIGNATOR_INDEX',nValue) recommendedSize()
    end
    when sTag = k.0LOCAL.DESIGNATOR_MINIMUM then do
      sMeaning = '('nValue')' updateValue('DESIGNATOR_MINIMUM',nValue) recommendedSize()
    end
    when sTag = k.0LOCAL.DESIGNATOR_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('DESIGNATOR_MAXIMUM',nValue) recommendedSize()
    end
    when sTag = k.0LOCAL.STRING_INDEX then do
      sMeaning = '('nValue')' updateValue('STRING_INDEX',nValue) recommendedSize()
    end
    when sTag = k.0LOCAL.STRING_MINIMUM then do
      sMeaning = '('nValue')' updateValue('STRING_MINIMUM',nValue) recommendedSize()
    end
    when sTag = k.0LOCAL.STRING_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('STRING_MAXIMUM',nValue) recommendedSize()
    end
    when sTag = k.0LOCAL.DELIMITER then do
      select
        when nValue = 1 then do
          sMeaning = '('nValue') Open set' recommendedSize()
          if g.0IN_DELIMITER
          then sMeaning = sMeaning '<-- Error: Already in a DELIMITER set'
          g.0IN_DELIMITER = 1
          g.0FIRST_USAGE = 1
          bIndent = 1
        end
        when nValue = 0 then do
          sMeaning = '('nValue') Close set' recommendedSize()
          if \g.0IN_DELIMITER
          then sMeaning = sMeaning '<-- Error: Not already in a DELIMITER set'
          g.0IN_DELIMITER = 0
          g.0INDENT = g.0INDENT - 2
        end
        otherwise sMeaning = '('nValue') <-- Error: DELIMITER data field ('nValue') must be 0 (CLOSE) or 1 (OPEN)'
      end
    end
    otherwise sMeaning = '<-- Error: Item ('xItem') is not a LOCAL item. Expected 0x, 1x, 2x, 3x, 4x, 5x, 7x, 8x, 9x or Ax (where x = 8,9,A,B)'
  end
  call emitDecode xItem,xParm,'LOCAL',k.0LOCAL.sTag,xValue,sMeaning
  if bIndent
  then do
    g.0INDENT = g.0INDENT + 2
    bIndent = 0
  end
return

undocumentedUsage: procedure
  parse arg xPage +4 xUsage +4
return '<-- Warning: Undocumented usage (document it by inserting' xUsage 'into file' xPage'.conf)'

appendRangeOfUsages:
  if left(g.0USAGE_MINIMUM,4) <> left(g.0USAGE_MAXIMUM,4)
  then sMeaning = sMeaning '<-- Error: USAGE_PAGE for USAGE_MAXIMUM and USAGE_MINIMUM must be the same' 
  else do
    nUsageMin = x2d(g.0USAGE_MINIMUM)
    nUsageMax = x2d(g.0USAGE_MAXIMUM)
    if nUsageMax < nUsageMin
    then do
      sMeaning = sMeaning '<-- Error: USAGE_MININUM ('g.0USAGE_MINIMUM') must be less than USAGE_MAXIMUM ('g.0USAGE_MAXIMUM')'
      temp = g.0USAGE_MAXIMUM /* Compromise: swap USAGE_MINIMUM and USAGE_MAXIMUM */
      g.0USAGE_MAXIMUM = g.0USAGE_MINIMUM
      g.0USAGE_MINIMUM = temp 
      nUsageMin = x2d(g.0USAGE_MINIMUM)
      nUsageMax = x2d(g.0USAGE_MAXIMUM)
    end
    if nUsageMax - nUsageMin + 1 < 3 /* 1 or 2 usages can be more efficiently specified as individual usages */
    then sMeaning = sMeaning '<-- Info: Consider specifying individual USAGEs instead of USAGE_MINIMUM/USAGE_MAXIMUM'
    do nExtendedUsage = nUsageMin to nUsageMax
      xExtendedUsage = d2x(nExtendedUsage,8)
      call addUsage xExtendedUsage
    end
    g.0USAGE_MINIMUM = 0
    g.0USAGE_MAXIMUM = 0
  end
return

loadPage: procedure expose g. k.
  parse arg xPage +4
  if g.0CACHED.xPage = 1 then return
  call loadUsageFile xPage'.conf'
  g.0CACHED.xPage = 1
return

getSanity: procedure expose g.
  parse arg sFlags
  sError = ''
  if isUndefined(g.0REPORT_SIZE)  then sError = sError '<-- Error: REPORT_SIZE is undefined'
  if g.0REPORT_SIZE = 0           then sError = sError '<-- Error: REPORT_SIZE must not be 0'
  if isUndefined(g.0REPORT_COUNT) then sError = sError '<-- Error: REPORT_COUNT is undefined'
  if g.0REPORT_COUNT = 0          then sError = sError '<-- Error: REPORT_COUNT must not be 0'
  if \isConstant(sFlags)
  then do
    if isUndefined(g.0LOGICAL_MINIMUM) then sError = sError '<-- Error: LOGICAL_MINIMUM is undefined'
    if isUndefined(g.0LOGICAL_MAXIMUM) then sError = sError '<-- Error: LOGICAL_MAXIMUM is undefined'
    if isDefined(g.0LOGICAL_MINIMUM) & isDefined(g.0LOGICAL_MAXIMUM) & isDefined(g.0REPORT_SIZE) & isDefined(g.0REPORT_COUNT)
    then do
      nBitsForLogicalMinimum = getMinBits(g.0LOGICAL_MINIMUM)
      if g.0REPORT_SIZE < nBitsForLogicalMinimum
      then sError = sError '<-- Error: REPORT_SIZE ('g.0REPORT_SIZE') is too small for LOGICAL_MINIMUM ('g.0LOGICAL_MINIMUM') which needs' nBitsForLogicalMinimum 'bits.'
      nBitsForLogicalMaximum = getMinBits(g.0LOGICAL_MAXIMUM)
      if g.0REPORT_SIZE < nBitsForLogicalMaximum
      then sError = sError '<-- Error: REPORT_SIZE ('g.0REPORT_SIZE') is too small for LOGICAL_MAXIMUM ('g.0LOGICAL_MAXIMUM') which needs' nBitsForLogicalMaximum 'bits.'
      if g.0LOGICAL_MAXIMUM < g.0LOGICAL_MINIMUM
      then sError = sError '<-- Error: LOGICAL_MAXIMUM ('g.0LOGICAL_MAXIMUM') is less than LOGICAL_MINIMUM ('g.0LOGICAL_MINIMUM')'
    end
    if isDefined(g.0PHYSICAL_MINIMUM) & isUndefined(g.0PHYSICAL_MAXIMUM)
    then sError = sError '<-- Error: PHYSICAL_MAXIMUM is undefined'
    if isUndefined(g.0PHYSICAL_MINIMUM) & isDefined(g.0PHYSICAL_MAXIMUM)
    then sError = sError '<-- Error: PHYSICAL_MINIMUM is undefined'
    if isDefined(g.0PHYSICAL_MINIMUM) & isDefined(g.0PHYSICAL_MAXIMUM)
    then do
      if g.0PHYSICAL_MAXIMUM < g.0PHYSICAL_MINIMUM
      then sError = sError '<-- Error: PHYSICAL_MAXIMUM ('g.0PHYSICAL_MAXIMUM') is less than PHYSICAL_MINIMUM ('g.0PHYSICAL_MINIMUM')'
    end
  end
  if g.0IN_DELIMITER
  then sMeaning = sMeaning '<-- Error: DELIMITER set has not been closed'
return sError

isUndefined: procedure
  arg nValue
return nValue = ''

isDefined: procedure
  arg nValue
return nValue <> ''

isInSet: procedure
  arg sKey,sSet 
return wordpos(sKey,sSet) > 0

getMinBits: procedure 
  parse arg n
  if n < 0
  then nMinBits = length(strip(x2b(d2x(n,16)),'LEADING','1')) + 1
  else nMinBits = length(strip(x2b(d2x(n,16)),'LEADING','0'))
return nMinBits

recommendedSize: procedure expose g. xItem xParm nValue nSize
  sItem0 = bitand(x2c(xItem),'11111100'b)
  xItem0 = c2x(sItem0)
  xItem1 = c2x(bitor(sItem0,'00000001'b))
  xItem2 = c2x(bitor(sItem0,'00000010'b))
  xItem4 = c2x(bitor(sItem0,'00000011'b))
  select 
    when nSize = 0 then do
    end
    when nSize = 1 then do
      select
        when nValue = 0                   then return '<-- Info: Consider replacing' xItem xParm 'with' xItem0
        otherwise nop
      end
    end
    when nSize = 2 then do
      select
        when nValue = 0                   then return '<-- Info: Consider replacing' xItem xParm 'with' xItem0
        when inRange(nValue,-128,127)     then return '<-- Info: Consider replacing' xItem xParm 'with' xItem1 left(xParm,2)
        otherwise nop
      end
    end
    when nSize = 4 then do
      select
        when nValue = 0                   then return '<-- Info: Consider replacing' xItem xParm 'with' xItem0
        when inRange(nValue,-128,127)     then return '<-- Info: Consider replacing' xItem xParm 'with' xItem1 left(xParm,2)
        when inrange(nValue,-32768,32767) then return '<-- Info: Consider replacing' xItem xParm 'with' xItem2 left(xParm,4)
        otherwise nop
      end
    end
    otherwise nop 
  end
return ''

recommendedUnsignedSize: procedure expose g. xItem xParm sValue nSize
  uValue = c2d(sValue) /* unsigned interpretation of sValue */
  sItem0 = bitand(x2c(xItem),'11111100'b)
  xItem0 = c2x(sItem0)
  xItem1 = c2x(bitor(sItem0,'00000001'b))
  xItem2 = c2x(bitor(sItem0,'00000010'b))
  xItem4 = c2x(bitor(sItem0,'00000011'b))
  select 
    when nSize = 0 then do
    end
    when nSize = 1 then do
      select
        when uValue = 0                   then return '<-- Info: Consider replacing' xItem xParm 'with' xItem0
        otherwise nop
      end
    end
    when nSize = 2 then do
      select
        when uValue = 0                   then return '<-- Info: Consider replacing' xItem xParm 'with' xItem0
        when inRange(uValue,0,255)        then return '<-- Info: Consider replacing' xItem xParm 'with' xItem1 left(xParm,2)
        otherwise nop
      end
    end
    when nSize = 4 then do
      select
        when nValue = 0                   then return '<-- Info: Consider replacing' xItem xParm 'with' xItem0
        when inRange(uValue,0,255)        then return '<-- Info: Consider replacing' xItem xParm 'with' xItem1 left(xParm,2)
        when inrange(uValue,0,65535)      then return '<-- Info: Consider replacing' xItem xParm 'with' xItem2 left(xParm,4)
        otherwise nop
      end
    end
    otherwise nop 
  end
return ''

inRange: procedure 
  parse arg n,min,max
return n >= min & n <= max  

updateValue: procedure expose g.
  parse arg sName,nValue
  sKey = '0'sName
  if g.sKey = nValue & sName <> 'USAGE' 
  then do
    g.0REDUNDANT = 1
    sWarning = '<-- Redundant:' sName 'is already' nValue
  end
  else do
    g.sKey = nValue
    sWarning = ''
  end
return sWarning

updateHexValue: procedure expose g.
  parse arg sName,xValue
  sKey = '0'sName
  if x2d(g.sKey) = x2d(xValue) & sName <> 'USAGE' 
  then do
    g.0REDUNDANT = 1
    sWarning = '<-- Redundant:' sName 'is already 0x'xValue
  end
  else do
    g.sKey = xValue
    sWarning = ''
  end
return sWarning

getDimension: procedure 
  parse arg nCount,nBits
return '('getQuantity(nCount,'field','fields') 'x' getQuantity(nBits, 'bit', 'bits')')'

dumpHex: procedure expose g. o.
  parse upper arg xData
  do while xData <> ''
    parse var xData x1 +8 x2 +8 x3 +8 x4 +8 x5 +8 x6 +8 x7 +8 x8 +8 xData
    call say '//' x1 x2 x3 x4 x5 x6 x7 x8
  end
return

getStatement: procedure
  parse arg sType sName,sComment
  sLabel = left(sType,8) sName
return left(sLabel, max(length(sLabel),50)) '//' sComment

emitInputFields: procedure expose inputField. k. o. f.
  /* Cycle through all the input fields accumulated and when the report_id
     changes, then emit a new structure */
  xLastReportId = 'unknown'
  do i = 1 to inputField.0
    parse var inputField.i xFlags sGlobals','sLocals','
    call setGlobals sGlobals
    call setLocals sLocals
    if xLastReportId <> g.0REPORT_ID
    then do /* The report id has changed */
      if i > 1 
      then call emitEndStructure 'inputReport',xLastReportId
      call emitBeginStructure 'inputReport',g.0REPORT_ID,'Device --> Host'
      xLastReportId = g.0REPORT_ID
    end
    call emitField i,inputField.i
  end
  call emitEndStructure 'inputReport',xLastReportId
return            

emitOutputFields: procedure expose outputField. k. o. f.
  /* Cycle through all the output fields accumulated and when the report_id
     changes, then emit a new structure */
  xLastReportId = 'unknown'
  do i = 1 to outputField.0
    parse var outputField.i xFlags sGlobals','sLocals','
    call setGlobals sGlobals
    call setLocals sLocals
    if xLastReportId <> g.0REPORT_ID
    then do /* The report id has changed */
      if i > 1 
      then call emitEndStructure 'outputReport',xLastReportId
      call emitBeginStructure 'outputReport',g.0REPORT_ID,'Device <-- Host'
      xLastReportId = g.0REPORT_ID
    end
    call emitField i,outputField.i
  end
  call emitEndStructure 'outputReport',xLastReportId
return            

emitFeatureFields: procedure expose featureField. k. o. f.
  /* Cycle through all the feature fields accumulated and when the report_id
     changes, then emit a new structure */
  xLastReportId = 'unknown'
  do i = 1 to featureField.0
    parse var featureField.i xFlags sGlobals','sLocals','
    call setGlobals sGlobals
    call setLocals sLocals
    if xLastReportId <> g.0REPORT_ID
    then do /* The report id has changed */
      if i > 1 
      then call emitEndStructure 'featureReport',xLastReportId
      call emitBeginStructure 'featureReport',g.0REPORT_ID,'Device <-> Host'
      xLastReportId = g.0REPORT_ID
    end
    call emitField i,featureField.i
  end
  call emitEndStructure 'featureReport',xLastReportId
return            

emitBeginStructure: procedure expose g. k. f. o.
  parse arg sStructureName,xReportId,sDirection
  f.0LASTCOLLECTION = ''
  if isSpecified(xReportId)
  then do
    f.0TYPEDEFNAME = getUniqueName(sStructureName || xReportId)'_t'
    call emitHeading getPageDesc(g.0USAGE_PAGE) sStructureName xReportId '('sDirection')'
    call say 'typedef struct'
    call say '{'
    c = x2c(xReportId)
    if isAlphanumeric(c)
    then sDesc = '('x2d(xReportId)')' "'"c"'"
    else sDesc = '('x2d(xReportId)')'
    call say '  'getStatement(k.0U8 'reportId;','Report ID = 0x'xReportId sDesc)
  end
  else do
    f.0TYPEDEFNAME = getUniqueName(sStructureName)'_t'
    call emitHeading getPageDesc(g.0USAGE_PAGE) sStructureName '('sDirection')'
    call say 'typedef struct'
    call say '{'
    call say '  'getStatement(,'No REPORT ID byte')
  end
return

emitEndStructure: procedure expose g. f. o.
  parse arg sStructureName,xReportId
  call say '}' f.0TYPEDEFNAME';'
  call say
return

emitHeading: procedure expose o.
  parse arg sHeading
  call say 
  call say '//--------------------------------------------------------------------------------'
  call say '//' sHeading
  call say '//--------------------------------------------------------------------------------'
  call say 
return  

emitUsages: procedure expose o. 
  arg xUsages
  nUsagesPerLine = 8
  nUsages = words(xUsages)
  xFirstUsages = subword(xUsages,1,nUsagesPerLine)
  call say '  // Usages: ' xFirstUsages
  if nUsages > nUsagesPerLine
  then do i = nUsagesPerLine+1 to nUsages by nUsagesPerLine
    call say '  //         ' subword(xUsages,i,nUsagesPerLine)
  end
return

emitField: procedure expose k. o. f.
  parse arg nField,xFlags sGlobals','sLocals','xUsages','sFlags','sCollectionNames
  call setGlobals sGlobals
  call setLocals sLocals
  sCollectionName = getCollectionName(sCollectionNames)
  if o.0VERBOSITY > 0
  then do
    call say
    call say '  // Field:  ' nField
    call say '  // Width:  ' g.0REPORT_SIZE
    call say '  // Count:  ' g.0REPORT_COUNT
    call say '  // Flags:  ' xFlags':' sFlags
    call say '  // Globals:' getFormattedGlobals()
    call say '  // Locals: ' getFormattedLocals()
    call emitUsages xUsages
    call say '  // Coll:   ' sCollectionNames
  end
  sFlags = x2c(xFlags)
  nUsages = words(xUsages)
  g.0FIELD_TYPE = getFieldType()
  if o.0VERBOSITY > 0
  then do
    if isData(sFlags)
    then do /* data i.e. can be changed */
      call say '  // Access:  Read/Write'
    end
    else do
      call say '  // Access:  Read/Only'
    end
  end
  xPage = g.0USAGE_PAGE
  /*
   *-----------------------------------------------------------
   * VARIABLE
   *-----------------------------------------------------------
  */
  if isVariable(sFlags)
  then do /* variable: one named field per usage, value = actual control value */
    /* REPORT_COUNT is the number of fields.
       REPORT_SIZE is the size of each field (in bits).
       LOGICAL_MINIMUM is the minimum value in each field.
       LOGICAL_MAXIMUM is the maximum value in each field.

    You can assign a usage to each field by either:

    1. Specifying an explicit list of usages. 
       If REPORT_COUNT is greater than the number of usages specified
       then the last specified usage is applied to the remaining fields. 
       E.g. REPORT_COUNT 5, USAGE A, USAGE B, USAGE C:
            field   usage 
              1      A    <-- Explicit
              2      B    <-- Explicit
              3      C    <-- Explicit
              4      C    <-- Repeated to fill the report count
              5      C

       or,

    2. Specifying a range of usages from USAGE_MINIMUM to USAGE_MAXIMUM.
       If REPORT_COUNT is greater than the number of usages in the range
       then the last usage in the range is applied to the remaining fields. 
       E.g. REPORT_COUNT 5, USAGE_MINIMUM A, USAGE_MAXIMUM C:
            field   usage
              1      A    <-- First in range
              2      B
              3      C    <-- Last in range
              4      C    <-- Repeated to fill the report count
              5      C

       or,

    3. Both of the above in any combination.
       If REPORT_COUNT is greater than the number of usages in the range
       then the last assigned usage is applied to the remaining fields. 
       E.g. REPORT_COUNT 5, USAGE A, USAGE_MINIMUM B, USAGE_MAXIMUM D:
            field   usage
              1      A    <-- Explicit
              2      B    <-- First in range
              3      C 
              4      D    <-- Last in range
              5      D    <-- Repeated to fill the report count

    */
    if o.0VERBOSITY > 0
    then do
      call say '  // Type:    Variable'
      call say '  'getStatement('', 'Page 0x'xPage':' getPageDesc(xPage))
    end
    if sCollectionName <> f.0LASTCOLLECTION
    then do
      call say '  'getStatement(,'Collection:' sCollectionName)
      f.0LASTCOLLECTION = sCollectionName
    end
    if nUsages = 0 & isConstant(sFlags) 
    then call emitPaddingFieldDecl g.0REPORT_COUNT,nField
    else do /* data or constant, with usage(s) specified */
      nRemainingReportCount = g.0REPORT_COUNT
      /* Emit all but the last usage */
      do i = 1 to nUsages-1 while nRemainingReportCount > 0
        xExtendedUsage = word(xUsages,i)
        call emitFieldDecl 1,xExtendedUsage
        nRemainingReportCount = nRemainingReportCount - 1
      end
      xExtendedUsage = word(xUsages,i) /* usage to be replicated if room */
      if nUsages > g.0REPORT_COUNT
      then do
        do nIgnored = i to nUsages
          xIgnoredUsage = word(xUsages,nIgnored)
          parse var xIgnoredUsage xPage +4 xUsage +4
          call say '  'getStatement('','Usage 0x'xPage||xUsage getUsageMeaningText(xIgnoredUsage)',' getRange() '<-- Ignored: REPORT_COUNT ('g.0REPORT_COUNT') is too small')
        end
      end
      /* Now replicate the last usage to fill the report count */
      else call emitFieldDecl nRemainingReportCount,xExtendedUsage
    end
  end
  /*
   *-----------------------------------------------------------
   * ARRAY
   *-----------------------------------------------------------
  */
  else do /* array: an array of indexes, value = index of a usage */
    /* REPORT_COUNT is the number of fields.
       REPORT_SIZE is the size of each field (in bits).
       LOGICAL_MINIMUM is the minimum INDEX in each field.
       LOGICAL_MAXIMUM is the maximum INDEX in each field.


    You can assign index numbers to usages by either:

    1. Specifying a list of usages. Each array element can contain an index 
       to one of the specified usages or the "no value" usage. 
       LOGICAL_MINIMUM indexes the first explicit usage, and 
       LOGICAL_MAXIMUM indexes the last explicit usage. 
       Any index outside the LOGICAL_MINIMUM and LOGICAL_MAXIMUM range is
       considered to be a "no value" usage.
       E.g. LOGICAL_MININUM 7, LOGICAL_MAXIMUM 9, 
            USAGE C, USAGE B, USAGE A:
            index usage
              7     C     <-- Explicit 
              8     B     <-- Explicit
              9     A     <-- Explicit
            other  novalue
       If a report contained 7 and 9, it means that both usage 'C' and 'A' are
       currently asserted, but does not say which was asserted first.

       or,

    2. Specifying a range of usages from USAGE_MINIMUM to USAGE_MAXIMUM 
       indexed by a corresponding index between LOGICAL_MINIMUM and 
       LOGICAL_MAXIMUM.
       E.g. LOGICAL_MINIMUM 7, LOGICAL_MAXIMUM 9, 
            USAGE_MININUM A, USAGE_MAXIMUM C:
            index usage
              7     A     <-- First in range
              8     B
              9     C     <-- Last in range
            other  novalue
       If a report contained 7 and 9, it means that both usage 'A' and 'C' are
       currently asserted, but does not say which was asserted first.

       or,

    3. Both of the above in any combination.
       E.g. LOGICAL_MINIMUM 7, LOGICAL_MAXIMUM 9, 
            USAGE_MININUM B, USAGE_MAXIMUM C
            USAGE A:
            index usage
              7     B     <-- First in range
              8     C     <-- Last in range
              9     A     <-- Explicit
            other  novalue

    Note: An array is not like a string of characters in a buffer. Each array 
    element can contain an index (from LOGICAL_MINIMUM to LOGICAL_MAXIMUM) 
    to a usage, so if, in a keyboard example, three keys on a keyboard are 
    pressed simultaneously, then three elements of the array will contain an 
    index to the corresponding usage (a key in this case) - and not necessarily 
    in the order they were pressed. The maximum number of keys that can be 
    asserted at once is limited by the REPORT_COUNT. The maximum number of keys
    that can be represented is:  LOGICAL_MAXIMUM - LOGICAL_MINIMUM + 1.
    */
    if o.0VERBOSITY > 0
    then do
      call say '  // Type:    Array'
      call say '  'getStatement('', 'Page 0x'xPage':' getPageDesc(xPage))
    end
    if sCollectionName <> f.0LASTCOLLECTION
    then do
      call say '  'getStatement(,'Collection:' sCollectionName)
      f.0LASTCOLLECTION = sCollectionName
    end
    if nUsages = 0 & isConstant(sFlags) 
    then call emitPaddingFieldDecl g.0REPORT_COUNT,nField
    else do /* data */
      call emitFieldDecl g.0REPORT_COUNT,g.0USAGE
    end
    if o.0ALL
    then do /* Document the valid indexes in the array */
      g.0LOGICAL_MAXIMUM_WIDTH = length(g.0LOGICAL_MAXIMUM)
      if g.0LOGICAL_MINIMUM = ''
      then nLogical = 0 /* only to avoid a prang */
      else nLogical = g.0LOGICAL_MINIMUM
      if nUsages > 0 
      then do
        do i = 1 to nUsages 
          xExtendedUsage = word(xUsages,i) /* ppppuuuu */
          parse var xExtendedUsage xPage +4 xUsage +4
          sUsageDesc = getUsageMeaningText(xExtendedUsage)
          if sUsageDesc <> '' | (sUsageDesc = '' & o.0VERBOSITY > 1)
          then do
            if nLogical > g.0LOGICAL_MAXIMUM
            then call say '  'getStatement('', 'Value' getFormattedLogical(nLogical) '= Usage 0x'xPage||xUsage':' sUsageDesc '<-- Error: Value ('nLogical') exceeds LOGICAL_MAXIMUM ('g.0LOGICAL_MAXIMUM')')
            else call say '  'getStatement('', 'Value' getFormattedLogical(nLogical) '= Usage 0x'xPage||xUsage':' sUsageDesc)
          end
          nLogical = nLogical + 1
        end
      end
    end
  end
return

getFormattedLogical: procedure expose g.
  parse arg nValue
return right(nValue,max(length(nValue), g.0LOGICAL_MAXIMUM_WIDTH))

emitFieldDecl: procedure expose g. k. f. o.
  parse arg nReportCount,xExtendedUsage,sPad
  if nReportCount < 1 then return
  sFieldName = getFieldName(xExtendedUsage,f.0TYPEDEFNAME)sPad
  parse var xExtendedUsage xPage +4 xUsage +4
  if xUsage = ''
  then sComment = getRange()
  else sComment = 'Usage 0x'xPage||xUsage':' getUsageMeaningText(xExtendedUsage)',' getRange()

  if isSpecified(g.0UNIT) | isSpecified(g.0PHYSICAL_MAXIMUM) | isSpecified(g.0PHYSICAL_MINIMUM)
  then sComment = sComment || getUnitConversionFormula()

  if wordpos(g.0REPORT_SIZE,'8 16 32 64') > 0
  then do
    if nReportCount = 1
    then call say '  'getStatement(g.0FIELD_TYPE sFieldName';'                   ,sComment)
    else call say '  'getStatement(g.0FIELD_TYPE sFieldName'['nReportCount'];'   ,sComment)
  end
  else do
    call      say '  'getStatement(g.0FIELD_TYPE sFieldName ':' g.0REPORT_SIZE';',sComment)
    do i = 1 to nReportCount-1
      call say '  'getStatement(g.0FIELD_TYPE sFieldName||i ':' g.0REPORT_SIZE';',sComment)
    end
  end
return


getValueOrZero: procedure
  arg nValue
  if nValue = '' then nValue = 0
return nValue

getUnitConversionFormula: procedure expose g. k. f. o.
  xUnit = g.0UNIT

  nLogicalMinimum  = getValueOrZero(g.0LOGICAL_MINIMUM) /* for expediency */
  nLogicalMaximum  = getValueOrZero(g.0LOGICAL_MAXIMUM)
  nPhysicalMinimum = getValueOrZero(g.0PHYSICAL_MINIMUM)
  nPhysicalMaximum = getValueOrZero(g.0PHYSICAL_MAXIMUM)

  if nPhysicalMinimum = 0 & nPhysicalMaximum = 0
  then do
    nPhysicalMinimum = nLogicalMinimum
    nPhysicalMaximum = nLogicalMaximum
  end
  if x2d(g.0UNIT) \== '00000000'
  then do
    parse var k.0UNIT.xUnit sDesc' ['sUnits'],'nBaseUnitExponent sBaseUnit /* e.g. Force in newtons [10 μN units],-5 N */
    parse var sDesc sQuantity ' in ' sUnitName
    if nBaseUnitExponent = '' then nBaseUnitExponent = 0
  end
  else do
    nBaseUnitExponent = 0
    sUnits = ''
    sBaseUnit = ''
  end

  if g.0UNIT_EXPONENT + nBaseUnitExponent = 0
  then sPhysicalUnits = sBaseUnit
  else sPhysicalUnits = '10'getSuperscript(g.0UNIT_EXPONENT + nBaseUnitExponent) sBaseUnit 'units'

  n = nPhysicalMaximum - nPhysicalMinimum
  d = nLogicalMaximum - nLogicalMinimum
  nGCD = getGreatestCommonDenominator(n,d)
  if nGCD > 1
  then do
    n = n / nGCD
    d = d / nGCD
  end

  sFormula = calc(calc(calc('Value','-',nLogicalMinimum),'x',calc(n,'/',d)),'+',nPhysicalMinimum)
  if left(sFormula,10) = 'Value x 1 ' then sFormula = 'Value' substr(sFormula,11)  /* kludge */
  select
    when g.0UNIT = ''           then sFormula = ', Physical =' sFormula /* UNIT is not defined */
    when g.0UNIT == '00000000'  then sFormula = ', Physical =' sFormula
    otherwise                        sFormula = ', Physical =' sFormula 'in' sPhysicalUnits
  end
return sFormula

getGreatestCommonDenominator: procedure
  parse arg n,d
  if n = 1 then return 1
  if d = 0 then return n
  return getGreatestCommonDenominator(d,n//d)
return

calc: procedure
  parse arg sArg1,sOperator,nArg2
  sResult = sArg1 sOperator nArg2
  select
    when sOperator = '+' then select
      when nArg2 = 0  then sResult = sArg1
      when nArg2 < 0  then sResult = '('sArg1 '-' (-nArg2)')'
      otherwise sResult = '('sArg1 '+' nArg2')'
    end
    when sOperator = '-' then select
      when nArg2 = 0  then sResult = sArg1
      when nArg2 < 0  then sResult = '('sArg1 '+' (-nArg2)')'
      otherwise sResult = '('sArg1 '-' nArg2')'
    end
    when sOperator = 'x' then select
      when nArg2 = 0  then sResult = 0
      when nArg2 = 1  then sResult = sArg1
      when nArg2 = -1 then sResult = '-'sArg1
      otherwise sResult = sArg1 'x' nArg2
    end
    when sOperator = '/' then select
      when nArg2 = 1  then sResult = sArg1
      when nArg2 = -1 then sResult = '-'sArg1
      otherwise sResult = sArg1 '/' nArg2
    end
    when sOperator = '^' then select
      when nArg2 = 0  then sResult = 1
      otherwise sResult = sArg1 '^' nArg2
    end
    otherwise do
      sResult = '('sArg1 sOperator nArg2')'
    end
  end
return sResult

emitPaddingFieldDecl: procedure expose g. k. o.
  parse arg nReportCount,nField
  if nReportCount < 1 then return
  if wordpos(g.0REPORT_SIZE,'8 16 32 64') > 0
  then do
    if nReportCount = 1
    then call say '  'getStatement(g.0FIELD_TYPE 'pad_'nField';', 'Pad')
    else call say '  'getStatement(g.0FIELD_TYPE 'pad_'nField'['nReportCount'];', 'Pad')
  end
  else do i = 1 to nReportCount
    call say '  'getStatement(g.0FIELD_TYPE ':' g.0REPORT_SIZE';', 'Pad')
  end
return

getFieldType: procedure expose g. k.
  select
    when g.0REPORT_SIZE <= 8 then do
      if g.0LOGICAL_MINIMUM < 0 
      then sFieldType = k.0I8
      else sFieldType = k.0U8
    end
    when g.0REPORT_SIZE <= 16 then do
      if g.0LOGICAL_MINIMUM < 0 
      then sFieldType = k.0I16
      else sFieldType = k.0U16
    end
    when g.0REPORT_SIZE <= 32 then do
      if g.0LOGICAL_MINIMUM < 0 
      then sFieldType = k.0I32
      else sFieldType = k.0U32
    end
    otherwise do
      if g.0LOGICAL_MINIMUM < 0 
      then sFieldType = k.0I64
      else sFieldType = k.0U64
    end
  end
return sFieldType

getRange: procedure expose g.
return 'Value =' g.0LOGICAL_MINIMUM 'to' g.0LOGICAL_MAXIMUM

getPadding: procedure expose g.
return 'Padding' getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE)

getFieldName: procedure expose k. f.
  parse arg xExtendedUsage,sStructureName
  parse var xExtendedUsage xPage +4 xUsage +4
  /* Use the collection names as a prefix */
  if f.0LASTCOLLECTION = ''
  then sLabel = 'VendorDefined'
  else sLabel = f.0LASTCOLLECTION
  /* Append the fieldname (or usage code) */
  if k.0LABEL.xPage.xUsage = ''
  then sLabel = sLabel xUsage
  else sLabel = sLabel k.0LABEL.xPage.xUsage
  sLabel = getSaneLabel(sLabel)
  /* 
  Prepend the usage page prefix, and generate a unique field name
  within the specified C structure by appending a sequence number if
  necessary
  */
  sFieldName = getUniqueName(space(getShortPageName(xPage)sLabel,0),sStructureName)
return sFieldName

getSaneLabel: procedure
  parse arg sLabel
  sNewLabel = ''
  sLastWord = ''
  do i = 1 to words(sLabel)
    sWord = word(sLabel,i)
    if pos(':',sWord) > 0
    then parse var sWord ':'sWord /* Strip any CA:, CL:, CP:, NA: prefix */
    if sWord <> sLastWord
    then do
      sNewLabel = sNewLabel sWord
      sLastWord = sWord
    end
  end 
  sLabel = space(translate(sNewLabel,'','~!@#$%^&*()+`-={}|[]\:;<>?,./"'"'"),0)
return sLabel

getUniqueName: procedure expose f.
  parse arg sName,sContext
  sNameWithinContext = sContext'.'sName
  if f.0NAME.sNameWithinContext = ''
  then do
    f.0NAME.sNameWithinContext = 0
  end
  else do
    nInstance = f.0NAME.sNameWithinContext + 1
    f.0NAME.sNameWithinContext = nInstance
    sName = sName'_'nInstance
  end
return sName

getShortPageName: procedure expose k.
  parse arg xPage +4
  parse value getPageName(xPage) with sPage','sShortPageName
return sShortPageName

getPageDesc: procedure expose k.
  parse arg xPage +4
  parse value getPageName(xPage) with sPage','sShortPageName
return sPage

getPageName: procedure expose k.
  parse arg xPage +4
  sPage = x2c(xPage)
  select
    when sPage > '0092'x & sPage < 'f1d0'x then sPageDesc =  'Reserved,RES_'
    when sPage >= 'ff00'x then do
        if k.0PAGE.xPage = ''
        then sPageDesc = 'Vendor-defined,VEN_'
        else sPageDesc = k.0PAGE.xPage
    end
    otherwise sPageDesc = k.0PAGE.xPAGE
  end
return sPageDesc

getUsageMeaning: procedure expose k.
  parse arg xPage +4 xUsage +4 /* ppppuuuu */
  parse var k.0USAGE.xPage.xUsage sMeaning ' ('sUsageTypeCode'='sUsageType')'
  if sUsageType <> ''
  then sMeaning = sMeaning '('sUsageType')'
return sMeaning

getUsageMeaningText: procedure expose k.
  parse arg xPage +4 xUsage +4 /* ppppuuuu */
  parse var k.0USAGE.xPage.xUsage sMeaning ' ('
return sMeaning

getPageAndUsageMeaning: procedure expose k.
  parse arg xPage +4 xUsage +4 /* ppppuuuu */
return getPageDesc(xPage)':' k.0USAGE.xPage.xUsage

getUsageDesc: procedure expose k.
  parse arg xPage +4 xUsage +4 /* ppppuuuu */
  parse var k.0USAGE.xPage.xUsage sUsageDesc '('
return strip(sUsageDesc)

getUsageTypeCode: procedure expose k.
  parse arg xPage +4 xUsage +4 /* ppppuuuu */
  parse var k.0USAGE.xPage.xUsage '('sUsageTypeCode'='
return sUsageTypeCode

getUsageType: procedure expose k.
  parse arg xPage +4 xUsage +4 /* ppppuuuu */
  parse var k.0USAGE.xPage.xUsage '('sUsageTypeCode'='sUsageType')'
return sUsageType

getCollectionName: procedure
  parse arg sCollectionNames
  nCollectionNames = words(sCollectionNames)
  sLastName = word(sCollectionNames,nCollectionNames)
  if left(sLastName,3) = 'NA:'
  then sCollectionNames = subword(sCollectionNames,1,nCollectionNames-1)
return sCollectionNames

getCollectionType: procedure expose g.
  parse arg xType
  xType = right(xType,2,'0')
return g.0COLLECTION_TYPE.xType

getCollectionCode: procedure expose g.
  parse upper arg sName +2
return g.0COLLECTION_TYPE.sName

getCollectionDesc: procedure expose g.
  parse arg xType
  xType = right(xType,2,'0')
return g.0COLLECTION.xType

getInputFlags:
  if isVariable(sValue)
  then sFlags = getFlags()            /* variable */
  else sFlags = getInputArrayFlags()  /* array    */
return sFlags

getOutputFlags:
return getFlags()

getFeatureFlags:
return getFlags()

getInputArrayFlags:
  sFlags = ''
  if isConstant(sValue)
  then sFlags = sFlags '1=Constant'
  else sFlags = sFlags '0=Data'
  sFlags = sFlags '0=Array'
  if isRelative(sValue)
  then sFlags = sFlags '1=Relative'
  else sFlags = sFlags '0=Absolute'
return strip(sFlags)

getFlags:
  sFlags = ''
  if isConstant(sValue)
  then sFlags = sFlags '1=Constant'
  else sFlags = sFlags '0=Data'
  if isVariable(sValue)
  then sFlags = sFlags '1=Variable'
  else sFlags = sFlags '0=Array'
  if isRelative(sValue)
  then sFlags = sFlags '1=Relative'
  else sFlags = sFlags '0=Absolute'
  if isWrap(sValue)
  then sFlags = sFlags '1=Wrap'
  else sFlags = sFlags '0=NoWrap'
  if isNonLinear(sValue)
  then sFlags = sFlags '1=NonLinear'
  else sFlags = sFlags '0=Linear'
  if isNoPrefState(sValue)
  then sFlags = sFlags '1=NoPrefState'
  else sFlags = sFlags '0=PrefState'
  if isNull(sValue)
  then sFlags = sFlags '1=Null'    
  else sFlags = sFlags '0=NoNull'
  if isVolatile(sValue)
  then sFlags = sFlags '1=Volatile'
  else sFlags = sFlags '0=NonVolatile'
  if isBuffer(sValue)
  then sFlags = sFlags '1=Buffer'
  else sFlags = sFlags '0=Bitmap'
return strip(sFlags)

isConstant: procedure
  parse arg sFlags
return isOn(sFlags, '00000001'b)

isData: procedure
  parse arg sFlags
return \isConstant(sFlags)

isVariable: procedure
  parse arg sFlags
return isOn(sFlags,'00000010'b)

isArray: procedure
  parse arg sFlags
return \isVariable(sFlags)

isRelative: procedure
  parse arg sFlags
return isOn(sFlags,'00000100'b)

isAbsolute: procedure
  parse arg sFlags
return \isRelative(sFlags)

isWrap: procedure
  parse arg sFlags
return isOn(sFlags,'00001000'b)

isNoWrap: procedure
  parse arg sFlags
return \isWrap(sFlags)

isNonLinear: procedure
  parse arg sFlags
return isOn(sFlags,'00010000'b)

isLinear: procedure
  parse arg sFlags
return \isNonLinear(sFlags)

isNoPrefState: procedure
  parse arg sFlags
return isOn(sFlags,'00100000'b)

isPrefState: procedure
  parse arg sFlags
return \isNoPrefState(sFlags)

isNull: procedure
  parse arg sFlags
return isOn(sFlags,'01000000'b)

isNoNull: procedure
  parse arg sFlags
return \isNull(sFlags)

isVolatile: procedure
  parse arg sFlags
return isOn(sFlags,'10000000'b)

isNonVolatile: procedure
  parse arg sFlags
return \isVolatile(sFlags)

isBuffer: procedure
  parse arg sFlags
return isOn(sFlags,'100000000'b)

isBitmap: procedure
  parse arg sFlags
return \isBuffer(sFlags)

isOn: procedure
  parse arg sByte,sBit
  sByte = right(sByte,4,'00'x)
  sBit  = right(sBit, 4,'00'x)
return bitand(sByte,sBit) = sBit

isSpecified: procedure
  arg nValue
return nValue <> '' & nValue <> 0

getUnitExponent: procedure expose k.
  parse arg nValue
  /*
     In: 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
    Out: 0  1  2  3  4  5  6  7 -8 -7 -6 -5 -4 -3 -2 -1
  */
  if nValue > 7
  then nValue = nValue - 16
return nValue

getPower: procedure expose k.
  parse arg xValue
  nExponent = getUnitExponent(x2d(xValue))
  if nExponent = 1
  then sExponent = ''
  else sExponent = getSuperscript(nExponent)
return sExponent

getUnit: procedure expose k.
  parse arg xValue
  xValue = right(xValue,8,'0')
  parse var xValue xReserved +1 xLight +1 xCurrent +1 xTemperature +1,
                   xTime     +1 xMass  +1 xLength  +1 xSystem      +1
  select                   
    when xSystem = '0' then sUnit = '0=None'
    when xSystem = 'F' then sUnit = 'F=Vendor-defined'
    when pos(xSystem,'56789ABCDE') > 0 then sUnit = xSystem'=Reserved <-- Error: Measurement system type ('xSystem') is reserved'
    otherwise do
      sUnit = xSystem'='k.0UNIT.0.xSystem
      if xLength      <> '0' then sUnit = sUnit','      xLength'='k.0UNIT.1.xSystem || getPower(xLength)
      if xMass        <> '0' then sUnit = sUnit','        xMass'='k.0UNIT.2.xSystem || getPower(xMass)
      if xTime        <> '0' then sUnit = sUnit','        xTime'='k.0UNIT.3.xSystem || getPower(xTime)
      if xTemperature <> '0' then sUnit = sUnit',' xTemperature'='k.0UNIT.4.xSystem || getPower(xTemperature)
      if xCurrent     <> '0' then sUnit = sUnit','     xCurrent'='k.0UNIT.5.xSystem || getPower(xCurrent)
      if xLight       <> '0' then sUnit = sUnit','       xLight'='k.0UNIT.6.xSystem || getPower(xLight)
    end
  end
return sUnit

emitOpenDecode: procedure expose g. o. f. o.
  if \o.0DECODE then return
  call emitHeading 'Decoded Application Collection'
  select
    when o.0HEADER = 'AVR' then do
      call say 'PROGMEM char' getUniqueName('usbHidReportDescriptor')'[] ='
      call say '{'
    end
    when o.0HEADER = 'MCHIP' then do
      call say 'ROM struct'
      call say '{'
      call say '  BYTE report[USB_HID_REPORT_DESCRIPTOR_SIZE];'
      call say '}' getUniqueName('hid_report_descriptor') '='
      call say '{'
      call say '  {'
    end
    when o.0HEADER = 'MIKROC' then do
      call say 'const struct'
      call say '{'
      call say '  char report[USB_HID_REPORT_DESCRIPTOR_SIZE];'
      call say '}' getUniqueName('hid_report_descriptor') '='
      call say '{'
      call say '  {'
    end
    otherwise do
      call say '/*'
    end
  end
  g.0DECODE_OPEN = 1
return

emitCloseDecode: procedure expose g. o.
  if \o.0DECODE then return
  if g.0DECODE_OPEN = 1
  then do  
    select
      when o.0HEADER = 'AVR' then do
        call say '};'
      end
      when o.0HEADER = 'MCHIP' then do
        call say '  }'
        call say '};'
      end
      when o.0HEADER = 'MIKROC' then do
        call say '  }'
        call say '};'
      end
      otherwise do
        call say '*/'
      end
    end
  end
  g.0DECODE_OPEN = 0
return

emitDecode: procedure expose g. o. f.
  if \o.0DECODE then return
  parse arg sCode,sParm,sType,sTag,xValue,sDescription
  if g.0DECODE_OPEN <> 1
  then do
    call emitOpenDecode
  end
  select
    when o.0HEADER = 'AVR' | o.0HEADER = 'MIKROC' | o.0HEADER = 'MCHIP' then do
      sChunk = ' '
      xChunk = sCode || sParm
      do i = 1 to length(xChunk) by 2
        xByte = substr(xChunk,i,2)
        sChunk = sChunk '0x'xByte','
      end
      if xValue = '' 
      then sDecode = left(sChunk,30) '//'left('',g.0INDENT) left('('sType')',8) left(sTag,18) sDescription
      else sDecode = left(sChunk,30) '//'left('',g.0INDENT) left('('sType')',8) left(sTag,18) '0x'xValue sDescription
    end
    otherwise do
      if xValue = '' 
      then sDecode = sCode left(sParm,8) left('',g.0INDENT) left('('sType')',8) left(sTag,18) sDescription
      else sDecode = sCode left(sParm,8) left('',g.0INDENT) left('('sType')',8) left(sTag,18) '0x'xValue sDescription
    end
  end
  if g.0REDUNDANT & o.0OPT /* If we should optimise redundant items */
  then nop 
  else call say sDecode
  g.0REDUNDANT = 0
return

getNext:
  parse arg nLength
  sChunk = substr(sData,nByte,nLength)
  nByte = nByte + nLength
return sChunk

getQuantity: procedure
  parse arg nCount,sSingular,sPlural
  if nCount = 1 then return nCount sSingular
return nCount sPlural  

initStack: procedure expose g.
  g.0T = 0              /* set top of stack index */
return

isStackEmpty: procedure expose g.
return g.0T = 0

pushStack: procedure expose g.
  parse arg item
  tos = g.0T + 1        /* get new top of stack index */
  g.0E.tos = item       /* set new top of stack item */
  g.0T = tos            /* set new top of stack index */
return

popStack: procedure expose g.
  tos = g.0T            /* get top of stack index for */
  if tos > 0            /* if anything is on the stack */
  then do
    item = g.0E.tos     /* get item at top of stack */
    g.0T = tos - 1
  end
  else item = ''        /* return null item */
return item

peekStack: procedure expose g.
  tos = g.0T            /* get top of stack index */
  if tos > 0            /* if anything is on the stack */
  then do
    item = g.0E.tos     /* get item at top of stack */
  end
  else item = ''        /* return null item */
return item

isAlphanumeric: procedure expose k.
  parse arg c
return pos(c,k.0ALPHANUM) > 0

isWhole: procedure 
  parse arg sValue
return datatype(sValue,'WHOLE')

addOption: procedure expose g. k.
  parse arg nOptionType,sShort,sLong,sDesc,sInitialValue
  nOption = g.0OPTION_INDEX.0 + 1
  g.0OPTION_INDEX.0 = nOption
  if sLong <> ''
  then do
    g.0OPTION_INDEX.sLong  = nOption /* Map long option name to index */
    g.0OPTION_LONG.nOption = sLong
  end
  if sShort <> ''
  then do
    g.0OPTION_INDEX.sShort = nOption /* Map short option name to index */
    g.0OPTION_SHORT.nOption = sShort
  end
  g.0OPTION.nOption = sInitialValue
  if isWhole(nOptionType)
  then g.0OPTION_TYPE.nOption = nOptionType
  else g.0OPTION_TYPE.nOption = k.0OPTION_BOOLEAN /* Default option type */
  g.0OPTION_DESC.nOption = sDesc
return

getOptionName: procedure expose g.
  parse arg nOption
  select
    when g.0OPTION_LONG.nOption <> '' then sOption = g.0OPTION_LONG.nOption 
    when g.0OPTION_SHORT.nOption <> '' then sOption = g.0OPTION_SHORT.nOption 
    otherwise sOption = ''
  end
return sOption

getOptionIndex: procedure expose g. k.
  parse arg sOption
  if g.0OPTION_INDEX.sOption <> ''
  then nOption = g.0OPTION_INDEX.sOption
  else nOption = 0
return nOption

getOptionType: procedure expose g. k.
  parse arg sOption
  nOption = getOptionIndex(sOption)
return g.0OPTION_TYPE.nOption

isOptionPresent: procedure expose g. k.
  parse arg sOption
  nOption = getOptionIndex(sOption)
return g.0OPTION_PRESENT.nOption = 1

setOption: procedure expose g. k.
  parse arg sOption,sValue
  nOption = getOptionIndex(sOption)
  if nOption = 0
  then say 'Invalid option ignored:' sToken
  else do
    nOptionType = getOptionType(sOption)
    g.0OPTION_PRESENT.nOption = 1
    select
      when nOptionType = k.0OPTION_COUNT then do
        g.0OPTION.nOption = g.0OPTION.nOption + 1
      end
      when nOptionType = k.0OPTION_BOOLEAN then do
        g.0OPTION.nOption = sValue
      end
      when nOptionType = k.0OPTION_LIST then do
        n = g.0OPTION.nOption.0 
        if n = '' 
        then n = 1
        else n = n + 1
        g.0OPTION.nOption.0 = n
        g.0OPTION.nOption.n = sValue
      end
      otherwise do
        g.0OPTION.nOption = sValue
      end
    end
  end
return

getOption: procedure expose g. k.
  parse arg sOption,n
  nOption = getOptionIndex(sOption)
  if n <> ''
  then sValue = g.0OPTION.nOption.n
  else sValue = g.0OPTION.nOption
return sValue

getOptionCount: procedure expose g. k.
  parse arg sOption
  nOption = getOptionIndex(sOption)
  if g.0OPTION.nOption.0 = ''
  then nOptionCount = 0
  else nOptionCount = g.0OPTION.nOption.0
return nOptionCount

setOptions: procedure expose g. k.
  parse arg sCommandLine
  /* A command line can consist of any combination of:
     1. --option (with no args, the option is boolean)
     2. --option (with no args, successive instances are counted)
     3. --option (with zero to n args)
     4. --option (with zero or more args)

     For example:
     --debug -v -v -t on --coord 3 4 --list one two three -f filename
       1      2  2  3      3           4                   4
  */
  g.0REST = sCommandLine
  g.0TOKEN = getNextToken()
  bGetNextToken = 1
  do while g.0TOKEN <> ''
    if isOptionLike(g.0TOKEN)
    then do
      sOption = g.0TOKEN
      if left(sOption,2) = '--' 
      then do /* long option */
        bGetNextToken = handleOption(sOption)
      end
      else do /* short option(s) */
        do i = 2 to length(sOption)
          sShortOption = '-'substr(sOption,i,1)
          bGetNextToken = handleOption(sShortOption)
        end
      end
    end
    else do /* eat the rest of the command line */
      g.0REST = strip(g.0TOKEN g.0REST)
      g.0TOKEN = ''
      bGetNextToken = 0
    end
    if bGetNextToken
    then g.0TOKEN = getNextToken()
  end
return

handleOption: procedure expose g. k.
  parse arg sOriginalOption
  sOption = sOriginalOption
  bNegated = left(sOption,5) = '--no-'
  if bNegated
  then sOption = '--'substr(sOption,6) /* e.g. sOption='--no-decode' becomes sOption='--decode' with bNegated = 1 */
  bGetNextToken = 1
  if getOptionIndex(sOption) = 0
  then do
    say 'Invalid option ignored:' sOriginalOption
  end
  else do
    nOptionType = getOptionType(sOption)
    select
      when nOptionType = k.0OPTION_COUNT then do /* --key [--key ...] */
        if bNegated
        then say 'Cannot negate non-boolean option:' sOriginalOption
        else call setOption sOption
      end
      when nOptionType = k.0OPTION_LIST then do /* --key [val ...] */
        sArgs = ''
        g.0TOKEN = getNextToken()
        do while \isOptionLike(g.0TOKEN) & g.0TOKEN <> ''
          sArgs = sArgs g.0TOKEN
          g.0TOKEN = getNextToken()
          bGetNextToken = 0
        end
        if bNegated
        then say 'Cannot negate non-boolean option:' sOriginalOption
        else call setOption sOption,strip(sArgs)
      end
      when nOptionType = k.0OPTION_BOOLEAN then do /* --key */
        call setOption sOption,\bNegated
      end
      otherwise do           /* --key val1 ... valn */
        sArgs = ''
        g.0TOKEN = getNextToken()
        nMaxArgs = nOptionType
        do i = 1 to nMaxArgs while \isOptionLike(g.0TOKEN) & g.0TOKEN <> ''
          sArgs = sArgs g.0TOKEN
          g.0TOKEN = getNextToken()
          bGetNextToken = 0
        end
        if bNegated
        then say 'Cannot negate non-boolean option:' sOriginalOption
        else call setOption sOption,strip(sArgs)
      end
    end
  end
return bGetNextToken

isOptionLike: procedure expose g.
  parse arg sToken
return left(sToken,1) = '-'

getNextToken: procedure expose g.
  parse var g.0REST sToken g.0REST
return sToken

addBooleanOption: procedure expose g. k.
  parse arg sShort,sLong,sDesc,bInitialValue
  call addOption k.0OPTION_BOOLEAN,sShort,sLong,sDesc,bInitialValue=1
return

addCountableOption: procedure expose g. k.
  parse arg sShort,sLong,sDesc,nInitialValue
  if \datatype(nInitialValue,'WHOLE') 
  then nInitialValue = 0
  call addOption k.0OPTION_COUNT,sShort,sLong,sDesc,nInitialValue
return

addListOption: procedure expose g. k.
  parse arg sShort,sLong,sDesc,sInitialValue
  call addOption k.0OPTION_LIST,sShort,sLong,sDesc,sInitialValue
return

addBoundedListOption: procedure expose g. k.
  parse arg sShort,sLong,sDesc,sInitialValue,nMaxListSize
  if \datatype(nMaxListSize,'WHOLE') | nMaxListSize <= 0
  then nMaxListSize = 1
  call addOption nMaxListSize,sShort,sLong,sInitialValue,sDesc
return

addSuperscript: procedure expose k.
  parse arg sText,sSuperscript
  k.0SUPER.sText = sSuperscript
return

getSuperscript: procedure expose k.
  parse arg sText
  sSuperscript = ''
  do i = 1 to length(sText)
    c = substr(sText,i,1)
    if k.0SUPER.c = ''
    then sSuperscript = sSuperscript || c
    else sSuperscript = sSuperscript || k.0SUPER.c
  end
return sSuperscript

Prolog:
  g.0EXPECTED_COLLECTION_USAGE = '' /* A USAGE with type CL, NAry, UM or US that has been seen */
  g.0REDUNDANT = 0         /* Item already has the same value set */
  g.0IN_DELIMITER = 0      /* Inside a delimited set of usages */
  g.0FIRST_USAGE  = 0      /* First delimited usage has been processed */
  g.0IN_APP_COLLECTION = 0 /* Inside an Application Collection */
  g.0IN_NAMED_ARRAY_COLLECTION = 0 /* Inside a Named Array Collection */
  f.0COLLECTION_NAME = ''  /* Collection hierarchy names */

  k.0I8  = 'int8_t'
  k.0U8  = 'uint8_t'
  k.0I16 = 'int16_t'
  k.0U16 = 'uint16_t'
  k.0I32 = 'int32_t'
  k.0U32 = 'uint32_t'
  k.0I64 = 'int64_t'
  k.0U64 = 'uint64_t'

  g.0OPTION_INDEX.0 = 0 /* Number of valid options */
  k.0OPTION_COUNT   = -2
  k.0OPTION_LIST    = -1
  k.0OPTION_BOOLEAN = 0

  call addListOption      '-f','--file'    ,'Read input from the specified file'
  call addListOption      '-c','--hex'     ,'Read hex input from command line'
  call addBooleanOption   '-r','--right'   ,'Read hex input from the rightmost side of each line'
  call addBooleanOption   '-b','--binary'  ,'Input file is binary (not text)'
  call addListOption      '-o','--output'  ,'Write output to the specified file (default is console)'
  call addBooleanOption   '-O','--opt'     ,'Optimise by ignoring redundant items'
  call addBooleanOption   '-s','--struct'  ,'Output C structure declarations (default)',1
  call addBooleanOption   '-d','--decode'  ,'Output decoded report descriptor (default)',1
  call addListOption      '-h','--header'  ,'Output C header in AVR, MIKROC or MICROCHIP format'
  call addBooleanOption   '-x','--dump'    ,'Output hex dump of report descriptor'
  call addBooleanOption   '-a','--all'     ,'Output all valid array indices and usages'
  call addListOption      '-i','--include' ,'Read vendor-specific definition file'
  call addCountableOption '-v','--verbose' ,'Output more detail'
  call addBooleanOption   '-V','--version' ,'Display version and exit'
  call addBooleanOption   '-?','--help'    ,'Display this information'
  call addBooleanOption   '-C','--codes'   ,'Display the list of valid hex codes and their meaning'

  call setOptions sCommandLine

  call initStack
  k.0UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  k.0LOWER = 'abcdefghijklmnopqrstuvwxyz'
  k.0ALPHANUM = k.0UPPER || k.0LOWER || '0123456789'

  k.0TYPE.MAIN                  = '00000000'b
  k.0TYPE.GLOBAL                = '00000100'b
  k.0TYPE.LOCAL                 = '00001000'b
  k.0TYPE.RESERVED              = '00001100'b

  call addMain '10000000'b,'INPUT'
  call addMain '10010000'b,'OUTPUT'
  call addMain '10110000'b,'FEATURE'
  call addMain '10100000'b,'COLLECTION'
  call addMain '11000000'b,'END_COLLECTION'

  call addGlobal '00000000'b,'USAGE_PAGE'
  call addGlobal '00010000'b,'LOGICAL_MINIMUM'
  call addGlobal '00100000'b,'LOGICAL_MAXIMUM'
  call addGlobal '00110000'b,'PHYSICAL_MINIMUM'
  call addGlobal '01000000'b,'PHYSICAL_MAXIMUM'
  call addGlobal '01010000'b,'UNIT_EXPONENT',0
  call addGlobal '01100000'b,'UNIT'
  call addGlobal '01110000'b,'REPORT_SIZE'
  call addGlobal '10000000'b,'REPORT_ID'
  call addGlobal '10010000'b,'REPORT_COUNT'
  call addGlobal '10100000'b,'PUSH'
  call addGlobal '10110000'b,'POP'

  call clearLocals
  call addLocal '00000000'b,'USAGE'
  call addLocal '00010000'b,'USAGE_MINIMUM'
  call addLocal '00100000'b,'USAGE_MAXIMUM'         
  call addLocal '00110000'b,'DESIGNATOR_INDEX'      
  call addLocal '01000000'b,'DESIGNATOR_MINIMUM'    
  call addLocal '01010000'b,'DESIGNATOR_MAXIMUM'    
  call addLocal '01110000'b,'STRING_INDEX'          
  call addLocal '10000000'b,'STRING_MINIMUM'        
  call addLocal '10010000'b,'STRING_MAXIMUM'        
  call addLocal '10100000'b,'DELIMITER'             

  call addCollection 00,'CP','Physical'
  call addCollection 01,'CA','Application'
  call addCollection 02,'CL','Logical'
  call addCollection 03,'CR','Report'
  call addCollection 04,'NA','Named Array'
  call addCollection 05,'US','Usage Switch'
  call addCollection 06,'UM','Usage Modifier'

  call addType 'BB','Buffered Bytes'
  call addType 'CA','Application Collection'
  call addType 'CACL','Application or Logical Collection'
  call addType 'CACP','Application or Physical Collection'
  call addType 'CL','Logical Collection'
  call addType 'CLCP','Logical or Physical Collection'
  call addType 'CP','Physical Collection'
  call addType 'CR','Report Collection'
  call addType 'DF','Dynamic Flag'
  call addType 'DV','Dynamic Value'
  call addType 'DVDF','Dynamic Value or Dynamic Flag'
  call addType 'LC','Linear Control'
  call addType 'MC','Momentary Control'
  call addType 'MCDV','Momentary Control or Dynamic Value'
  call addType 'NAry','Named Array Collection'
  call addType 'OOC','On/Off Control'
  call addType 'OSC','One Shot Control'
  call addType 'OSC-NAry','One Shot Control or Named Array Collection'
  call addType 'RTC','Re-trigger Control'
  call addType 'MULTI','Selector, On/Off Control, Momentary Control, or One Shot Control'
  call addType 'Sel','Selector'
  call addType 'SF','Static Flag'
  call addType 'SFDF','Static Flag or Dynamic Flag'
  call addType 'SFDFSEL','Static Flag, Dynamic Flag, or Selector'
  call addType 'SV','Static Value'
  call addType 'SVDV','Static Value or Dynamic Value'
  call addType 'UM','Usage Modifier Collection'
  call addType 'US','Usage Switch Collection'

  k.0SUPER. = ''
  call addSuperscript '0','⁰'
  call addSuperscript '1','¹'
  call addSuperscript '2','²'
  call addSuperscript '3','³'
  call addSuperscript '4','⁴'
  call addSuperscript '5','⁵'
  call addSuperscript '6','⁶'
  call addSuperscript '7','⁷'
  call addSuperscript '8','⁸'
  call addSuperscript '9','⁹'
  call addSuperscript '+','⁺'
  call addSuperscript '-','⁻'
  call addSuperscript '=','⁼'
  call addSuperscript '(','⁽'
  call addSuperscript ')','⁾'

  /* Some pre-defined common SI units:
          .---------- Reserved                 |-- Perhaps should be "amount of substance" in moles, to conform with SI
          |.--------- Luminous intensity (in candelas)
          ||.-------- Current (in amperes)
          |||.------- Temperature (in kelvin)
          ||||.------ Time (in seconds)        |
          |||||.----- Mass (in grams)          |-- Odd, since CGS units were deprecated in favour of MKS units in the 1940's
          ||||||.---- Length (in centimetres)  |
          |||||||.--- System of measurement (either 1 or 2 for metric measurement system)
          ||||||||
          VVVVVVVV
  Nibble: 76543210    Description of unit [base units],kms_exponent kms_unit
          --------    ------------------------------------------------------ */
  k.0UNIT.00000000 = 'No unit,0'
  k.0UNIT.00000012 = 'Rotation in radians [1 rad units],0 rad'

  /* SI base units (excluding "amount of substance" in moles) */
  k.0UNIT.00000011 = 'Distance in metres [1 cm units],-2 m'
  k.0UNIT.00000101 = 'Mass in grams [1 g units],-3 kg'
  k.0UNIT.00001001 = 'Time in seconds [1 s units],0 s'
  k.0UNIT.00010001 = 'Temperature in kelvin [1 K units],0 K'
  k.0UNIT.00100001 = 'Current in amperes [1 A units],0 A'
  k.0UNIT.01000001 = 'Luminous intensity in candelas [1 cd units],0 cd'
/*k.0UNIT.10000000 = 'Amount of substance in moles [1 mol units],0 mol' */                            /* cannot be represented: no mole support */

  /* Coherent derived units in the SI expressed in terms of base units */
  k.0UNIT.00000021 = 'Area [1 cm² units],-4 m²'
  k.0UNIT.00000031 = 'Volume [1 cm³ units],-6 m³'
  k.0UNIT.0000F011 = 'Velocity [1 cm/s units],-2 m/s'
  k.0UNIT.0000E011 = 'Acceleration [1 cm/s² units],-2 m/s²'
  k.0UNIT.000000F0 = 'Wavenumber in reciprocal metres [100 /cm units],2 /m'
  k.0UNIT.000001D1 = 'Mass density [1 g/cm³ units],3 kg/m³'
  k.0UNIT.000001E1 = 'Surface density [1 g/cm² units],1 kg/m²'
  k.0UNIT.00000F31 = 'Specific volume [1 cm³/g units],-3 m³/kg'
  k.0UNIT.001000E1 = 'Current density [1 A/cm² units],4 A/m²'
  k.0UNIT.001000F1 = 'Magnetic field strength [1 A/cm units],2 A/m'
/*k.0UNIT.10000031 = 'Amount concentration in mole per cubic metre [1 mol/cm³ units],-6 mol/m³' */    /* cannot be represented: no mole support */
/*k.0UNIT.000001D1 = 'Mass concentration [1 g/cm³ units],3 kg/m³' */                                  /* same units as mass density (see above) */
  k.0UNIT.010000E1 = 'Luminance [1 cd/cm² units],4 cd/m²'
/*k.0UNIT.00000001 = 'Refractive index [dimensionless]' */ 
/*k.0UNIT.00000001 = 'Relative permeability [dimensionless]' */ 

  /* Coherent derived units in the SI with special names and symbols */
/*k.0UNIT.00000001 = 'Plane angle in radians [1 rad units],0 m/m'    */ 
/*k.0UNIT.00000001 = 'Solid angle in steradians [1 sr units], m²/m²' */ 
  k.0UNIT.0000F001 = 'Frequency in hertz [1 Hz units],0 Hz'
  k.0UNIT.0000E111 = 'Force in newtons [10 μN units],-5 N'
  k.0UNIT.0000E1F1 = 'Pressure in pascals [0.1 Pa units],-1 Pa'
  k.0UNIT.0000E121 = 'Energy in joules [0.1 μJ units],-7 J'
  k.0UNIT.0000D121 = 'Power in watts [0.1 μW units],-7 W'
  k.0UNIT.00101001 = 'Electric charge in coulombs [1 C units],0 C'
  k.0UNIT.00F0D121 = 'Electric potential difference in volts [0.1 μV units],-7 V'
  k.0UNIT.00204FE1 = 'Capacitance in farads [10 MF units],7 F' /* sheesh! */
  k.0UNIT.00E0D121 = 'Electric resistance in ohms [0.1 μΩ units],-7 Ω'
  k.0UNIT.00203FE1 = 'Electric conductance in siemens [10 MS units],7 S'
  k.0UNIT.00F0E121 = 'Magnetic flux in webers [0.1 μWb units],-7 Wb'
  k.0UNIT.00F0E101 = 'Magnetic flux density in teslas [1 mT units],-3 T'
  k.0UNIT.00E0E121 = 'Inductance in henrys [0.1 μH units],-7 H'
/*k.0UNIT.01000001 = 'Luminous flux in lumen [1 lm units],0 cd sr' */                                 /* same units as Luminous intensity (see above) */
/*k.0UNIT.010000E1 = 'Luminance in lux [1 lx units],4 cd/m²'       */                                 /* same units as Luminance (see above) */
/*k.0UNIT.0000F001 = 'Activity referred to a radionuclide in becquerels [1 Bq units],0 Bq' */         /* same units as Frequency (see above) */
  k.0UNIT.0000E021 = 'Absorbed dose in gray [1 μGy units],-6 Gy'
/*k.0UNIT.0000E021 = 'Dose equivalent in sievert [1 μSv units],-6 Sv' */                              /* same units as Absorbed dose (see above) */
/*k.0UNIT.1000F001 = 'Catalytic activity in katal [1 mol/s units],0 mol/s' */                         /* cannot be represented: no mole support */
  
  /* Coherent derived units whose names and symbols include SI coherent derived units with special names and symbols */
  k.0UNIT.0000F1F1 = 'Dynamic viscosity in pascal seconds [0.1 Pa s units],-1 Pa s'
/*k.0UNIT.0000E121 = 'Moment of force in newton metres [0.1 μN m units],-7 N m' */                    /* same units as Energy (see above) */
  k.0UNIT.0000E101 = 'Surface tension in newton per metre [1 g/s² units],-3 kg/s²'
  /*      xLAKTMLs */
  k.0UNIT.0000F012 = 'Angular velocity [1 rad/s units],0 rad/s'
  k.0UNIT.0000E012 = 'Angular acceleration [1 rad/s² units],0 rad/s²'
  k.0UNIT.0000D101 = 'Heat flux density in watt per square metre [1 mW/m² units],-3 W/m²'
  k.0UNIT.000FE121 = 'Heat capacity in joule per kelvin [0.1 μJ/K units],-7 J/K'
  k.0UNIT.000FE021 = 'Specific heat capacity in joule per kilogram kelvin [100 μJ/(kg K) units],-4 J/(kg K)'
  k.0UNIT.0000E021 = 'Specific energy in joule per kilogram [100 μJ/kg units],-4 J/kg'
  k.0UNIT.000FD111 = 'Thermal conductivity in watts per metre per kelvin [10 μW/(m K) units],-5 W/(m K)'
/*k.0UNIT.0000E1F1 = 'Energy density in joule per cubic metre [1 MJ/m³ units],6 J/m³' */              /* same units as Pressure (see above) */
  k.0UNIT.00F0D111 = 'Electric field strength in volt per metre [10 μV/m units],-5 V/m'
  k.0UNIT.001010D1 = 'Electric charge density in coulomb per m³ [1 MC/m³ units],6 C/m³'
  k.0UNIT.001010E1 = 'Surface charge density in coulomb per m² [10 kC/m² units],4 C/m²'
/*k.0UNIT.001010E1 = 'Electric flux density in coulomb per m² [10 kC/m² units],4 C/m²' */             /* same units as Surface charge density (see above) */
  k.0UNIT.00204FD1 = 'Permittivity in farad per metre [1 GF/m units],9 F/m' /* WTF! */
  k.0UNIT.00E0E111 = 'Permeability in henry per metre [0.01 H/m units],-2 H/m'
/*k.0UNIT.F000E121 = 'Molar energy in joule per mole [0.1 μJ/mol units],-7 J/mol' */                  /* cannot be represented: no mole support */
/*k.0UNIT.F00FE121 = 'Molar entropy in joule per mole kelvin [0.1 μJ/(mol K) units],-7 J/(mol K)' */  /* cannot be represented: no mole support */
  k.0UNIT.00101F00 = 'Exposure (x-rays and gamma rays) in coulomb per kilogram [0.001 C/kg units],-3 C/kg'
  k.0UNIT.0000D020 = 'Absorbed dose rate in gray per second [1 μGy/s units],-6 Gy/s'
/*k.0UNIT.0000D121 = 'Radiant intensity in watt per steradian [0.1 μW/sr units],-7 W/sr' */                /* same units as Power (see above) */
/*k.0UNIT.0000D101 = 'Radiance in watt per square metre steradian [1 mW/(m² sr) units],-3 W/(m² sr)' */    /* same units as Heat flux density (see above) */
/*k.0UNIT.F00FE121 = 'Molar entropy in joule per mole kelvin [0.1 μJ/(mol K) units],-7 J/(mol K)' */       /* cannot be represented: no mole support */
/*k.0UNIT.1000FD00 = 'Catalytic activity concentration in katal per cubic metre [1 Gkat/m³ units],9 kat/m³' */ /* cannot be represented: no mole support */

  /* Others */
  k.0UNIT.0000F111 = 'Momentum [1 g cm/s units],-5 kg m/s'
  k.0UNIT.0000D100 = 'Jerk (change in acceleration) [0.1 cm/s³ units],-3 m/s³'

  /* Other common units (non-metric):
          .---------- Reserved
          |.--------- Luminous intensity (in candelas) - same as metric
          ||.-------- Current (in amperes) - same as metric
          |||.------- Temperature (in degrees Fahrenheit)
          ||||.------ Time (in seconds) - same as metric
          |||||.----- Mass (in slugs)
          ||||||.---- Length (in inches)
          |||||||.--- System of measurement (either 3 or 4 for non-metric measurement system)
          ||||||||
          VVVVVVVV
  Nibble: 76543210    Description of unit
          --------    ------------------------------------- */
  k.0UNIT.00000013 = 'Distance in inches [1 inch units],0 inch'
  k.0UNIT.00000023 = 'Area in square inches [1 inch² units],0 inch²'
  k.0UNIT.00000033 = 'Volume in cubic inches [1 inch³ units],0 inch³'
  k.0UNIT.00001003 = 'Time in seconds [1 s units],0 s' /* Imperial seconds haha */
  k.0UNIT.00010003 = 'Temperature in degrees Fahrenheit [1 °F units],0 °F'
  k.0UNIT.00000014 = 'Rotation in degrees [1° units],0 degrees'
  k.0UNIT.0000F014 = 'Angular velocity [1°/s units],0 °/s'
  k.0UNIT.0000E014 = 'Angular acceleration [1°/s² units],0 °/s²'

  
  /*      .--Nibble number
          | .--Measurement system
          | |
          V V                  */
  k.0UNIT.0.1 = 'System=SI Linear'
  k.0UNIT.0.2 = 'System=SI Rotation'
  k.0UNIT.0.3 = 'System=English Linear'
  k.0UNIT.0.4 = 'System=English Rotation'

  k.0UNIT.1.1 = 'Length=Centimetre'
  k.0UNIT.1.2 = 'Rotation=Radians'
  k.0UNIT.1.3 = 'Length=Inch'
  k.0UNIT.1.4 = 'Rotation=Degrees'

  k.0UNIT.2.1 = 'Mass=Gram'
  k.0UNIT.2.2 = 'Mass=Gram'
  k.0UNIT.2.3 = 'Mass=Slug'
  k.0UNIT.2.4 = 'Mass=Slug'

  k.0UNIT.3.1 = 'Time=Seconds'
  k.0UNIT.3.2 = 'Time=Seconds'
  k.0UNIT.3.3 = 'Time=Seconds'
  k.0UNIT.3.4 = 'Time=Seconds'
  
  k.0UNIT.4.1 = 'Temperature=Kelvin'
  k.0UNIT.4.2 = 'Temperature=Kelvin'
  k.0UNIT.4.3 = 'Temperature=Fahrenheit'
  k.0UNIT.4.4 = 'Temperature=Fahrenheit'

  k.0UNIT.5.1 = 'Current=Ampere'
  k.0UNIT.5.2 = 'Current=Ampere'
  k.0UNIT.5.3 = 'Current=Ampere'
  k.0UNIT.5.4 = 'Current=Ampere'

  k.0UNIT.6.1 = 'Luminous Intensity=Candela'
  k.0UNIT.6.2 = 'Luminous Intensity=Candela'
  k.0UNIT.6.3 = 'Luminous Intensity=Candela'
  k.0UNIT.6.4 = 'Luminous Intensity=Candela'

  call loadUsageFile 'rd.conf'
  do i = 1 to getOptionCount('--include')
    sIncludeFile = getOption('--include',i)
    if openFile(sIncludeFile)
    then call loadUsageFile getOption('--include',i)
    else say 'Could not open file' sIncludeFile
  end
return

openFile: procedure expose g.
  parse arg sFile,sOptions
  if sFile = '' then return 0
  if sOptions = '' then sOptions = 'READ'
return stream(sFile,'COMMAND','OPEN' sOptions) = 'READY:'

closeFile: procedure expose g.
  parse arg sFile
return stream(sFile,'COMMAND','CLOSE') = 'READY:'

say: procedure expose o.
  parse arg sText
  rc = lineout(o.0OUTPUT,sText)
return  

loadUsageFile: procedure expose k. g.
  parse arg sFile
  if sFile = '' then return
  if openFile(sFile)
  then do
    do while chars(sFile) > 0
      call parseUsageDefinition linein(sFile)
    end
    rc = closeFile(sFile)  
  end
return 

parseUsageDefinition: procedure expose k. g.
  parse arg sLine
  parse upper arg s1 s2 .
  select
    when s1 = '' then nop /* null is valid hex so nip it in the bud here */
    when s1 = 'PAGE' then do
      parse var sLine . xPage sPage
      if pos('-',xPage) = 0
      then do
        if isHex(xPage)
        then do
          xPage = right(xPage,4,'0')
          k.0PAGE.xPage = sPage
          g.0PAGE = xPage
        end
      end
      else do
        parse var xPage xPageFrom'-'xPageTo
        if isHex(xPageFrom) & isHex(xPageTo)
        then do
          do i = x2d(xPageFrom) to x2d(xPageTo)
            xPage = d2x(i,4)
            k.0PAGE.xPage = sPage
            g.0PAGE = xPage
          end
        end
      end
    end
    when isHex(s1) | pos('-',s1) > 0 then do
      parse var sLine xUsage sUsage','sType','sLabel
      sDesc = k.0TYPE.sType
      xPage = g.0PAGE
      if sDesc <> ''
      then sUsageDesc = sUsage '('sType'='sDesc')'
      else sUsageDesc = sUsage 
      sUsageLabel = getCamelCase(sUsage, sLabel)
      if pos('-',xUsage) = 0
      then do
        if isHex(xUsage)
        then do
          xUsage = right(xUsage,4,'0')
          sDesc = k.0TYPE.sType
          xPage = g.0PAGE
          k.0USAGE.xPage.xUsage = sUsageDesc
          k.0LABEL.xPage.xUsage = sUsageLabel
        end
      end
      else do
        parse var xUsage xUsageFrom'-'xUsageTo
        if isHex(xUsageFrom) & isHex(xUsageTo)
        then do
          do i = x2d(xUsageFrom) to x2d(xUsageTo)
            xUsage = d2x(i,4)
            k.0USAGE.xPage.xUsage = sUsageDesc
            k.0LABEL.xPage.xUsage = sUsageLabel
          end
        end
      end
    end
    otherwise nop
  end
return

isHex: procedure
  parse arg xString
return xString <> '' & datatype(xString,'X')

is0x: procedure
  parse arg xString 0 '0x'xValue
return left(xString,2) = '0x' & datatype(xValue,'X')

isDec: procedure
  parse arg n
return n <> '' & datatype(n,'WHOLE')

isChar: procedure
  parse arg s
return length(s) = 3 & left(s,1) = "'" & right(s,1) = "'"

isString: procedure
  parse arg s
return length(s) > 2 & left(s,1) = '"' & right(s,1) = '"'

toUpper: procedure
  parse arg sText
return translate(sText)

toLower: procedure expose k.
  parse arg sText
return translate(sText, k.0LOWER, k.0UPPER)
  
getCamelCase: procedure expose k.
  parse arg sUsage,sLabel
  if sLabel <> '' then return sLabel
  sUsage = translate(sUsage,'','/-')
  sCamelCase = ''
  do i = 1 to words(sUsage)
    sWord = toLower(word(sUsage,i))
    parse var sWord sFirst +1 sRest
    sWord = toUpper(sFirst)sRest
    sCamelCase = sCamelCase sWord
  end
return space(sCamelCase,0)  

addCollection: procedure expose g.
  parse arg xType,sName,sDesc
  xType = right(xType,2,'0')
  g.0COLLECTION_TYPE.xType = sName
  g.0COLLECTION_TYPE.sName = xType
  g.0COLLECTION.xType = sDesc
return

addType: procedure expose k.
  parse arg sType,sMeaning
  k.0TYPE.sType = sMeaning
return

addMain: procedure expose k.
  parse arg sCode,sName
  k.0MAIN.sCode = sName
  k.0MAIN.sName = sCode
return

addGlobal: procedure expose k. g.
  parse arg sCode,sName,nValue
  k.0GLOBAL.sCode = sName
  k.0GLOBAL.sName = sCode
  sKey = '0'sName
  g.sKey = nValue
return

addLocal: procedure expose k.
  parse arg sCode,sName
  k.0LOCAL.sCode = sName
  k.0LOCAL.sName = sCode
return

clearLocals: procedure expose g.
  call setLocals 0 0 0 0 0 0 0 0 0
  g.0USAGES = ''             
return

getFormattedGlobalsLong: procedure expose g.
  sGlobals = 'USAGE_PAGE=0x'g.0USAGE_PAGE,
             'LOGICAL(MIN='g.0LOGICAL_MINIMUM',MAX='g.0LOGICAL_MAXIMUM')',
             'PHYSICAL(MIN='g.0PHYSICAL_MINIMUM',MAX='g.0PHYSICAL_MAXIMUM')',
             'UNIT(0x'g.0UNIT',EXP='g.0UNIT_EXPONENT')',
             'REPORT(ID=0x'g.0REPORT_ID',SIZE='g.0REPORT_SIZE',COUNT='g.0REPORT_COUNT')'
return sGlobals

getFormattedPhysicalUnits: procedure expose g.
  sGlobals = 'PHYSICAL(MIN='g.0PHYSICAL_MINIMUM',MAX='g.0PHYSICAL_MAXIMUM')',
             'UNIT(0x'g.0UNIT',EXP='g.0UNIT_EXPONENT')'
return sGlobals


getFormattedGlobals: procedure expose g.
  sGlobals = 'PAGE:'g.0USAGE_PAGE,
             'LMIN:'g.0LOGICAL_MINIMUM,
             'LMAX:'g.0LOGICAL_MAXIMUM,
             'PMIN:'g.0PHYSICAL_MINIMUM,
             'PMAX:'g.0PHYSICAL_MAXIMUM,
             'UEXP:'g.0UNIT_EXPONENT,
             'UNIT:'g.0UNIT,
             'RSIZ:'g.0REPORT_SIZE,
             'RID:'g.0REPORT_ID,
             'RCNT:'g.0REPORT_COUNT
return sGlobals

getGlobals: procedure expose g.
  sGlobals = g.0USAGE_PAGE'/'||,
             g.0LOGICAL_MINIMUM'/'||,
             g.0LOGICAL_MAXIMUM'/'||,
             g.0PHYSICAL_MINIMUM'/'||,
             g.0PHYSICAL_MAXIMUM'/'||,
             g.0UNIT_EXPONENT'/'||,
             g.0UNIT'/'||,
             g.0REPORT_SIZE'/'||,
             g.0REPORT_ID'/'||,
             g.0REPORT_COUNT
return sGlobals

setGlobals: procedure expose g.
  parse arg  g.0USAGE_PAGE'/',
             g.0LOGICAL_MINIMUM'/',
             g.0LOGICAL_MAXIMUM'/',
             g.0PHYSICAL_MINIMUM'/',
             g.0PHYSICAL_MAXIMUM'/',
             g.0UNIT_EXPONENT'/',
             g.0UNIT'/',
             g.0REPORT_SIZE'/',
             g.0REPORT_ID'/',
             g.0REPORT_COUNT,
             .
return

getFormattedLocals: procedure expose g.
  sLocals  = 'USAG:'g.0USAGE,
             'UMIN:'g.0USAGE_MINIMUM,
             'UMAX:'g.0USAGE_MAXIMUM,         
             'DIDX:'g.0DESIGNATOR_INDEX,      
             'DMIN:'g.0DESIGNATOR_MINIMUM,    
             'DMAX:'g.0DESIGNATOR_MAXIMUM,    
             'SIDX:'g.0STRING_INDEX,          
             'SMIN:'g.0STRING_MINIMUM,        
             'SMAX:'g.0STRING_MAXIMUM     
return sLocals

getLocals: procedure expose g.
  sLocals  = g.0USAGE,
             g.0USAGE_MINIMUM,
             g.0USAGE_MAXIMUM,         
             g.0DESIGNATOR_INDEX,      
             g.0DESIGNATOR_MINIMUM,    
             g.0DESIGNATOR_MAXIMUM,    
             g.0STRING_INDEX,          
             g.0STRING_MINIMUM,        
             g.0STRING_MAXIMUM     
return sLocals

setLocals: procedure expose g.
  parse arg  g.0USAGE,
             g.0USAGE_MINIMUM,
             g.0USAGE_MAXIMUM,         
             g.0DESIGNATOR_INDEX,      
             g.0DESIGNATOR_MINIMUM,    
             g.0DESIGNATOR_MAXIMUM,    
             g.0STRING_INDEX,          
             g.0STRING_MINIMUM,        
             g.0STRING_MAXIMUM,
             .
return

showCodes: procedure
  say 'Table of item codes in hexadecimal. The item code varies depending on the'
  say 'length of the subsequent item data field as follows:'
  say ''
  say '                              Data Field Length'
  say 'Item                           0    1    2    4   Comment'
  say '---------------------------   --   --   --   --   -----------------------------'
  say '(MAIN)   INPUT                80   81   82   83   Defines input to the host device'
  say '(MAIN)   OUTPUT               90   91   92   93   Defines output from the host device'
  say '(MAIN)   COLLECTION           A0   A1   A2   A3   See collection types below'
  say '(MAIN)   FEATURE              B0   B1   B2   B3   Defines data to or from the host device'
  say '(MAIN)   END_COLLECTION       C0                  Item data field is not supported'
  say '(GLOBAL) USAGE_PAGE                05   06   07   USAGE_PAGE 00 is invalid'
  say '(GLOBAL) LOGICAL_MINIMUM      14   15   16   17'
  say '(GLOBAL) LOGICAL_MAXIMUM      24   25   26   27'
  say '(GLOBAL) PHYSICAL_MINIMUM     34   35   36   37'
  say '(GLOBAL) PHYSICAL_MAXIMUM     44   45   46   47'
  say '(GLOBAL) UNIT_EXPONENT        54   55   56   57'
  say '(GLOBAL) UNIT                 64   65   66   67'
  say '(GLOBAL) REPORT_ID                 85   86   87   REPORT_ID=0 is reserved'
  say '(GLOBAL) REPORT_SIZE               75   76   77   REPORT_SIZE=0 is invalid'
  say '(GLOBAL) REPORT_COUNT         94   95   96   97   REPORT_COUNT=0 is not useful'
  say '(GLOBAL) PUSH                 A4                  Item data field is not supported'
  say '(GLOBAL) POP                  B4                  Item data field is not supported'
  say '(LOCAL)  USAGE                08   09   0A   0B'
  say '(LOCAL)  USAGE_MINIMUM        18   19   1A   1B'
  say '(LOCAL)  USAGE_MAXIMUM        28   29   2A   2B'
  say '(LOCAL)  DESIGNATOR_INDEX     38   39   3A   3B'
  say '(LOCAL)  DESIGNATOR_MINIMUM   48   49   4A   4B'
  say '(LOCAL)  DESIGNATOR_MAXIMUM   58   59   5A   5B'
  say '(LOCAL)  STRING_INDEX         78   79   7A   7B'
  say '(LOCAL)  STRING_MINIMUM       88   89   8A   8B'
  say '(LOCAL)  STRING_MAXIMUM       98   99   9A   9B'
  say '(LOCAL)  DELIMITER            A8   A9   AA   AB'
  say '' 
  say 'COLLECTION item codes are as follows:'
  say ''
  say 'Physical Collection:          A1 00               Alternatively: A0'
  say 'Application Collection:       A1 01               Alternatively: A2 01 00, or A3 01 00 00 00'
  say 'Logical Collection:           A1 02'
  say 'Report Collection:            A1 03'
  say 'Named Array Collection:       A1 04               Must contain only Selector usages'
  say 'Usage Switch Collection:      A1 05'
  say 'Usage Modifier Collection:    A1 06'
return

Epilog:
  if g.0OUTPUT <> ''
  then call closeFile(g.0OUTPUT)
return
