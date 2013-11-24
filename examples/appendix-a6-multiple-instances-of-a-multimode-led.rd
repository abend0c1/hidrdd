| A.6 Multiple Instances of a Multi-Mode LED
; Pointer
; Pointer 1
; Pointer 2

| This example shows how to implement an indicator that supports blinking as well as multiple colors. In this
| example, there are two LEDs (Play and Stop) that can be On, Blinking, or Off, and when they are
| illuminated they can be Red, Green, or Amber. The LED page provides slow and fast blinking usages, and
| either could have been chosen here to enable the single blinking mode that this device supports.

05 01 Usage Page(Generic Desktop)
09 06 Usage(Keyboard),
a1 01 Collection(Application),

| Declare the globals that are used by all the Main items.

75 02 Report Size(2),
95 01 Report Count(1),
15 01 Logical Minimum(1),
25 03 Logical Maximum(3),

| Declare the Play LED.

05 0c Usage Page(Consumer),
09 b0 Usage(Play),
a1 02 Collection(Logical),
05 08 Usage Page(LED),
09 3c Usage(Usage Multi Mode Indicator),  ; Declare Mode field
a1 02 Collection(Logical),
09 3d Usage(Indicator On),
09 3f Usage(Indicator Slow Blink),
09 41 Usage(Indicator Off),
b1 40 Feature(data, Array, Null),          ; 3 modes supported
c0 End Collection(),
09 47 Usage(Usage Indicator Color),        ; Declare Color field
a1 02 Collection(Logical),
09 48 Usage(Red),                          ; of the LED.
09 49 Usage(Green),
09 4a Usage(Amber),
b1 40 Feature(data, Array, Null),          ; Three colors supported
c0 End Collection(),
c0 End Collection(),

| Declare the controls for the Stop LED.

05 0c Usage Page(Consumer),
09 b7 Usage Minimum(Stop),
a1 02 Collection(Logical),
05 08 Usage Page(LED),
09 3c Usage(Usage Multi Mode Indicator),
a1 02 Collection(Logical),
09 3d Usage(Indicator On),
09 3f Usage(Indicator Slow Blink),
09 41 Usage(Indicator Off),
b1 40 Feature(data, Array, Null),
c0 End Collection(),
09 47 Usage(Usage Indicator Color),
a1 02 Collection(Logical),
09 48 Usage(Red),
09 49 Usage(Green),
09 4a Usage(Amber),
b1 40 Feature(data, Array, Null),
c0 End Collection(),
c0 End Collection(),

c0 End Collection


| This differs from the example in the Specification in that it has been wrapped in the 
| required Application Collection, and the erroneous "Usage Minimum(Play)" has been 
| replaced by "Usage(Play)".