--Copy the default turtle directory
local turtle = {}
for k, v in pairs( _G.turtle ) do
	turtle[ k ] = v
end

--copy default gps
local gps = {}
for k, v in pairs( _G.gps ) do
	gps[ k ] = v
end

if not fs.isDir( ".lama" ) then
	fs.makeDir( ".lama" )
end

--get the current env
--anything declared as env.name will end up in the loaded API
local env = getfenv()

local fuel = {}
local facing = {}
local position = {}
local leftEquipment = {}
local rightEquipment = {}

--Fuel tracking
fuel.load = function() --loading fuel data
	if fs.exists( ".lama/fuel" ) then --if we've got previous data, we want to use it
		local file = fs.open( ".lama/fuel", "r" )
		fuel.amount = tonumber( file.readAll() )
		file.close()
	else --otherwise, use the current fuel level
		fuel.amount = turtle.getFuelLevel()
	end
end

fuel.save = function() --save fuel data
	local file = fs.open( ".lama/fuel", "w" )
	file.write( fuel.amount )
	file.close()
end

--facing tracking
facing.turnRight = function() --changes the facing clockwise (on a compass) once
	if facing.face == "north" then
		facing.face = "east"
	elseif facing.face == "east" then
		facing.face = "south"
	elseif facing.face == "south" then
		facing.face = "west"
	elseif facing.face == "west" then
		facing.face = "north"
	end
end

facing.save = function() --saves facing and current movement direction
	local file = fs.open( ".lama/facing", "w" )
	file.write( textutils.serialize( {facing.face, facing.direction} ) )
	file.close()
end

facing.load = function() --loads facing / current movement direction
	if fs.exists( ".lama/facing" ) then --if we have previous data, we use it
		local file = fs.open( ".lama/facing", "r" )
		facing.face, facing.direction = unpack( textutils.unserialize( file.readAll() ) )
		file.close()
	else --otherwise, try to locate via gps
		local x, y, z = gps.locate(1)
		if x and turtle.forward() then
			local newx, newy, newz = gps.locate(1)
			if not newx then --we didn't get a location
				facing.face = "north" --default
			elseif newx > x then
				facing.face = "east"
			elseif newx < x then
				facing.face = "west"
			elseif newz > z then
				facing.face = "south"
			elseif newz < z then
				facing.face = "north"
			end
		else
			facing.face = "north" --we couldn't move forward, something was obstructing
		end
	end
end

equipment.save = function()
	local file = fs.open(".lama/equipment","w")
	file.write(textutils.serialize({leftEquipment, rightEquipment})
end

equipment.load = function()
	if fs.exists(".lama/equipment") then
		local file = fs.open(".lama/equipment", "r") 
		equipmentLeft,equipmentRight = unpack(textutils.unserialize(file.readAll()))
	else
		equipmentLeft,equipmentRight = {},{}
	end
end

--position tracking
position.save = function() --saves position (x, y, z)
	position.update() --update the position based on direction and fuel level, then save it to a file
	local file = fs.open( ".lama/position", "w" )
	file.write( textutils.serialize( { position.x, position.y, position.z } ) )
	file.close()
end

position.load = function() --loads position (x, y z)
	if fs.exists( ".lama/position" ) then --if we have previous data, use it
		local file = fs.open( ".lama/position", "r" )
		position.x, position.y, position.z = unpack( textutils.unserialize( file.readAll() ) )
		file.close()
	else --otherwise try for gps coords
		local x, y, z = gps.locate(1)
		if x then
			position.x, position.y, position.z = x, y, z
		else --now we assume 1,1,1
			position.x, position.y, position.z = 1, 1, 1
		end
	end
end

position.update = function() --updates the position of the turtle
	local diff = fuel.amount - turtle.getFuelLevel()
	if diff > 0 then --if we've spent fuel (ei moved), we'll need to move that number in a direction
		if facing.direction == 'east' then
			position.x = position.x + diff
		elseif facing.direction == "west" then
			position.x = position.x - diff
		elseif facing.direction == "south" then
			position.z = position.z + diff
		elseif facing.direction == "north" then
			position.z = position.z - diff
		elseif facing.direction == "up" then
			position.y = position.y + diff
		elseif facing.direction == "down" then
			position.y = position.y - diff
		end
	end
	fuel.amount = turtle.getFuelLevel() --update the fuel amount
	fuel.save() --save the fuel amount
end

--direct opposite compass values, mainly for env.back
local opposite = {
	["north"] = "south",
	["south"] = "north",
	["east"] = "west",
	["west"] = "east",
}

env.forward = function() --basically, turtle.forward
	if facing.direction ~= facing.face then --if we were going a different direction before
		position.save() --save out position
		facing.direction = facing.face --update the direction
		facing.save() --save the direction
	end
	return turtle.forward() --go forward, return result
end

env.back = function() --same as env.forward, but going backwards
	if facing.direction ~= opposite[ facing.face ] then
		position.save()
		facing.direction = opposite[ facing.face ]
		facing.save()
	end
	return turtle.back()
end

env.up = function() --turtle.up
	if facing.direction ~= "up" then --if we were going a different direction
		position.save() --save our position
		facing.direction = "up" --set the direction to up
		facing.save() --save the direction
	end
	return turtle.up() --go up, return result
end

env.down = function() --env.up, but for going down
	if facing.direction ~= "down" then
		position.save()
		facing.direction = "down"
		facing.save()
	end
	return turtle.down()
end

env.turnRight = function() --turtle.turnRight
	position.save() --save the position (x,y,z)
	facing.turnRight() --update our compass direction
	facing.save() --save it
	return turtle.turnRight() --return the result
end

env.turnLeft = function() --env.turnRight, but the other direction
	position.save()
	facing.turnRight() --going clockwise 3 times is the same as
	facing.turnRight() --going counterclockwise once
	facing.turnRight()
	facing.save()
	return turtle.turnLeft()
end

env.refuel = function( n ) --needed because we depend on fuel level
	position.update() --update our position
	if turtle.refuel( n ) then --if we refueled then
		fuel.amount = turtle.getFuelLevel() --set our amount to the current level
		fuel.save() --save that amount
		return true
	end
	return false --otherwise, return false
end

env.equipLeft = function()
	local tData = turtle.getItemDetail()
	local bOk = turtle.equipLeft()
	if bOk then
		equipmentLeft = tData
		equipment.save
	end
end

env.equipRight = function()
	local tData = turtle.getItemDetail()
	local bOk = turtle.equipRight()
	if bOk then
		equipmentRight = tData
		equipment.save
	end
end

env.overwrite = function( t ) --writes env values into the table given
	t = t or _G.turtle    --or, if no value was given, _G.turtle
	for k, v in pairs( env ) do
		t[ k ] = v
	end
end

env.getPosition = function() --returns the current position of the turtle
	position.update() --first we should update the position (otherwise it'll give coords of the last time we did this)
	return position.x, position.y, position.z, facing.face
end

env.setPosition = function( x, y, z, face ) --sets the current position of the turtle
	position.x = x
	position.y = y
	position.z = z
	facing.face = face or facing.face --default the the current facing if it's not provided
	position.save() --save our new position
	facing.save() --save the way we are facing
end

--overwrite gps.locate
_G.gps.locate = function( n, b )
	local x, y, z, facing = env.getPosition()
	return x, y, z
end

facing.load()
position.load()
fuel.load()

fuel.save()
position.save()
facing.save()
