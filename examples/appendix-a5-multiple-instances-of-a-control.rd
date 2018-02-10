| A.5 Multiple Instances of a Control

| This example shows how to implement multiple instances of a set of controls by defining a device with two
| pointers, each with X and Y axes. An application looking for Pointer usages would find two of each type
| enumerated.


05 01 UsagePage(Generic Desktop),
09 02 Usage(Mouse),
a1 01 Collection(Application),
75 08 Report Size
95 02 Report Count
14       Logical Minimum (0)
26 ff 00 Logical Maximum

09 01 Usage(Pointer),
a1 02 Collection(Logical),

  05 0a UsagePage(Ordinal),
  09 01 Usage(Instance 1),
  a1 00 Collection(Physical),        ; Pointer 1
    05 01 UsagePage(Generic Desktop),
    09 30 Usage(X-axis),
    09 31 Usage(Y-axis),
    81 02 Input
  c0 Collection End,

  05 0a UsagePage(Ordinal),
  09 02 Usage(Instance 2),
  a1 00 Collection(Physical),        ; Pointer 2
    05 01 UsagePage(Generic Desktop),
    09 30 Usage(X-axis),
    09 31 Usage(Y-axis),
    81 02 Input
    c0 Collection End,
  c0 Collection End,

c0 Collection End,


| This differs from the example in the Specification in that it has been wrapped in 
| the required Application Collection and also has Input fields and Report Count
| and Report Size - without which the descriptor would be invalid.