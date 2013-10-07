HID Report Descriptor decoder v1.00
===================================

This will extract anything that looks like a USB Human
Interface Device (HID) report descriptor from the specified
input file and attempt to decode it into a C header file.
It does this by concatenating all the printable-hex-like
sequences it finds on each line (until the first unrecognisable
sequence is encountered) into a single string of hex digits, and
then attempts to decode that string as though it was a HID Report
Descriptor. If your input file is already in binary format, 
then specify the -b option.

Syntax
------

    rexx rd.rex [-bvdsx] filein

or

    rexx rd.rex -h[vdsx] xx...

Where

    filein           = Input file path to be decoded
    -h --hex         = Read hex input (xx...) from command line
    -b --binary      = Input file is binary (not text)
    -s --struct      = Output C structure declarations (default)
    -d --decode      = Output decoded report descriptor
    -x --dump        = Output hex dump of report descriptor
    -v --verbose     = Output more detail
    --version        = Display version and exit
    -? --help        = Display this information

Prerequisites
-------------
You need a REXX interpreter installed, such as
  1. [Regina REXX](http://regina-rexx.sourceforge.net)
  2. [Open Object REXX](http://www.oorexx.org/)

Example
-------
    rexx rd.rex -h 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0
    ...decodes the given hex string

    rexx rd.rex myinputfile.h
    ...decodes the hex strings found in the specified file

