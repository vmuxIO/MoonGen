local units = require "configenv.flow.units"

local option = {}

option.description = "Stop sending this flow after a certain amount of data. As"
	.. " flows should only be cut short at a whole number of packets sent, every"
	.. " value passed will be rounded up to the nearest whole number of packets."
option.configHelp = "Passing a number instead of a string will interpret the value as megabit."
function option.getHelp()
	return { { "<number><sizeUnit>", "Default use case." } }
end

local function _parse_limit(lstring, psize)
	local num, unit = string.match(lstring, "^(%d+%.?%d*)(%a+)$")
	if not num then
		return nil, "Invalid format. Should be '<number><unit>'."
	end

	num, unit = tonumber(num), string.lower(unit)
	if unit == "" then
		unit = units.size.m --default is mbit
	elseif string.find(unit, "bit$") then
		unit = units.size[string.sub(unit, 1, -4)]
	elseif string.find(unit, "b$") then
		unit = units.size[string.sub(unit, 1, -2)] * 8
	elseif string.find(unit, "p$") then
		unit = units.size[string.sub(unit, 1, -2)] * psize * 8
	else
		return nil, unit.sizeError
	end

	return num, unit
end

function option.parse(self, limit, error)
	if not limit then return end

	local psize = self:getPacketLength(true)
	local t = type(limit)

	local num, unit
	if t == "number" then
		num, unit = limit, units.size.m
	elseif t == "string" then
		num, unit = _parse_limit(limit, psize)
		error:assert(num, unit)
	else
		error("Invalid argument. String or number expected, got %s.", t)
	end

	-- round up to mimic behaviour of timeLimit
	if num then
		return math.ceil(num * unit / (psize * 8))
	end
end

return option
