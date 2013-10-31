/*REXX*/
/* RDD! HID Report Descriptor Decoder v1.0.3

Copyright (c) 2011-2013, Andrew J. Armstrong
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

  o.0HELP      = getOption('--help')
  if o.0HELP | sCommandLine = ''
  then do
    parse source . . sThis .
    say getVersion()
    say
    say 'This will extract anything that looks like a USB Human'
    say 'Interface Device (HID) report descriptor from the specified'
    say 'input file and attempt to decode it into a C header file.'
    say 'It does this by concatenating all the printable-hex-like'
    say 'sequences it finds on each line (until the first unrecognisable'
    say 'sequence is encountered) into a single string of hex digits, and'
    say 'then attempts to decode that string as though it was a HID Report'
    say 'Descriptor.'
    say 'As such, it is not perfect...merely useful.'
    say 
    say 'Syntax: rexx' sThis '[-h format] [-i file] [-dsvxb] -f filein'
    say '    or: rexx' sThis '[-h format] [-i file] [-dsvx]  -c hex'
    say
    say 'Where:'
    say '      filein           = Input file path to be decoded'
    say '      file             = Include file of PAGE/USAGE definitions'
    say '      hex              = Printable hex to be decoded from command line'
    say '      format           = Type of output C header file format:'
    say '                         AVR    - AVR style'
    say '                         MIKROC - MikroElektronika mikroC Pro for PIC style'
    say '                         MCHIP  - Microchip C18 style'
    do i = 1 to g.0OPTION_INDEX.0
      say '      'left(strip(g.0OPTION_SHORT.i g.0OPTION_LONG.i),16) '=' g.0OPTION_DESC.i
    end
    say 
    say 'Example:'
    say '      rexx' sThis '--hex 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0'
    say '       ...decodes the given hex string'
    say
    say '      rexx' sThis 'usbdesc.h'
    say '       ...decodes the hex strings found in the specified file'
    return
  end

  o.0BINARY    = getOption('--binary')
  o.0VERBOSITY = getOption('--verbose')
  o.0STRUCT    = getOption('--struct')
  o.0DECODE    = getOption('--decode')
  o.0HEADER    = toUpper(getOption('--header',1))
  o.0DUMP      = getOption('--dump')

  if \(o.0DECODE | o.0STRUCT | o.0DUMP) /* If neither --decode nor --struct nor --dump was specified */
  then o.0STRUCT = 1          /* then assume --struct was specified */

  sData = ''
  select
    when getOptionCount('--file') > 0 then sFile = getOption('--file',1)
    when getOptionCount('--hex') > 0  then sData = getOption('--hex',1)
    otherwise sFile = g.0REST /* assume command line is the name of the input file */
  end

  xData = readDescriptor(sFile,sData)
  if o.0DUMP
  then do
    call emitHeading 'Report descriptor data in hex (length' length(xData)/2 'bytes)'
    say
    call dumpHex xData
    say
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
    select
      when sSize = '00000000'b then sParm = ''
      when sSize = '00000001'b then sParm = getNext(1)
      when sSize = '00000010'b then sParm = getNext(2)
      otherwise                     sParm = getNext(4)
    end
    xItem = c2x(sItem)
    xParm = c2x(sParm)
    sValue = reverse(sParm) /* 0xllhh --> 0xhhll */
    xValue = right(c2x(sValue),8,'0')
    select
      when sType = k.0TYPE.MAIN   then call processMAIN
      when sType = k.0TYPE.GLOBAL then call processGLOBAL
      when sType = k.0TYPE.LOCAL  then call processLOCAL
      otherwise call say xItem,xParm,'LOCAL',,,'<-- Invalid Item'
    end
  end
  if sCollectionStack <> ''
  then say 'RDD003E Missing END_COLLECTION MAIN tag (0xC0)'
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
      say 'RDD002E Expecting printable hexadecimal data. Found:' sData
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
          do i = 1 to words(sLine)
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
            then xData = xData || sWord
            else leave /* stop when the first non-hexadecimal value is found */
          end
        end
      end
      rc = closeFile(sFile)  
    end
    else say 'Could not open file' sFile
  end
return xData

processMAIN:
  select
    when sTag = k.0MAIN.INPUT then do
      sFlags = getInputFlags()
      call say xItem,xParm,'MAIN','INPUT',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sFlags getSanity()
      n = inputField.0 + 1
      inputField.n = xValue getGlobals()','getLocals()','g.0USAGES','sFlags','f.0COLLECTION_NAME
      inputField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.OUTPUT then do
      sFlags = getOutputFlags()
      call say xItem,xParm,'MAIN','OUTPUT',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sFlags getSanity()
      n = outputField.0 + 1
      outputField.n = xValue getGlobals()','getLocals()','g.0USAGES','sFlags','f.0COLLECTION_NAME
      outputField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.FEATURE then do
      sFlags = getFeatureFlags()
      call say xItem,xParm,'MAIN','FEATURE',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sFlags getSanity()
      n = featureField.0 + 1
      featureField.n = xValue getGlobals()','getLocals()','g.0USAGES','sFlags','f.0COLLECTION_NAME
      featureField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.COLLECTION then do
      xPage = right(g.0USAGE_PAGE,4,'0')
      xUsage = right(g.0USAGE,4,'0')
      xExtendedUsage = xPage || xUsage
      parse value getUsageDescAndType(xPage,xUsage) with sCollectionName '('
      f.0COLLECTION_NAME = space(sCollectionName,0)
      sValue = reverse(sParm)
      nValue = c2d(sValue)
      xValue = c2x(sValue)
      sCollectionStack = nValue sCollectionStack /* push onto collection stack */
      select 
        when nValue > 127 then sMeaning = 'Vendor Defined'
        when nValue > 6   then sMeaning = 'Reserved'
        otherwise do
          sMeaning = g.0COLLECTION.xParm '(Usage=0x'xExtendedUsage':',
                                           'Page='getPageDesc(xPage)',',
                                           'Usage='getUsageDesc(xPage,xUsage)',',
                                           'Type='getUsageType(xPage,xUsage)')'
          if left(xExtendedUsage,2) <> 'FF' & pos(getCollectionType(xValue),getUsageType(xPage,xUsage)) = 0
          then do
            sMeaning = sMeaning '<-- Warning: USAGE type should be' getCollectionType(xValue),
                                '('getCollectionDesc(xValue)')'
          end
        end
      end
      call say xItem,xParm,'MAIN','COLLECTION',xValue,sMeaning
      g.0INDENT = g.0INDENT + 2
      g.0USAGES = ''
    end
    when sTag = k.0MAIN.END_COLLECTION then do
      g.0INDENT = g.0INDENT - 2
      parse var sCollectionStack nCollectionType sCollectionStack /* pop the collection stack */
      xCollectionType = d2x(nCollectionType,2)
      call say xItem,xParm,'MAIN','END_COLLECTION',,getCollectionDesc(xCollectionType)
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
        g.0USAGES = ''
      end
    end
    otherwise call say xItem,xParm,'MAIN',,,'<-- Invalid: Unknown MAIN tag'
  end
