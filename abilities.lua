local bDebug = false

local logger = {
    debug = function(...) 
        print(table.concat({...}, " "))
    end
}

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
        local text = line:GetText()
        
        spellValueMin, spellValueMax  = string.match(text, "(%d+)%s+to%s+(%d+)")
        duration = string.match(text, "over%s+(%d+)%s+sec")
        isHeal = isHeal or string.match(text, "restore") or string.match(text, "heal")
        isAoe = isAoe or string.match(text, "allies") or string.match(text, "enemies")
        
        if spellValueMin and duration then
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
                if cost.type == "MANA" then
                    manaCost = cost.minCost
                end
            end
        end
        if not spellName then
            break
        end
        if spellType ~= "FUTURESPELL" and valueMin then
            table.insert(spellList, {id = spellId, name = spellName,manaCost=manaCost, valueMin = valueMin, castTime=castTime or 0,duration=duration,isHeal=isHeal,isAoe=false})
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
    logger.debug(stringifyTable(spellList))
    return spellList
end

local function GetPlayerSpellList()
    
    return spellList 
end


local spellList = GeneratePlayerSpellList()

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
    if not metrics then return nil end  -- Handling nil metrics
    
    local bestSpell = {}
    local candidates = {}
    
    
    
    -- Urgency Check
    for _, unit in pairs(metrics.minttd_party.targets or {}) do
        for _, spell in pairs(spellList or {}) do
            if spell.isHeal and spell.castTime <= metrics.minttd_party.value and isSpellUsable(spell.id) then
                table.insert(candidates, {spell=spell, target=unit})
            end
        end
    end
    
    for _, unit in pairs(metrics.maxttd_enemies.targets or {}) do
        for _, spell in pairs(spellList or {}) do
            if not spell.isHeal and spell.castTime <= metrics.maxttd_enemies.value and isSpellUsable(spell.id) then
                table.insert(candidates, {spell=spell, target=unit})
            end
        end
    end
    
    -- Efficiency and Precision Checks
    for _, candidate in pairs(candidates) do
        local spell = candidate.spell
        local unit = candidate.target
        local unitMissingHealth = safelyGetUnitHealthMiss(unit)  -- Update this based on your logic
        local efficiency = spell.valueMin / spell.manaCost
        local precision = math.abs(unitMissingHealth - spell.valueMin)
        logger.debug("considering:",unit,spell.name,unitMissingHealth,efficiency,precision )
        if spell.isHeal then
            if spell.isAoe and metrics.party_num_hp50_dtpsgt0 > 1 then
                efficiency = efficiency * metrics.party_num_hp50_dtpsgt0
            end
            if (spell.duration and metrics.minttd_party.value >= spell.duration) or (precision < unitMissingHealth * 0.2) then
                table.insert(bestSpell, {spell=spell, target=unit, metric=efficiency})
            end
        else
            if spell.isAoe and metrics.enemy_num_hp50_dtpsgt0 > 1 then
                efficiency = efficiency * metrics.enemy_num_hp50_dtpsgt0
            end
            if (spell.duration and metrics.maxttd_enemies.value >= spell.duration) or (metrics.maxttd_enemies.value <= metrics.minttd_party.value - 2) then
                table.insert(bestSpell, {spell=spell, target=unit, metric=spell.valueMin }) --consider efficiency?
            end
        end
    end
    
    table.sort(bestSpell, function(a, b) return a.metric > b.metric end)
    return bestSpell[1] or nil  -- Handle empty bestSpell
end