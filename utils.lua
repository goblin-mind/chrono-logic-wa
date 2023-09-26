LogLevel = {
    TRACE = 1,
    DEBUG = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5
}

local function logMessage(level, ...)

    if level >= logger.logLevel then
        local result = table.concat(map({...}, function(it)
            return type(it) == "table" and stringifyTable(it) or tostring(it)
        end), " ")
        print(result)
        return result
    end
end

function map(t, f_or_key)
    local new_t = {}
    for _, v in pairs(t) do
        if type(f_or_key) == "function" then
            table.insert(new_t, f_or_key(v))
        else
            table.insert(new_t, v[f_or_key])
        end
    end
    return new_t
end

logger = {
    logLevel = aura_env.config['loglevel'],
    trace = function(...)
        return logMessage(LogLevel.TRACE, ...)
    end,
    debug = function(...)
        return logMessage(LogLevel.DEBUG, ...)
    end,
    info = function(...)
        return logMessage(LogLevel.INFO, ...)
    end,
    warn = function(...)
        return logMessage(LogLevel.WARN, ...)
    end,
    error = function(...)
        return logMessage(LogLevel.ERROR, ...)
    end
}

function sum(tbl)
    local total = 0
    for _, v in pairs(tbl) do
        total = total + v
    end
    return total
end

function identity(x)
    return x
end

function filter(tbl, predicate)
    local result = {}
    for _, v in pairs(tbl) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end

function reduce(tbl, fn, initial)
    local acc = initial
    for _, v in pairs(tbl) do
        acc = fn(acc, v)
    end
    return acc
end

function stringifyTable(t, indent)
    indent = indent or ""
    local result = "{\n"
    for k, v in pairs(t) do
        result = result .. indent .. "  " .. tostring(k) .. " : "
        if type(v) == "table" then
            result = result .. stringifyTable(v, indent .. "  ") .. ",\n"
        else
            result = result .. tostring(v) .. ",\n"
        end
    end
    result = result .. indent .. "}"
    return result
end

function flattenTable(tbl, parentKey, flatTbl)
    flatTbl = flatTbl or {}
    parentKey = parentKey or ""

    for k, v in pairs(tbl) do
        local newKey = parentKey == "" and k or (parentKey .. "." .. k)
        if type(v) == "table" then
            flattenTable(v, newKey, flatTbl)
        else
            flatTbl[newKey] = v
        end
    end

    return flatTbl
end

function tableToAlignedString(tbl, query)
    local function roundF(num)
        return type(num) == 'number' and string.format("%.1f", num) or tostring(num)
    end
    query = query or {}
    local colWidths = {}
    local str = ""
    local orderBy = query.orderBy or next(tbl[1] or {})
    local columns = query.columns or {}

    -- Default to all columns if none specified
    if #columns == 0 then
        for _, spell in pairs(tbl) do
            for k, _ in pairs(spell) do
                table.insert(columns, k)
                colWidths[k] = #k
            end
        end
    end
    for _, item in pairs(tbl) do
        local value = item[orderBy]
        if value == nil then
            item[orderBy] = 0 -- Default value for nil
        elseif value ~= value then -- Check for NaN or -NaN
            item[orderBy] = 0 -- Default value for NaN
        elseif tostring(value) == 'nan' then -- Check for NaN or -NaN
            item[orderBy] = 0 -- Default value for NaN
        end
    end
    local function sortTable(t, orderKey)
        local sortedTbl = {}
        for k in pairs(t) do
            table.insert(sortedTbl, k)
        end
        table.sort(sortedTbl, function(a, b)

            local aValue = t[a][orderKey]
            local bValue = t[b][orderKey]

            aValue = aValue or 0
            bValue = bValue or 0
            if aValue ~= aValue then
                aValue = 0
            end -- Check for NaN
            if bValue ~= bValue then
                bValue = 0
            end -- Check for NaN
            return aValue > bValue
        end)
        return sortedTbl
    end

    -- Initialize column widths
    if columns then
        for _, col in ipairs(columns) do
            colWidths[col] = #col
        end
    else
        for _, spell in pairs(tbl) do
            for k, _ in pairs(spell) do
                colWidths[k] = #k
            end
        end
    end

    -- Calculate maximum width
    for spellId, spell in pairs(tbl) do
        for k, v in pairs(spell) do
            if colWidths[k] then
                colWidths[k] = math.max(colWidths[k], type(v) == "number" and #roundF(v) or #tostring(v))
            end
        end
    end

    -- Create header string
    for _, col in ipairs(columns or colWidths) do
        str = str .. col .. string.rep(" ", colWidths[col] - #col) .. " | "
    end
    str = str .. "\n"

    -- Create rows
    local sortedKeys = orderBy and sortTable(tbl, orderBy) or pairs(tbl)
    for _, spellId in ipairs(sortedKeys or tbl) do
        local spell = tbl[spellId]
        for _, col in ipairs(columns or colWidths) do
            local val = type(spell[col]) == "number" and roundF(spell[col]) or tostring(spell[col] or "")
            str = str .. val .. string.rep(" ", colWidths[col] - #val) .. " | "
        end
        str = str .. "\n"
    end

    return str
end

function table_merge(t1, ...)
    local arg = {...}
    for i, tbl in ipairs(arg) do
        for k, v in pairs(tbl) do
            t1[k] = v
        end
    end
    return t1
end

function maxVal(targets, metric)
    return reduce(map(targets, metric), math.max, -math.huge)
end

function minVal(targets, metric)
    return reduce(map(targets, metric), math.min, math.huge)
end

function filter(tbl, condition)
    local out = {}
    for i, v in ipairs(tbl) do
        if condition(v) then
            table.insert(out, v)
        end
    end
    return out
end

function findMax(targets, metric)
    local max_val = -math.huge
    local max_target = nil
    local keys = {}

    for k in pairs(targets or {}) do
        table.insert(keys, k)
    end

    for _, k in ipairs(keys) do
        local target = targets[k]
        local val = target and target[metric] or nil

        if val ~= nil and type(val) == "number" and tostring(val) ~= "nan" and tostring(val) ~= "-nan" then
            if val > max_val then
                max_val = val
                max_target = target
            end
        end
    end

    return max_target
end