return

processGLOBAL:
  xValue = c2x(sValue)
  nValue = x2d(xValue,2*length(sValue))
  sMeaning = ''
  select
    when sTag = k.0GLOBAL.USAGE_PAGE then do
      xPage = right(xValue,4,'0')
      call loadPage xPage
      xValue = xPage 
      sMeaning = getPageDesc(xPage) updateHexValue('USAGE_PAGE',xValue)
    end
    when sTag = k.0GLOBAL.LOGICAL_MINIMUM then do
      sMeaning = '('nValue')' updateValue('LOGICAL_MINIMUM',nValue)
    end
    when sTag = k.0GLOBAL.LOGICAL_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('LOGICAL_MAXIMUM',nValue)
    end
    when sTag = k.0GLOBAL.PHYSICAL_MINIMUM then do
      sMeaning = '('nValue')' updateValue('PHYSICAL_MINIMUM',nValue)
    end
    when sTag = k.0GLOBAL.PHYSICAL_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('PHYSICAL_MAXIMUM',nValue)
    end
    when sTag = k.0GLOBAL.UNIT_EXPONENT then do
      nUnitExponent = getUnitExponent(nValue) 
      sMeaning = '(Unit Value x 10^'nUnitExponent')' updateValue('UNIT_EXPONENT',nUnitExponent)
    end
    when sTag = k.0GLOBAL.UNIT then do
      xValue = right(xValue,8,'0')
      sMeaning = k.0UNIT.xValue '('getUnit(xValue)')' updateHexValue('UNIT',xValue)
    end
    when sTag = k.0GLOBAL.REPORT_SIZE then do
      sMeaning = '('nValue') Number of bits per field' updateValue('REPORT_SIZE',nValue)
      if nValue <= 0
      then sMeaning = sMeaning '<-- Error: Report size should be > 0'
    end
    when sTag = k.0GLOBAL.REPORT_ID then do
      c = x2c(xValue)
      if isAlphanumeric(c)
      then sMeaning = '('nValue')' "'"c"'" updateHexValue('REPORT_ID',xValue)
      else sMeaning = '('nValue')'         updateHexValue('REPORT_ID',xValue)
      if nValue = 0 then sMeaning = sMeaning '<-- Error: REPORT_ID 0 is reserved'
      if nValue > 255 then sMeaning = sMeaning '<-- Error: REPORT_ID must be in the range 0x01 to 0xFF'
    end
    when sTag = k.0GLOBAL.REPORT_COUNT then do
      sMeaning = '('nValue') Number of fields' updateValue('REPORT_COUNT',nValue)
      if nValue <= 0
      then sMeaning = sMeaning '<-- Error: Report count should be > 0'
    end
    when sTag = k.0GLOBAL.PUSH then do
      xValue = ''
      call pushStack getGlobals()
      sMeaning = getFormattedGlobalsLong()
    end
    when sTag = k.0GLOBAL.POP then do
      xValue = ''
      call setGlobals popStack()
      sMeaning = getFormattedGlobalsLong()
    end
    otherwise sMeaning = '<-- Invalid: Unknown GLOBAL tag'
  end
  call say xItem,xParm,'GLOBAL',k.0GLOBAL.sTag,xValue,sMeaning
return

