| Here are two examples of volume controls. The first example defines a pair of buttons that are used to ramp
| volume up and down, and the second example is a normal volume knob.

| A.1.1 Up/Down Buttons
| The following example defines a pair of buttons that ramp a variable, such as Volume Up and Volume
| Down buttons. The Input device must be defined as Relative. A value of –1 will reduce and +1 will increase
| the volume at a rate determined by the vendor. A value of 0 will have no effect on the volume

05 0c UsagePage(Consumer)
09 01 Usage(Consumer Control)
a1 01 Collection(Application),
09 e0 Usage(Volume)
15 ff Logical Minimum(-1), 
25 01 Logical Maximum(1),
75 02 ReportSize(2), 
95 01 ReportCount(1),
81 06 Input(Data, Variable, Relative)
c0 End collection


| A.1.2 Knob
| The following example defines a volume knob that turns 270°:

05 0c UsagePage(Consumer)
09 01 Usage(Consumer Control)
a1 01 Collection(Application),
09 e0 Usage(Volume)
15 00 Logical Minimum(0), 
25 64 Logical Maximum(100),
75 07 ReportSize(7), 
95 01 ReportCount(1),
81 22 Input(Data, Variable, Absolute, No Wrap, Linear, No Preferred)
c0 End collection


| The Logical Minimum and Logical Maximum values depend on the resolution provided by the vendor.
| Because the knob only turns 270 degrees, the No Wrap flag is set. A volume control usually generates an
| analog output using an audio taper. However, in this example, the volume control simply generates a Linear
| output as a function of its physical position from 0 to 100 percent. The controlling application would apply
| the audio taper to the output. The No Preferred flag is set because the control will remain in the last position
| that the user left it in.