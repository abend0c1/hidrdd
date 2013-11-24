| A.2 Tape Jog Wheel
| A tape jog wheel is a spring-loaded knob that rotates ±90°, with a small indent for the user’s index finger. As
| the user twists the knob right or left, the tape is advanced or backed up at a rate proportional to the rotation
| from the spring-loaded center position.


05 0c UsagePage(Consumer)
09 01 Usage(Consumer Control)
a1 01 Collection(Application),
09 bd Usage(Tape Jog?)
15 81 Logical Minimum(-127), 
25 7f Logical Maximum(127),
75 08 ReportSize(8), 
95 02 ReportCount(2),
81 06 Input(Data ,Variable, Relative, No Wrap, Linear, Preferred)
c0    End Collection

| The Preferred flag is set because the control will return to the center position when the user releases it.