local LogLevel = {DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4}

local function logMessage( level, ...)
    if level >= logger.logLevel then
        print(table.concat({...}, " "))
    end
end


logger = {
    logLevel = LogLevel.WARN,
    debug = function( ...) logMessage( LogLevel.DEBUG, ...) end,
    info = function( ...) logMessage( LogLevel.INFO, ...) end,
    warn = function( ...) logMessage( LogLevel.WARN, ...) end,
    error = function( ...) logMessage( LogLevel.ERROR, ...) end
}

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

function tableToAlignedString(tbl)
    local colWidths = {}
    local str = ""
    
    -- Initialize column widths with header lengths
    colWidths["spellId"] = #("spellId")
    for _, spell in pairs(tbl) do
        for k, _ in pairs(spell) do
            colWidths[k] = #k
        end
    end
    
    -- Calculate maximum width for each column
    for spellId, spell in pairs(tbl) do
        colWidths["spellId"] = math.max(colWidths["spellId"], #tostring(spellId))
        for k, v in pairs(spell) do
            colWidths[k] = math.max(colWidths[k], #tostring(v))
        end
    end
    
    -- Create header string
    for k, w in pairs(colWidths) do
        str = str .. k .. string.rep(" ", w - #k) .. " | "
    end
    str = str .. "\n"
    
    -- Create rows
    for spellId, spell in pairs(tbl) do
        for k, w in pairs(colWidths) do
            local val = tostring(spell[k] or "")
            if k == "spellId" then val = tostring(spellId) end
            str = str .. val .. string.rep(" ", w - #val) .. " | "
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

function table_merge(t1, t2)
    for k, v in pairs(t2) do
        t1[k] = v
    end
    return t1
end

function hasAura(unit,aura,atype)
    local name,_ = AuraUtil.FindAuraByName(aura, unit,atype)
    return name==aura
end

function isSpellUsable(spellId)
    if not spellId then return true end 
    local usable,_ = IsUsableSpell(spellId)
    if not usable then return false end
    --print(usable)
    local start, duration, enabled = GetSpellCooldown(spellId)
    if not start then return true end
    
    local timeLeft = start + duration - GetTime()
    local isOnCooldown = (timeLeft > 1.5)
    
    return  not isOnCooldown
end

