local ENTRY = "testa.lua"
local LUAC = "./luac"

local print_err = print
local print_warn = print
local print_info = print


--[[
        'ENTRY' is the entire project entry file
        'LUAC' is the lua compile path
        'print_err/print_warn/print_info' used to custom print behavior

        USAGE: 
                1. set lualint.lua(just this file) as the host startup file
                2. set proper value of 'package.path and  package.cpath'
                        if host has already set it, ignore this
                3. set 'ENTRY' 'LUAC' as proper value
        
        NOTE:
                luac version must match the luaVM
                This is a simple lualint tool, but it not only a lint tool,
                it also do dynamic check if require module has the field
                which accessed by current lua file, check behaviours as follow:
                        1. GETTABLE
                        2. GETTABUP     
                        3. SETTABUP
]]--

local compiler_version = assert(io.popen(LUAC .. " -v")):read("l")
assert(compiler_version:find(_VERSION, 1, false), "Compiler Version does not match luaVM Version")

local LUA_PATH = {}
local LUA_CPATH = {}
local ENV = {}
local ONCE = {}

for n in string.gmatch(package.path, "([^;]+);") do
        LUA_PATH[#LUA_PATH + 1] = n
end
for n in string.gmatch(package.cpath, "([^;]+);") do
        LUA_CPATH[#LUA_CPATH + 1] = t
end

setmetatable(ENV, {
        __index = _ENV
})

--disable errmsg
ENV._G.print = function(...) end

local function checkmodule(module)
        local n, err1 = package.searchpath(module, package.path)
        if n then
                return "lua", n
        end
        local soname = string.match(module, "([^\\.]+)")
        local n, err2 = package.searchpath(soname, package.cpath)
        if n then
                return "so", n
        end
        return "no", err1 .. err2
end

local function compile(file, module)
        local t = ENV.package.loaded[module]
        if t then
                return t
        end
        local tbl, err = assert(loadfile(file, "t", ENV))()
        if not tbl then
                print_err("[ERROR] compile ", file, " error", err)
                os.exit(1)
        end
        ENV.package.loaded[module] = tbl
        return tbl
end

local function parse(filename)
        local list = {}
        local pipe = assert(io.popen(LUAC .. " -l -p " .. filename))
        for line in pipe:lines() do
                list[#list + 1] = line
        end
        return list
end
local quotes = "\""
quotes = quotes:byte(1)

local function split(line)
        local ir, ln, CODE, A, B, C, comment = 
                string.match(line,
                        "%s+(%d+)%s+([^%s]+)%s+(%a+)%s+([-%d]+)%s+([-%d]+)%s*([-%d]*)%s*;?%s*(.*)")
        if not ir then
                return nil
        end
        comment = comment:gsub("\"", "")
        return {
                ir = ir,
                ln = ln,
                CODE = CODE,
                A = A,
                B = B,
                C = C,
                comment = comment
        }
end

local ignore = {
        "_PATH", "_G", "_LOADED", "_TRACEBACK", "_VERSION", "__pow", "arg",
        "assert", "collectgarbage", "coroutine", "debug", "dofile", "error",
        "gcinfo", "getfenv", "getmetatable", "io", "ipairs", "loadfile",
        "loadlib", "loadstring", "math", "newproxy", "next", "os", "pairs",
        "pcall", "print", "rawequal", "rawget", "rawset", "require",
        "setfenv", "setmetatable", "string", "table", "tonumber", "tostring",
        "type", "unpack", "xpcall",
}

local ignore_map = {}

for _, v in pairs(ignore) do
        ignore_map[v] = true
end

local function lintone(filename)
        local module = {}
        local module_reg = {}
        local mode = ""
        local lines = parse(filename)
        print_info("[INFO] lint", filename)
        for i = 1, #lines do
                local l = lines[i]
                if l:find("^main") then
                        mode = "main"
                elseif l:find("^function") then
                        mode = "function"
                end
                local info = split(l)
                if info then
                        if mode == "main" and info.CODE == "GETTABLE" then
                                local reg = module_reg[info.B]
                                local tbl = module[info.B]
                                if reg and not tbl[info.comment] then
                                        print_err(string.format("[ERROR] file '%s:%s' Module '%s' has no field '%s'",
                                                filename, info.ln, reg, info.comment))
                                end
                        elseif info.CODE == "GETTABUP" then
                                local tbl, field = string.match(info.comment, "%s*([^%s]+)%s+([^%s]+)")
                                if tbl == "_ENV" then
                                        if field == "require" then
                                                --LOADK
                                                i = i + 1
                                                l = lines[i]
                                                info = split(l)
                                                assert(info.CODE == "LOADK")
                                                local name = info.comment
                                                assert(name ~= "")
                                                --CALL
                                                i = i + 1
                                                l = lines[i]
                                                info = split(l)
                                                assert(info.CODE == "CALL")
                                                local mode, path = checkmodule(name)
                                                if mode == "lua" then
                                                        local exist
                                                        module_reg[name] = info.A
                                                        module_reg[info.A] = name
                                                        module[info.A] = compile(path, name)
                                                        if not ONCE[name] then 
                                                                lintone(path)
                                                                ONCE[name] = true
                                                        end
                                                elseif mode == "so" then
                                                        print_info(string.format("[INFO] file '%s:%s' require module:%s share object skip aynalzer",
                                                                filename, info.ln, name, path))
                                                elseif mode == "no" then
                                                        print_err(string.format("[ERROR] file '%s:%s' require module '%s' nonexist %s",
                                                                filename, info.ln, name, path))
                                                end
                                        elseif not ignore_map[field] then
                                                        print_warn(string.format("[WARNNING] file '%s:%s' Global Get Variable '%s'",
                                                                                                filename, info.ln, field))

                                        end
                                else
                                        local reg = module_reg[tbl]
                                        if reg then
                                                local obj = assert(module[reg])
                                                if not obj[field] then
                                                        print_err(string.format("[WARNNING] file '%s:%s' Module '%s' has no field '%s'",
                                                                filename, info.ln, tbl, field))
                                                end
                                        end
                                end
                        elseif info.CODE == "SETTABUP" then
                                local tbl, field = string.match(info.comment, "%s*([^%s]+)%s+([^%s]+)")
                                if tbl == "_ENV" then
                                        print_warn(string.format("[WARNNING] file '%s:%s' Global Set Variable '%s'",
                                                filename, info.ln, field))
                                end
                        end
                end
                i = i + 1
        end
end

lintone(ENTRY)
--compile("src/server.lua")
--require "main"



