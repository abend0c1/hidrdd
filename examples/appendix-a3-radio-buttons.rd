| A.3 Radio Buttons
| Radio buttons are a group of mutually exclusive buttons. In this example, an audio receiver uses three radio
| buttons to select between a computer, a DVD device, or the World Wide Web as a display source.


| A.3.1 Mechanically Linked Radio Buttons
| Traditionally, radio button implementations have had a mechanical system that releases any buttons not
| pressed and holds the last pressed button in an active state until another button is pressed. In the example
| below, one of three values will be returned: Media Select Computer, Media Select DVD, or Media Select
| WEB.

05 0c UsagePage(Consumer)
09 01 Usage(Consumer Control)
a1 01 Collection(Application),
15 01 Logical Minimum(1), 
25 03 Logical Maximum(3),
09 88 Usage(Media Select Computer),
09 89 Usage(Media Select DVD),
09 8a Usage(Media Select WWW),
75 02 ReportSize(2), 
95 01 ReportCount(1),
81 00 Input(Data, Array, Absolute, No Wrap, Linear, No Preferred, No Null Position)
c0    End Collection

| The No Preferred flag is set because the report will always present the value of the last button pressed. The
| No Null Position flag indicates that there is never a state in which the control is not sending meaningful data.
| The returned values are 1 = Media Select Computer, 2 = Media Select DVD, or 3 = Media Select WWW.



| A.3.2 Radio Buttons with No Mechanical Linkage
| Many systems today use a separate display to indicate the current selection and there is no mechanical
| connection between the buttons. In this example, the control will return one of four values: Null (a value
| outside of the Logical Minimum and Logical Maximum range), Media Select Computer, Media Select
| DVD, or Media Select WWW.

05 0c UsagePage(Consumer)
09 01 Usage(Consumer Control)
a1 01 Collection(Application),
15 01 Logical Minimum(1), 
25 03 Logical Maximum(3),
09 88 Usage(Media Select Computer),
09 89 Usage(Media Select DVD),
09 8a Usage(Media Select WWW),
75 02 ReportSize(2), 
95 01 ReportCount(1),
81 40 Input(Data, Array, Absolute, No Wrap, Linear, No Preferred, Null Position)
c0    End Collection

| The No Preferred flag is set because a valid selection is presented only as long as the user is pressing a
| button. When the user releases a button, the report will present a Null value. The Null Position flag indicates
| that there is a state in which the control is not sending meaningful data and that an application can expect a
| Null value which should be ignored. A Report Size of 2 declares a 2-bit field where only four possible
| values can be returned: 0 = Null, 1 = Media Select Computer, 2 = Media Select DVD, or 3 = Media Select
| WWW.