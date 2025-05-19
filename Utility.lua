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
	--local function Number_To_Byte(Number,Byte_Lenght,Stream)
	--	--	Signed_Number_To_Byte
	--	for Char in string.gmatch(string.pack('<i'..Byte_Lenght,Number),'.') do
	--		table.insert(Stream,string.byte(Char))
	--	end
	--end
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
		table.insert(Stream,string.byte(Char))
	end
end

return {
	Number_To_Byte=Number_To_Byte,
	Table_Append=Table_Append,
	Bytes_To_String=Bytes_To_String,
	Write_String=Write_String,
}