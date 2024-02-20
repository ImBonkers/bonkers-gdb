local M = {}

-- Define log levels
M.levels = {
    DEBUG = "DEBUG",
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR"
}

M.enabled = {
    ["DEBUG"] = true,
    ["INFO"] = true,
    ["WARN"] = true,
    ["ERROR"] = true
}
-- Current log level
M.current_level = M.levels.DEBUG

-- Function to log a message with a given level
function M.log(level, message)
    -- Check if the current log level allows logging the message
    if M.enabled[level] then

        local info = debug.getinfo(3, "Sl")
        local source = info.short_src
        local file = string.match(source, ".*/(.*)")
        local line = info.currentline
        -- Format and print the log message
        -- You can customize the format as you like
        local formatted_message = string.format("[%s] (%s:%s) %s: %s", os.date("%Y-%m-%d %H:%M:%S"), file, line, level, message)
        print(formatted_message)

        -- Optionally, write the log to a file
        local log_file = io.open("neovim_plugin.log", "a")
        if log_file then
            log_file:write(formatted_message .. "\n")
            log_file:close()
        end
    end
end

-- Helper functions for different log levels
function M.debug(message)
    M.log(M.levels.DEBUG, message)
end

function M.info(message)
    M.log(M.levels.INFO, message)
end

function M.warn(message)
    M.log(M.levels.WARN, message)
end

function M.error(message)
    M.log(M.levels.ERROR, message)
end

return M
