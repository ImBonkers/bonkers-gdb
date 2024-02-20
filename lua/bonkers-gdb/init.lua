local logger = require("bonkers-gdb.logger")
local gdb_output = require("bonkers-gdb.gdb")
local GDB = {}

local function split (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

GDB.interface = {
    original = {
        buf = -1,
        win = -1,
    },
    source_code = {
        buf = -1,
        win = -1,
    },
    stack = {
        buf = -1,
        win = -1,
    },
    locals  = {
        buf = -1,
        win = -1,
    },
    console = {
        buf = -1,
        win = -1,
    },
    commands = {
        buf = -1,
        win = -1,
    },
}

GDB.variables = {}
GDB.variable_objects = {}

function GDB.create_window()

    if (vim.api.nvim_win_is_valid(GDB.interface.source_code.win)) then
        vim.api.nvim_set_current_win(GDB.interface.source_code.win)
    end

    if (vim.api.nvim_win_is_valid(GDB.interface.console.win)) then
        vim.api.nvim_win_close(GDB.interface.console.win, true)
        vim.api.nvim_buf_delete(GDB.interface.console.buf, {force = true})
    end

    if (vim.api.nvim_win_is_valid(GDB.interface.locals.win)) then
        vim.api.nvim_win_close(GDB.interface.locals.win, true)
        vim.api.nvim_buf_delete(GDB.interface.locals.buf, {force = true})
    end

    local original = vim.api.nvim_get_current_win()
    local original_buf = vim.api.nvim_get_current_buf()
    -- NOTE: Should check if window contains valid debuggable program
    GDB.interface.source_code.win = original;
    GDB.interface.source_code.buf = original_buf;
    GDB.interface.original.win = original;
    GDB.interface.original.buf = original_buf;


    vim.cmd("botright split")
    local bottom_panel = vim.api.nvim_get_current_win()
    local bottom_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bottom_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(bottom_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(bottom_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(bottom_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(bottom_buf, "filetype", "gdb_console")
    vim.api.nvim_buf_set_name(bottom_buf, "GDB Console")

    GDB.interface.console.win = bottom_panel
    GDB.interface.console.buf = bottom_buf
    vim.api.nvim_win_set_height(bottom_panel, 20)
    vim.api.nvim_win_set_buf(bottom_panel, bottom_buf)


    vim.api.nvim_set_current_win(original)


    vim.cmd("topleft vsplit")
    local left_panel = vim.api.nvim_get_current_win()
    local left_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(left_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(left_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(left_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(left_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(left_buf, "filetype", "gdb_locals")
    vim.api.nvim_buf_set_name(left_buf, "GDB Locals")


    GDB.interface.locals.win = left_panel
    GDB.interface.locals.buf = left_buf
    vim.api.nvim_win_set_width(left_panel, 40)
    vim.api.nvim_win_set_buf(left_panel, left_buf)


    vim.api.nvim_set_current_win(original)
end

local function table_from_gdb(data)
    local data_str = data:sub(2, -2)

    local elements = {}
    for elem in data_str:gmatch("'([^']*)'") do
        table.insert(elements, elem)
    end

    return elements
end

function GDB.setup()
    vim.cmd [[
        highlight BreakpointHL guifg=#ff0000 guibg=NONE ctermfg=red ctermbg=NONE
    ]]

    GDB.gdb_job = vim.fn.jobstart(
        "gdb -interpreter=mi",
        {
            on_stdout = function(_, data)
                local inspect_data = vim.inspect(data)
                local tbl =  table_from_gdb(inspect_data)
                for _, v in ipairs(tbl) do
                    logger.debug(v)
                    gdb_output.handle_gdb_output(v, GDB)
                end
            end,
            on_stderr = function(_, data)
                logger.error(data)
            end,
            on_exit = function(_, code)
                logger.debug("Job exited with code: " .. code)
            end,
        }
    )

    if (GDB.gdb_job == 0) then
        logger.debug("Failed to start gdb")
    end

    vim.fn.chansend(GDB.gdb_job, "file N:/Documents/Work/C++/ParserToolchain/lexer/bin/easylexer.exe".."\n")
end

function GDB.add_variable(name, value)
    GDB.variables[name] = value
    if (GDB.variable_objects[name] == nil) then
        GDB.variable_objects[name] = true
        GDB.run_command_async("-var-create " .. name .. " @ " .. name)
    end
end

function GDB.update_variables()
    local buf = GDB.interface.locals.buf
    if (buf == -1) then
        return
    end

    local lines = {}
    for k, v in pairs(GDB.variables) do
        table.insert(lines, k)
    end
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function GDB.run_command()
    GDB.run_command_async("-break-insert 106")
    GDB.run_command_async("-exec-run")
    GDB.run_command_async("-stack-list-variables --simple-values")
end

function GDB.run_command_async(cmd)
    logger.info("Running command: " .. cmd)
    if (GDB.gdb_job == 0) then
        logger.error("GDB job not running")
        return
    end

    if (GDB.interface.console.buf ~= -1) then
        local buf = GDB.interface.console.buf
        local line_count = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, line_count, -1, false, {cmd})
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end

    vim.fn.chansend(GDB.gdb_job, cmd.."\n")
end

function GDB.insert_breakpoint(line)
    local buf = vim.api.nvim_get_current_buf()
    local sign_name = "Breakpoint"

    logger.debug("Inserting breakpoint at line " .. line)
    vim.fn.sign_define(sign_name, {text = "⬤", texthl = "BreakpointHL"})
    vim.fn.sign_place(0, "BreakpointGroup", sign_name, buf, {lnum = line, priority = 100})

end

return GDB
