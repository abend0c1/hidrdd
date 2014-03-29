|  A.7 Desktop Tablet Example

| This is the Report descriptor for a typical desktop digitizing tablet. The tablet’s digitizing region is 12
| inches square, and it reports data in units of .001 inches. It is optionally equipped with any or all of three
| cordless transducers: a 16-button cursor, a stylus with a tip and a barrel switch, and a stylus with a pressure
| transducer.

| The example digitizer can distinguish between the different cursors, and it sends a report based on the cursor
| that last changed state. The ReportID report data entity indicates which cursor is generating the current
| report. The X and Y position data and the In Range bit are in the same field for each report type, but the
| pressure and button data are different for each transducer, with padding in the report where necessary. The
| vanilla stylus and puck transducers generate 6-byte reports, whereas the pressure stylus generates a 7-byte
| report.

| The Report descriptor below is structured as an application collection containing three physical collections,
| one for each supported cursor. The ReportID items precede each cursor collection, which causes a separate,
| tagged report to be defined for each cursor. The Push and Pop items are used to save and restore the item
| state that defines the X and Y fields. The Report descriptor takes advantage of the fact that the tablet is
| square— that is, the physical and logical ranges of X and Y position are identical.

|  Example Digitizer Report Descriptor
05 0d      Usage Page(Digitizers),   ; Application collection
09 01      Usage(Digitizer),
a1 01      Collection(Application),
85 01       ReportID(1),    ; 2-Button Stylus
09 21        Usage(Puck),
a1 02        Collection, <-- Changed to Logical
05 01          Usage Page(Generic Desktop),  ; X and Y Position
09 30          Usage(X), 
09 31          Usage(Y),
75 10          ReportSize(16), 
95 02          ReportCount(2),
15 00          Logical Minimum(0), 
26 e0 2e      Logical Maximum(12000),
35 00          Physical Minimum(0), 
45 0c          Physical Maximum(12),
65 13          Units(English Linear: Distance),  ; Inches
55 00          Exponent(0),
a4            Push,    ; Save position item state
81 02          Input(Data, Variable, Absolute),

05 0d          Usage Page(Digitizers),
09 32          Usage(In Range),   ; In Range bit, switches
09 44          Usage(Barrel Switch),
09 42          Usage(Tip Switch),
15 00          Logical Minimum(0), 
25 01          Logical Maximum(1),
35 00          Physical Minimum(0), 
45 01          Physical Maximum(1),
65 00          Units(None),
75 01          Report Size(1), 
95 03          Report Count(3),
81 02          Input(Variable, Absolute),

95 01          Report Count(1), 
75 05          Report Size(5),  ; Padding (5 bits)
81 03          Input(Constant),
c0          End Collection,

09 20        Usage(Stylus),
a1 02        Collection <-- Changed to Logical
b4            Pop,  ; Refer to Global items
a4            Push,  ; saved during last Push
85 02          Report ID(2),  ; 16-Button Cursor Tag
95 02          ReportCount(2), ; Report Count (2)
09 30          Usage(X),   ; X and Y position usages
09 31          Usage(Y),
81 02          Input(Data, Variable, Absolute),

05 0d          Usage Page(Digitizer),
09 32          Usage(In Range),    ; In Range bit
15 00          Logical Minimum(0), 
25 01          Logical Maximum(1),
35 00          Physical Minimum(0), 
45 01          Physical Maximum(1),
65 00          Units(None),
75 01          Report Size(1), 
95 01          Report Count(1),
81 02          Input(Data, Variable, Absolute),

05 09         Usage Page(Buttons),  ; Button index
19 00          Usage Minimum(0), 
29 10          Usage Maximum(16),
25 10          Logical Maximum(16),
75 05          Report Size(5), 
95 01          Report Count(1),
81 00          Input(Data, Array, No Null Position),

95 01          Report Count(1), 
75 02          Report Size(2),    ; Padding (2 bits)
81 03          Input(Constant),
c0          End Collection,

05 0d        Usage Page(Digitizer),
09 20        Usage(Stylus),
a1 02        Collection <-- Changed to Logical
b4            Pop,      ; Refer to Global items saved during initial Push
85 03          Report ID(3),    ; Pressure Stylus Tag
09 30          Usage(X), ; X and Y position usages
09 31          Usage(Y),
81 02          Input(Date, Variable, Absolute),

15 00         Logical Minimum(0), 
25 01          Logical Maximum(1),
35 00          Physical Minimum(0), 
45 01          Physical Maximum(1),
65 00          Units(None),
75 01          Report Size(1), 
95 06          Report Count(6),  ; Padding (6 bits)
81 03          Input(Constant),

05 0d          Usage Page(Digitizer),
09 32          Usage(In Range),      ; In Range bit, barrel switch
09 44          Usage(Barrel Switch),
95 02          Report Count(2),
81 02          Input(Variable, Absolute),

09 30          Usage(Tip Pressure),    ; Tip pressure
15 00          Logical Minimum(0), 
25 7f          Logical Maximum(127),
35 00          Physical Minimum(0), 
45 2d          Physical Maximum(45),
66 11 e1      Units(SI Linear: Force), 
55 04          Exponent(4),
75 08          Report Size(8), 
95 01          Report Count(1),
81 12          Input(Variable, Absolute, Non Linear),
c0          End Collection,
c0        End Collection
