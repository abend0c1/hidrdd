| A.8 A Device with a Display

| The following example is of a 2x16-character display device. The device uses one Feature, one Input, and
| two Output reports.

| A Feature report is declared for identifying fixed features of the display and display status. All of the
| Feature report’s fields are constants.

| The Character Spacing usage is not declared, so it can be assumed that the respective inter-character spacing
| is forced by the pixel layout of the display, and any downloaded font characters do not have to include it.
| In this example, the Character Height and Width are fixed. The fields are declared in the Report descriptor
| and the actual values are reported when the Feature report is read. For example, the Character Height and
| Width fields will always return 7 and 5, respectively.

| Uploading of the font is not supported by this display so there is no Font Report Input report.

05 14 UsagePage(Alphanumeric Display),
09 01 Usage(Alphanumeric Display),
15 00 Logical Minimum(0),
a1 01 Collection(Application),

| The first report defined is a Feature report with seven fields. The Rows, Columns, Character Height and
| Width fields are Static Values (SV) and their report size is set to 5 to demonstrate how the bit packing takes
| place in a report. Standard Character Set, Data Read Back and Vertical Scroll are Static Flags (SF).

09 20 Usage(Display Attributes Report),
a1 02 Collection(Logical),
09 35 Usage(Rows),
09 36 Usage(Columns),
09 3d Usage(Character Width),
09 3e Usage(Character Height),
85 01 ReportID(1),
25 1f Logical Maximum(31),
75 05 ReportSize(5), 
95 04 ReportCount(4),
b1 03 Feature(Constant, Variable, Absolute),   ; Four 5-bit fields

75 01 ReportSize(1), 
95 03 ReportCount(3),
25 01 Logical Maximum(1),
09 21 Usage(ASCII Character Set),
09 22 Usage(Data Read Back),
09 29 Usage(Vertical Scroll),
b1 03 Feature(Constant, Variable, Absolute),   ; Three 1-bit fields

95 01 ReportCount(1),
b1 03 Feature(Constant, Variable, Absolute), ; 1-bit pad


| The following Character Attributes collection defines a byte where bits 0, 1, and 2 define Enhance,
| Underline, and Blink attributes that can be applied to a character. The remaining bits in the byte pad it to a
| byte boundary and ignored by the display. Modifying the fields defined in this collection will have no effect
| on the display. They simply form a template that is used to define the contents of a Attribute Data report.

09 48 Usage (Character Attributes)
a1 02 Collection(Logical)
09 4b Usage(Char Attr Enhance)
09 4c Usage(Char Attr Underline
09 4d Usage(Char Attr Blink)
75 01 ReportSize(1)
95 03 ReportCount(3)
b1 03 Feature(Const, var)
75 05 ReportSize(5)
95 01 ReportCount(1)
b1 03 Feature(Const) ; pad to byte boundary
c0 End Collection()

c0 End Collection(),

| The second report defined is an Input report that is generated on the interrupt endpoint each time the status
| of the display changes. Each of the possible states that can be identified by the display are identified in the
| Display Status collection. This report can also be read over the control pipe to determine the current status.

75 08 ReportSize(8), 
95 01 ReportCount(1),
25 02 Logical Maximum(2),
09 2d Usage(Display Status),
a1 02 Collection(Logical),
09 2e Usage(Stat Not Ready),
09 2f Usage(Stat Ready),
09 30 Usage(Err Not a loadable character),
81 00 Input(Data, Array, Absolute, No Null), ; 8-bit status field
c0 End Collection(),


| A second Feature report is defined for getting or setting the current cursor position.
09 32 Usage(Cursor Position Report),
a1 02 Collection(Logical),
85 02 ReportID(2),
75 04 ReportSize(4), 
95 01 ReportCount(1),
25 0f Logical Maximum(15),
09 34 Usage(Column),
b1 22 Feature(Data, Variable, Absolute, No Preferred State), ;Column
Logical Maximum(1),
09 33 Usage(Row),
b1 22 Feature(Data, Variable, Absolute, No Preferred State), ;Row
c0 End Collection(),


| There are a number of ways that data can be transferred between the host and the display: one byte at a time,
| multiple bytes, or the whole screen using a 32-byte buffered-byte transfer. The choice may depend on
| whether the device is implemented as a low-speed or a high-speed device. In this example, a third Feature
| report is defined for writing up to four sequential characters from the display in a single report. Note that the
| Data Read Back usage is not declared in the Report descriptor, which implies that the display character data
| is write-only

| The following Character Report contains 2, 4 byte fields, one for character data and another for character
| attributes. Each allow 4 characters to be modified simultaneously.

09 2b Usage (Character Report)
a1 02 Collection(Logical)
85 03 ReportID (3)
09 2c Usage (Display Data)
75 08 ReportSize(8)
95 04 ReportCount(4)
b2 0201 Feature(Data, Variable, Absolute, Buffered Bytes), ;4-byte data buffer
09 4a Usage (Attribute Data)
75 08 ReportSize(8)
95 04 ReportCount(4)
b2 0201 Feature(Data, Variable, Absolute, Buffered Bytes), ;4-byte data buffer
c0 End Collection()

| A fourth Feature report is defined for updating the font. The Display Data field identifies the character to be
| modified. Because Character Height = 7 and Character Width = 5, 35 bits will be required for a font
| character. A 40-bit buffered-byte field (5x8) is declared to contain the font data. Note that the Data Read
| Back usage is not declared in the Report descriptor, which implies that the display font data is write-only.

85 04 ReportID(4),
09 3b Usage(Font Report),
a1 02 Collection(Logical),
15 00 Logical Minimum(0), 
25 7e Logical Maximum(126),
75 08 ReportSize(8), 
95 01 ReportCount(1),
09 2c Usage(Display Data),
91 02 Output(Data, Variable, Absolute), ; Character to write
95 05 ReportCount(5),                   ; Assumes a 5x7 font, 35 bits
09 3c Usage(Font Data),
92 0201 Output(Data, Variable, Absolute, Buffered Bytes),   ; Font data
c0 End Collection(),

c0 End Collection()