RDD! HID Report Descriptor Decoder
==================================

This will extract anything that looks like a USB Human Interface Device (HID) report descriptor from the specified input file and attempt to decode it into a C header file. It does this by concatenating all the printable-hex-like sequences it finds on each line (until the first unrecognisable sequence is encountered) into a single string of hex digits, and then attempts to decode that string as though it was a HID Report Descriptor. If your input file is already in binary format, then specify the -b option.

Features
--------
* Decodes HID Report Descriptors
* Converts HID Report Descriptor into C language structure declarations
* Highlights redundant descriptor tags
* Accepts binary or textual input (for example existing C structure definitions)
* Decodes vendor-specific descriptors (if you supply a simple definition file)

Syntax
------

    rexx rd.rex [-bvdsx] filein [-i path]

or

    rexx rd.rex -h[vdsx] [-i path] xx...

Where

    filein           = Input file path to be decoded
    path             = Vendor-specific definition file to be included
    -h --hex         = Read hex input (xx...) from command line
    -b --binary      = Input file is binary (not text)
    -i --include     = Include vendor-specific definitions file
    -s --struct      = Output C structure declarations (default)
    -d --decode      = Output decoded report descriptor
    -x --dump        = Output hex dump of report descriptor
    -v --verbose     = Output more detail
    -vv              = Output even more detail
    -vvv             = Ouput an insane amount of detail
    --version        = Display version and exit
    -? --help        = Display this information

Prerequisites
-------------
You need a REXX interpreter installed, such as
  1. [Regina REXX](http://regina-rexx.sourceforge.net)
  2. [Open Object REXX](http://www.oorexx.org/)

Examples
-------
    rexx rd.rex -dh 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0
    ...decodes the given hex string. Spaces are not significant

    rexx rd.rex -sh 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0
    ...generates C structure declarations for the given hex string

    rexx rd.rex -d myinputfile.h
    ...decodes the hex strings found in myinputfile.h

    rexx rd.rex myinputfile.h
    ...generates C structure declarations for the hex strings found in myinputfile.h

    rexx rd.rex --include mybuttonmap.txt myinputfile.h
    ...generates C structure declarations for the hex strings found in myinputfile.h 
    using vendor-defined usages defined in mybuttonmap.txt

Include File Format
-------------------
  
Refer to FFA0-Plantronics.txt for an example.

Each USB HID Usage code is a 4 byte value comprising a 2 byte Usage Page and a 2 byte Usage within that page. Vendor-specific usages must have a Usage Page code in the range 0xFF00 to 0xFFFF. Within each Usage Page, there can be up to 65536 usages (from 0x0000 to 0xFFFF). The official USB HID Usage Tables specification defines usages for almost everything imaginable - including parts of the human body...although, strangely, it stops short of defining usages for any of the [naughty bits](http://en.wiktionary.org/wiki/naughty_bit). If you need to define a usage for naughty bits, then a vendor-specific usage page is the place to do it.

The --include file contains the following comma-separated lines...

* One line, identified by "PAGE", describing the the vendor-specific usage page:
    * pppp - The vendor-specific Usage Page in hex (FF00 to FFFF)
    * vendordesc - A short description of the vendor and product
    * vendorprefix - A very short (few letters) abbreviation of the vendor and product which is used as a prefix on any generated C language variable names

* One line for each usage within the vendor-specific page:
    * uuuu - The Usage number in hex (0 to FFFF). Leading zeros are optional.
    * usagedesc - A short description of the usage
    * usagetype - Optional: An abbreviation of the type of the usage. This is largely for future use and has no impact on the decoding. The following usage types are at least known about:
        * BB - Buffered Bytes
        * CA - Application Collection
        * CL - Logical Collection
        * CP - Physical Collection
        * DF - Dynamic Flag
        * DV - Dynamic Value
        * DV-DF - Dynamic Value/Flag
        * LC - Linear Control
        * MC - Momentary Control
        * NAry - Named Array
        * OOC - On/Off Control
        * OSC - One Shot Control
        * OSC-NAry - One Shot Control/Named Array
        * RTC - Re-trigger Control
        * MULTI - Selector, On/Off, Momentary or One Shot
        * Sel - Selector
        * SF - Static Flag
        * SV - Static Value
        * UM - Usage Modifier
        * US - Usage Switch
    * usageshortname - Optional: A short name of the usage which is used in any generated C language variable names. Normally this is extracted from the "usagedesc", but if you want to specify a different short name, then define it here.

* Blank lines are ignored, as is any line that does not begin with either "PAGE" or a hexadecimal usage number (uuuu).

The file should look like this:

        // A vendor PAGE line should precede one or more usages:
        PAGE pppp,vendordesc,vendorprefix
        // Each usage line is identified by a hexadecimal usage number (uuuu):
        uuuu,usagedesc,usagetype[,usageshortname]
        .
        .
        .
        uuuu,usagedesc,usagetype[,usageshortname]

...and it can contain more than one vendor-specific page.
