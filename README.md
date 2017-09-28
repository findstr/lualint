# lualint
a simple lua lint tool

## Custom
        
        'ENTRY' is the entire project entry file
        'LUAC' is the lua compile path
        'print_err' used to custom error message print behavior
        'print_warn' used to custom warn message print behavior
        'print_info' used to custom info message print behavior

## Usage:

        1. set lualint.lua(just this file) as the host startup file
        2. set proper value of 'package.path and  package.cpath'
                if host has already set it, ignore this
        3. set 'ENTRY' 'LUAC' as proper value

## Note:

        luac version must match the luaVM
        This is a simple lualint tool, but it not only a lint tool,
        it also do dynamic check if require module has the field
        which accessed by current lua file, check behaviours as follow:
                1. GETTABLE
                2. GETTABUP     
                3. SETTABUP

## Run Example:

        By default, ENTRY="testa.lua", LUAC="./luac" print_err/print_warn/print_info is print
        So before run it, you should copy 'lua' and 'luac' to this directory, then run
        "./lua lualint.lua", it will dump the message
        
--------------

Chinese Blog: http://blog.gotocoding.com/archives/598