processLOCAL:
  xValue = c2x(sValue)
  nValue = x2d(xValue,2*length(sValue))
  xPage = g.0USAGE_PAGE
  bIndent = 0
  sMeaning = ''
  select
    when sTag = k.0LOCAL.USAGE then do
      if length(sValue) = 4
      then do /* Both page and usage are specified: ppppuuuu */
        sMeaning = getExtendedUsageDescAndType(xValue)
      end
      else do /* Only usage is specified: uuuu */
        xUsage = right(xValue,4,'0')
        xValue = xPage || xUsage
        sMeaning = getUsageDescAndType(xPage,xUsage) updateHexValue('USAGE',xUsage)
      end
      if g.0IN_DELIMITER
      then do /* only use the first usage in the delimited set */
        if g.0FIRST_USAGE
        then g.0USAGES = g.0USAGES xValue
        g.0FIRST_USAGE = 0 
      end
      else g.0USAGES = g.0USAGES xValue
    end
    when sTag = k.0LOCAL.USAGE_MINIMUM then do
      xUsage = right(xValue,4,'0')
      xValue = xPage || xUsage
      sMeaning = getUsageDescAndType(xPage,xUsage) updateHexValue('USAGE_MINIMUM',xUsage)
    end
    when sTag = k.0LOCAL.USAGE_MAXIMUM then do
      xUsage = right(xValue,4,'0')
      xValue = xPage || xUsage
      sMeaning = getUsageDescAndType(xPage,xUsage) updateHexValue('USAGE_MAXIMUM',xUsage)
    end
    when sTag = k.0LOCAL.DESIGNATOR_INDEX then do
      sMeaning = '('nValue')' updateValue('DESIGNATOR_INDEX',nValue)
    end
    when sTag = k.0LOCAL.DESIGNATOR_MINIMUM then do
      sMeaning = '('nValue')' updateValue('DESIGNATOR_MINIMUM',nValue)
    end
    when sTag = k.0LOCAL.DESIGNATOR_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('DESIGNATOR_MAXIMUM',nValue)
    end
    when sTag = k.0LOCAL.STRING_INDEX then do
      sMeaning = '('nValue')' updateValue('STRING_INDEX',nValue)
    end
    when sTag = k.0LOCAL.STRING_MINIMUM then do
      sMeaning = '('nValue')' updateValue('STRING_MINIMUM',nValue)
    end
    when sTag = k.0LOCAL.STRING_MAXIMUM then do
      sMeaning = '('nValue')' updateValue('STRING_MAXIMUM',nValue)
    end
    when sTag = k.0LOCAL.DELIMITER then do
      select
        when nValue = 1 then do
          if g.0IN_DELIMITER
          then sMeaning = '('nValue') <-- Error: Already in a DELIMITER set'
          g.0IN_DELIMITER = 1
          g.0FIRST_USAGE = 1
          bIndent = 1
          sMeaning = '('nValue') Open set'
        end
        when nValue = 0 then do
          if \g.0IN_DELIMITER
          then sMeaning = '('nValue') <-- Error: Not already in a DELIMITER set'
          g.0IN_DELIMITER = 0
          g.0INDENT = g.0INDENT - 2
          sMeaning = '('nValue') Close set'
        end
        otherwise sMeaning = '('nValue') <-- Invalid: Should be 0 or 1'
      end
    end
    otherwise sMeaning = '<-- Invalid: Unknown LOCAL tag'
  end
  call say xItem,xParm,'LOCAL',k.0LOCAL.sTag,xValue,sMeaning
  if bIndent
  then do
    g.0INDENT = g.0INDENT + 2
    bIndent = 0
  end
return

loadPage: procedure expose g. k.
  parse arg xPage
  if g.0CACHED.xPage = 1 then return
  call loadUsageFile xPage'.conf'
  g.0CACHED.xPage = 1
return

getSanity: procedure expose g.
  sError = ''
  if g.0REPORT_SIZE = 0
  then sError = sError '<-- Error: REPORT_SIZE = 0'
  if g.0REPORT_COUNT = 0
  then sError = sError '<-- Error: REPORT_COUNT = 0'
  nMinBits = getMinBits(g.0LOGICAL_MINIMUM)
  if g.0REPORT_SIZE < nMinBits
  then sError = sError '<-- Error: REPORT_SIZE ('g.0REPORT_SIZE') is too small for LOGICAL_MINIMUM ('g.0LOGICAL_MINIMUM') which needs' nMinBits 'bits.'
  nMinBits = getMinBits(g.0LOGICAL_MAXIMUM)
  if g.0REPORT_SIZE < nMinBits
  then sError = sError '<-- Error: REPORT_SIZE ('g.0REPORT_SIZE') is too small for LOGICAL_MAXIMUM ('g.0LOGICAL_MAXIMUM') which needs' nMinBits 'bits.'
  if g.0LOGICAL_MAXIMUM < g.0LOGICAL_MINIMUM
  then sError = sError '<-- Error: LOGICAL_MAXIMUM ('g.0LOGICAL_MAXIMUM') is less than LOGICAL_MINIMUM ('g.0LOGICAL_MINIMUM')'
  if g.0PHYSICAL_MAXIMUM < g.0PHYSICAL_MINIMUM
  then sError = sError '<-- Error: PHYSICAL_MAXIMUM ('g.0PHYSICAL_MAXIMUM') is less than PHYSICAL_MINIMUM ('g.0PHYSICAL_MINIMUM')'
return sError

getMinBits: procedure 
  parse arg n
  if n < 0
  then nMinBits = length(strip(x2b(d2x(n,16)),'LEADING','1')) + 1
  else nMinBits = length(strip(x2b(d2x(n,16)),'LEADING','0'))
return nMinBits

updateValue: procedure expose g.
  parse arg sName,nValue
  sKey = '0'sName
  if g.sKey = nValue
  then do
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
  if x2d(g.sKey) = x2d(xValue)
  then do
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

dumpHex: procedure expose g.
  parse upper arg xData
  do while xData <> ''
    parse var xData x1 +8 x2 +8 x3 +8 x4 +8 x5 +8 x6 +8 x7 +8 x8 +8 xData
    say '//' x1 x2 x3 x4 x5 x6 x7 x8
  end
return

getStatement: procedure
  parse arg sType sName,sComment
  sLabel = left(sType,8) sName
return left(sLabel, max(length(sLabel),37)) '//' sComment

emitInputFields: procedure expose inputField. k. o. f.
  /* Cycle through all the input fields accumulated and when the report_id
     changes, then emit a new structure */
  f.0LASTCOLLECTION = ''
  xLastReportId = ''
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
  f.0LASTCOLLECTION = ''
  xLastReportId = ''
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
  f.0LASTCOLLECTION = ''
  xLastReportId = ''
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

