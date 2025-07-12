--[[Data={
		File_Property_1=file_property_1,...
		Group_1={--Group
			Group_Property_1=group_property_1,...
			Channel_1={--Channel
				Channel_Property_1=channel_property_1,...
				[0]=Data_Type,
				Raw_Data_1,...
			},...
		},...
	}
]]
--[[Call hierarchy
	Interface,
		Lua_TDMS:New()[:Auto_Write_File(File_Handle)]
			:Write_Data(Data)
	Internal,
		Write_Data(Data):
			Set_Lead_In()
			:Set_Meta_Data(Data)
			 └Write_Raw_Data_Index()
			 └Write_Porperties()
			 └Remove_From_Position()
			 └Detect_TDMS_Type(Value)
			:Set_Raw_Data()
			 └Detect_TDMS_Type(Value)
			[:Write_File(File_Handle)]
]]

----------------

local Use_tdsType_U8_Instead_Of_Boolean_In_Raw_Data=true

----------------

local tdsType={
	I8=1,
	I16=2,
	I32=3,
	I64=4,
	U8=5,
	U16=6,
	U32=7,
	U64=8,
	SingleFloat=9,
	DoubleFloat=10,
	String=0x20,
	Boolean=0x21,
	TimeStamp=0x44,
}
local kToc={
	MetaData=0x1<<1,
	RawData=0x1<<3,
	InterleavedData=0x1<<5,--	interleaved / contiguous
	BigEndian=0x1<<6,--	big-endian / little-endian [default]
										--	only little-endian for now
	NewObjList=0x1<<2,
}

----------------

;	local Utility=require'Lua_TDMS.Utility'
local Number_To_Byte=Utility.Number_To_Byte
local Table_Append=Utility.Table_Append
local Bytes_To_String=Utility.Bytes_To_String
local Write_String=Utility.Write_String
local Write_Timestamp=Utility.Write_Timestamp

local function Write_Object_Length_Path(Stream,Group_Name,Channel_Name)
	local Object_Path="/"..
		(Group_Name
			and ("'"..Group_Name.."'"..(Channel_Name and ("/'"..Channel_Name.."'") or ''))
			or '')
	Write_String(Stream,Object_Path)
end

local tdsType_2_Data_Package_Method={
	[tdsType.U8]=function(Stream,Value)
		local Target_Value
		if type(Value)=='boolean' then
			Target_Value=Value and 1 or 0
		else
			Target_Value=Value
		end
		Number_To_Byte(Target_Value,1,Stream)
	end,
	[tdsType.U16]=function(Stream,Value)
		Number_To_Byte(Value,2,Stream)
	end,
	[tdsType.U32]=function(Stream,Value)
		Number_To_Byte(Value,4,Stream)
	end,
	[tdsType.U64]=function(Stream,Value)
		Number_To_Byte(Value,8,Stream)
	end,
	[tdsType.I8]=function(Stream,Value)
		Number_To_Byte(Value,1,Stream)
	end,
	[tdsType.I16]=function(Stream,Value)
		Number_To_Byte(Value,2,Stream)
	end,
	[tdsType.I32]=function(Stream,Value)
		Number_To_Byte(Value,4,Stream)
	end,
	[tdsType.I64]=function(Stream,Value)
		Number_To_Byte(Value,8,Stream)
	end,
	[tdsType.SingleFloat]=function(Stream,Value)
		for Char in string.gmatch(string.pack('<f',Value),'.') do
			table.insert(Stream,string.byte(Char))
		end
	end,
	[tdsType.DoubleFloat]=function(Stream,Value)
		for Char in string.gmatch(string.pack('<d',Value),'.') do
			table.insert(Stream,string.byte(Char))
		end
	end,
	[tdsType.String]=function(Stream,Value)
		for Char in string.gmatch(Value,'.') do
			table.insert(Stream,string.byte(Char))
		end
	end,
	[tdsType.Boolean]=function(Stream,Value)
		Number_To_Byte(
			type(Value)=='boolean' and (Value and 1 or 0) or Value
			,1,Stream)
	end,
	[tdsType.TimeStamp]=Write_Timestamp,
}

