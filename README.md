RDD! HID Report Descriptor Decoder
==================================
This will read a USB Human Interface Device (HID) report descriptor from the
specified input file then attempt to decode it and, optionally, create a
C language header file from it. It also does some minimal sanity checks
to verify that the report descriptor is valid.  The input file can be a
binary file or a text file (for example, an existing C header file). If
it is a text file, it will concatenate all the printable-hex-like text
that it finds on each line (until the first non-hex sequence is found)
into a single string of hex digits, and then attempt to decode that string.
You can feed it an existing C header file and it will decode it as long
as you have all the hex strings (e.g. 0x0F, 0x0Fb2) at the beginning of
each line. Commas (,) and semicolons (;) are ignored. Specify the --right
option if the hex strings are on the rightmost side of each line.


Features
--------
* Decodes all the USB HID descriptors currently published by usb.org
* Converts HID Report Descriptor into C language structure declarations
* Highlights common errors such as redundant descriptor tags, field size errors etc
* Accepts binary or textual input (for example existing C structure definitions)
* Decodes vendor-specific descriptors (if you supply a simple definition file)


Usage
-----

      rexx rd.rex [-h format] [-i fileinc] [-o fileout] [-dsvxb] -f filein

Or:

      rexx rd.rex [-h format] [-i fileinc] [-o fileout] [-dsvx]  -c hex

Where:

      filein           = Input file path to be decoded
      fileout          = Output file (default is console)
      fileinc          = Include file of PAGE/USAGE definitions
      hex              = Printable hex to be decoded from command line
      format           = Type of output C header file format:
                         AVR    - AVR style
                         MIKROC - MikroElektronika mikroC Pro for PIC style
                         MCHIP  - Microchip C18 style
      -f --file        = Read input from the specified file
      -c --hex         = Read hex input from command line
      -r --right       = Read hex input from the rightmost side of each line
      -b --binary      = Input file is binary (not text)
      -o --output      = Write output to the specified file (default is console)
      -s --struct      = Output C structure declarations (default)
      -d --decode      = Output decoded report descriptor
      -h --header      = Output C header in AVR, MIKROC or MICROCHIP format
      -x --dump        = Output hex dump of report descriptor
      -a --all         = Output all valid array indices and usages
      -i --include     = Read vendor-specific definition file
      -v --verbose     = Output more detail
      --version        = Display version and exit
      -? --help        = Display this information
      -vv              = Modifies --all so that even array field indices that
                         have blank usage descriptions are listed

Prerequisites
-------------
You need a REXX interpreter installed, such as
  1. [Regina REXX](http://regina-rexx.sourceforge.net)
  2. [Open Object REXX](http://www.oorexx.org/)


Examples
-------
    rexx rd.rex -d --hex 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0
    ...decodes the given hex string. Spaces are not significant

    rexx rd.rex -sc 05010906 A1010508 19012903 15002501 75019503 91029505 9101 C0
    ...generates C structure declarations for the given hex string

    rexx rd.rex -d -f myinputfile.h -o myoutputfile.txt
    ...decodes the hex strings found in myinputfile.h into myoutputfile.txt

    rexx rd.rex myinputfile.h
    ...generates C structure declarations for the hex strings found in myinputfile.h

    rexx rd.rex --include mybuttonmap.txt -f myinputfile.h
    ...generates C structure declarations for the hex strings found in myinputfile.h 
    using vendor-defined usages defined in mybuttonmap.txt

    rexx rd.rex -dr usblyzer.txt
    ...decodes the hex strings found on the rightmost side of each line of the
    usblyzer.txt input file

Configuration File Format
-------------------------

The configuration file (rd.conf) format is identical to the [Include File Format shown below](#include-file-format).
It contains the approximately 3000 known usages that are documented by usb.org.
The maximum number of usages is 4294967296 so it makes sense to store the small number of
known ones in a single file. However, if you have vendor-defined usages then you may want to include the 
definitions for them using an "include" file...


Include File Format
-------------------

Vendor usages can be defined in a separate file which will be automatically loaded if you name it
pppp.conf - where pppp is the hex vendor usage page number. You can name it anything you like, but if you do that you will
have to explicitly include it by coding "--include your.special.usages" on the command line.

See FFA0-Plantronics.txt for an example. This example file would be automatically loaded if it was named FFA0.conf.

Each USB HID Usage code is a 4 byte value comprising a 2 byte Usage Page and a 2 byte Usage within that page. Vendor-specific usages must have a Usage Page code in the range 0xFF00 to 0xFFFF. Within each Usage Page, there can be up to 65536 usages (from 0x0000 to 0xFFFF). The official USB HID Usage Tables specification defines usages for almost everything imaginable - including parts of the human body...although, strangely, it stops short of defining usages for any of the [naughty bits](http://en.wiktionary.org/wiki/naughty_bit). If you need to define a usage for naughty bits, then a vendor-specific usage page is the place to do it.

The --include file contains the following lines of comma-separated values...

* One line describing the the vendor-specific usage page:
    * pppp - The vendor-specific Usage Page in hex (FF00 to FFFF)
    * vendordesc - A short description of the vendor and product
    * vendorprefix - A very short (few letters) abbreviation of the vendor and product which is used as a prefix on any generated C language variable names

* One line for each usage within the vendor-specific page:
    * ppppuuuu - The explicit usage number comprising the vendor page number (pppp) in hex and usage number (uuuu) in hex.
    * usagedesc - A short description of the usage
    * usagetype - Optional: An abbreviation of the type of the usage. This is largely for future use and has no impact on the decoding. The following usage types are currently documented in the usb.org documents:
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
        * SF-DF - Static or Dynamic Flag
        * SV - Static Value
        * SV-DV - Static or Dynamic Value
        * UM - Usage Modifier
        * US - Usage Switch
    * usageshortname - Optional: A short name of the usage which is used in any generated C language variable names. Normally camel-case names are generated from the "usagedesc", for example, "System Speaker Mute" would be translated to variable name
    "SystemSpeakerMute", but if you want to specify a different short name, for example, "Mute", then you can define it here.

* Blank lines are ignored, as is any line that does not begin with a hexadecimal number (pppp or ppppuuuu).

The include file should look like this:

        // A usage page definition line should precede one or more usages in that page:
        pppp pagedesc,vendorprefix

        // Each usage line is identified by a hexadecimal usage number (ppppuuuu):
        ppppuuuu usagedesc,usagetype[,usageshortname]
        .
        .
        .
        ppppuuuu usagedesc,usagetype[,usageshortname]
