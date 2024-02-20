-- GDB output handling goes here
-- It should delegate appropriate actions
-- given the output from GDB

local logger = require("bonkers-GDB.logger")
local json = require("bonkers-GDB.json")
local GDB = {}

function GDB.sanitize_input(input)
    local result = input:gsub("([%w+%-]*)=", function(match)
        return "\"" .. match .. "\":"
    end)

    result = result:gsub("=", ":")

    logger.debug("Sanitized input: " .. result)
    return result
end

function GDB.create_table(input)
    local sanitized_input = GDB.sanitize_input(input)
    local tbl = json.decode(sanitized_input)
    if tbl == nil then
        logger.error("Failed to decode JSON")
        return nil
    end
    logger.debug("Decoded JSON: " .. json.encode(tbl))
    return tbl
end


function GDB.handle_gdb_output(input, context)
    if (input:len() == 0) then
        return
    end

    local symbol = input:sub(0,1)
    local handler = GDB.type[symbol]
    if (handler) then
        local data = input:sub(2, -1)
        handler(data, context)
    end
end

-- GDB output types
-- #############################################

function GDB.handle_gdb_caret(input, context)
    local separator = input:find(',')
    local response = input:sub(0, separator-1)

    logger.info("GDB response: " .. response)
    local handler = GDB.response[response]
    if (handler) then
        local data = input:sub(separator+1, -1)
        handler(data, context)
    end
end

-- GDB caret response handlers
-- #############################################

function GDB.handle_gdb_done(input, context)
    local separator = input:find('=')
    local data_type = input:sub(0, separator-1)
    logger.info("GDB done: " .. data_type)
    local handler = GDB.done[data_type]
    if (handler) then
        local data = input:sub(separator+1, -1)
        handler(data, context)
    end
end


function GDB.handle_gdb_breakpoint(input, context)
    local tbl = GDB.create_table(input)
    if (tbl == nil) then
        return
    end

    for i, variable in ipairs(tbl) do
        for k, v in pairs(variable) do
            logger.debug(k .. ": " .. v)
        end
    end
end

function GDB.handle_gdb_variables(input, context)
    local tbl = GDB.create_table(input)
    if (tbl == nil) then
        return
    end

    for i, variable in ipairs(tbl) do
        local var_name = variable["name"]
        local var_type = variable["type"]
        context.add_variable(var_name, var_type)
        for k, v in pairs(variable) do
            logger.debug(k .. ": " .. v)
        end
    end
    context.update_variables()
end

function GDB.handle_gdb_name(input, context)
    input = "{" .. input .. "}"
    local tbl = GDB.create_table(input)
    if (tbl == nil) then
        return
    end

    logger.debug("Name: " .. input)
    for i, variable in ipairs(tbl) do
        for k, v in pairs(variable) do
            logger.debug(k .. ": " .. v)
        end
    end
end

function GDB.handle_gdb_children(input, context)
    input = input:sub(input:find(",")+1, -1)
    input = input:sub(input:find("=")+1, -1)
    input = input:sub(1, input:find("],"))
    input = input:gsub("([^%a]+)(child=)", function(symbol, match)
        return symbol
    end)

    local tbl = GDB.create_table(input)
    if (tbl == nil) then
        logger.error("Failed to create children table")
        return
    end

    for i, variable in ipairs(tbl) do
        if (variable["type"]) then
            local var_path = variable["name"]
            local var_name = variable["exp"]
            local var_type = variable["type"]
            context.add_variable(var_path, var_type)
        end
    end
end

GDB.response = {
    ["done"] = GDB.handle_gdb_done,
    ["running"] = nil,
    ["connected"] = nil,
    ["error"] = nil,
    ["exit"] = nil
}

GDB.type = {
    ["^"] = GDB.handle_gdb_caret,
    ["*"] = GDB.handle_gdb_star,
    ["+"] = GDB.handle_gdb_plus,
    ["="] = GDB.handle_gdb_equal,
    ["~"] = GDB.handle_gdb_tilde,
    ["@"] = GDB.handle_gdb_at,
    ["&"] = GDB.handle_gdb_ampersand,
}

GDB.done = {
    ["bkpt"] = GDB.handle_gdb_breakpoint,
    ["variables"] = GDB.handle_gdb_variables,
    ["name"] = GDB.handle_gdb_name,
    ["numchild"] = GDB.handle_gdb_children
}

return GDB