emitBeginStructure: procedure expose g. k. f.
  parse arg sStructureName,xReportId,sDirection
  if xReportId <> 0
  then f.0TYPEDEFNAME = getUniqueName(sStructureName || xReportId)'_t'
  else f.0TYPEDEFNAME = getUniqueName(sStructureName)'_t'
  call emitHeading getPageDesc(g.0USAGE_PAGE) sStructureName xReportId '('sDirection')'
  if xReportId <> 0
  then do
    say 'typedef struct'
    say '{'
    c = x2c(xReportId)
    if isAlphanumeric(c)
    then sDesc = '('x2d(xReportId)')' "'"c"'"
    else sDesc = '('x2d(xReportId)')'
    say '  'getStatement(k.0U8 'reportId;','Report ID = 0x'xReportId sDesc)
  end
  else do
    say 'typedef struct'
    say '{'
    say '  'getStatement(,'No REPORT ID byte')
  end
return

emitEndStructure: procedure expose g. f.
  parse arg sStructureName,xReportId
  say '}' f.0TYPEDEFNAME';'
  say
return

emitHeading: procedure
  parse arg sHeading
  say 
  say '//--------------------------------------------------------------------------------'
  say '//' sHeading
  say '//--------------------------------------------------------------------------------'
  say 
return  

emitField: procedure expose k. o. f.
  parse arg nField,xFlags sGlobals','sLocals','xExplicitUsages','sFlags','sCollectionName
  call setGlobals sGlobals
  call setLocals sLocals
  if o.0VERBOSITY > 0
  then do
    say
    say '  // Field:  ' nField
    say '  // Width:  ' g.0REPORT_SIZE
    say '  // Count:  ' g.0REPORT_COUNT
    say '  // Flags:  ' xFlags':' sFlags
    say '  // Globals:' getFormattedGlobals()
    say '  // Locals: ' getFormattedLocals()
    say '  // Usages: ' strip(xExplicitUsages) /* list of specified usages, if any */
  end
  sFlags = x2c(xFlags)
  nUsageMin = x2d(g.0USAGE_MINIMUM)
  nUsageMax = x2d(g.0USAGE_MAXIMUM)
  nUsage = nUsageMin /* first usage to be emitted in the range */
  nExplicitUsages = words(xExplicitUsages)
  g.0FIELD_TYPE = getFieldType()
  if o.0VERBOSITY > 0
  then do
    if isData(sFlags)
    then do /* data i.e. can be changed */
      say '  // Access:  Read/Write'
    end
    else do
      say '  // Access:  Read/Only'
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
       USAGE_MINIMUM is the minimum usage in a range.
       USAGE_MAXIMUM is the maximum usage in a range.

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

    3. Both of the above, in which case the explicit usages are assigned
       first, and then the range of usages is assigned, and then  the
       last assigned usage is applied to the remaining fields if any.
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
      say '  // Type:    Variable'
      say '  'getStatement('', xPage getPageDesc(xPage))
    end
    if sCollectionName <> f.0LASTCOLLECTION
    then do
      say '  'getStatement(,sCollectionName 'collection')

      f.0LASTCOLLECTION = sCollectionName
    end
    sUsages = getUsages(xExplicitUsages,nUsageMin,nUsageMax)
    nUsages = words(sUsages)
    if nUsages = 0 & isConstant(sFlags) 
    then call emitPaddingFieldDecl g.0REPORT_COUNT,nField
    else do /* data or constant, with usage(s) specified */
      nRemainingReportCount = g.0REPORT_COUNT
      /* Emit all but the last usage */
      do i = 1 to nUsages-1 while nRemainingReportCount > 0
        xExtendedUsage = word(sUsages,i)
        call emitFieldDecl 1,xExtendedUsage
        nRemainingReportCount = nRemainingReportCount - 1
      end
      xExtendedUsage = word(sUsages,i) /* usage to be replicated if room */
      if nUsages > g.0REPORT_COUNT
      then do
        do nIgnored = i to nUsages
          xIgnoredUsage = word(sUsages,nIgnored)
          parse var xIgnoredUsage xPage +4 xUsage +4
          say '  'getStatement('',xPage xUsage getUsageDescAndType(xPage,xUsage) getRange() '<-- Ignored: REPORT_COUNT ('g.0REPORT_COUNT') is too small')
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
       USAGE_MINIMUM is the minimum usage in a range.
       USAGE_MAXIMUM is the maximum usage in a range.


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

    3. Both of the above, in which case the explicit usages are assigned
       first, and then the range of usages is assigned.
       E.g. LOGICAL_MINIMUM 7, LOGICAL_MAXIMUM 9, 
            USAGE_MININUM B, USAGE_MAXIMUM C
            USAGE A:
            index usage
              7     A     <-- Explicit
              8     B     <-- First in range
              9     C     <-- Last in range
            other  novalue

    Note: An array is not like a string of characters in a buffer, each array 
    element can contain an INDEX (from LOGICAL_MINIMUM to LOGICAL_MAXIMUM) 
    to a usage, so if, in a keyboard example, three keys on a keyboard are 
    pressed simultaneously, then three elements of the array will contain an 
    index to the corresponding usage (a key in this case) - and not necessarily 
    in the order they were pressed. The maximum number of keys that can be 
    asserted at once is limited by the REPORT_COUNT. The maximum number of keys
    that can be represented is:  LOGICAL_MAXIMUM - LOGICAL_MINIMUM + 1.
    */
    if o.0VERBOSITY > 0
    then do
      say '  // Type:    Array'
      say '  'getStatement('', xPage getPageDesc(xPage))
    end
    /* todo: coming up with a field name is tricky...each field can
             index many usages, so a particular usage name can't be
             used.
    */
    if sCollectionName <> f.0LASTCOLLECTION
    then do
      say '  'getStatement(,sCollectionName 'collection')

      f.0LASTCOLLECTION = sCollectionName
    end
    sUsages = getUsages(xExplicitUsages,nUsageMin,nUsageMax)
    nUsages = words(sUsages)
    if nUsages = 0 & isConstant(sFlags) 
    then call emitPaddingFieldDecl g.0REPORT_COUNT,nField
    else do /* data */
      call emitFieldDecl g.0REPORT_COUNT,xPage
    end
    if o.0VERBOSITY > 1
    then do /* Document the valid indexes in the array */
      nLogical = g.0LOGICAL_MINIMUM
      /* Emit any explicitly listed usages */
      if nExplicitUsages > 0 
      then do
        do i = 1 to nExplicitUsages 
          xExtendedUsage = word(xExplicitUsages,i) /* ppppuuuu */
          parse var xExtendedUsage xPage +4 xUsage +4
          sUsageDesc = getUsageDescAndType(xPage,xUsage)
          if sUsageDesc <> '' | (sUsageDesc = '' & o.0VERBOSITY > 2)
          then say '  'getStatement('', 'Value' nLogical '=' xPage xUsage sUsageDesc)
          nLogical = nLogical + 1
        end
      end
      /* Emit a range of usages if present */
      if nUsageMin < nUsageMax 
      then do
        do nUsage = nUsageMin to nUsageMax
          xPage = g.0USAGE_PAGE
          xUsage = d2x(nUsage,4)
          sUsageDesc = getUsageDescAndType(xPage,xUsage)
          if sUsageDesc <> '' | (sUsageDesc = '' & o.0VERBOSITY > 2)
          then say '  'getStatement('', 'Value' nLogical '=' xPage xUsage sUsageDesc)
          nLogical = nLogical + 1
        end
      end
    end
  end