local Index_Length_Of_Remaining_Segment
local Index_Length_Of_Meta
local Index_Toc
local function Set_Lead_In(TDMS)
	local Lead_In={
		0x54,0x44,0x53,0x6D,
	}
	Index_Toc=#Lead_In+1
	Table_Append(Lead_In,
		0x00,0x00,0x00,0x00,
		0x69,0x12,0x00,0x00--Version number
	)
	Index_Length_Of_Remaining_Segment=#Lead_In+1
	Table_Append(Lead_In,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
	--	Next segment offset
	Index_Length_Of_Meta=#Lead_In+1
	Table_Append(Lead_In,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
	--Raw data offset
	TDMS.Lead_In=Lead_In
	return TDMS
end

local function Detect_TDMS_Type(Value,Data_Type)
	local Lua_Type=type(Value)
	local TDMS_Type=
		Lua_Type=='string' and tdsType.String
		or (Lua_Type=='number'
			and (math.type(Value)=='integer' and tdsType.I32
			or (math.type(Value)=='float' and tdsType.DoubleFloat))
		)
		or Lua_Type=='table' and tdsType.TimeStamp
		or Lua_Type=='boolean' and (
			Use_tdsType_U8_Instead_Of_Boolean_In_Raw_Data and
				(
					Data_Type=='property value' and tdsType.Boolean
					or (assert(Data_Type=='raw data') and  tdsType.U8)
				)
				or tdsType.Boolean
			)
	return TDMS_Type
end

local Set_Meta_Data do
	local function Generate_Group_Channel_List(Data)
		local Group_List={}
		for Key,Value in pairs(Data) do
			if type(Value)=='table' and Value[0]~=tdsType.TimeStamp then
				table.insert(Group_List,Key)
			end
		end
		table.sort(Group_List)
		return Group_List
	end

	local No_Raw_Data=0xFFFFFFFF
	local Same_Raw_Data_As_Previous_Segment=0x00000000
	local function Write_Raw_Data_Index(Stream,Object,Channel_Retained)
		if Object==false--[[Group]] then
			Number_To_Byte(No_Raw_Data,4,Stream)
			return
		end
		local Channel=Object
		local Length_Of_Index_Information=4+4+4+8
		Number_To_Byte(Length_Of_Index_Information,4,Stream)
		
		local Is_Raw_Data_Index_Changed
		
		local Raw_Data_Index_Retained=Channel_Retained[Channel_Retained]
		
		local Data_Type=Channel[0] or Detect_TDMS_Type(Channel[1],'raw data')
		if Raw_Data_Index_Retained.Data_Type~=Data_Type and assert(not Raw_Data_Index_Retained.Data_Type,"Data type can not change after creation!") then
			Is_Raw_Data_Index_Changed=true
			Raw_Data_Index_Retained.Data_Type=Data_Type
		end
		Number_To_Byte(Data_Type,4,Stream)
		
		local Array_Dimension=1
		Number_To_Byte(Array_Dimension,4,Stream)
		
		local Number_of_Values=#Channel--udint
		if Raw_Data_Index_Retained.Number_of_Values~=Number_of_Values then
			Is_Raw_Data_Index_Changed=true
			Raw_Data_Index_Retained.Number_of_Values=Number_of_Values
		end
		Number_To_Byte(Number_of_Values,8,Stream)
		local Total_Size=nil--bytes
		----
		return Is_Raw_Data_Index_Changed
	end

	local Write_Porperties do
		local function Write_Porperty(Stream,Property_Name,Property_Value)
			Write_String(Stream,Property_Name)
			--write data type of the property value
			local Property_Type=Detect_TDMS_Type(Property_Value,'property value')
			--write value of the property
			Number_To_Byte(Property_Type,4,Stream)
			if Property_Type==tdsType.String then
				Write_String(Stream,Property_Value)
			else
				tdsType_2_Data_Package_Method[Property_Type](Stream,Property_Value)
			end
		end
		function Write_Porperties(Stream,Object,Object_Retained)
			local new_write_count_of_properties=0--Number of properties
			local Position_At_Number_Of_Properties=#Stream+1
			Table_Append(Stream,false,false,false,false)
			local Properties_List={}
			for Key,Value in pairs(Object) do
				if (type(Value)~='table' or (Value[0]==tdsType.TimeStamp and type(Value[1])=='number')) and type(Key)~='number' and Object_Retained[Key]~=Value then
					Object_Retained[Key]=Value
					new_write_count_of_properties=new_write_count_of_properties+1
					local Property_Name=Key
					table.insert(Properties_List,Key)
				end
			end
			table.sort(Properties_List)
			for Index,Property_Name in ipairs(Properties_List) do
				local Property_Value=Object[Property_Name]
				Write_Porperty(Stream,Property_Name,Property_Value)
			end
			Number_To_Byte(new_write_count_of_properties,4,Stream,-Position_At_Number_Of_Properties)
			return new_write_count_of_properties>0
		end
	end

	local function Remove_From_Position(Stream,Position)
		for Index=#Stream,Position,-1 do
			table.remove(Stream,Index)
		end
	end

	function Set_Meta_Data(TDMS,Data)
		TDMS.Channel_List={}
		local Meta_Data={
			--Number of new objects in this segment
			--Length of the first object path
			--Raw data index
			--Number of properties
		}
		local Data_Retained=TDMS.Data_Retained
		
		local Position_At_Number_Of_Objects=#Meta_Data+1
		Table_Append(Meta_Data,0x00,0x00,0x00,0x00)
		
		local new_write_object_count=0
		
		do--file object property
			local Position_At_File_Property=#Meta_Data+1
			Write_Object_Length_Path(Meta_Data)
			Write_Raw_Data_Index(Meta_Data,false)
			local Is_New_Write_Properties=Write_Porperties(Meta_Data,Data,Data_Retained)
			if Is_New_Write_Properties then
				new_write_object_count=new_write_object_count+1
			else
				Remove_From_Position(Meta_Data,Position_At_File_Property)
			end
		end
		
		local Group_List=Generate_Group_Channel_List(Data)
		for Index,Group_Name in ipairs(Group_List) do
			local Group=Data[Group_Name]
			local Group_Retained
			do--group object property
				Group_Retained=Data_Retained[Group_Name] or {}
				local Position_At_Current_Group=#Meta_Data+1
				Write_Object_Length_Path(Meta_Data,Group_Name)
				Write_Raw_Data_Index(Meta_Data,false)
				local Is_New_Write_Properties=Write_Porperties(Meta_Data,Group,Group_Retained)
				if Is_New_Write_Properties or not Data_Retained[Group_Name] then
					new_write_object_count=new_write_object_count+1
					Data_Retained[Group_Name]=Group_Retained
				else
					Remove_From_Position(Meta_Data,Position_At_Current_Group)
				end
			end
			local Group_Channel_List=Generate_Group_Channel_List(Group)
			for Index,Channel_Name in ipairs(Group_Channel_List) do
				local Channel=Group[Channel_Name]
				local Channel_Retained=Group_Retained[Channel_Name]
				if not Channel_Retained then
					Channel_Retained={
						Data_Type=false,
						Number_of_Values=false,
					}
					local Raw_Data_Index_Retained={}
					Channel_Retained[Channel_Retained]=Raw_Data_Index_Retained
				end
				--
				table.insert(TDMS.Channel_List,Channel)
				do--channel object property, raw data index
					local Position_At_Current_Channel=#Meta_Data+1
					Write_Object_Length_Path(Meta_Data,Group_Name,Channel_Name)
					local Position_At_Raw_Data_Index=#Meta_Data+1
					local Is_Raw_Data_Index_Changed=Write_Raw_Data_Index(Meta_Data,Channel,Channel_Retained)
					if not Is_Raw_Data_Index_Changed then
						Remove_From_Position(Meta_Data,Position_At_Raw_Data_Index)
					end
					----
					local Is_New_Write_Properties=Write_Porperties(Meta_Data,Channel,Channel_Retained)
					if Is_New_Write_Properties or not Group_Retained[Channel_Name]  then
						if not Is_Raw_Data_Index_Changed then
							Number_To_Byte(Same_Raw_Data_As_Previous_Segment,4,Meta_Data,Position_At_Raw_Data_Index)
						end
						new_write_object_count=new_write_object_count+1
						Group_Retained[Channel_Name]=Channel_Retained
					else
						Remove_From_Position(Meta_Data,Position_At_Current_Channel)
					end
				end
			end
		end
		if new_write_object_count>0 then
			Number_To_Byte(new_write_object_count,4,Meta_Data,-Position_At_Number_Of_Objects)
			TDMS.Lead_In[Index_Toc]=TDMS.Lead_In[Index_Toc]|kToc.NewObjList
		else
			Remove_From_Position(Meta_Data,Position_At_Number_Of_Objects)
			;	assert(#Meta_Data==0)
		end
		TDMS.Meta_Data=Meta_Data
		--------
		Number_To_Byte(#Meta_Data,8,TDMS.Lead_In,-Index_Length_Of_Meta)
		TDMS.Lead_In[Index_Toc]=TDMS.Lead_In[Index_Toc]
			|(#TDMS.Meta_Data>0 and kToc.MetaData or 0)
		return TDMS
	end
end

local function Set_Raw_Data(TDMS)
	local Raw_Data={}
	for Index,Channel in ipairs(TDMS.Channel_List) do
		local Data_Type=Channel[0] or Detect_TDMS_Type(Channel[1],'raw data')
		local Append_Data=tdsType_2_Data_Package_Method[Data_Type]
		for Index,Data in ipairs(Channel) do
			Append_Data(Raw_Data,Data)
		end
	end
	TDMS.Raw_Data=Raw_Data
	local Length_Of_Remaining_Segment=#TDMS.Meta_Data+#TDMS.Raw_Data
	Number_To_Byte(Length_Of_Remaining_Segment,8,TDMS.Lead_In,-Index_Length_Of_Remaining_Segment)
	TDMS.Lead_In[Index_Toc]=TDMS.Lead_In[Index_Toc]
		|(#TDMS.Raw_Data and kToc.RawData or 0)
	return TDMS
end

local function Write_File(TDMS,File_Handle)
	--overwrite or append
	if #TDMS.Meta_Data==0 and assert(TDMS.Lead_In_File_Offset) then
		assert(TDMS.Lead_In[Index_Toc]&kToc.MetaData==0 and TDMS.Lead_In[Index_Toc]&kToc.NewObjList==0)
		local Length_Of_Remaining_Segment=assert(TDMS.Length_Of_Remaining_Segment)+#TDMS.Raw_Data
		TDMS.Length_Of_Remaining_Segment=Length_Of_Remaining_Segment
		File_Handle:seek('set',TDMS.Lead_In_File_Offset+Index_Length_Of_Remaining_Segment-1)
		local Length_Of_Remaining_Segment_Data_List={}
		Number_To_Byte(Length_Of_Remaining_Segment,8,Length_Of_Remaining_Segment_Data_List)
		File_Handle:write(Bytes_To_String(Length_Of_Remaining_Segment_Data_List))
		File_Handle:seek('end')
	else
		TDMS.Length_Of_Remaining_Segment=#TDMS.Meta_Data+#TDMS.Raw_Data
		TDMS.Lead_In_File_Offset=File_Handle:seek()
		File_Handle:write(Bytes_To_String(TDMS.Lead_In))
		File_Handle:write(Bytes_To_String(TDMS.Meta_Data))
	end
	File_Handle:write(Bytes_To_String((TDMS.Raw_Data)))
	File_Handle:flush()
	return TDMS
end

local function Write_Data(TDMS,Data)
	TDMS:Set_Lead_In():Set_Meta_Data(Data):Set_Raw_Data()
	if TDMS.File_Handle then
		TDMS:Write_File(TDMS.File_Handle)
	end
	return TDMS
end

local function Auto_Write_File(TDMS,File_Handle)
	TDMS.File_Handle=File_Handle
	return TDMS
end

----------------

local New do
	local Metatable={__index={
			Set_Lead_In=Set_Lead_In,
			Set_Meta_Data=Set_Meta_Data,
			Set_Raw_Data=Set_Raw_Data,
			Write_File=Write_File,
			Auto_Write_File=Auto_Write_File,
			Write_Data=Write_Data,
		}
	}
	function New()
		local TDMS=setmetatable({
				File_Handle=nil,
				Lead_In_File_Offset=nil,
				Length_Of_Remaining_Segment=nil,
				Data_Retained={
				}
			},Metatable
		)
		return TDMS
	end
end

local Lua_TDMS={
	New=New,
	--	see `Metatable`
	tdsType=tdsType,
}

return Lua_TDMS