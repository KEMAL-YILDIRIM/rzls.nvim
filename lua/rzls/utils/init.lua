local M = {}

---@generic T
---@param val T
---@param message string?
---@return T
function M.debug(val, message)
    if true then
        local prefix = message and message .. ": " or ""
        vim.notify(prefix .. vim.inspect(val))
    end
    return val
end

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)) or os.time())
function M.uuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%x", v)
    end)
end

return M
