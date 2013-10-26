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

  sFile        = g.0REST
  sData        = getOption('--hex')
  o.0BINARY    = getOption('--binary')
  o.0VERBOSITY = getOption('--verbose')
  o.0STRUCT    = getOption('--struct')
  o.0DECODE    = getOption('--decode')
  o.0FORMAT    = toUpper(getOption('--format'))
  o.0DUMP      = getOption('--dump')
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
    say 'Syntax: rexx' sThis '[-f format] [-dsvxb] filein'
    say '    or: rexx' sThis '[-f format] [-dsvx] -h hex'
    say
    say 'Where:'
    say '      filein           = Input file path to be decoded'
    say '      hex              = Printable hex to be decoded'
    say '      format           = Output C header file format:'
    say '                         AVR    - AVR style'
    say '                         MIKROC - MikroElektronika mikroC Pro for PIC style'
    say '                         MCHIP  - Microchip C18 style'
    do i = 1 to g.0OPTION_INDEX.0
      say '      'left(strip(g.0OPTION_SHORT.i g.0OPTION_LONG.i),16) '=' g.0OPTION_DESC.i
    end
    say 
    say 'Example:'
    say '      rexx' sThis '-h 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0'
    say '       ...decodes the given hex string'
    say
    say '      rexx' sThis 'myinputfile.h'
    say '       ...decodes the hex strings found in the specified file'
    return
  end

  if \(o.0DECODE | o.0STRUCT | o.0DUMP) /* If neither --decode nor --struct nor --dump was specified */
  then o.0STRUCT = 1          /* then assume --struct was specified */

  featureField.0 = 0
  inputField.0 = 0
  outputField.0 = 0
  sCollectionStack = ''
  g.0INDENT = 0

  xData = readDescriptor(sFile,sData)
  if o.0DUMP
  then do
    call emitHeading 'Report descriptor data in hex (length' length(xData)/2 'bytes)'
    say
    call dumpHex xData
    say
  end

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
    sValue = getLittleEndian(sParm) /* llhh --> hhll */
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
    if \datatype(xData,'XADECIMAL')
    then do
      say 'RDD002E Expecting printable hexadecimal data. Found:' sData
      xData = ''
    end
  end
  else do
    xData = ''
    rc = stream(sFile,'COMMAND','OPEN READ')
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
              if datatype(sWord,'X')
              then sWord = c2x(sWord)
            end
            otherwise nop
          end
          if datatype(sWord,'X')
          then xData = xData || sWord
          else leave /* stop when the first non-hexadecimal value is found */
        end
      end
    end
    rc = stream(sFile,'COMMAND','CLOSE')  
  end
return xData

processMAIN:
  select
    when sTag = k.0MAIN.INPUT then do
      sDesc = getInputDesc()
      call say xItem,xParm,'MAIN','INPUT',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sDesc getSanity()
      n = inputField.0 + 1
      inputField.n = xValue getGlobals()','getLocals()','g.0USAGES','sDesc
      inputField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.OUTPUT then do
      sDesc = getOutputDesc()
      call say xItem,xParm,'MAIN','OUTPUT',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sDesc getSanity()
      n = outputField.0 + 1
      outputField.n = xValue getGlobals()','getLocals()','g.0USAGES','sDesc
      outputField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.FEATURE then do
      sDesc = getFeatureDesc()
      call say xItem,xParm,'MAIN','FEATURE',xValue,getDimension(g.0REPORT_COUNT, g.0REPORT_SIZE) sDesc getSanity()
      n = featureField.0 + 1
      featureField.n = xValue getGlobals()','getLocals()','g.0USAGES','sDesc
      featureField.0 = n
      call clearLocals
    end
    when sTag = k.0MAIN.COLLECTION then do
      xPage = right(g.0USAGE_PAGE,4,'0')
      xUsage = right(g.0USAGE,4,'0')
      xExtendedUsage = xPage || xUsage
      parse value getUsageDescAndType(xPage,xUsage) with sCollectionName '('
      f.0COLLECTION_NAME = space(sCollectionName,0)
      sValue = getLittleEndian(sParm)
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
          if left(xExtendedUsage,2) <> 'FF' & getCollectionType(xValue) <> getUsageType(xPage,xUsage)
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
      if nCollectionType = 1
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
  sMeaning = ''
  select
    when sTag = k.0LOCAL.USAGE then do
      if length(sValue) = 4
      then do /* Both page and usage are specified: ppppuuuu */
        parse var xValue xUsage +4 xPage +4
      end
      else do /* Only usage is specified: uuuu */
        xUsage = right(xValue,4,'0')
        xValue = xPage || xUsage
      end
      g.0USAGES = g.0USAGES xValue
      sMeaning = getUsageDescAndType(xPage,xUsage) updateHexValue('USAGE',xUsage)
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
        when nValue = 1 then sMeaning = '('nValue') Open set'
        when nValue = 0 then sMeaning = '('nValue') Close set'
        otherwise sMeaning = '('nValue') <-- Invalid: Should be 0 or 1'
      end
    end
    otherwise sMeaning = '<-- Invalid: Unknown LOCAL tag'
  end
  call say xItem,xParm,'LOCAL',k.0LOCAL.sTag,xValue,sMeaning
return

getSanity: procedure expose g.
  sError = ''
  if g.0REPORT_SIZE = 0
  then sError = sError '<-- Error: REPORT_SIZE = 0'
  if g.0REPORT_COUNT = 0
  then sError = sError '<-- Error: REPORT_COUNT = 0'
return sError

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
  xLastReportId = ''
  do i = 1 to inputField.0
    parse var inputField.i xFlags sGlobals','sLocals','xExplicitUsages','sDesc
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
  xLastReportId = ''
  do i = 1 to outputField.0
    parse var outputField.i xFlags sGlobals','sLocals','xExplicitUsages','sDesc
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
  xLastReportId = ''
  do i = 1 to featureField.0
    parse var featureField.i xFlags sGlobals','sLocals','xExplicitUsages','sDesc
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
  call emitHeading getPageDesc(g.0USAGE_PAGE) sStructureName xReportId getCollectionName() '('sDirection')'
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
  if xReportId <> 0
  then do
    say '}' getUniqueName(sStructureName || xReportId'_'getCollectionName())'_t;'
  end
  else do
    say '}' getUniqueName(sStructureName'_'getCollectionName())'_t;'
  end
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
  parse arg nField,xFlags sGlobals','sLocals','xExplicitUsages','sFlags
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
    if isData(sFlags)
    then do /* data */
      nRemainingReportCount = g.0REPORT_COUNT
      /* Build the combined list of usages - explicit (if any) + range (if any) */
      sUsages = xExplicitUsages
      if nUsageMin <> 0 | nUsageMax <> 0 /* if a range is present */
      then do nUsage = nUsageMin to nUsageMax
        xExtendedUsage = g.0USAGE_PAGE || d2x(nUsage,4)
        sUsages = sUsages xExtendedUsage
      end
      /* Now emit all but the last usage */
      nUsages = words(sUsages)
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
          say '  'getStatement('',xPage xUsage getUsageDescAndType(xPage,xUsage) getRange() '<-- Ignored: REPORT_COUNT is too small')
        end
      end
      /* Now replicate the last usage to fill the report count */
      else call emitFieldDecl nRemainingReportCount,xExtendedUsage
    end
    else do /* constant, so emit padding field(s) */
      call emitPaddingFieldDecl g.0REPORT_COUNT,nField
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
    if isData(sFlags)
    then do /* data */
      call emitFieldDecl g.0REPORT_COUNT,xPage
    end
    else do /* constant, so emit padding field */
      call emitPaddingFieldDecl g.0REPORT_COUNT,nField
    end
    nLogical = x2d(g.0LOGICAL_MINIMUM)
    if o.0VERBOSITY > 1
    then do /* Document the valid indexes in the array */
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

