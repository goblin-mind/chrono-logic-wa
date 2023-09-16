--commons
local LogLevel = {DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4}
local logLevel = LogLevel.WARN

local function logMessage( level, ...)
    if level >= logLevel then
        print(table.concat({...}, " "))
    end
end


logger = {
    logLevel = LogLevel.DEBUG,
    
    log = logMessage,
    
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

--abilities
local function GetSpellValueFromTooltip(spellID)
    if not spellID then
        return nil, nil, nil, nil, nil
    end
    
    local tooltip = CreateFrame("GameTooltip", "MyScanningTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:SetSpellByID(spellID)
    
    local spellValueMin, spellValueMax, isHeal, isAoe, duration
    for i = 1, tooltip:NumLines() do
        local line = _G["MyScanningTooltipTextLeft" .. i]
        local text = string.lower(line:GetText())

        spellValueMin, spellValueMax  = string.match(text, "(%d+)%s+to%s+(%d+)")
        duration = string.match(text, "over%s+(%d+)%s+sec%s+")
        isHeal = isHeal or (string.find(text, "restor[%a]*") or string.find(text, "heal[%a]*")) and true
        isAoe = isAoe or string.match(text, "allies|enemies|members")
        aDot,duration = string.match(text, "additional (%d+)%s+over (%d+)") 
        -- logger.warn("getting tooltip",text)
        if spellValueMin then
            
            break
        end
    end
    
    return tonumber(spellValueMin), tonumber(spellValueMax), isHeal, tonumber(duration), isAoe
end


-- Function to calculate spell cast time
local function CalculateSpellCastTime(spellID)
    local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
    if not castTime then
        return math.huge
    end
    return (castTime / 1000) 
end


local function GeneratePlayerSpellList()
    local spellList = {}
    
    -- Spells
    local i = 1
    while true do
        local spellName, _, spellId = GetSpellBookItemName(i, "spell")
        local spellType,_ = GetSpellBookItemInfo(i, "spell")
        local valueMin, spellValueMax, isHeal, duration = GetSpellValueFromTooltip(spellId)
        local castTime = CalculateSpellCastTime(spellId)
        local manaCost = 0;
        local costInfo = GetSpellPowerCost(spellName)
        
        if costInfo then
            for _, cost in ipairs(costInfo) do
                if cost.name == "MANA" or cost.name == "ENERGY" or cost.name == "RAGE" then
                    manaCost = cost.minCost
                end
            end
        end
        if not spellName then
            break
        end
        if spellType ~= "FUTURESPELL" and valueMin then
            table.insert(spellList, {id = spellId, name = spellName,manaCost=manaCost, valueMin = valueMin, castTime=castTime or 0,duration=duration or castTime,isHeal=isHeal,isAoe=false})
        end
        i = i + 1
    end
    
    -- Melee
    local minDamage, maxDamage, _, _, _ = UnitDamage("player")
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    table.insert(spellList, {id = nil, name = "Melee",manaCost = 0, valueMin = minDamage, valueMax = maxDamage, castTime = mainSpeed, duration = false, isHeal = false, isAoe = false})
    
    -- Wand
    local speed, minWandDamage, maxWandDamage, _, _ = UnitRangedDamage("player")
    if speed > 0 then
        table.insert(spellList, {id = nil, name = "Wand",manaCost = 0, valueMin = minWandDamage, valueMax = maxWandDamage, castTime = speed, duration = false, isHeal = false, isAoe = false})
    end
    -- Items
    local maxSlots = 18  -- Max bag slots in WoW Classic
    for bag = 0, 4 do
        for slot = 1, maxSlots do
            local itemId = C_Container.GetContainerItemID(bag, slot)
            if itemId then
                local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemId)
                local itemMin, itemMax, isItemHeal, itemOverTime = 10, 20, false, nil  -- Dummy values; can be replaced
                local itemSpellId = select(2, GetItemSpell(itemId))  -- Gets spell ID if the item casts a spell
                
                if itemSpellId then
                    local valueMin, spellValueMax, isHeal, duration = GetSpellValueFromTooltip(itemSpellId)
                end
                if (valueMin) then 
                    table.insert(spellList, {
                            id = itemId, 
                            name = itemName, 
                            valueMin = valueMin, 
                            valueMax = spellValueMax, 
                            castTime = 0, 
                            manaCost = 0,
                            duration = duration, 
                            isHeal = isHeal, 
                            isAoe = false, 
                            texture = 12345
                    })
                end
            end
        end
    end
    logger.info(stringifyTable(spellList))
    return spellList
end

local function GetPlayerSpellList()
    
    return spellList 
end


local spellList = GeneratePlayerSpellList()


local function isSpellUsable(spellId)
    local isUsable, notEnoughMana = IsUsableSpell(spellId)
    return isUsable and  notEnoughMana == false
end
local function safelyGetUnitHealthMiss(unit)
    if not unit then return 0 end
    local maxHealth = UnitHealthMax(unit) or 0
    local currentHealth = UnitHealth(unit) or 0
    return maxHealth - currentHealth
end
function pickBestAction(metrics)
    if not metrics then return nil end
    
    local bestAction = nil
    local maxPotential = 0
    
    for _, spell in pairs(spellList or {}) do
        if isSpellUsable(spell.id) then
            local potential = 0

            -- Healing logic
            if spell.isHeal then
                for _, unit in pairs(metrics.minttd_party.targets or {}) do
                    local unitMissingHealth = safelyGetUnitHealthMiss(unit)
                    local unitPotential = math.min(unitMissingHealth, spell.valueMin or 0)
                    unitPotential = unitPotential / (spell.castTime or 1) / spell.manaCost
                    if spell.isAoe then
                        potential = potential + unitPotential  -- Accumulate for AoE
                    else
                        potential = math.max(potential, unitPotential)  -- Max for single target
                    end
                end
            -- Damage logic
            else
                for _, unit in pairs(metrics.maxttd_enemies.targets or {}) do
                    local unitHealth = UnitHealth(unit) or 0
                    local unitPotential = math.min(unitHealth, spell.valueMin or 0)
                    unitPotential = unitPotential / (spell.duration or 1) / spell.manaCost
                    if spell.isAoe then
                        potential = potential + unitPotential  -- Accumulate for AoE
                    else
                        potential = math.max(potential, unitPotential)  -- Max for single target
                    end
                end
            end
            logger.warn(stringifyTable({spell,potential}))
            if potential > maxPotential then
                
                maxPotential = potential
                bestAction = spell
                bestAction.potential = potential
            end
        end
    end
    
    return bestAction
end