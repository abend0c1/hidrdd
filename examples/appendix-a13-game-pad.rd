| A.13 Game Pad
| This is an example of a game pad with the following features:
| • A two-axis rocker that tilts forward/backward and right/left
| • Six buttons

05 01 UsagePage(Generic Desktop),
09 05 Usage(Game Pad),
a1 01 Collection(Application),
  09 01 Usage (Pointer),
  a1 00 Collection (Physical),
    09 30 Usage (X),
    09 31 Usage (Y),
    15 ff Logical Minimum (-1), 
    25 01 Logical Maximum (1),
    95 02 Report Count (2), 
    75 02 Report Size (2),
    81 02 Input (Data, Variable, Absolute, No Null),
  c0 End Collection(),
  95 01 Report Count (1),
  75 04 Report Size (4),
  81 03 Input (Constant, Variable, Absolute), ; 4-bit pad
  05 09 Usage Page (Buttons),    ; Buttons on the stick
  19 01 Usage Minimum (Button 1),
  29 06 Usage Maximum (Button 6),
  15 00 Logical Minimum (0), 
--> 25 01 Logical Maximum (1),  <-- removed
  95 06 Report Count (6),
  75 01 Report Size (1),
  81 02 Input (Data, Variable, Absolute),
  95 01 Report Count (1),        ; 2-bit Pad
  75 02 Report Size (2), <-- inserted
  81 03 Input (Constant, Variable, Absolute)
c0 End Collection()

| The above has been slightly improved by:
| 1. Replacing the pad fields so that n fields x 1-bit wide
|    becomes 1 field x n-bits wide
| 2. Removing the redundant Logical Maximum (1)