emitFieldDecl: procedure expose g. k. f.
  parse arg nReportCount,xExtendedUsage,sPad
  if nReportCount < 1 then return
  sFieldName = getFieldName(xExtendedUsage)sPad
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
  parse arg xPage +4 xUsage +4
  sLabel = k.0LABEL.xPage.xUsage
  if sLabel = '' then parse value getUsageDescAndType(xPage,xUsage) with sLabel'('
  if sLabel = '' then sLabel = xUsage
  if sLabel = '' then sLabel = getCollectionName()
  sFieldName = getUniqueName(space(getShortPageName(xPage)'_'sLabel,0))
return sFieldName

getCollectionName: procedure expose f.
  if f.0COLLECTION_NAME = ''
  then sCollectionName = 'VendorDefined'
  else sCollectionName = f.0COLLECTION_NAME
return sCollectionName

getUniqueName: procedure expose f.
  parse arg sFieldName
  if f.0FIELDNAME.sFieldName = ''
  then do
    f.0FIELDNAME.sFieldName = 0
  end
  else do
    nFieldName = f.0FIELDNAME.sFieldName + 1
    f.0FIELDNAME.sFieldName = nFieldName
    sFieldName = sFieldName'_'nFieldName
  end
return sFieldName

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
  parse arg xPage,xUsage
  sUsageDescAndType = k.0USAGE.xPage.xUsage
return sUsageDescAndType

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

getInputDesc:
  if isVariable(sValue)
  then sFlags = getFlags()            /* variable */
  else sFlags = getInputArrayFlags()  /* array    */
return sFlags

getOutputDesc:
return getFlags()

getFeatureDesc:
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
  call emitHeading 'Decoded report descriptor'
  say 
  select
    when o.0FORMAT = 'AVR' then do
      say 'PROGMEM char' getUniqueName('usbHidReportDescriptor')'[] ='
      say '{'
    end
    when o.0FORMAT = 'MCHIP' then do
      say 'ROM struct'
      say '{'
      say '  BYTE report[USB_HID_REPORT_DESCRIPTOR_SIZE];'
      say '}' getUniqueName('hid_report_descriptor') '='
      say '{'
      say '  {'
    end
    when o.0FORMAT = 'MIKROC' then do
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
      when o.0FORMAT = 'AVR' then do
        say '};'
      end
      when o.0FORMAT = 'MCHIP' then do
        say '  }'
        say '};'
      end
      when o.0FORMAT = 'MIKROC' then do
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
    when o.0FORMAT = 'AVR' | o.0FORMAT = 'MIKROC' | o.0FORMAT = 'MCHIP' then do
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
    when o.0FORMAT = 'MICROCHIP' then do
      say o.0FORMAT sCode sParm sType sTag xValue sDescription
    end
    otherwise do
      if xValue = '' 
      then say sCode left(sParm,8) left('',g.0INDENT) left('('sType')',8) left(sTag,18) sDescription
      else say sCode left(sParm,8) left('',g.0INDENT) left('('sType')',8) left(sTag,18) '0x'xValue sDescription
    end
  end
return

getLittleEndian: procedure
  parse arg sBytes
return reverse(sBytes)  

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
    g.0OPTION_PRESENT.nOption = 1
    nOptionType = getOptionType(sOption)
    select
      when nOptionType = k.0OPTION_COUNT then do
        g.0OPTION.nOption = g.0OPTION.nOption + 1
      end
      when nOptionType = k.0OPTION_BOOLEAN then do
        g.0OPTION.nOption = \g.0OPTION.nOption
      end
      otherwise do
        g.0OPTION.nOption = sValue
      end
    end
  end
return

getOption: procedure expose g. k.
  parse arg sOption
  nOption = getOptionIndex(sOption)
return g.0OPTION.nOption

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
  k.0I8 = 'int8_t'
  k.0U8 = 'uint8_t'
  k.0I16 = 'int16_t'
  k.0U16 = 'uint16_t'
  k.0I32 = 'int32_t'
  k.0U32 = 'uint32_t'

  g.0OPTION_INDEX.0 = 0 /* Number of valid options */
  k.0OPTION_COUNT   = -2
  k.0OPTION_LIST    = -1
  k.0OPTION_BOOLEAN = 0

  call addListOption      '-h','--hex'     ,'Read hex input from command line'
  call addBooleanOption   '-b','--binary'  ,'Input file is binary (not text)'
  call addBooleanOption   '-s','--struct'  ,'Output C structure declarations (default)'
  call addBooleanOption   '-d','--decode'  ,'Output decoded report descriptor'
  call addListOption      '-f','--format'  ,'Output C header in AVR, MIKROC or MICROCHIP format'
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
  call addType 'RTFM','Read The Manual'
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

  do i = 1 until sourceline(i) = '/*DATA'
  end
  do i = i + 1 while sourceline(i) <> 'END*/'
    call parseUsageDefinition sourceline(i)
  end

  sFile = getOption('--include')
  if sFile <> ''
  then do
    sState = stream(sFile,'COMMAND','OPEN READ')
    do while chars(sFile) > 0
      call parseUsageDefinition linein(sFile)
    end
    sState = stream(sFile,'COMMAND','CLOSE')  
  end
return

parseUsageDefinition: procedure expose k. g.
  parse arg sLine
  parse upper arg s1 s2 .
  select
    when s1 = '' then nop /* null is valid hex so nip it in the bud here */
    when s1 = 'PAGE' then do
      parse var sLine . xPage sPage
      xPage = right(xPage,4,'0')
      k.0PAGE.xPage = sPage
      g.0PAGE = xPage
    end
    when datatype(s1,'X') then do
      parse var sLine xUsage sUsage','sType','sLabel
      xUsage = right(xUsage,4,'0')
      sDesc = k.0TYPE.sType
      xPage = g.0PAGE
      if sDesc <> ''
      then k.0USAGE.xPage.xUsage = sUsage '('sType'='sDesc')'
      else k.0USAGE.xPage.xUsage = sUsage 
      k.0LABEL.xPage.xUsage = getCamelCase(sUsage, sLabel)
    end
    otherwise nop
  end
return

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


/*
The following is a list of the known usage codes.

The format of PAGE entries is:
PAGE xx longname,variableprefix

The format of USAGE entries under each PAGE entry is:
xx longname[,datatype[,shortname]]
Normally, "shortname" is derived from "longname" by removing spaces,
but occasionally the "longname" contains special characters that
can't easily be converted to a short name (which is used name 
variables in C structure definitions) so "shortname", if 
present, is used instead. 
*/

