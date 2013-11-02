    05 01                    // G USAGE_PAGE (Generic Desktop)
    09 06                    // L USAGE (Keyboard)
    a1 01                    // M COLLECTION (Application)
    85 4B                    //   G REPORT_ID
    05 07                    //   G USAGE_PAGE (Keyboard)
    19 e0                    //   L USAGE_MINIMUM (Keyboard LeftControl)
    29 e7                    //   L USAGE_MAXIMUM (Keyboard Right GUI)
    15 00                    //   G LOGICAL_MINIMUM (0)
    25 01                    //   G LOGICAL_MAXIMUM (1)
    75 01                    //   G REPORT_SIZE (1)
    95 08                    //   G REPORT_COUNT (8)
    81 02                    //   M INPUT (Data,Var,Abs)

    75 08                    //   G REPORT_SIZE (8)
    95 01                    //   G REPORT_COUNT (1)
    81 03                    //   M INPUT (Cnst,Var,Abs)

    95 01                    //   G REPORT_COUNT (1)
    26 ff 00              //   G LOGICAL_MAXIMUM (255)
    19 00                    //   L USAGE_MINIMUM (Reserved (no event indicated))
    2a ff 00              //   L USAGE_MAXIMUM (255)
    81 00                    //   M INPUT (Data,Ary,Abs)
/*
Output Report (PIC <-- Host) 2 bytes as follows:

    .---------------------------------------.
    |          REPORT_ID_KEYBOARD           | OUT: Report Id
    |---------------------------------------|
    |    |    |    |    |    |SCRL|CAPL|NUML| OUT: NumLock,CapsLock,ScrollLock - and 5 unused pad bits
    '---------------------------------------'
*/
    75 01                    //   G REPORT_SIZE (1)
    95 03                    //   G REPORT_COUNT (3)
    05 08                    //   G USAGE_PAGE (LEDs)
    19 01                    //   L USAGE_MINIMUM (Num Lock)
    29 03                    //   L USAGE_MAXIMUM (Scroll Lock)
    25 01                    //   G LOGICAL_MAXIMUM (1)
    91 02                    //   M OUTPUT (Data,Var,Abs)

    75 05                    //   G REPORT_SIZE (5)
    95 01                    //   G REPORT_COUNT (1)
    91 03                    //   M OUTPUT (Cnst,Var,Abs)

    c0                          // M END_COLLECTION

/*
System Control Input Report (PIC --> Host) 2 bytes as follows:
    .---------------------------------------.
    |        REPORT_ID_SYSTEM_CONTROL       | IN: Report Id
    |---------------------------------------|
    |           Power Control Code          | IN: Power Off, Sleep, Power On
    '---------------------------------------'
*/
    05 01                    // G USAGE_PAGE (Generic Desktop)
    09 80                    // L USAGE (System Control)
    a1 01                    // M COLLECTION (Application)
    85 53                    //   G REPORT_ID
    19 00                    //   L USAGE_MINIMUM (0x00)
    2a FF 00              //   L USAGE_MAXIMUM (0xFF)
    15 00                    //   G LOGICAL_MINIMUM (0x00)
    26 FF 00              //   G LOGICAL_MAXIMUM (0xFF)
    75 08                    //   G REPORT_SIZE (8)
    95 01                    //   G REPORT_COUNT (1)
    81 00                    //   M INPUT (Data,Ary,Abs)
    c0                          // M END_COLLECTION

/*
Consumer Device Input Report (PIC --> Host) 3 bytes as follows:
    .---------------------------------------.
    |       REPORT_ID_CONSUMER_DEVICE       | IN: Report Id
    |---------------------------------------|
    |    Consumer Device Code (Low byte)    | IN: Mute, Vol+, Vol- etc
    |---------------------------------------|
    |    Consumer Device Code (High byte)   | IN:
    '---------------------------------------'
*/
    05 0C                    // G USAGE_PAGE (Consumer Devices)
    09 01                    // L USAGE (Consumer Control)
    a1 01                    // M COLLECTION (Application)
    85 43                    //   G REPORT_ID
    19 00                    //   L USAGE_MINIMUM (0)
    2a 3c 02              //   L USAGE_MAXIMUM (0x023C)
    15 00                    //   G LOGICAL_MINIMUM (0)
    26 3c 02              //   G LOGICAL_MAXIMUM (0x023C)
    75 10                    //   G REPORT_SIZE (16)
    95 01                    //   G REPORT_COUNT (1)
    81 00                    //   M INPUT (Data,Ary,Abs)
    c0                          // M END_COLLECTION