--commons
local LogLevel = {DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4}
local logLevel = LogLevel.ERROR

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
        spellValueMin, spellValueMax = string.match(text, "(%d+)%s+to%s+(%d+)%s+[%a%s]+%s+damage")
        if not spellValueMin then
            spellValueMin, spellValueMax = string.match(text, "(%d+)%s+to%s+(%d+)%s+[%a%s]+%s+healing")
        end
        if not spellValueMin then
            spellValueMin, spellValueMax = string.match(text, "(%d+)%s+to%s+(%d+).$")
        end
        if not spellValueMin then
            spellValueMin = string.match(text, "(%d+)%s+damage")
        end
        
        duration = string.match(text, "over%s+(%d+)%s+sec") or string.match(text, "for%s+(%d+)%s+sec")
        
        
        isHeal = isHeal or (string.find(text, "restor[%a]*") or string.find(text, "heal[%a]*") or string.find(text, "absorb[%a]*")) and true
        isAoe = isAoe or string.match(text, "allies|enemies|members")
        --aDot,duration = string.match(text, "additional%s+(%d+)%s+over%s+(%d+)") 
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
        local castTime = math.max(CalculateSpellCastTime(spellId) or 1,1)
        local manaCost = 0;
        local costInfo = GetSpellPowerCost(spellName)
        local icon = GetSpellTexture(spellId)
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
            table.insert(spellList, {id = spellId,texture=icon, name = spellName,manaCost=manaCost, valueMin = valueMin, castTime=castTime or 0,duration=duration or 1,isHeal=isHeal,isAoe=false})
        end
        i = i + 1
    end
    
    -- Melee
    local minDamage, maxDamage, _, _, _ = UnitDamage("player")
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    table.insert(spellList, {id = nil, name = "Melee",manaCost = maxDamage, valueMin = minDamage, valueMax = maxDamage, castTime = mainSpeed, duration = 1,texture=133479, isHeal = false, isAoe = false})
    
    -- Wand
    local speed, minWandDamage, maxWandDamage, _, _ = UnitRangedDamage("player")
    if speed > 0 then
        table.insert(spellList, {id = nil, name = "Wand",manaCost = maxWandDamage, valueMin = minWandDamage, valueMax = maxWandDamage, castTime = speed, duration = 1,texture=135149, isHeal = false, isAoe = false})
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
                            castTime = 0.1, 
                            manaCost = 1,
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

local function hasDebuff(unit, debuffName, timeThreshold)
    
    if not debuffName then return false end
    logger.debug("checking",unit,debuffName,timeThreshold)
    
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId = AuraUtil.FindAuraByName(debuffName, unit, "HARMFUL")
    if name == debuffName then
        return true
    end
    return false
end

local function hasBuff(unit, buffName, timeThreshold)
    
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime = UnitAura(unit, i)
        
        if name == buffName then
            local timeRemaining = expirationTime - GetTime()
            if timeRemaining <= timeThreshold then
                return false, timeRemaining
            else
                return true, timeRemaining
            end
        end
    end
    return false
end

local function isSpellUsable(spellId)
    if not spellId then return true end 
    local isUsable, notEnoughMana = IsUsableSpell(spellId)
    local start, duration, enabled = GetSpellCooldown(spellId)
    
    local timeLeft = start + duration - GetTime()
    local isOnCooldown = (timeLeft > 0.3)
    
    return isUsable and notEnoughMana == false and not isOnCooldown
end
local function safelyGetUnitHealthMiss(unit)
    if not unit then return 0 end
    local maxHealth = UnitHealthMax(unit) or 0
    local currentHealth = UnitHealth(unit) or 0
    return maxHealth - currentHealth
end

local function getPotential(unitHealth,spell,potential)
    local unitPotential = math.min(unitHealth, spell.valueMin or 0)
    unitPotential = unitPotential / (spell.castTime or 1) /  (spell.manaCost or spell.duration )
    if spell.isAoe then
        logger.info(stringifyTable({spell,potential}))
        return  potential + unitPotential  -- Accumulate for AoE
    else
        logger.info(stringifyTable({spell,potential}))
        return math.max(potential, unitPotential)  -- Max for single target
    end
    
end

function pickBestAction(metrics)
    if not metrics then return nil end
    
    local bestAction = nil
    local maxPotential = 0
    
    local manaBalance = 1 --metrics.ttd_mana_self/metrics.maxttd_enemies.value
    local healUrgency = 1 --metrics.maxttd_enemies.value/metrics.minttd_party.value
    
    for _, spell in pairs(spellList or {}) do
        if isSpellUsable(spell.id)   then
            local potential = 0
            local unitHealth =0;
            -- Healing logic
            if spell.isHeal then
                for _, unit in pairs(metrics.minttd_party.targets or {}) do
                    if  spell.duration>1 and not hasBuff(unit,spell.name,0.5) and (not spell.name=='Power Word:Shield' or not hasDebuff(unit,'Weakened Soul',0.5)) then 
                        
                        
                        unitHealth = safelyGetUnitHealthMiss(unit)
                        potential = getPotential(unitHealth,spell,potential)
                    end
                end
                -- Damage logic
            else
                for _, unit in pairs(metrics.maxttd_enemies.targets or {}) do
                    if spell.duration>1 and not hasDebuff(unit,spell.name,0.5) then
                        unitHealth = UnitHealth(unit) or 0
                        potential = getPotential(unitHealth,spell,potential)
                    end
                end
            end
            
            if potential > maxPotential then
                
                maxPotential = potential
                bestAction = spell
                bestAction.potential = potential
            end
        end
    end
    
    return bestAction
end

