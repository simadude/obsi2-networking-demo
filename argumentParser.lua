
---@param args string[]
---@return table<string, any>
local function parser(args)
    ---@type table<string, type>
    local reqType = {
        ["--name"] = "string",
        ["--protocol"] = "string",
        ["--hostname"] = "string",
        ["--host"] = "nil",
        ["--port"] = "number"
    }

    local tab = {}

    local nextIsParameter = false
    local currentArg = ""
    for _, arg in ipairs(args) do
        if not nextIsParameter then
            currentArg = arg
            if reqType[currentArg] and reqType[currentArg] ~= "nil" then
                nextIsParameter = true
            elseif reqType[currentArg] and reqType[currentArg] == "nil" then
                tab[currentArg] = true
            elseif not reqType[currentArg] then
                error(("Unknown argument %s"):format(currentArg))
            end
        else
            if reqType[currentArg] == "string" then
                tab[currentArg] = arg
                nextIsParameter = false
            elseif reqType[currentArg] == "number" then
                local n = tonumber(arg)
                if not n then
                    error(("Can't parse the number %s for the argument %s"):format(arg, currentArg))
                end
                tab[currentArg] = n
                nextIsParameter = false
            end
        end
    end
    if nextIsParameter then
        error(("No paramater provided after %s"):format(currentArg))
    end

    return tab
end

return parser