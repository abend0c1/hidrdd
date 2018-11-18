| A.9 Remote Control
| The remote control in this example has 24 buttons with the following labels:
| • A number pad with ten digits, 1 through 9 and 0
| • Channel Up and Channel Down
| • Volume Up and Volume Down
| • Mute
| • Power
| • Sleep Timer
| • On Screen
| • Enter Choice, Choice 1, Choice 2, and Choice 3
| • Broadcast
| • Return

05 0c UsagePage(Consumer),
09 01 Usage(Consumer Control),
a1 01 Collection(Linked), <-- Application (not "Linked")
  09 02 Usage(Numeric Key Pad),
  a1 04 Collection(Named Array), <-- Named Array (not "Logical")
    05 09 UsagePage(Button),
    09 01 Usage(Button 1),
    09 02 Usage(Button 2),
    09 03 Usage(Button 3),
    09 04 Usage(Button 4),
    09 05 Usage(Button 5),
    09 06 Usage(Button 6),
    09 07 Usage(Button 7),
    09 08 Usage(Button 8),
    09 09 Usage(Button 9),
    09 0a Usage(Button 10),
    15 01 Logical Minimum(1),
    25 0a Logical Maximum(10),
    75 04 ReportSize(4),
    95 01 ReportCount(1),
    81 40 Input(Data, Array, Absolute, Null State)
  c0 End Collection(),

  05 0c UsagePage(Consumer Devices),
  09 86 Usage(Channel),    ; Channel buttons
  09 e0 Usage(Volume),     ; Volume buttons
  15 ff Logical Minimum(-1),
  25 01 Logical Maximum(1),
  75 02 ReportSize(2),
  95 02 ReportCount(2),
  81 06 Input(Data, Variable, Relative, Preferred),
  09 e2 Usage(Mute),
  09 30 Usage(Power),
  09 34 Usage(Sleep Mode),
  09 60 Usage(Data On Screen),
  09 64 Usage(Broadcast Mode),     ; Broadcast
  09 46 Usage(Menu Escape),        ; Return <-- No such usage as "Selection Back"
  09 81 Usage(Assign Selection),   ; Enter Choice
  15 01 Logical Minimum(1),
  25 07 Logical Maximum(7),
  75 04 ReportSize(4),
  95 01 ReportCount(1),
  81 40 Input(Data, Array, Absolute, Null State),

  09 80 Usage(Selection),
  a1 04 Collection(Named Array),       ; Three choice buttons <-- Named Array (not "Logical")
    05 09 UsagePage(Button),
    09 01 Usage(Button 1),           ; Choice 1
    09 02 Usage(Button 2),           ; Choice 2
    09 03 Usage(Button 3),           ; Choice 3
    15 01 Logical Minimum(1),
    25 03 Logical Maximum(3),
    75 02 ReportSize(2),
    95 01 ReportCount(1),
    81 40 Input(Data, Array, Absolute, Null State),
  c0 End Collection(),

  15 01 Logical Minimum(1),
  25 02 Logical Maximum(2),
  75 02 ReportSize(2),
  95 01 ReportCount(1),
  81 03 Input(Constant, Variable, Absolute),  ; 2-bit pad
c0 End Collection(),