return

getUsages: procedure expose g.
  parse arg sUsages,nUsageMin,nUsageMax
  /* Build the combined list of usages - explicit (if any) + range (if any) */
  if nUsageMin <> 0 | nUsageMax <> 0 /* if a range is present */
  then do nUsage = nUsageMin to nUsageMax
    xExtendedUsage = g.0USAGE_PAGE || d2x(nUsage,4)
    sUsages = sUsages xExtendedUsage
  end
return sUsages

emitFieldDecl: procedure expose g. k. f.
  parse arg nReportCount,xExtendedUsage,sPad
  if nReportCount < 1 then return
  sFieldName = getFieldName(xExtendedUsage,f.0TYPEDEFNAME)sPad
  parse var xExtendedUsage xPage +4 xUsage +4
  if wordpos(g.0REPORT_SIZE,'8 16 32') > 0
  then do
    if nReportCount = 1
    then say '  'getStatement(g.0FIELD_TYPE sFieldName';'                   , xPage xUsage getUsageDescAndType(xPage,xUsage) getRange())
    else say '  'getStatement(g.0FIELD_TYPE sFieldName'['nReportCount'];'   , xPage xUsage getUsageDescAndType(xPage,xUsage) getRange())
  end
  else do
    say '  'getStatement(g.0FIELD_TYPE sFieldName ':' g.0REPORT_SIZE';', xPage xUsage getUsageDescAndType(xPage,xUsage) getRange())
    do i = 1 to nReportCount-1
      say '  'getStatement(g.0FIELD_TYPE sFieldName||i ':' g.0REPORT_SIZE';', xPage xUsage getUsageDescAndType(xPage,xUsage) getRange())
    end
  end
return

emitPaddingFieldDecl: procedure expose g. k.
  parse arg nReportCount,nField
  if nReportCount < 1 then return
  if wordpos(g.0REPORT_SIZE,'8 16 32') > 0
  then do
    if nReportCount = 1
    then say '  'getStatement(g.0FIELD_TYPE 'pad_'nField';', 'Pad')
    else say '  'getStatement(g.0FIELD_TYPE 'pad_'nField'['nReportCount'];', 'Pad')
  end
  else do i = 1 to nReportCount
    say '  'getStatement(g.0FIELD_TYPE ':' g.0REPORT_SIZE';', 'Pad')
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
    otherwise do
      if g.0LOGICAL_MINIMUM < 0 
      then sFieldType = k.0I32
      else sFieldType = k.0U32
    end
  end
return sFieldType

getRange: procedure expose g.
return 'Value =' g.0LOGICAL_MINIMUM 'to' g.0LOGICAL_MAXIMUM

getPadding: procedure expose g.
return 'Padding' getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE)

getFieldName: procedure expose k. f.
  parse arg xPage +4 xUsage +4,sStructureName
  sLabel = k.0LABEL.xPage.xUsage
  if sLabel = '' then parse value getUsageDescAndType(xPage,xUsage) with sLabel'('
  if sLabel = '' then sLabel = xUsage
  if sLabel = '' then sLabel = getCollectionName()
  sLabel = getSaneLabel(sLabel)
  sFieldName = getUniqueName(space(getShortPageName(xPage)'_'sLabel,0),sStructureName)
return sFieldName

getSaneLabel: procedure
  parse arg sLabel
  sLabel = space(translate(sLabel,'','~!@#$%^&*()+`-={}|[]\:;<>?,./"'"'"),0)
return sLabel

getCollectionName: procedure expose f.
  if f.0COLLECTION_NAME = ''
  then sCollectionName = 'VendorDefined'
  else sCollectionName = f.0COLLECTION_NAME
return sCollectionName

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
    when sPage > '0092'x & sPage < 'ff00'x then sPageDesc =  'Reserved,RES'
    when sPage >= 'ff00'x then do
        if k.0PAGE.xPage = ''
        then sPageDesc = 'Vendor-defined,VEN'
        else sPageDesc = k.0PAGE.xPage
    end
    otherwise sPageDesc = k.0PAGE.xPAGE
  end
