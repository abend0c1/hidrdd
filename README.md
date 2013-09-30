HID Report Descriptor decoder v1.00
===================================

This will extract anything that looks like a USB Human
Interface Device (HID) report descriptor from the specified
input file and attempt to decode it into a C header file.
It does this by concatenating all the printable-hex-like
sequences it finds on each line (until the first unrecognisable
sequence is encountered) into a single string of hex digits, and
then attempts to decode that string as though it was a HID Report
Descriptor.

As such, it is not perfect...merely useful.

Syntax
------
    rexx rd.rex [-b] filein

or

    rexx rd.rex -h hex

Where

    filein    = Input file path to be decoded
    -h hex    = Decode the hexadecimal string "hex"
                Spaces are ignored.
    -b        = Input file is binary (not text)

Prerequisites
-------------
You need a REXX interpreter installed, such as
  1. [Regina REXX](http://regina-rexx.sourceforge.net)
  2. [Open Object REXX](http://www.oorexx.org/)

Example
-------
    rexx rd.rex -h 0501 0906 A101 C0
    ...decodes the given hex string

    rexx rd.rex myinputfile.h
    ...decodes the hex strings found in the specified file