/*DATA

PAGE 01 Generic Desktop Page,GD
00 Undefined
01 Pointer,CP,
02 Mouse,CA,
04 Joystick,CA,
05 Game Pad,CA,
06 Keyboard,CA,
07 Keypad,CA,
08 Multi-axis Controller,CA,
09 Tablet PC System Controls,CA,
30 X,DV,
31 Y,DV,
32 Z,DV,
33 Rx,DV,
34 Ry,DV,
35 Rz,DV,
36 Slider,DV,
37 Dial,DV,
38 Wheel,DV,
39 Hat switch,DV,
3A Counted Buffer,CL,
3B Byte Count,DV,
3C Motion Wakeup,OSC,
3D Start,OOC,
3E Select,OOC,
40 Vx,DV,
41 Vy,DV,
42 Vz,DV,
43 Vbrx,DV,
44 Vbry,DV,
45 Vbrz,DV,
46 Vno,DV,
47 Feature Notification,DV-DF,
48 Resolution Multiplier,DV,
80 System Control,CA,
81 System Power Down,OSC,
82 System Sleep,OSC,
83 System Wake Up,OSC,
84 System Context Menu,OSC,
85 System Main Menu,OSC,
86 System App Menu,OSC,
87 System Menu Help,OSC,
88 System Menu Exit,OSC,
89 System Menu Select,OSC,
8A System Menu Right,RTC,
8B System Menu Left,RTC,
8C System Menu Up,RTC,
8D System Menu Down,RTC,
8E System Cold Restart,OSC,
8F System Warm Restart,OSC,
90 D-pad Up,OOC,
91 D-pad Down,OOC,
92 D-pad Right,OOC,
93 D-pad Left,OOC,
A0 System Dock,OSC,
A1 System Undock,OSC,
A2 System Setup,OSC,
A3 System Break,OSC,
A4 System Debugger Break,OSC,
A5 Application Break,OSC,
A6 Application Debugger Break,OSC,
A7 System Speaker Mute,OSC,
A8 System Hibernate,OSC,
B0 System Display Invert,OSC,
B1 System Display Internal,OSC,
B2 System Display External,OSC,
B3 System Display Both,OSC,
B4 System Display Dual,OSC,
B5 System Display Toggle Int/Ext,OSC,
B6 System Display Swap Primary/Secondary,OSC,
B7 System Display LCD Autoscale,OSC,

PAGE 02 Simulation Controls Page,SC
00 Undefined
01 Flight Simulation Device,CA,
02 Automobile Simulation Device,CA,
03 Tank Simulation Device,CA,
04 Spaceship Simulation Device,CA,
05 Submarine Simulation Device,CA,
06 Sailing Simulation Device,CA,
07 Motorcycle Simulation Device,CA,
08 Sports Simulation Device,CA,
09 Airplane Simulation Device,CA,
0A Helicopter Simulation Device,CA,
0B Magic Carpet Simulation Device,CA,
0C Bicycle Simulation Device,CA,
20 Flight Control Stick,CA,
21 Flight Stick,CA,
22 Cyclic Control,CP,
23 Cyclic Trim,CP,
24 Flight Yoke,CA,
25 Track Control,CP,
B0 Aileron,DV,
B1 Aileron Trim,DV,
B2 Anti-Torque Control,DV,AntiTorqueControl
B3 Autopilot Enable,OOC,
B4 Chaff Release,OSC,
B5 Collective Control,DV,
B6 Dive Brake,DV,
B7 Electronic Countermeasures,OOC,
B8 Elevator,DV,
B9 Elevator Trim,DV,
BA Rudder,DV,
BB Throttle,DV,
BC Flight Communications,OOC,
BD Flare Release,OSC,
BE Landing Gear,OOC,
BF Toe Brake,DV,
C0 Trigger,MC,
C1 Weapons Arm,OOC,
C2 Weapons Select,OSC,
C3 Wing Flaps,DV,
C4 Accelerator,DV,
C5 Brake,DV,
C6 Clutch,DV,
C7 Shifter,DV,
C8 Steering,DV,
C9 Turret Direction,DV,
CA Barrel Elevation,DV,
CB Dive Plane,DV,
CC Ballast,DV,
CD Bicycle Crank,DV,
CE Handle Bars,DV,
CF Front Brake,DV,
D0 Rear Brake,DV,

PAGE 03 Virtual Reality Controls Page,VR
00 Unidentified 
01 Belt,CA,
02 Body Suit,CA,
03 Flexor,CP,
04 Glove,CA,
05 Head Tracker,CP,
06 Head Mounted Display,CA,
07 Hand Tracker,CA,
08 Oculometer,CA,
09 Vest,CA,
0A Animatronic Device,CA,
20 Stereo Enable,OOC
21 Display Enable,OOC

PAGE 04 Sport Controls Page,SC
00 Unidentified
01 Baseball Bat,CA,
02 Golf Club,CA,
03 Rowing Machine,CA,
04 Treadmill,CA,
30 Oar,DV,
31 Slope,DV,
32 Rate,DV,
33 Stick Speed,DV,
34 Stick Face Angle,DV,
35 Stick Heel/Toe,DV,
36 Stick Follow Through,DV,
37 Stick Tempo,DV,
38 Stick Type,NAry,
39 Stick Height,DV,
50 Putter,Sel,
51 1 Iron,Sel,Number1Iron
52 2 Iron,Sel,Number2Iron
53 3 Iron,Sel,Number3Iron
54 4 Iron,Sel,Number4Iron
55 5 Iron,Sel,Number5Iron
56 6 Iron,Sel,Number6Iron
57 7 Iron,Sel,Number7Iron
58 8 Iron,Sel,Number8Iron
59 9 Iron,Sel,Number9Iron
5A 10 Iron,Sel,Number10Iron
5B 11 Iron,Sel,Number11Iron
5C Sand Wedge,Sel,
5D Loft Wedge,Sel,
5E Power Wedge,Sel,
5F 1 Wood,Sel,Number1Wood
60 3 Wood,Sel,Number3Wood
61 5 Wood,Sel,Number5Wood
62 7 Wood,Sel,Number7Wood
63 9 Wood,Sel,Number9Wood

PAGE 05 Game Controls Page,GC
00 Undefined
01 3D Game Controller,CA,
02 Pinball Device,CA,
03 Gun Device,CA,
20 Point of View,CP,
21 Turn Right/Left,DV,
22 Pitch Forward/Backward,DV,
23 Roll Right/Left,DV,
24 Move Right/Left,DV,
25 Move Forward/Backward,DV,
26 Move Up/Down,DV,
27 Lean Right/Left,DV,
28 Lean Forward/Backward,DV,
29 Height of POV,DV,
2A Flipper,MC,
2B Secondary Flipper,MC,
2C Bump,MC,
2D New Game,OSC,
2E Shoot Ball,OSC,
2F Player,OSC,
30 Gun Bolt,OOC,
31 Gun Clip,OOC,
32 Gun Selector,NAry,
33 Gun Single Shot,Sel,
34 Gun Burst,Sel,
35 Gun Automatic,Sel,
36 Gun Safety,OOC,
37 Gamepad Fire/Jump,CL,
39 Gamepad Trigger,CL,

PAGE 06 Generic Device Controls Page,GD
00 Unidentified 
20 Battery Strength,DV
21 Wireless Channel,DV
22 Wireless ID,DV
23 Discover Wireless Control,OSC
24 Security Code Character Entered,OSC
25 Security Code Character Erased,OSC
26 Security Code Cleared,OSC

PAGE 07 Keyboard/Keypad Page,KB
00 Keyboard No event indicated,Sel
01 Keyboard ErrorRollOver,Sel
02 Keyboard POSTFail,Sel
03 Keyboard ErrorUndefined,Sel
04 Keyboard a and A,Sel,A
05 Keyboard b and B,Sel,B
06 Keyboard c and C,Sel,C
07 Keyboard d and D,Sel,D
08 Keyboard e and E,Sel,E
09 Keyboard f and F,Sel,F
0A Keyboard g and G,Sel,G
0B Keyboard h and H,Sel,H
0C Keyboard i and I,Sel,I
0D Keyboard j and J,Sel,J
0E Keyboard k and K,Sel,K
0F Keyboard l and L,Sel,L
10 Keyboard m and M,Sel,M
11 Keyboard n and N,Sel,N
12 Keyboard o and O,Sel,O
13 Keyboard p and P,Sel,P
14 Keyboard q and Q,Sel,Q
15 Keyboard r and R,Sel,R
16 Keyboard s and S,Sel,S
17 Keyboard t and T,Sel,T
18 Keyboard u and U,Sel,U
19 Keyboard v and V,Sel,V
1A Keyboard w and W,Sel,W
1B Keyboard x and X,Sel,X
1C Keyboard y and Y,Sel,Y
1D Keyboard z and Z,Sel,Z
1E Keyboard 1 and !,Sel,Digit1AndExclamationMark
1F Keyboard 2 and @,Sel,Digit2AndAtSign
20 Keyboard 3 and #,Sel,Digit3AndHash
21 Keyboard 4 and $,Sel,Digit4AndDollar
22 Keyboard 5 and %,Sel,Digit5AndPercent
23 Keyboard 6 and ^,Sel,Digit6AndCaret
24 Keyboard 7 and &,Sel,Digit7AndAmpersand
25 Keyboard 8 and *,Sel,Digit8AndAsterisk
26 Keyboard 9 and (,Sel,Digit9AndLeftParenthesis
27 Keyboard 0 and ),Sel,Digit0AndRightParenthesis
28 Keyboard Return,Sel
29 Keyboard Escape,Sel
2A Keyboard Delete,Sel
2B Keyboard Tab,Sel
2C Keyboard Spacebar,Sel
2D Keyboard - and _,Sel,HyphenAndUnderscore
2E Keyboard = and +,Sel,EqualsAndPlus
2F Keyboard [ and {,Sel,LeftSquareBracketAndLeftBrace
30 Keyboard ] and },Sel,RightSquareBracketAndRightBrace
31 Keyboard \ and |,Sel,BackslashAndVerticalBar
32 Keyboard Non-US # and ~,Sel,NonUSHashAndTilde
33 Keyboard ; and :,Sel,SemicolonAndColon
34 Keyboard ' and ",Sel,ApostropheAndQuotationMark
35 Keyboard ` and ~,Sel,GraveAndTilde
36 Keyboard Comma and <,Sel,CommaAndLessThanSign
37 Keyboard . and >,Sel,PeriodAndGreaterThanSign
38 Keyboard / and ?,Sel,SlashAndQuestionMark
39 Keyboard Caps Lock,Sel
3A Keyboard F1,Sel
3B Keyboard F2,Sel
3C Keyboard F3,Sel
3D Keyboard F4,Sel
3E Keyboard F5,Sel
3F Keyboard F6,Sel
40 Keyboard F7,Sel
41 Keyboard F8,Sel
42 Keyboard F9,Sel
43 Keyboard F10,Sel
44 Keyboard F11,Sel
45 Keyboard F12,Sel
46 Keyboard Print Screen,Sel
47 Keyboard Scroll Lock,Sel
48 Keyboard Pause,Sel
49 Keyboard Insert,Sel
4A Keyboard Home,Sel
4B Keyboard Page Up,Sel
4C Keyboard Delete Forward,Sel
4D Keyboard End,Sel
4E Keyboard Page Down,Sel
4F Keyboard Right Arrow,Sel
50 Keyboard Left Arrow,Sel
51 Keyboard Down Arrow,Sel
52 Keyboard Up Arrow,Sel
53 Keypad Num Lock and Clear,Sel
54 Keypad /,Sel,KeypadSlash
55 Keypad *,Sel,KeypadAsterisk
56 Keypad Comma,Sel
57 Keypad +,Sel,KeypadPlus
58 Keypad Enter,Sel
59 Keypad 1 and End,Sel,KeypadDigit1AndEnd
5A Keypad 2 and Down Arrow,Sel,KeypadDigit2AndDownArrow
5B Keypad 3 and PageDn,Sel,KeypadDigit3AndPageDown
5C Keypad 4 and Left Arrow,Sel,KeypadDigit4AndLeftArrow
5D Keypad 5,Sel,KeypadDigit5
5E Keypad 6 and Right Arrow,Sel,KeypadDigit6AndRightArrow
5F Keypad 7 and Home,Sel,KeypadDigit7AndHome
60 Keypad 8 and Up Arrow,Sel,KeypadDigit8AndUpArrow
61 Keypad 9 and PageUp,Sel,KeypadDigit9AndPageUp
62 Keypad 0 and Insert,Sel,KeypadDigit0AndInsert
63 Keypad . and Delete,Sel,KeypadDecimalPointandDelete
64 Keyboard Non-US \ and |,Sel,NonUSBackslashAndVerticalBar
65 Keyboard Application,Sel
66 Keyboard Power,Sel
67 Keypad =,Sel,KeypadEquals
68 Keyboard F13,Sel
69 Keyboard F14,Sel
6A Keyboard F15,Sel
6B Keyboard F16,Sel
6C Keyboard F17,Sel
6D Keyboard F18,Sel
6E Keyboard F19,Sel
6F Keyboard F20,Sel
70 Keyboard F21,Sel
71 Keyboard F22,Sel
72 Keyboard F23,Sel
73 Keyboard F24,Sel
74 Keyboard Execute,Sel
75 Keyboard Help,Sel
76 Keyboard Menu,Sel
77 Keyboard Select,Sel
78 Keyboard Stop,Sel
79 Keyboard Again,Sel
7A Keyboard Undo,Sel
7B Keyboard Cut,Sel
7C Keyboard Copy,Sel
7D Keyboard Paste,Sel
7E Keyboard Find,Sel
7F Keyboard Mute,Sel
80 Keyboard Volume Up,Sel
81 Keyboard Volume Down,Sel
82 Keyboard Locking Caps Lock,Sel
83 Keyboard Locking Num Lock,Sel
84 Keyboard Locking Scroll Lock,Sel
85 Keypad Comma,Sel
86 Keypad Equal Sign,Sel
87 Keyboard International1,Sel
88 Keyboard International2,Sel
89 Keyboard International3,Sel
8A Keyboard International4,Sel
8B Keyboard International5,Sel
8C Keyboard International6,Sel
8D Keyboard International7,Sel
8E Keyboard International8,Sel
8F Keyboard International9,Sel
90 Keyboard LANG1,Sel
91 Keyboard LANG2,Sel
92 Keyboard LANG3,Sel
93 Keyboard LANG4,Sel
94 Keyboard LANG5,Sel
95 Keyboard LANG6,Sel
96 Keyboard LANG7,Sel
97 Keyboard LANG8,Sel
98 Keyboard LANG9,Sel
99 Keyboard Alternate Erase,Sel
9A Keyboard SysReq/Attention,Sel
9B Keyboard Cancel,Sel
9C Keyboard Clear,Sel
9D Keyboard Prior,Sel
9E Keyboard Return,Sel
9F Keyboard Separator,Sel
A0 Keyboard Out,Sel
A1 Keyboard Oper,Sel
A2 Keyboard Clear/Again,Sel
A3 Keyboard CrSel/Props,Sel
A4 Keyboard ExSel,Sel
B0 Keypad 00,Sel
B1 Keypad 000,Sel
B2 Thousands Separator,Sel
B3 Decimal Separator,Sel
B4 Currency Unit,Sel
B5 Currency Sub-unit,Sel
B6 Keypad (,Sel,KeypadLeftParenthesis
B7 Keypad ),Sel,KeypadRightParenthesis
B8 Keypad {,Sel,KeypadLeftBrace
B9 Keypad },Sel,KeypadRightBrace
BA Keypad Tab,Sel
BB Keypad Backspace,Sel
BC Keypad A,Sel,KeypadA
BD Keypad B,Sel,KeypadB
BE Keypad C,Sel,KeypadC
BF Keypad D,Sel,KeypadD
C0 Keypad E,Sel,KeypadE
C1 Keypad F,Sel,KeypadF
C2 Keypad XOR,Sel
C3 Keypad ^,Sel,KeypadCaret
C4 Keypad %,Sel,KeypadPercent
C5 Keypad <,Sel,KeypadLessThanSign
C6 Keypad >,Sel,KeypadGreaterThanSign
C7 Keypad &,Sel,KeypadAmpersand
C8 Keypad &&,Sel,KeypadDoubleAmpersand
C9 Keypad |,Sel,KeypadVerticalBar
CA Keypad ||,Sel,KeypadDoubleVerticalBar
CB Keypad :,Sel,KeypadColor
CC Keypad #,Sel,KeypadHash
CD Keypad Space,Sel
CE Keypad @,Sel,KeypadAtSign
CF Keypad !,Sel,KeypadExclamationMark
D0 Keypad Memory Store,Sel
D1 Keypad Memory Recall,Sel
D2 Keypad Memory Clear,Sel
D3 Keypad Memory Add,Sel
D4 Keypad Memory Subtract,Sel
D5 Keypad Memory Multiply,Sel
D6 Keypad Memory Divide,Sel
D7 Keypad +/-,Sel,KeypadPlusOrMinus
D8 Keypad Clear,Sel
D9 Keypad Clear Entry,Sel
DA Keypad Binary,Sel
DB Keypad Octal,Sel
DC Keypad Decimal,Sel
DD Keypad Hexadecimal,Sel
E0 Keyboard Left Control,DV
E1 Keyboard Left Shift,DV
E2 Keyboard Left Alt,DV
E3 Keyboard Left GUI,DV
E4 Keyboard Right Control,DV
E5 Keyboard Right Shift,DV
E6 Keyboard Right Alt,DV
E7 Keyboard Right GUI,DV

PAGE 08 LED Indicator Page,LED
00 Undefined
01 Num Lock,OOC,
02 Caps Lock,OOC,
03 Scroll Lock,OOC,
04 Compose,OOC,
05 Kana,OOC,
06 Power,OOC,
07 Shift,OOC,
08 Do Not Disturb,OOC,
09 Mute,OOC,
0A Tone Enable,OOC,
0B High Cut Filter,OOC,
0C Low Cut Filter,OOC,
0D Equalizer Enable,OOC,
0E Sound Field On,OOC,
0F Surround On,OOC,
10 Repeat,OOC,
11 Stereo,OOC,
12 Sampling Rate Detect,OOC,
13 Spinning,OOC,
14 CAV,OOC,
15 CLV,OOC,
16 Recording Format Detect,OOC,
17 Off-Hook,OOC,
18 Ring,OOC,
19 Message Waiting,OOC,
1A Data Mode,OOC,
1B Battery Operation,OOC,
1C Battery OK,OOC,
1D Battery Low,OOC,
1E Speaker,OOC,
1F Head Set,OOC,
20 Hold,OOC,
21 Microphone,OOC,
22 Coverage,OOC,
23 Night Mode,OOC,
24 Send Calls,OOC,
25 Call Pickup,OOC,
26 Conference,OOC,
27 Stand-by,OOC,
28 Camera On,OOC,
29 Camera Off,OOC,
2A On-Line,OOC,
2B Off-Line,OOC,
2C Busy,OOC,
2D Ready,OOC,
2E Paper-Out,OOC,
2F Paper-Jam,OOC,
30 Remote,OOC,
31 Forward,OOC,
32 Reverse,OOC,
33 Stop,OOC,
34 Rewind,OOC,
35 Fast Forward,OOC,
36 Play,OOC,
37 Pause,OOC,
38 Record,OOC,
39 Error,OOC,
3A Usage Selected Indicator,US,
3B Usage In Use Indicator,US,
3C Usage Multi Mode Indicator,UM,
3D Indicator On,Sel,
3E Indicator Flash,Sel,
3F Indicator Slow Blink,Sel,
40 Indicator Fast Blink,Sel,
41 Indicator Off,Sel,
42 Flash On Time,DV,
43 Slow Blink On Time,DV,
44 Slow Blink Off Time,DV,
45 Fast Blink On Time,DV,
46 Fast Blink Off Time,DV,
47 Usage Indicator Color,UM,
48 Indicator Red,Sel,
49 Indicator Green,Sel,
4A Indicator Amber,Sel,
4B Generic Indicator,OOC,
4C System Suspend,OOC,
4D External Power Connected,OOC,

PAGE 09 Button Page,BTN
00 No button pressed,
01 Button 1 Primary/trigger,RTFM,Button1
02 Button 2 Secondary,RTFM,Button2
03 Button 3 Tertiary,RTFM,Button3
04 Button 4,RTFM
05 Button 5,RTFM
06 Button 6,RTFM
07 Button 7,RTFM
08 Button 8,RTFM
09 Button 9,RTFM
0A Button 10,RTFM
0B Button 11,RTFM
0C Button 12,RTFM
0D Button 13,RTFM
0E Button 14,RTFM
0F Button 15,RTFM
10 Button 16,RTFM
11 Button 17,RTFM
12 Button 18,RTFM
13 Button 19,RTFM
14 Button 20,RTFM
15 Button 21,RTFM
16 Button 22,RTFM
17 Button 23,RTFM
18 Button 24,RTFM
19 Button 25,RTFM
1A Button 26,RTFM
1B Button 27,RTFM
1C Button 28,RTFM
1D Button 29,RTFM
1E Button 30,RTFM
1F Button 31,RTFM
20 Button 32,RTFM
21 Button 33,RTFM
22 Button 34,RTFM
23 Button 35,RTFM
24 Button 36,RTFM
25 Button 37,RTFM
26 Button 38,RTFM
27 Button 39,RTFM
28 Button 40,RTFM

PAGE 0A Ordinal Page,ORD
00 Reserved 
01 Instance 1,UM
02 Instance 2,UM
03 Instance 3,UM
04 Instance 4,UM

PAGE 0B Telephony Device Page,TEL
00 Unassigned
01 Phone,CA,
02 Answering Machine,CA,
03 Message Controls,CL,
04 Handset,CL,
05 Headset,CL,
06 Telephony Key Pad,NAry,
07 Programmable Button,NAry,
20 Hook Switch,OOC,
21 Flash,MC,
22 Feature,OSC,
23 Hold,OOC,
24 Redial,OSC,
25 Transfer,OSC,
26 Drop,OSC,
27 Park,OOC,
28 Forward Calls,OOC,
29 Alternate Function,MC,
2A Line,OSC-NAry,
2B Speaker Phone,OOC,
2C Conference,OOC,
2D Ring Enable,OOC,
2E Ring Select,OSC,
2F Phone Mute,OOC,
30 Caller ID,MC,
31 Send,OOC,
50 Speed Dial,OSC,
51 Store Number,OSC,
52 Recall Number,OSC,
53 Phone Directory,OOC,
70 Voice Mail,OOC,
71 Screen Calls,OOC,
72 Do Not Disturb,OOC,
73 Message,OSC,
74 Answer On/Off,OOC,
90 Inside Dial Tone,MC,
91 Outside Dial Tone,MC,
92 Inside Ring Tone,MC,
93 Outside Ring Tone,MC,
94 Priority Ring Tone,MC,
95 Inside Ringback,MC,
96 Priority Ringback,MC,
97 Line Busy Tone,MC,
98 Reorder Tone,MC,
99 Call Waiting Tone,MC,
9A Confirmation Tone 1,MC,
9B Confirmation Tone 2,MC,
9C Tones Off,OOC,
9D Outside Ringback,MC,
9E Ringer,OOC,
B0 Phone Key 0,Sel,
B1 Phone Key 1,Sel,
B2 Phone Key 2,Sel,
B3 Phone Key 3,Sel,
B4 Phone Key 4,Sel,
B5 Phone Key 5,Sel,
B6 Phone Key 6,Sel,
B7 Phone Key 7,Sel,
B8 Phone Key 8,Sel,
B9 Phone Key 9,Sel,

PAGE 0C Consumer Device Page,CD
00 Unassigned
01 Consumer Control,CA,
02 Numeric Key Pad,NAry,
03 Programmable Buttons,NAry,
04 Microphone,CA,
05 Headphone,CA,
06 Graphic Equalizer,CA,
20 +10,OSC,Plus10
21 +100,OSC,Plus100
22 AM/PM,OSC,
30 Power,OOC,
31 Reset,OSC,
32 Sleep,OSC,
33 Sleep After,OSC,
34 Sleep Mode,RTC,
35 Illumination,OOC,
36 Function Buttons,NAry,
40 Menu,OOC,
41 Menu Pick,OSC,
42 Menu Up,OSC,
43 Menu Down,OSC,
44 Menu Left,OSC,
45 Menu Right,OSC,
46 Menu Escape,OSC,
47 Menu Value Increase,OSC,
48 Menu Value Decrease,OSC,
60 Data On Screen,OOC,
61 Closed Caption,OOC,
62 Closed Caption Select,OSC,
63 VCR/TV,OOC,
64 Broadcast Mode,OSC,
65 Snapshot,OSC,
66 Still,OSC,
80 Selection,NAry,
81 Assign Selection,OSC,
82 Mode Step,OSC,
83 Recall Last,OSC,
84 Enter Channel,OSC,
85 Order Movie,OSC,
86 Channel,LC,
87 Media Selection,NAry,
88 Media Select Computer,Sel,
89 Media Select TV,Sel,
8A Media Select WWW,Sel,
8B Media Select DVD,Sel,
8C Media Select Telephone,Sel,
8D Media Select Program Guide,Sel,
8E Media Select Video Phone,Sel,
8F Media Select Games,Sel,
90 Media Select Messages,Sel,
91 Media Select CD,Sel,
92 Media Select VCR,Sel,
93 Media Select Tuner,Sel,
94 Quit,OSC,
95 Help,OOC,
96 Media Select Tape,Sel,
97 Media Select Cable,Sel,
98 Media Select Satellite,Sel,
99 Media Select Security,Sel,
9A Media Select Home,Sel,
9B Media Select Call,Sel,
9C Channel Increment,OSC,
9D Channel Decrement,OSC,
9E Media Select SAP,Sel,
A0 VCR Plus,OSC,
A1 Once,OSC,
A2 Daily,OSC,
A3 Weekly,OSC,
A4 Monthly,OSC,
B0 Play,OOC,
B1 Pause,OOC,
B2 Record,OOC,
B3 Fast Forward,OOC,
B4 Rewind,OOC,
B5 Scan Next Track,OSC,
B6 Scan Previous Track,OSC,
B7 Stop,OSC,
B8 Eject,OSC,
B9 Random Play,OOC,
BA Select Disc,NAry,
BB Enter Disc,MC,
BC Repeat,OSC,
BD Tracking,LC,
BE Track Normal,OSC,
BF Slow Tracking,LC,
C0 Frame Forward,RTC,
C1 Frame Back,RTC,
C2 Mark,OSC,
C3 Clear Mark,OSC,
C4 Repeat From Mark,OOC,
C5 Return To Mark,OSC,
C6 Search Mark Forward,OSC,
C7 Search Mark Backwards,OSC,
C8 Counter Reset,OSC,
C9 Show Counter,OSC,
CA Tracking Increment,RTC,
CB Tracking Decrement,RTC,
CC Stop/Eject,OSC,
CD Play/Pause,OSC,
CE Play/Skip,OSC,
E0 Volume,LC,
E1 Balance,LC,
E2 Mute,OOC,
E3 Bass,LC,
E4 Treble,LC,
E5 Bass Boost,OOC,
E6 Surround Mode,OSC,
E7 Loudness,OOC,
E8 MPX,OOC,MPX
E9 Volume Increment,RTC,
EA Volume Decrement,RTC,
F0 Speed Select,OSC,
F1 Playback Speed,NAry,
F2 Standard Play,Sel,
F3 Long Play,Sel,
F4 Extended Play,Sel,
F5 Slow,OSC,
100 Fan Enable,OOC,
101 Fan Speed,LC,
102 Light Enable,OOC,
103 Light Illumination Level,LC,
104 Climate Control Enable,OOC,
105 Room Temperature,LC,
106 Security Enable,OOC,
107 Fire Alarm,OSC,
108 Police Alarm,OSC,
109 Proximity,LC,
10A Motion,OSC,
10B Duress Alarm,OSC,
10C Holdup Alarm,OSC,
10D Medical Alarm,OSC,
150 Balance Right,RTC,
151 Balance Left,RTC,
152 Bass Increment,RTC,
153 Bass Decrement,RTC,
154 Treble Increment,RTC,
155 Treble Decrement,RTC,
160 Speaker System,CL,
161 Channel Left,CL,
162 Channel Right,CL,
163 Channel Center,CL,
164 Channel Front,CL,
165 Channel Center Front,CL,
166 Channel Side,CL,
167 Channel Surround,CL,
168 Channel Low Frequency Enhancement,CL,
169 Channel Top,CL,
16A Channel Unknown,CL,
170 Sub-channel,LC,
171 Sub-channel Increment,OSC,
172 Sub-channel Decrement,OSC,
173 Alternate Audio Increment,OSC,
174 Alternate Audio Decrement,OSC,
180 Application Launch Buttons,NAry,
181 AL Launch Button Configuration Tool,Sel,
182 AL Programmable Button Configuration,Sel,
183 AL Consumer Control Configuration,Sel,
184 AL Word Processor,Sel,
185 AL Text Editor,Sel,
186 AL Spreadsheet,Sel,
187 AL Graphics Editor,Sel,
188 AL Presentation App,Sel,
189 AL Database App,Sel,
18A AL Email Reader,Sel,
18B AL Newsreader,Sel,
18C AL Voicemail,Sel,
18D AL Contacts/Address Book,Sel,
18E AL Calendar/Schedule,Sel,
18F AL Task/Project Manager,Sel,
190 AL Log/Journal/Timecard,Sel,
191 AL Checkbook/Finance,Sel,
192 AL Calculator,Sel,
193 AL A/V Capture/Playback,Sel,
194 AL Local Machine Browser,Sel,
195 AL LAN/WAN Browser,Sel,
196 AL Internet Browser,Sel,
197 AL Remote Networking/ISP Connect,Sel,
198 AL Network Conference,Sel,
199 AL Network Chat,Sel,
19A AL Telephony/Dialer,Sel,
19B AL Logon,Sel,
19C AL Logoff,Sel,
19D AL Logon/Logoff,Sel,
19E AL Terminal Lock/Screensaver,Sel,
19F AL Control Panel,Sel,
1A0 AL Command Line Processor/Run,Sel,
1A1 AL Process/Task Manager,Sel,
1A2 AL Select Task/Application,Sel,
1A3 AL Next Task/Application,Sel,
1A4 AL Previous Task/Application,Sel,
1A5 AL Preemptive Halt Task/Application,Sel,
1A6 AL Integrated Help Center,Sel,
1A7 AL Documents,Sel,
1A8 AL Thesaurus,Sel,
1A9 AL Dictionary,Sel,
1AA AL Desktop,Sel,
1AB AL Spell Check,Sel,
1AC AL Grammar Check,Sel,
1AD AL Wireless Status,Sel,
1AE AL Keyboard Layout,Sel,
1AF AL Virus Protection,Sel,
1B0 AL Encryption,Sel,
1B1 AL Screen Saver,Sel,
1B2 AL Alarms,Sel,
1B3 AL Clock,Sel,
1B4 AL File Browser,Sel,
1B5 AL Power Status,Sel,
1B6 AL Image Browser,Sel,
1B7 AL Audio Browser,Sel,
1B8 AL Movie Browser,Sel,
1B9 AL Digital Rights Manager,Sel,
1BA AL Digital Wallet,Sel,
1BC AL Instant Messaging,Sel,
1BD AL OEM Features/Tips/Tutorial Browser,Sel,
1BE AL OEM Help,Sel,
1BF AL Online Community,Sel,
1C0 AL Entertainment Content Browser,Sel,
1C1 AL Online Shopping Browser,Sel,
1C2 AL SmartCard Information/Help,Sel,
1C3 AL Market Monitor/Finance Browser,Sel,
1C4 AL Customized Corporate News Browser,Sel,
1C5 AL Online Activity Browser,Sel,
1C6 AL Research/Search Browser,Sel,
1C7 AL Audio Player,Sel,
200 Generic GUI Application Controls,NAry,
201 AC New,Sel,
202 AC Open,Sel,
203 AC Close,Sel,
204 AC Exit,Sel,
205 AC Maximize,Sel,
206 AC Minimize,Sel,
207 AC Save,Sel,
208 AC Print,Sel,
209 AC Properties,Sel,
21A AC Undo,Sel,
21B AC Copy,Sel,
21C AC Cut,Sel,
21D AC Paste,Sel,
21E AC Select All,Sel,
21F AC Find,Sel,
220 AC Find and Replace,Sel,
221 AC Search,Sel,
222 AC Go To,Sel,
223 AC Home,Sel,
224 AC Back,Sel,
225 AC Forward,Sel,
226 AC Stop,Sel,
227 AC Refresh,Sel,
228 AC Previous Link,Sel,
229 AC Next Link,Sel,
22A AC Bookmarks,Sel,
22B AC History,Sel,
22C AC Subscriptions,Sel,
22D AC Zoom In,Sel,
22E AC Zoom Out,Sel,
22F AC Zoom,LC,
230 AC Full Screen View,Sel,
231 AC Normal View,Sel,
232 AC View Toggle,Sel,
233 AC Scroll Up,Sel,
234 AC Scroll Down,Sel,
235 AC Scroll,LC,
236 AC Pan Left,Sel,
237 AC Pan Right,Sel,
238 AC Pan,LC,
239 AC New Window,Sel,
23A AC Tile Horizontally,Sel,
23B AC Tile Vertically,Sel,
23C AC Format,Sel,
23D AC Edit,Sel,
23E AC Bold,Sel,
23F AC Italics,Sel,
240 AC Underline,Sel,
241 AC Strikethrough,Sel,
242 AC Subscript,Sel,
243 AC Superscript,Sel,
244 AC All Caps,Sel,
245 AC Rotate,Sel,
246 AC Resize,Sel,
247 AC Flip horizontal,Sel,
248 AC Flip Vertical,Sel,
249 AC Mirror Horizontal,Sel,
24A AC Mirror Vertical,Sel,
24B AC Font Select,Sel,
24C AC Font Color,Sel,
24D AC Font Size,Sel,
24E AC Justify Left,Sel,
24F AC Justify Center H,Sel,
250 AC Justify Right,Sel,
251 AC Justify Block H,Sel,
252 AC Justify Top,Sel,
253 AC Justify Center V,Sel,
254 AC Justify Bottom,Sel,
255 AC Justify Block V,Sel,
256 AC Indent Decrease,Sel,
257 AC Indent Increase,Sel,
258 AC Numbered List,Sel,
259 AC Restart Numbering,Sel,
25A AC Bulleted List,Sel,
25B AC Promote,Sel,
25C AC Demote,Sel,
25D AC Yes,Sel,
25E AC No,Sel,
25F AC Cancel,Sel,
260 AC Catalog,Sel,
261 AC Buy/Checkout,Sel,
262 AC Add to Cart,Sel,
263 AC Expand,Sel,
264 AC Expand All,Sel,
265 AC Collapse,Sel,
266 AC Collapse All,Sel,
267 AC Print Preview,Sel,
268 AC Paste Special,Sel,
269 AC Insert Mode,Sel,
26A AC Delete,Sel,
26B AC Lock,Sel,
26C AC Unlock,Sel,
26D AC Protect,Sel,
26E AC Unprotect,Sel,
26F AC Attach Comment,Sel,
270 AC Delete Comment,Sel,
271 AC View Comment,Sel,
272 AC Select Word,Sel,
273 AC Select Sentence,Sel,
274 AC Select Paragraph,Sel,
275 AC Select Column,Sel,
276 AC Select Row,Sel,
277 AC Select Table,Sel,
278 AC Select Object,Sel,
279 AC Redo/Repeat,Sel,
27A AC Sort,Sel,
27B AC Sort Ascending,Sel,
27C AC Sort Descending,Sel,
27D AC Filter,Sel,
27E AC Set Clock,Sel,
27F AC View Clock,Sel,
280 AC Select Time Zone,Sel,
281 AC Edit Time Zones,Sel,
282 AC Set Alarm,Sel,
283 AC Clear Alarm,Sel,
284 AC Snooze Alarm,Sel,
285 AC Reset Alarm,Sel,
286 AC Synchronize,Sel,
287 AC Send/Receive,Sel,
288 AC Send To,Sel,
289 AC Reply,Sel,
28A AC Reply All,Sel,
28B AC Forward Msg,Sel,
28C AC Send,Sel,
28D AC Attach File,Sel,
28E AC Upload,Sel,
28F AC Download (Save Target As),Sel,
290 AC Set Borders,Sel,
291 AC Insert Row,Sel,
292 AC Insert Column,Sel,
293 AC Insert File,Sel,
294 AC Insert Picture,Sel,
295 AC Insert Object,Sel,
296 AC Insert Symbol,Sel,
297 AC Save and Close,Sel,
298 AC Rename,Sel,
299 AC Merge,Sel,
29A AC Split,Sel,
29B AC Disribute Horizontally,Sel,
29C AC Distribute Vertically,Sel,

PAGE 0D Digitizers,DIG
00 Undefined
01 Digitizer,CA,
02 Pen,CA,
03 Light Pen,CA,
04 Touch Screen,CA,
05 Touch Pad,CA,
06 White Board,CA,
07 Coordinate Measuring Machine,CA,
08 3D Digitizer,CA,Digitizer3D
09 Stereo Plotter,CA,
0A Articulated Arm,CA,
0B Armature,CA,
0C Multiple Point Digitizer,CA,
0D Free Space Wand,CA,
0E Configuration,CA,
20 Stylus,CL,
21 Puck,CL,
22 Finger,CL,
23 Device Settings,CL,
30 Tip Pressure,DV,
31 Barrel Pressure,DV,
32 In Range,MC,
33 Touch,MC,
34 Untouch,OSC,
35 Tap,OSC,
36 Quality,DV,
37 Data Valid,MC,
38 Transducer Index,DV,
39 Tablet Function Keys,CL,
3A Program Change Keys,CL,
3B Battery Strength,DV,
3C Invert,MC,
3D X Tilt,DV,
3E Y Tilt,DV,
3F Azimuth,DV,
40 Altitude,DV,
41 Twist,DV,
42 Tip Switch,MC,
43 Secondary Tip Switch,MC,
44 Barrel Switch,MC,
45 Eraser,MC,
46 Tablet Pick,MC,
47 Confidence,DV,
48 Width,DV,
49 Height,DV,
51 Contact Identifier,DV,
52 Device Mode,DV,
53 Device Identifier,SVDV,
54 Contact Count,DV,
55 Contact Count Maximum,DV,

PAGE 0E Reserved,RES

PAGE 0F Physical Interfacd Device Page,PID

PAGE 10 Unicode Page,UNI

PAGE 11 Reserved,RES
PAGE 12 Reserved,RES
PAGE 13 Reserved,RES

PAGE 14 Alphanumeric Display Page,AD
00 Undefined 
01 Alphanumeric Display,CA,
02 Bitmapped Display,CA,
20 Display Attributes Report,CL,
21 ASCII Character Set,SF,
22 Data Read Back,SF,
23 Font Read Back,SF,
24 Display Control Report,CL,
25 Clear Display,DF,
26 Display Enable,DF,
27 Screen Saver Delay,SVDV,
28 Screen Saver Enable,DF,
29 Vertical Scroll,SFDF,
2A Horizontal Scroll,SFDF,
2B Character Report,CL,
2C Display Data,DV,
2D Display Status,CL,
2E Stat Not Ready,Sel,
2F Stat Ready,Sel,
30 Err Not a loadable character,Sel,
31 Err Font data cannot be read,Sel,
32 Cursor Position Report,CL,
33 Row,DV,
34 Column,DV,
35 Rows,SV,
36 Columns,SV,
37 Cursor Pixel Positioning,SF,
38 Cursor Mode,DF,
39 Cursor Enable,DF,
3A Cursor Blink,DF,
3B Font Report,CL,
3C Font Data,BB,
3D Character Width,SV,
3E Character Height,SV,
3F Character Spacing Horizontal,SV,
40 Character Spacing Vertical,SV,
41 Unicode Character Set,SF,
42 Font 7-Segment,SF,
43 7-Segment Direct Map,SF,DirectMap7Segment
44 Font 14-Segment,SF,
45 14-Segment Direct Map,SF,DirectMap14Segment
46 Display Brightness,DV,
47 Display Contrast,DV,
48 Character Attribute,CL,
49 Attribute Readback,SF,
4A Attribute Data,DV,
4B Char Attr Enhance,OOC,
4C Char Attr Underline,OOC,
4D Char Attr Blink,OOC,
80 Bitmap Size X,SV,
81 Bitmap Size Y,SV,
83 Bit Depth Format,SV,
84 Display Orientation,DV,
85 Palette Report,CL,
86 Palette Data Size,SV,
87 Palette Data Offset,SV,
88 Palette Data,BB,
8A Blit Report,CL,
8B Blit Rectangle X1,SV,
8C Blit Rectangle Y1,SV,
8D Blit Rectangle X2,SV,
8E Blit Rectangle Y2,SV,
8F Blit Data,BB,
90 Soft Button,CL,
91 Soft Button ID,SV,
92 Soft Button Side,SV,
93 Soft Button Offset 1,SV,
94 Soft Button Offset 2,SV,
95 Soft Button Report,SV,

PAGE 15 Reserved,RES
PAGE 16 Reserved,RES
PAGE 17 Reserved,RES
PAGE 18 Reserved,RES
PAGE 19 Reserved,RES
PAGE 1A Reserved,RES
PAGE 1B Reserved,RES
PAGE 1C Reserved,RES
PAGE 1D Reserved,RES
PAGE 1E Reserved,RES
PAGE 1F Reserved,RES

PAGE 20 Reserved,RES
PAGE 21 Reserved,RES
PAGE 22 Reserved,RES
PAGE 23 Reserved,RES
PAGE 24 Reserved,RES
PAGE 25 Reserved,RES
PAGE 26 Reserved,RES
PAGE 17 Reserved,RES
PAGE 28 Reserved,RES
PAGE 29 Reserved,RES
PAGE 2A Reserved,RES
PAGE 2B Reserved,RES
PAGE 2C Reserved,RES
PAGE 2D Reserved,RES
PAGE 2E Reserved,RES
PAGE 2F Reserved,RES

PAGE 30 Reserved,RES
PAGE 31 Reserved,RES
PAGE 32 Reserved,RES
PAGE 33 Reserved,RES
PAGE 34 Reserved,RES
PAGE 35 Reserved,RES
PAGE 36 Reserved,RES
PAGE 37 Reserved,RES
PAGE 38 Reserved,RES
PAGE 39 Reserved,RES
PAGE 3A Reserved,RES
PAGE 3B Reserved,RES
PAGE 3C Reserved,RES
PAGE 3D Reserved,RES
PAGE 3E Reserved,RES
PAGE 3F Reserved,RES

PAGE 40 Medical Instrument Page,MED
00 Undefined
01 Medical Ultrasound,CA,
20 VCR/Acquisition,OOC,
21 Freeze/Thaw,OOC,
22 Clip Store,OSC,
23 Update,OSC,
24 Next,OSC,
25 Save,OSC,
26 Print,OSC,
27 Microphone Enable,OSC,
40 Cine,LC,
41 Transmit Power,LC,
42 Volume,LC,
43 Focus,LC,
44 Depth,LC,
60 Soft Step - Primary,LC,
61 Soft Step - Secondary,LC,
70 Depth Gain Compensation,LC,
80 Zoom Select,OSC,
81 Zoom Adjust,LC,
82 Spectral Doppler Mode Select,OSC,
83 Spectral Doppler Adjust,LC,
84 Color Doppler Mode Select,OSC,
85 Color Doppler Adjust,LC,
86 Motion Mode Select,OSC,
87 Motion Mode Adjust,LC,
88 2-D Mode Select,OSC,ModeSelect2D
89 2-D Mode Adjust,LC,ModeAdjust2D
A0 Soft Control Select,OSC,
A1 Soft Control Adjust,LC,

PAGE 41 Reserved,RES
PAGE 42 Reserved,RES
PAGE 43 Reserved,RES
PAGE 44 Reserved,RES
PAGE 45 Reserved,RES
PAGE 46 Reserved,RES
PAGE 47 Reserved,RES
PAGE 48 Reserved,RES
PAGE 49 Reserved,RES
PAGE 4A Reserved,RES
PAGE 4B Reserved,RES
PAGE 4C Reserved,RES
PAGE 4D Reserved,RES
PAGE 4E Reserved,RES
PAGE 4F Reserved,RES

PAGE 50 Reserved,RES
PAGE 51 Reserved,RES
PAGE 52 Reserved,RES
PAGE 53 Reserved,RES
PAGE 54 Reserved,RES
PAGE 55 Reserved,RES
PAGE 56 Reserved,RES
PAGE 57 Reserved,RES
PAGE 58 Reserved,RES
PAGE 59 Reserved,RES
PAGE 5A Reserved,RES
PAGE 5B Reserved,RES
PAGE 5C Reserved,RES
PAGE 5D Reserved,RES
PAGE 5E Reserved,RES
PAGE 5F Reserved,RES

PAGE 60 Reserved,RES
PAGE 61 Reserved,RES
PAGE 62 Reserved,RES
PAGE 63 Reserved,RES
PAGE 64 Reserved,RES
PAGE 65 Reserved,RES
PAGE 66 Reserved,RES
PAGE 67 Reserved,RES
PAGE 68 Reserved,RES
PAGE 69 Reserved,RES
PAGE 6A Reserved,RES
PAGE 6B Reserved,RES
PAGE 6C Reserved,RES
PAGE 6D Reserved,RES
PAGE 6E Reserved,RES
PAGE 6F Reserved,RES

PAGE 70 Reserved,RES
PAGE 71 Reserved,RES
PAGE 72 Reserved,RES
PAGE 73 Reserved,RES
PAGE 74 Reserved,RES
PAGE 75 Reserved,RES
PAGE 76 Reserved,RES
PAGE 77 Reserved,RES
PAGE 78 Reserved,RES
PAGE 79 Reserved,RES
PAGE 7A Reserved,RES
PAGE 7B Reserved,RES
PAGE 7C Reserved,RES
PAGE 7D Reserved,RES
PAGE 7E Reserved,RES
PAGE 7F Reserved,RES

PAGE 80 Monitor Page,MON
PAGE 81 Monitor Page,MON
PAGE 82 Monitor Page,MON
PAGE 83 Monitor Page,MON

PAGE 84 Power Page,POW
PAGE 85 Power Page,POW
PAGE 86 Power Page,POW
PAGE 87 Power Page,POW

PAGE 8C Bar Code Scanner Page,BAR

PAGE 8D Scale Page,SCA

PAGE 8E Magnetic Stripe Reading Devices,MSR

PAGE 8F Point Of Sale Devices,POS

PAGE 90 Camera Control Page,CAM

PAGE 91 Arcade Page,ARC

END*/
