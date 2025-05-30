local Lua_TDMS=require'Lua_TDMS'
local tdsType=Lua_TDMS.tdsType
----
local IsEqual do
	local State,Table=pcall(require,'Table')
	Table=require'Table'
	IsEqual=Table and Table.IsEqual
end
if not IsEqual then
	error"find something to detect / compare table"
end

local function Output_Result(Stream,Expected)
	local Result={}
	for Index,Byte in ipairs(Stream) do
		table.insert(Result,Byte)
		if not Expected then
			io.write(string.format('%02x ',Byte))
			if Index%4==0 then
				print''
			end
		end
	end
	if Expected then
		assert(IsEqual(Result,Expected))
	end
end
local TDMS=Lua_TDMS.New():Write_Data{
	Group_1={
		Channel_1={
			[0]=tdsType.I32,--default
			--unit_string='PC',--unit name of TDMS
			1,2
		}
	}
}
Output_Result(TDMS.Lead_In,{
	0x54,0x44,0x53,0x6d,
	0x0e,0x00,0x00,0x00,
	0x69,0x12,0x00,0x00,
	0x54,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x4c,0x00,0x00,0x00,0x00,0x00,0x00,0x00}
)
Output_Result(TDMS.Meta_Data,{
	0x02,0x00,0x00,0x00,--number of objects
	0x0a,0x00,0x00,0x00,--length of the first object path
	0x2f,0x27,0x47,0x72,0x6f,0x75,0x70,0x5f,0x31,0x27,
	0xff,0xff,0xff,0xff,--raw data index
	0x00,0x00,0x00,0x00,--number of properties
	0x16,0x00,0x00,0x00,--length of the first object path
	0x2f,0x27,0x47,0x72,0x6f,0x75,0x70,0x5f,0x31,0x27,0x2f,0x27,0x43,0x68,0x61,0x6e,0x6e,0x65,0x6c,0x5f,0x31,0x27,
	0x14,0x00,0x00,0x00,--length of the raw data index
	0x03,0x00,0x00,0x00,--data type
	0x01,0x00,0x00,0x00,--array dimension
	0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,--number of values
	0x00,0x00,0x00,0x00 --number of properties
})
Output_Result(TDMS.Raw_Data,{
	0x01,0x00,0x00,0x00,
	0x02,0x00,0x00,0x00
}) 
print"basic test OK"
----
TDMS:Write_Data{
	Group_1={
		Channel_1={
			[0]=tdsType.I32,--default
			--unit_string='PC',--unit name of TDMS
			3,4
		}
	}
}
Output_Result(TDMS.Lead_In,{
	0x54,0x44,0x53,0x6d,
	0x08,0x00,0x00,0x00,
	0x69,0x12,0x00,0x00,
	0x08,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,
})
Output_Result(TDMS.Meta_Data,{})
Output_Result(TDMS.Raw_Data,{
	0x03,0x00,0x00,0x00,
	0x04,0x00,0x00,0x00,
})
print"Append Data without Property test OK"
--------
local File_Handle=
--	io.open('Test_File.tdms','r+b') or 
	io.open('Test_File.tdms','wb')

TDMS=Lua_TDMS.New()
	:Auto_Write_File(File_Handle)
	:Write_Data{
		Author="Robert",
		--['DateTime']=os.time(),
		--	not 'Date/Time'
		--	timestamp not support yet
		Group={
			prop='value',
			num=10,
			Channel1={
				1,2,--auto detect, default tdsType.I32
			},
		}
}
Output_Result(TDMS.Lead_In,{
	0x54,0x44,0x53,0x6d,
	0x0e,0x00,0x00,0x00,
	0x69,0x12,0x00,0x00,
	0x98,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,
	0x90,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,
})
Output_Result(TDMS.Meta_Data,{
	0x03,0x00,0x00,0x00,
	0x01,0x00,0x00,0x00,
	0x2f,
	0xff,0xff,0xff,0xff,
	0x01,0x00,0x00,0x00,--number of properties
	0x06,0x00,0x00,0x00,--length of the property name
	0x41,0x75,0x74,0x68,0x6f,0x72,--length of the first property name
	0x20,0x00,0x00,0x00,--property value type
	0x06,0x00,0x00,0x00,--length of property value
	0x52,0x6f,0x62,0x65,0x72,0x74,--property value
	0x08,0x00,0x00,0x00,--length of the second object path
	0x2f,0x27,0x47,0x72,--object path string
	0x6f,0x75,0x70,0x27,
	0xff,0xff,0xff,0xff,
	0x02,0x00,0x00,0x00,--number of properties
	0x03,0x00,0x00,0x00,--0x03: length of the property name
	0x6e,0x75,0x6d,0x03,--0x03: property value type
	0x00,0x00,0x00,0x0a,--0x0b: property value
	0x00,0x00,0x00,0x04,
	0x00,0x00,0x00,0x70,
	0x72,0x6f,0x70,0x20,--0x20: property value type
	0x00,0x00,0x00,0x05,--0x05: property value length
	0x00,0x00,0x00,0x76,--property value
	0x61,0x6c,0x75,0x65,
	0x13,0x00,0x00,0x00,
	0x2f,0x27,0x47,0x72,
	0x6f,0x75,0x70,0x27,
	0x2f,0x27,0x43,0x68,
	0x61,0x6e,0x6e,0x65,
	0x6c,0x31,0x27,0x14,--0x14: length of the raw data index
	0x00,0x00,0x00,0x03,--0x03: data type
	0x00,0x00,0x00,0x01,
	0x00,0x00,0x00,0x02,
	0x00,0x00,0x00,0x00,
	0x00,0x00,0x00,0x00,
	0x00,0x00,0x00})
print"New Data with Property test OK"
--do return end
--------
TDMS:Write_Data{
	Group={
		Channel1={
			3,4,--auto detect, default tdsType.I32
		},
	}
}
Output_Result(TDMS.Meta_Data,{})
print"Append Raw Data test OK"
--------
TDMS:Write_Data{
	Group={
		num=11,
		Channel1={
			prop='Value',
			5,6,--auto detect, default tdsType.I32
		},
	}
}
Output_Result(TDMS.Meta_Data,{
	0x02,0x00,0x00,0x00,
	0x08,0x00,0x00,0x00,
	0x2f,0x27,0x47,0x72,
	0x6f,0x75,0x70,0x27,
	0xff,0xff,0xff,0xff,--No_Raw_Data
	0x01,0x00,0x00,0x00,--0x01: number of properties
	0x03,0x00,0x00,0x00,--0x03: length of the first property name
	0x6e,0x75,0x6d,0x03,--property name
											--0x03: property value type
	0x00,0x00,0x00,0x0b,--0x0b: property value
	0x00,0x00,0x00,0x13,--0x13: length of the second object path
	0x00,0x00,0x00,0x2f,--0x2f..: object path string
	0x27,0x47,0x72,0x6f,
	0x75,0x70,0x27,0x2f,
	0x27,0x43,0x68,0x61,0x6e,0x6e,0x65,0x6c,0x31,0x27,
	0x00,0x00,0x00,0x00,--Same_Raw_Data_As_Previous_Segment
	0x01,0x00,0x00,0x00,--0x01: number of properties
	0x04,0x00,0x00,0x00,--0x04: length of the first property name
	0x70,0x72,0x6f,0x70,--property name
	0x20,0x00,0x00,0x00,--0x20: property value type
	0x05,0x00,0x00,0x00,--0x05: property value length
	0x56,0x61,0x6c,0x75,0x65,--property value
})


File_Handle:close()

print"Change Property test OK"