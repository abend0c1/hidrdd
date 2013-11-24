| A.10 Telephone

| This is an example of a speaker phone with the following features:
| • Six programmable buttons, each with an In Use indicator LED. The first two programmable buttons
|   also have LEDs that can be used to indicate that the function (line) is selected but not necessarily in
|   use.
| • A Message Waiting indicator that can blink when the voice mailbox is full.
| • A standard telephone keypad.
| • Nine permanently marked buttons: Alternate Function, Conference, Transfer, Drop, Hold, Speaker
|   Phone, Volume Up, and Volume Down.
| • An In Use indicator for the Alternate Function button.
| • An Off-Hook indicator used by the handset.



;Declare all the inputs

95 01 ReportCount(1),
05 0b UsagePage(Telephony Devices),
09 01 Usage(Phone),
a1 01 Collection(Application),
  09 07 Usage(Programmable Button),
  a1 02 Collection(Logical),
    05 09 UsagePage(Button),
    09 01 Usage Minimum(Button 1),
    09 06 Usage Maximum(Button 6),
    75 03 ReportSize(3),
    15 01 Logical Minimum(1),
    25 06 Logical Maximum(6),
    81 40 Input(Data, Array, Absolute, Null State),  ; 3-bit buffer for prog buttons
  c0 End Collection(),
  05 0b UsagePage(Telephony Devices),
  09 06 Usage(Telephony Key Pad),
  a1 02 Collection(Logical),
    19 b0 Usage Minimum(Phone Key 0),
    29 bb Usage Maximum(Phone Key Pound),
    25 0c Logical Maximum(12),                     ; 12 buttons
    75 04 ReportSize(4),
    81 40 Input(Data, Array, Absolute, Null State), ; 4-bit field, keypad buttons
  c0 End Collection(),

  05 0b UsagePage(Telephony Devices),
  09 20 Usage(Hook Switch),
  09 29 Usage(Alternate Function),
  09 2c Usage(Conference),
  09 25 Usage(Transfer),
  09 26 Usage(Drop),
  09 23 Usage(Hold),
  09 2b Usage(Speaker Phone),
  25 07 Logical Maximum(7),                      ; 7 buttons
  75 03 ReportSize(3),
  81 40 Input(Data, Array, Absolute, Null State),  ; 3-bit field for misc. buttons
  05 0c UsagePage(Consumer Devices),
  09 e0 Usage(Volume),
  15 ff Logical Minimum(-1),
  25 01 Logical Maximum(1),
  75 02 ReportSize(2),
  81 02 Input(Data, Variable, Absolute),  ; 2-bit field for volume

  ;Declare all the indicator outputs (LEDs)
  ; Define two Usage Selected Indicators and associate them
  ; with programmable buttons 1 and 2

  75 01 ReportSize(1),
  15 00 Logical Minimum(0),
  25 01 Logical Maximum(1),
  05 08 UsagePage(LEDs),
  09 3a Usage(Usage Selected Indicator),
  a1 02 Collection(Logical),
    05 0b UsagePage(Telephony Devices),
    09 07 Usage(Programmable Buttons),
    a1 02 Collection(Logical),
      05 09 UsagePage(Button),
      09 01 Usage Minimum(Button 1),
      09 02 Usage Maximum(Button 2),
      95 02 ReportCount(2),
      91 02 Output(Data, Variable, Absolute),
    c0 End Collection(),
  c0 End Collection(),


  ; Define six Usage In Use Indicators and associate them
  ; with Programmable buttons 1 through 6
  ; Message Waiting, and Alternate Function

  05 08 UsagePage(LEDs),
  09 3b Usage(Usage In Use Indicator),
  a1 02 Collection(Logical),
    05 0b UsagePage(Telephony Devices),
    09 07 Usage(Programmable Key),
    a1 02 Collection(Logical),
      05 09 UsagePage(Button),
      19 01 Usage Minimum(Button 1),
      29 06 Usage Maximum(Button 6),
      95 06 ReportCount(6),
      91 02 Output(Data, Variable, Absolute),
    c0 End Collection(),
    05 0b UsagePage(Telephony Devices),
    09 29 Usage(Alternate Function),
    95 01 ReportCount(1),
    91 02 Output(Data, Variable, Absolute),
  c0 End Collection(),
  
  05 08 UsagePage(LEDs),
  09 3c Usage(Usage Multi Mode Indicator),
  a1 02 Collection(Logical),
    05 0b UsagePage(Telephony Devices),
    09 03 Usage(Message),
    a1 02 Collection(Logical),
      05 08 UsagePage(LEDs),
      09 3d Usage(Indicator On),
      09 40 Usage(Indicator Fast Blink),
      09 41 Usage(Indicator Off),
      75 02 ReportSize(2),
      91 00 Output(Data, Array),
    c0 End Collection(),
  c0 End Collection(),


  ;Volume Control
  05 0c UsagePage(Consumer),
  09 e0 Usage(Volume),            ; Volume buttons
  15 ff Logical Minimum(-1),
  25 01 Logical Maximum(1),
  75 02 ReportSize(2),           ; 2-bit field for volume
  95 01 ReportCount(1),
  91 06 Output(Data, Variable, Relative, Preferred),

  ;Pad to byte boundary
  75 03 ReportSize(3),
  95 01 ReportCount(1),
  91 01 Output(Constant),        ; 3-bit pad
c0 End Collection()


| The above example was corrected by:
| 1. Setting Usage Page to LED prior to specifying the
|    Indcator On, Indicator Fast Blink and Indicator Off usages.
| 2. Setting the Report Size to 1 bit for buttons. The existing
|    size of 2 caused fields to be misaligned.
