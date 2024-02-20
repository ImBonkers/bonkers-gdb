
if exists("g:loaded_bonkers_gdb")
    finish
endif
let g:loaded_bonkers_gdb = 1

lua plugin = require("bonkers-gdb")
lua plugin.setup()

command! BonkersGdb lua print("Hello, world!")
command! -nargs=1 BonkersInsert lua plugin.insert_breakpoint(<f-args>)
command! -nargs=1 BonkersRunCommand lua plugin.run_command_async(<f-args>)
command! BonkersTest lua plugin.run_command()
command! BonkersGdbRun lua plugin.run_command_async("-exec-run")
command! BonkersWindow lua plugin.create_window()