return sPageDesc

getUsageDescAndType: procedure expose k.
  parse arg xPage,xUsage /* pppp, uuuu */
return k.0USAGE.xPage.xUsage

getExtendedUsageDescAndType: procedure expose k.
  parse arg xPage +4 xUsage +4 /* ppppuuuu */
return getPageDesc(xPage)':' k.0USAGE.xPage.xUsage

getUsageDesc: procedure expose k.
  parse arg xPage,xUsage
  /* sUsageDesc = k.0USAGE.xPage.xUsage  */
  parse var k.0USAGE.xPage.xUsage sUsageDesc '('
return strip(sUsageDesc)

getUsageType: procedure expose k.
  parse arg xPage,xUsage
  parse var k.0USAGE.xPage.xUsage '('sUsageType'='
return sUsageType

getCollectionType: procedure expose g.
  parse arg xType
return g.0COLLECTION_TYPE.xType

getCollectionDesc: procedure expose g.
  parse arg xType
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
  if isVariable(sValue)
  then sFlags = sFlags '1=Variable'
  else sFlags = sFlags '0=Array'
  if isRelative(sValue)
  then sFlags = sFlags '1=Relative'
  else sFlags = sFlags '0=Absolute'
return strip(sFlags)

getFlags:
  sFlags = getInputArrayFlags()
  if isWrap(sValue)
  then sFlags = sFlags '1=Wrap'
  else sFlags = sFlags '0=NoWrap'
  if isNonLinear(sValue)
  then sFlags = sFlags '1=NonLinear'
  else sFlags = sFlags '0=Linear'
  if isNoPrestate(sValue)
  then sFlags = sFlags '1=NoPrefState'
  else sFlags = sFlags '0=PrefState'
  if isNull(sValue,'01000000'b)
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

isNoPreState: procedure
  parse arg sFlags
return isOn(sFlags,'00100000'b)

isPreState: procedure
  parse arg sFlags
return \isNoPreState(sFlags)

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
return getUnitExponent(x2d(xValue))

getUnit: procedure expose k.
  parse arg xValue
  xValue = right(xValue,8,'0')
  parse var xValue xReserved +1 xLight +1 xCurrent +1 xTemperature +1,
                   xTime     +1 xMass  +1 xLength  +1 xSystem      +1
  select                   
    when xSystem = '0' then sUnit = '0=None'
    when xSystem = 'F' then sUnit = 'F=Vendor-defined'
    when pos(xSystem,'56789ABCDE') > 0 then sUnit = 'E=Reserved <-- Error: Measurement system type' xSystem 'is reserved'
    otherwise do
      sUnit = xSystem'='k.0UNIT.0.xSystem
      if xLength      <> '0' then sUnit = sUnit','      xLength'='k.0UNIT.1.xSystem'^'getPower(xLength)
      if xMass        <> '0' then sUnit = sUnit','        xMass'='k.0UNIT.2.xSystem'^'getPower(xMass)
      if xTime        <> '0' then sUnit = sUnit','        xTime'='k.0UNIT.3.xSystem'^'getPower(xTime)
      if xTemperature <> '0' then sUnit = sUnit',' xTemperature'='k.0UNIT.4.xSystem'^'getPower(xTemperature)
      if xCurrent     <> '0' then sUnit = sUnit','     xCurrent'='k.0UNIT.5.xSystem'^'getPower(xCurrent)
      if xLight       <> '0' then sUnit = sUnit','       xLight'='k.0UNIT.6.xSystem'^'getPower(xLight)
    end
  end
return sUnit

emitOpenDecode: procedure expose g. o. f.
  if \o.0DECODE then return
  call emitHeading 'Decoded Application Collection'
  select
    when o.0HEADER = 'AVR' then do
      say 'PROGMEM char' getUniqueName('usbHidReportDescriptor')'[] ='
      say '{'
    end
    when o.0HEADER = 'MCHIP' then do
      say 'ROM struct'
      say '{'
      say '  BYTE report[USB_HID_REPORT_DESCRIPTOR_SIZE];'
      say '}' getUniqueName('hid_report_descriptor') '='
      say '{'
      say '  {'
    end
    when o.0HEADER = 'MIKROC' then do
      say 'const struct'
      say '{'
      say '  char report[USB_HID_REPORT_DESCRIPTOR_SIZE];'
      say '}' getUniqueName('hid_report_descriptor') '='
      say '{'
      say '  {'
    end
    otherwise do
      say '/*'
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
        say '};'
      end
      when o.0HEADER = 'MCHIP' then do
        say '  }'
        say '};'
      end
      when o.0HEADER = 'MIKROC' then do
        say '  }'
        say '};'
      end
      otherwise do
        say '*/'
      end
    end
  end
  g.0DECODE_OPEN = 0
return

say: procedure expose g. o. f.
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
      then say left(sChunk,30) '//'left('',g.0INDENT) left('('sType')',8) left(sTag,18) sDescription
      else say left(sChunk,30) '//'left('',g.0INDENT) left('('sType')',8) left(sTag,18) '0x'xValue sDescription
    end
    when o.0HEADER = 'MICROCHIP' then do
      say o.0HEADER sCode sParm sType sTag xValue sDescription
    end
    otherwise do
      if xValue = '' 
      then say sCode left(sParm,8) left('',g.0INDENT) left('('sType')',8) left(sTag,18) sDescription
      else say sCode left(sParm,8) left('',g.0INDENT) left('('sType')',8) left(sTag,18) '0x'xValue sDescription
    end
  end
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

