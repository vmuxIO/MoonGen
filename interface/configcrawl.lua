local lfs = require "lfs"
local log = require "log"

local errors = require "errors"

local crawl = {}
local errhnd = errors()

local _current_file
local flows = {}
local _env_flows = setmetatable({}, {
	__newindex = function(_, key, val)
		if flows[key] then
			errhnd(3, "Duplicate flow %q. Also in file %s.", key, flows[key].file)
		end

		val.file = _current_file
		flows[key] = val
	end,
	__index = flows
})

local _env = require "configenv" ({}, errhnd, _env_flows)
local function _parse_file(filename)
	local f, msg = loadfile(filename)
	if not f then
		errhnd(0, msg)
		return
	end

	_current_file = filename
	setfenv(f, _env)()
end

local uids = {}
function crawl.getFlow(name, options, presets)
	local f = flows[name]:getInstance(options, presets)

	if not f then return end

	if not f.results.uid then
		f.results.uid = #uids + 1
	elseif uids[f.results.uid] then
		log:error("Uid %d is not unique to flow %d.", f.results.uid, name)
		return nil
	end
	uids[f.results.uid] = f

	return f
end

function crawl.cloneFlow(flow, changes)
	local f = {}

	for i,v in pairs(flow) do
		f[i] = v
	end

	for i,v in pairs(changes) do
		f[i] = v
	end

	return setmetatable(f, getmetatable(flow))
end

function crawl.passFlow(flow)
	local f = {}

	for i,v in pairs(flow) do
		f[i] = v
	end

	f.file, f.name, f.prepared = flow.file, flow.name, false
	return f
end

function crawl.receiveFlow(fdef)
	if not flows[fdef.name] then
		_parse_file(fdef.file)
	end

	local f = setmetatable(fdef, { __index = flows[fdef.name] })
	f:prepare()
	return f
end

return setmetatable(crawl, {
	__call = function(_, baseDir, suppressWarnings)
		baseDir = baseDir or "flows"
		for f in lfs.dir(baseDir) do
			f = baseDir .. "/" .. f
			if lfs.attributes(f, "mode") == "file" then
				_parse_file(f)
			end
		end

		local cnt = errhnd:count()
		if cnt > 0 and not suppressWarnings then
			log:error("%d errors found while crawling config:", cnt)
			errhnd:print(true, log.warn, log)
		end

		return flows
	end
})
