| A.4 Named Array Field
| To simplify an application finding a “one of many” set of controls, the array field associated with it can be
| named by wrapping the array declaration in a logical collection.

| In the following example, the device returns one of three status codes: Not Ready, Ready, or Err Not a
| loadable character. An application can simply query for the Display Status usage to find the array field that
| will contain the status codes.

05 14 UsagePage(Alphanumeric Display)
09 01 Usage(Consumer Control)
a1 01 Collection(Application),
75 02 ReportSize(2), 
95 01 ReportCount(1),
25 02 Logical Maximum(2),
09 2d Usage(Display Status),
a1 02 Collection(Logical),
09 2e Usage(Stat Not Ready),
09 2f Usage(Stat Ready),
09 30 Usage(Err Not a loadable character),
81 00 Input(Data, Array, Absolute, No Null Position), ; 3-bit status field
c0 End Collection(),
c0 End Collection(),


| The No Null Position flag indicates that there is never a state in which it is not sending meaningful data. The
| returned values are Null = No event (outside of the Logical Minimum / Logical Maximum range) 1 = Stat
| Not Ready, 2 = Stat Ready, or 3 = Err Not a loadable character.

| Actually, the above explanation is incorrect because usages are assigned starting at the Logical Minimum:
|    0 = Stat Not Ready
|    1 = Stat Ready
|    2 = Err Not a loadable character
|    3 = No event - outside Logical Minimum=0 Logical Maximum=2 range
| ...also, Logical Minimum is not specified and is therefore undefined