pushStack: procedure expose g.
  parse arg item
  tos = g.0T + 1        /* get new top of stack index */
  g.0E.tos = item       /* set new top of stack item */
  g.0T = tos            /* set new top of stack index */
return

popStack: procedure expose g.
  tos = g.0T            /* get top of stack index for */
  item = g.0E.tos       /* get item at top of stack */
  g.0T = max(tos-1,1)
return item

peekStack: procedure expose g.
  tos = g.0T            /* get top of stack index */
  item = g.0E.tos       /* get item at top of stack */
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
  then say 'RDD001W Invalid option ignored:' sToken
  else do
    nOptionType = getOptionType(sOption)
    g.0OPTION_PRESENT.nOption = 1
    select
      when nOptionType = k.0OPTION_COUNT then do
        g.0OPTION.nOption = g.0OPTION.nOption + 1
      end
      when nOptionType = k.0OPTION_BOOLEAN then do
        g.0OPTION.nOption = \g.0OPTION.nOption
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
  parse arg sOption
  bGetNextToken = 1
  if getOptionIndex(sOption) = 0
  then do
    say 'RDD001W Invalid option ignored:' sOption
  end
  else do
    nOptionType = getOptionType(sOption)
    select
      when nOptionType = k.0OPTION_COUNT then do /* --key [--key ...] */
        call setOption sOption
      end
      when nOptionType = k.0OPTION_LIST then do /* --key [val ...] */
        sArgs = ''
        g.0TOKEN = getNextToken()
        do while \isOptionLike(g.0TOKEN) & g.0TOKEN <> ''
          sArgs = sArgs g.0TOKEN
          g.0TOKEN = getNextToken()
          bGetNextToken = 0
        end
        call setOption sOption,strip(sArgs)
      end
      when nOptionType = k.0OPTION_BOOLEAN then do /* --key */
        call setOption sOption
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
        call setOption sOption,strip(sArgs)
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

