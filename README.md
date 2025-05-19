## Feature
Create NI LabVIEW TDMS from lua table.
Support Property, Incremental Meta Information.

## Usage
```lua
Lua_TDMS=require'Lua_TDMS'
TDMS=Lua_TDMS.New():Write_Data{
	Group_1={
		Group_Property='string',
		Channel_1={
			Channel_Property=123,
			[0]=Lua_TDMS.tdsType.I32,--if nil, auto detect from [1]
			1,2
		}
	}
}:Write_File(File_Handle)
--should write everyt time after `Write_Data`.
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

Use `Output_Result` in [Test.lua] to check 'TDMS.Lead_In', 'TDMS.Meta_Data', 'TDMS.Raw_Data'.

## Related
- [TDMS File Format Internal Structure - NI](https://www.ni.com/en/support/documentation/supplemental/07/tdms-file-format-internal-structure.html)