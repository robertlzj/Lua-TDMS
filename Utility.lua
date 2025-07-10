local Is_Test=not ...

local Number_To_Byte do
	function Number_To_Byte(Number,Byte_Length,Stream,Input)
		--	Unsigned_Number_To_Byte
		local Index,Is_Insert_Or_Overwrite if Input then
			Index=math.abs(Input)
			if Input<0 then
				Is_Insert_Or_Overwrite='overwirte'
			else
				Is_Insert_Or_Overwrite='insert'
			end
		else
			Index=#Stream+1
			Is_Insert_Or_Overwrite='insert'
		end
		assert(Number<=(0x100^Byte_Length-1))
		for Byte_Position=1,Byte_Length do
			local Byte_Offset=Byte_Position-1
			local Bit_Offset=Byte_Offset*8
			local Byte=(Number>>Bit_Offset)&0xFF
			if Is_Insert_Or_Overwrite=='insert' then
				table.insert(Stream,Index+Byte_Offset,Byte)
			else
				Stream[Index+Byte_Offset]=Byte
			end
		end
	end
	if Is_Test then
		local IsEqual=require'Table'.IsEqual
		local Container={}
		Number_To_Byte(255,4,Container)
		assert(IsEqual(Container,{0xff,0,0,0}))
		Container={}
		Number_To_Byte(0xffFFffFF,4,Container,1)
		assert(IsEqual(Container,{0xff,0xff,0xff,0xff}))
		--
		Container={}
		Number_To_Byte(-125,1,Container)
		assert(IsEqual(Container,{0x83}))
		--
		Container={}
		Number_To_Byte(-125,4,Container)
		assert(IsEqual(Container,{0x83,0xff,0xff,0xff}))
		print"'Unsigned_Number_To_Byte' test OK"
	end
end

local function Table_Append(Table,...)
	for index,item in ipairs{...} do
		table.insert(Table,item)
	end
end

local function Bytes_To_String(Bytes)
	local Length=#Bytes
	return string.pack(string.rep('B',Length),table.unpack(Bytes))
end

local function Write_String(Stream,String)
	local String_Length=#String
	Number_To_Byte(String_Length,4,Stream)
	for Char in string.gmatch(String,'(.)') do
		--print(string.format('%x',string.byte(Byte)))
		table.insert(Stream,string.byte(Char))
	end
end

local Write_Timestamp do--Write_Timestamp
	local Tick_Millisecond=2^64/1000
	local Part_Byte_Count=4
	local Little_Endian='<'
	local Format_Byte=Little_Endian..'I'..Part_Byte_Count
	--	I: unsigned int
	local Split=2^(8*Part_Byte_Count)
	local TDMS_Epoch_Start_Second=-2082873600+86400
	assert(
		os.time({year=1970,month=1,day=1,hour=8})==0
		and
		os.time{
			year=1904,month=1,day=1,
			hour=0,min=0,sec=0,
		}==nil
	)
	function Write_Timestamp(Stream,Date_Millisecond)
		local Second,Millisecond=table.unpack(Date_Millisecond)
		local TDMS_Epoch_Second=Second-TDMS_Epoch_Start_Second
		for Byte in string.gmatch(string.pack(Little_Endian..'i8',TDMS_Epoch_Second),'(.)') do
			table.insert(Stream,string.byte(Byte))
		end
		if false--[[alternative]]then
			Number_To_Byte(TDMS_Epoch_Second,8,Stream)
		end
		----
		Millisecond=Millisecond or 0
		assert(0<=Millisecond and Millisecond<1000)
		local Tick_Count=Millisecond*Tick_Millisecond
		local Low_Part=Tick_Count%Split
		local Low_Part_String=string.pack(Format_Byte,Low_Part)
		for Byte in string.gmatch(Low_Part_String,'(.)') do
			table.insert(Stream,string.byte(Byte))
		end
		if false--[[alternative]]then
			Number_To_Byte(Low_Part,4,Stream)
		end
		local High_Part=Tick_Count//Split
		local High_Part_String=string.pack(Format_Byte,High_Part)
		for Byte in string.gmatch(High_Part_String,'(.)') do
			table.insert(Stream,string.byte(Byte))
		end
		if false--[[alternative]]then
			Number_To_Byte(High_Part,4,Stream)
		end
	end
	if Is_Test then
		--from [LabVIEW Timestamp Overview - NI](https://www.ni.com/en/support/documentation/supplemental/08/labview-timestamp-overview.html)
		do
			local Stream={}
			Write_Timestamp(Stream,{TDMS_Epoch_Start_Second})
			local Result={
				0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0
			}
			for Index,Char in ipairs(Stream) do
				assert(Result[Index]==Char)
				io.write(string.format('%02x ',Char))
			end
			print''
		end
		----
		do
			local Stream={}
			Write_Timestamp(Stream,{TDMS_Epoch_Start_Second-1,500})
			local Result={
				0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
				0,0,0,0,0,0,0,0x80
			}
			for Index,Char in ipairs(Stream) do
				assert(Result[Index]==Char)
				io.write(string.format('%02x ',Char))
			end
			print''
		end
		----
		do
			local Stream={}
			Write_Timestamp(Stream,{os.time({year=2002,month=1,day=1,hour=0}),800})
			local Result={0x00,0x5B,0x55,0xB8,0,0,0,0,
				false,false,0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,}
			for Index,Char in ipairs(Stream) do
				assert(not Result[Index] or Result[Index]==Char)
				io.write(string.format('%02x ',Char))
			end
			print''
		end
	end
end

return {
	Number_To_Byte=Number_To_Byte,
	Table_Append=Table_Append,
	Bytes_To_String=Bytes_To_String,
	Write_String=Write_String,
	Write_Timestamp=Write_Timestamp,
}