Prolog:
  g.0IN_DELIMITER = 0 /* Inside a delimited set of usages */
  g.0FIRST_USAGE  = 0 /* First delimited usage has been processed */

  k.0I8  = 'int8_t'
  k.0U8  = 'uint8_t'
  k.0I16 = 'int16_t'
  k.0U16 = 'uint16_t'
  k.0I32 = 'int32_t'
  k.0U32 = 'uint32_t'

  g.0OPTION_INDEX.0 = 0 /* Number of valid options */
  k.0OPTION_COUNT   = -2
  k.0OPTION_LIST    = -1
  k.0OPTION_BOOLEAN = 0

  call addListOption      '-f','--file'    ,'Read input from the specified file'
  call addListOption      '-c','--hex'     ,'Read hex input from command line'
  call addBooleanOption   '-b','--binary'  ,'Input file is binary (not text)'
  call addBooleanOption   '-s','--struct'  ,'Output C structure declarations (default)'
  call addBooleanOption   '-d','--decode'  ,'Output decoded report descriptor'
  call addListOption      '-h','--header'  ,'Output C header in AVR, MIKROC or MICROCHIP format'
  call addBooleanOption   '-x','--dump'    ,'Output hex dump of report descriptor'
  call addListOption      '-i','--include' ,'Read vendor-specific definition file'
  call addCountableOption '-v','--verbose' ,'Output more detail'
  call addBooleanOption       ,'--version' ,'Display version and exit'
  call addBooleanOption   '-?','--help'    ,'Display this information'

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

  call clearGlobals
  call addGlobal '00000000'b,'USAGE_PAGE'
  call addGlobal '00010000'b,'LOGICAL_MINIMUM'
  call addGlobal '00100000'b,'LOGICAL_MAXIMUM'
  call addGlobal '00110000'b,'PHYSICAL_MINIMUM'
  call addGlobal '01000000'b,'PHYSICAL_MAXIMUM'
  call addGlobal '01010000'b,'UNIT_EXPONENT'
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
  call addType 'CACP','Application or Physical Collection'
  call addType 'CL','Logical Collection'
  call addType 'CP','Physical Collection'
  call addType 'DF','Dynamic Flag'
  call addType 'DV','Dynamic Value'
  call addType 'DV-DF','Dynamic Value/Flag'
  call addType 'LC','Linear Control'
  call addType 'MC','Momentary Control'
  call addType 'NAry','Named Array'
  call addType 'OOC','On/Off Control'
  call addType 'OSC','One Shot Control'
  call addType 'OSC-NAry','One Shot Control/Named Array'
  call addType 'RTC','Re-trigger Control'
  call addType 'MULTI','Selector, On/Off, Momentary, or One Shot'
  call addType 'Sel','Selector'
  call addType 'SF','Static Flag'
  call addType 'SFDF','Static Flag or Dynamic Flag'
  call addType 'SV','Static Value'
  call addType 'SVDV','Static Value or Dynamic Value'
  call addType 'UM','Usage Modifier'
  call addType 'US','Usage Switch'

  /* Some pre-defined common SI units:
          .---------- Reserved                 |-- Perhaps should be "amount of substance" in moles, to conform with SI
          |.--------- Luminous intensity (in candelas)
          ||.-------- Current (in amperes)
          |||.------- Temperature (in kelvin for SI)
          ||||.------ Time (in seconds)        |
          |||||.----- Mass (in grams)          |-- Odd, since CGS units were deprecated in favour of MKS units (+ the above + moles for SI units)
          ||||||.---- Length (in centimetres)  |
          |||||||.--- System of measurement
          ||||||||
          VVVVVVVV
  Nibble: 76543210    Description of unit
          --------    ------------------------------------- */
  /* SI base units (excluding "amount of substance" in moles) */
  k.0UNIT.00000011 = 'Distance in metres [1 cm units]'
  k.0UNIT.00000101 = 'Mass in grams [1 g units]'
  k.0UNIT.00001001 = 'Time in seconds [1 s units]'
  k.0UNIT.00010001 = 'Temperature in kelvin [1 K units]'
  k.0UNIT.00100001 = 'Current in amperes [1 A units]'
  k.0UNIT.01000001 = 'Luminous intensity in candelas [1 cd units]'

  /* Coherent derived units in the SI expressed in terms of base units */
  k.0UNIT.00000021 = 'Area [1 cm² units]'
  k.0UNIT.00000031 = 'Volume [1 cm³ units]'
  k.0UNIT.0000F011 = 'Velocity [1 cm/s units]'
  k.0UNIT.0000E011 = 'Acceleration [1 cm/s² units]'
  k.0UNIT.000001D1 = 'Mass density [1 g/cm³ units]'
  k.0UNIT.000001E1 = 'Surface density [1 g/cm² units]'
  k.0UNIT.00000F31 = 'Specific volume [1 cm³/g units]'
  k.0UNIT.001000E1 = 'Current density [1 A/cm² units]'
  k.0UNIT.001000F1 = 'Magnetic field strength [1 A/cm units]'
  k.0UNIT.010000E1 = 'Luminance [1 cd/cm² units]'

  /* Coherent derived units in the SI with special names and symbols */
  k.0UNIT.0000F001 = 'Frequency in hertz [1 Hz units]'
  k.0UNIT.0000E111 = 'Force in newtons [10 μN units]'
  k.0UNIT.0000E1F1 = 'Pressure in pascals [0.1 Pa units]'
  k.0UNIT.0000E121 = 'Energy in joules [0.1 μJ units]'
  k.0UNIT.0000D121 = 'Power in watts [0.1 μW units]'
  k.0UNIT.00101001 = 'Electric charge in coulombs [1 C units]'
  k.0UNIT.00F0D121 = 'Voltage [0.1 μV units]'
  k.0UNIT.00204FE1 = 'Capacitance in farads [10 MF units]' /* sheesh! */
  k.0UNIT.00E0D121 = 'Resistance in ohms [0.1 μΩ units]'
  k.0UNIT.00203FE1 = 'Conductance in siemens [10 MS units]'
  k.0UNIT.00F0E121 = 'Magnetic flux in webers [0.1 μWb units]'
  k.0UNIT.00F0E101 = 'Magnetic flux density in teslas [1 mT units]'
  k.0UNIT.00E0E121 = 'Inductance in henries [0.1 μH units]'
  k.0UNIT.010000E1 = 'Luminance [1 cd/cm² units]'

  /* Coherent derived units whose names and symbols include SI coherent derived units with special names and symbols */
  k.0UNIT.0000F1F1 = 'Dynamic viscosity in pascal seconds [0.1 Pa s units]'
  k.0UNIT.0000E121 = 'Moment of force in newton metres [0.1 μN m units]'
  k.0UNIT.0000E121 = 'Surface tension in newton per metre [1 g/s² units]'
  k.0UNIT.0000F002 = 'Angular velocity [1 rad/s units]'
  k.0UNIT.0000E002 = 'Angular acceleration [1 rad/s² units]'
  k.0UNIT.0000D101 = 'Heat flux density in watt per square metre [1 mW/m² units]'
  k.0UNIT.000FE121 = 'Heat capacity in joule per kelvin [0.1 μJ/K units]'
  k.0UNIT.000FE021 = 'Specific heat capacity in joule per kilogram kelvin [100 μJ/(kg K) units]'
  k.0UNIT.0000E021 = 'Specific energy in joule per kilogram [100 μJ/kg units]'
  k.0UNIT.000FD111 = 'Thermal conductivity in watts per metre per kelvin [10 μW/(m K) units]'
  k.0UNIT.00F0D111 = 'Electric field strength in volt per metre [10 μV/m units]'
  k.0UNIT.001010D1 = 'Electric charge density in coulomb per m³ [1 MC/m³ units]'
  k.0UNIT.001010E1 = 'Surface charge density in coulomb per m² [10 kC/m² units]'
  k.0UNIT.00204FD1 = 'Permittivity in farad per metre [1 GF/m units]' /* WTF! */
  k.0UNIT.00E0E111 = 'Permeability in henry per metre [0.01 H/m units]'
  k.0UNIT.0000F111 = 'Momentum [1 gram cm/s units]'
  
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

addGlobal: procedure expose k.
  parse arg sCode,sName
  k.0GLOBAL.sCode = sName
  k.0GLOBAL.sName = sCode
return

addLocal: procedure expose k.
  parse arg sCode,sName
  k.0LOCAL.sCode = sName
  k.0LOCAL.sName = sCode
return

clearGlobals: procedure expose g.
  call setGlobals 0 0 0 0 0 0 0 0 0 0
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
  sGlobals = g.0USAGE_PAGE,
             g.0LOGICAL_MINIMUM,
             g.0LOGICAL_MAXIMUM,
             g.0PHYSICAL_MINIMUM,
             g.0PHYSICAL_MAXIMUM,
             g.0UNIT_EXPONENT,
             g.0UNIT,
             g.0REPORT_SIZE,
             g.0REPORT_ID,
             g.0REPORT_COUNT
return sGlobals

setGlobals: procedure expose g.
  parse arg  g.0USAGE_PAGE,
             g.0LOGICAL_MINIMUM,
             g.0LOGICAL_MAXIMUM,
             g.0PHYSICAL_MINIMUM,
             g.0PHYSICAL_MAXIMUM,
             g.0UNIT_EXPONENT,
             g.0UNIT,
             g.0REPORT_SIZE,
             g.0REPORT_ID,
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

Epilog:
return
