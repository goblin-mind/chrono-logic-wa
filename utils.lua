LogLevel = {
    TRACE = 1,
    DEBUG = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5
}

local function logMessage(level, ...)

    if level >= logger.logLevel then
        print(table.concat(map({...}, function(it)
            return type(it) == "table" and stringifyTable(it) or tostring(it)
        end), " "))
    end
end
function map(t, f_or_key)
    local new_t = {}
    for k, v in pairs(t) do
        if type(f_or_key) == "function" then
            new_t[k] = f_or_key(v, k)
        else
            new_t[k] = v[f_or_key]
        end
    end
    return new_t
end

logger = {
    logLevel = aura_env.config['loglevel'],
    trace = function(...)
        logMessage(LogLevel.TRACE, ...)
    end,
    debug = function(...)
        logMessage(LogLevel.DEBUG, ...)
    end,
    info = function(...)
        logMessage(LogLevel.INFO, ...)
    end,
    warn = function(...)
        logMessage(LogLevel.WARN, ...)
    end,
    error = function(...)
        logMessage(LogLevel.ERROR, ...)
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
    local colWidths = {}
    local str = ""
    local orderBy = query.orderBy or nil
    local columns = query.columns or nil

    local function sortTable(t, orderKey)
        local sortedTbl = {}
        for k in pairs(t) do
            table.insert(sortedTbl, k)
        end
        table.sort(sortedTbl, function(a, b)
            return (t[a][orderKey] or 0) > (t[b][orderKey] or 0)
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
                colWidths[k] = math.max(colWidths[k], #tostring(v))
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
            local val = tostring(spell[col] or "")
            str = str .. val .. string.rep(" ", colWidths[col] - #val) .. " | "
        end
        str = str .. "\n"
    end

    return str
end

function CalculateSpellCastTime(spellID)
    local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
    if not castTime then
        return math.huge
    end
    return (castTime / 1000)
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

function hasAura(unit, aura, atype)
    local name, _ = AuraUtil.FindAuraByName(aura, unit, atype)
    return name == aura
end

function isSpellUsable(spellId)
    if not spellId then
        return true
    end
    local usable, _ = IsUsableSpell(spellId)
    if not usable then
        return false
    end
    -- print(usable)
    local start, duration, enabled = GetSpellCooldown(spellId)
    if not start then
        return true
    end

    local timeLeft = start + duration - GetTime()
    local isOnCooldown = (timeLeft > 1.5)

    return not isOnCooldown
end

