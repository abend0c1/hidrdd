| 6.1.6 UPC/EAN Control Report

05 8c USAGE PAGE(Barcode Device Page) <-- Added
09 01 USAGE (Barcode Scanner) <-- Added
a1 01 COLLECTION (Application) <-- Added
	09 16 USAGE (UPC/EAN Control Report)
	a1 02 COLLECTION (Logical) <-- Changed to Application
	  85 06 REPORT_ID (6)
	  75 04 REPORT_SIZE(4)
	  95 01 REPORT_COUNT(1) <-- Added
	  09 b0 USAGE (Check)
	  a1 04 COLLECTION (Logical) <-- Changed to Named Array 
	    15 00 LOGICAL_MAXIMUM (1) <-- Added
	    25 04 LOGICAL_MAXIMUM (5) <-- Changed to 4 (indexes 0 to 4 = 5 usages)
	    19 b1 USAGE_MINIMUM (Check Disable Price)
	    29 b5 USAGE_MAXIMUM (Check Enable European 5 digit Price)
	    91 00 OUTPUT (Data,Ary,Abs)
	  c0 COLLECTION_END
	  09 a9 USAGE (Periodical)
	  a1 04 COLLECTION (Logical) <-- Changed to Named Array
	    25 02 LOGICAL_MAXIMUM (3) <-- Changed to 2 (indexes 0 to 2 = 3 usages)
	| -->  75 04 REPORT_SIZE (4) <-- Removed
	    19 aa USAGE_MINIMUM (Periodical Auto-Discriminate +2)
	    29 ac USAGE_MAXIMUM (Periodical Ignore +2)
	    91 00 OUTPUT (Data,Ary,Abs)
	  c0 COLLECTION_END
	  09 a9 USAGE (Periodical)
	  a1 04 COLLECTION (Logical) <-- Changed to Named Array
	    19 ad USAGE_MINIMUM (Periodical Auto-Discriminate +5)
	    29 af USAGE_MAXIMUM (Periodical Ignore +5)
	    91 00 OUTPUT (Data,Ary,Abs)
	  c0 COLLECTION_END
	| -->  15 00 LOGICAL_MINIMUM (0) <-- Removed
	  25 01 LOGICAL_MAXIMUM (1)
	  75 01 REPORT_SIZE (1)
	  95 18 REPORT_COUNT (24) <-- Should really be 17, with 5 pad bits after

| --> The following list of usages was replaced by equivalent ranges below:	  
| -->	  09 91 USAGE (Bookland EAN)
| -->	  09 92 USAGE (Convert EAN 8 to 13 Type)
| -->	  09 93 USAGE (Convert UPC A to EAN-13)
| -->	  09 94 USAGE (Convert UPC-E to A)
| -->	  09 95 USAGE (EAN-13)
| -->	  09 96 USAGE (EAN-8)
| -->	  09 97 USAGE (EAN-99 128_Mandatory)
| -->	  09 98 USAGE (EAN-99 P5/128_Optional)
| -->	  09 99 USAGE (Enable EAN Two Label)
| -->	  09 9a USAGE (UPC/EAN)
| -->	  09 9b USAGE (UPC/EAN Coupon Code )

| -->	  09 9d USAGE (UPC-A)
| -->	  09 9e USAGE (UPC-A with 128 Mandatory)
| -->	  09 9f USAGE (UPC-A with 128 Optional)

| -->	  09 a0 USAGE (UPC-A with P5 Optional)
| -->	  09 a1 USAGE (UPC-E)
| -->	  09 a2 USAGE (UPC-E1)
    19 91 USAGE_MINIMUM (Bookland EAN)
    29 9b USAGE_MAXIMUM (UPC/EAN Coupon Code )
    19 9d USAGE_MINIMUM (UPC-A)
    29 9f USAGE_MAXIMUM (UPC-A with 128 Optional)
    19 a0 USAGE_MINIMUM (UPC-E)
    29 a2 USAGE_MAXIMUM (UPC-E1)

	  91 02 OUTPUT (Data,Var,Abs)

	c0 END_COLLECTION
c0 End Collection <-- Added