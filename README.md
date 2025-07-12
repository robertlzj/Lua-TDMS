## Feature
Create NI LabVIEW TDMS from lua table.  
Support Property, Incremental Meta Information, timestamp.  
Lua 5.3.

## Usage
```lua
Lua_TDMS=require'Lua_TDMS'
TDMS=Lua_TDMS.New():Write_Data{
	File_Property='file property',
	Group_1={
		Group_Property='string',
		Channel_1={
			Channel_Property=123,
			[0]=Lua_TDMS.tdsType.I32,--if nil, auto detect from [1]
			1,2
		}
	}
}:Write_File(File_Handle)
--should write every time after `Write_Data`.
--	or:
TDMS:Auto_Write_File(File_Handle)
TDMS:Write_Data{
	Group_1={
		--Group_Property='string',--inherited
		Channel_1={
			Channel_Property=567,--change property value
			3,4
		}
	}
}

```
Also check [Test.lua].  
Use `Output_Result` in [Test.lua] to check 'TDMS.Lead_In', 'TDMS.Meta_Data', 'TDMS.Raw_Data'.

### Timestamp
- Timestamp in property value:
  `DateTime={[0]=tdsType.TimeStamp,Second,Millisecond}`
- Timestamp in raw data:
  `Channel_Name={[0]=tdsType.TimeStamp,{Second,Millisecond},..}`.
	Could omit `[0]=tdsType.TimeStamp` for could been auto detect.
	
May get "time result cannot be represented in this installation".
Check [Lua 5.3.0, os.time(), and year 2038 : r/lua](https://www.reddit.com/r/lua/comments/1dcpotn/comment/l82vazx/)
	
### Boolean
Store data type of boolean. For:
- Property value. Will use data type: `tdsType.Boolean`.
- Raw data. By default, will use data type: `tdsType.U8`.
  "U8" comes from test "Test Binary Footprint of Data Type Of Boolean In Raw Data.vi", then use binary viewer to check output file.
	Also, if use "Boolean", "TDMS - File Viewer.vi" will get error: "TDMS: ERROR: TDS Exception in Initialize: Tds Error: TdsErrNotTdsFile(-2503)".
	And, "TDMS - File Viewer (NXG Style).vi" will get correct result (true/false).
	There is a switcher variable `Use_tdsType_U8_Instead_Of_Boolean_In_Raw_Data`.

## Related
- [TDMS File Format Internal Structure - NI](https://www.ni.com/en/support/documentation/supplemental/07/tdms-file-format-internal-structure.html)
-	[LabVIEW Timestamp Overview - NI](https://www.ni.com/en/support/documentation/supplemental/08/labview-timestamp-overview.html)
