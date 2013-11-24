05 01        (GLOBAL) USAGE_PAGE         0x0001 Generic Desktop Page 
09 06        (LOCAL)  USAGE              0x00010006 Keyboard (CA=Application Collection) 
A1 01        (MAIN)   COLLECTION         0x01 Application (Usage=0x00010006: Page=Generic Desktop Page, Usage=Keyboard, Type=CA)
05 07          (GLOBAL) USAGE_PAGE         0x0007 Keyboard/Keypad Page 
19 E0          (LOCAL)  USAGE_MINIMUM      0x000700E0 Keyboard Left Control (DV=Dynamic Value) 
29 E7          (LOCAL)  USAGE_MAXIMUM      0x000700E7 Keyboard Right GUI (DV=Dynamic Value) 
15 00          (GLOBAL) LOGICAL_MINIMUM    0x00 (0) <-- Redundant: LOGICAL_MINIMUM is already 0
25 01          (GLOBAL) LOGICAL_MAXIMUM    0x01 (1) 
75 01          (GLOBAL) REPORT_SIZE        0x01 (1) Number of bits per field 
95 08          (GLOBAL) REPORT_COUNT       0x08 (8) Number of fields 
81 02          (MAIN)   INPUT              0x00000002 (8 fields x 1 bit) 0=Data 1=Variable 0=Absolute 0=NoWrap 0=Linear 0=PrefState 0=NoNull 0=NonVolatile 0=Bitmap 
95 01          (GLOBAL) REPORT_COUNT       0x01 (1) Number of fields 
75 08          (GLOBAL) REPORT_SIZE        0x08 (8) Number of bits per field 
81 01          (MAIN)   INPUT              0x00000001 (1 field x 8 bits) 1=Constant 0=Array 0=Absolute 0=Ignored 0=Ignored 0=PrefState 0=NoNull 
95 05          (GLOBAL) REPORT_COUNT       0x05 (5) Number of fields 
75 01          (GLOBAL) REPORT_SIZE        0x01 (1) Number of bits per field 
05 08          (GLOBAL) USAGE_PAGE         0x0008 LED Indicator Page 
19 01          (LOCAL)  USAGE_MINIMUM      0x00080001 Num Lock (OOC=On/Off Control) 
29 05          (LOCAL)  USAGE_MAXIMUM      0x00080005 Kana (OOC=On/Off Control) 
91 02          (MAIN)   OUTPUT             0x00000002 (5 fields x 1 bit) 0=Data 1=Variable 0=Absolute 0=NoWrap 0=Linear 0=PrefState 0=NoNull 0=NonVolatile 0=Bitmap 
95 01          (GLOBAL) REPORT_COUNT       0x01 (1) Number of fields 
75 03          (GLOBAL) REPORT_SIZE        0x03 (3) Number of bits per field 
91 01          (MAIN)   OUTPUT             0x00000001 (1 field x 3 bits) 1=Constant 0=Array 0=Absolute 0=NoWrap 0=Linear 0=PrefState 0=NoNull 0=NonVolatile 0=Bitmap 
95 06          (GLOBAL) REPORT_COUNT       0x06 (6) Number of fields 
75 08          (GLOBAL) REPORT_SIZE        0x08 (8) Number of bits per field 
15 00          (GLOBAL) LOGICAL_MINIMUM    0x00 (0) <-- Redundant: LOGICAL_MINIMUM is already 0
25 65          (GLOBAL) LOGICAL_MAXIMUM    0x65 (101) 
05 07          (GLOBAL) USAGE_PAGE         0x0007 Keyboard/Keypad Page 
19 00          (LOCAL)  USAGE_MINIMUM      0x00070000 Keyboard No event indicated (Sel=Selector) <-- Redundant: USAGE_MINIMUM is already 0x0000
29 65          (LOCAL)  USAGE_MAXIMUM      0x00070065 Keyboard Application (Sel=Selector) 
81 00          (MAIN)   INPUT              0x00000000 (6 fields x 8 bits) 0=Data 0=Array 0=Absolute 0=Ignored 0=Ignored 0=PrefState 0=NoNull 
C0           (MAIN)   END_COLLECTION     Application
