| Appendix C: Physical Descriptor Example

| Physical descriptors allow a device to identify how the user physically interacts with the device. These are
| particularly useful for devices such as ergonomically designed flight simulator throttle controls.

| Attaching a designator to a control is as simple as adding a usage. The Designator Index is used to access a
| Physical descriptor in a physical descriptor set. In this example, the stick is designed to be held in either
| hand. However, the way that the user accesses the buttons will change depending on which hand is used.

| Consider the joystick below. When the joystick is held by a right-handed person, the thumb falls on the left
| button (2). It would make sense to assign this button to a function that requires quick access or a fast repeat
| rate, while the button on the right (4) would be assigned a function that does not. This is because a right-
| handed user must stretch the thumb from the resting position to touch button 4. If a left-handed person held
| the device, the reverse would be true because the thumb would naturally rest on the button on the right (4).

| These considerations result in the Effort values that are declared for the right-hand bias physical descriptor
| set (1) below. Buttons 2, 3, 4, and the hat switch are accessed by the user’s thumb. The Effort assignments
| are Button 2 = 0, Hat switch = 1, Button 3 = 2, and Button 4 = 3. In the case of the Hat switch and Button 3,
| the thumb has to stretch the same amount. The user must, in essence, “heel and toe” the two controls with
| the thumb. The Hat switch receives the lower Effort value because the tip of the thumb (toe) is considered a
| more effective manipulator than the first joint of the thumb (heel).

| The left hand of a right-handed user normally manipulates the throttle, while a left-handed user must let go
| of the stick and use the index finger to manipulate it. This is why the Physical descriptor for both right-
| handed and left-handed users indicates the left index finger. However, for the left-handed user, the Effort is
| higher.

| Figure 31: Joystick Button Layout
|
|                   Hatswitch
|                       |
|                       V
|                .------------.
|               /     (())     \ 
| Button 2 --> | ( )        ( ) | <-- Button 4
|               \     (  )     /  <-- Button 3
|                `---. || .---'
|                    | || |  <-- Button 1 (Trigger, behind stick)
|                    | || |
|                    |    |
|                    |    |
|                    |    |
|                    |    |
|                    |    |
|                    |    |
|                   /      \
|               _  |__    __|
|           ___|_|____|__|__________
|          / Throttle               \
|          |________________________|
|           \______________________/
|
|                    Lovely!

| In the following Report descriptor example, Physical descriptor 1 is attached to the throttle, Physical
| descriptor 2 to the stick, and so on. Two physical descriptor sets are provided: right and left hand. The
| physical descriptor set that is actually referenced depends on whether the user is right- or left-handed. It is
| assumed that the orientation of the user is stored in the user’s profile on the system.

05 01 Usage Page (Generic Desktop),
15 00 Logical Minimum (0),
09 04 Usage (Joystick),
a1 01 Collection (Application),
  05 02 Usage Page (Simulation Controls),
  09 bb Usage (Throttle),
  39 01 Designator Index (1),
  15 81 Logical Minimum (-127),
  25 7f Logical Maximum (127),
  75 08 Report Size (8),
  95 01 Report Count (1),
  81 02 Input (Data, Variable, Absolute),

  05 01 Usage Page (Generic Desktop),
  39 02 Designator Index(2),
  09 01 Usage (Pointer),
  a1 00 Collection (Physical),
    09 30 Usage (X),
    09 31 Usage (Y),
    95 02 Report Count (2),
    81 02 Input (Data, Variable, Absolute),
  c0 End Collection(),

  09 39 Usage (Hat switch),
  39 03 Designator Index (3),
  15 00 Logical Minimum (0), 
  25 03 Logical Maximum (3),
  35 00 Physical Minimum (0), 
  46 0e 01 Physical Maximum (270),
  65 14 Unit (English Rotation: Angular Position), ; Degrees
  55 00 Unit Exponent (0),
  75 04 Report Size (4), 
  95 01 Report Count (1),
  81 42 Input (Data, Variable, Absolute, Null State),

  05 09 Usage Page (Buttons),     ; Buttons on the stick
  19 01 Usage Minimum (Button 1),
  29 04 Usage Maximum (Button 4),
|-->  35 04 Physical Minimum (4), <-- Removed
|-->  45 07 Physical Maximum (7), <-- Removed
  15 00 Logical Minimum (0), 
  25 01 Logical Maximum (1),
  35 00 Physical Minimum (0), 
  45 01 Physical Maximum (1),
  95 04 Report Count (4),
  75 01 Report Size (1),
  65 00 Unit (None),
  81 02 Input (Data, Variable, Absolute),
c0 End Collection()


| The above example has been corrected by:
| 1. Removing the Physical Minimum(4) and Physical Maximum(7) items
|    as they are subsequently overridden anyway.
