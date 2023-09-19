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
        return {}
    end
    
    local tooltip = CreateFrame("GameTooltip", "MyScanningTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:SetSpellByID(spellID)
    -- Initialize spellValueMin to 0
    local spellValueMin = 0
    -- Function to add matched value to spellValueMin
    local function addMatchedValue(text,pattern)
        local match = string.match(text, pattern)
        logger.debug(text,pattern,match)
        if match then
            spellValueMin = spellValueMin + tonumber(match)
        end
    end
    
    local  spellValueMax, isHeal, isAoe, duration,isAbsorb
    for i = 1, tooltip:NumLines() do
        local line = _G["MyScanningTooltipTextLeft" .. i]
        local text = string.lower(line:GetText())
        
        addMatchedValue(text,"(%d+)%s+to%s+%d+%s+[%a%s]+%s+damage")
        addMatchedValue(text,"(%d+)%s+to%s+%d+%s+[%a%s]+%s+healing")
        addMatchedValue(text,"(%d+)%s+to%s+%d+%s?%p?$")  -- Assuming you meant any punctuation at the end
        --addMatchedValue(text,"(%d+)%s+[%a-]+%s+damage") 
        addMatchedValue(text,"(%d+)%s*[%a-]*%s+damage")
        
        duration = string.match(text, "over%s+(%d+)%s+sec") or string.match(text, "for%s+(%d+)%s+sec")
        
        isAbsorb = isAbsorb or string.find(text, "absorb[%a]*") and true
        isHeal = isHeal or (string.find(text, "restor[%a]*") or string.find(text, "heal[%a]*") or isAbsorb) and true
        isAoe = isAoe or string.match(text, "allies|enemies|members")
        --aDot,duration = string.match(text, "additional%s+(%d+)%s+over%s+(%d+)") 
        if spellValueMin>0 then            
            break
        end
    end
    
    return {valueMin=tonumber(spellValueMin), isHeal=isHeal, duration=tonumber(duration)or 1, isAoe=isAoe, isAbsorb=isAbsorb}
end

-- Function to calculate spell cast time
local function CalculateSpellCastTime(spellID)
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

local function GeneratePlayerSpellList()
    local spellList = {}
    
    -- Spells
    local i = 1
    while true do
        local spellName, _, spellId = GetSpellBookItemName(i, "spell")
        local spellType,_ = GetSpellBookItemInfo(i, "spell")
        local tootipVals = GetSpellValueFromTooltip(spellId)
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
        if spellType ~= "FUTURESPELL" and tootipVals.valueMin > 0 then
            table.insert(spellList, table_merge(tootipVals,{id = spellId,texture=icon, name = spellName,manaCost=manaCost,castTime=castTime or 1.5}))
        end
        i = i + 1
    end
    
    -- Melee
    local minDamage, maxDamage, _, _, _ = UnitDamage("player")
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    table.insert(spellList, {id = nil, name = "Melee",manaCost = 1, valueMin = minDamage, valueMax = maxDamage, castTime = mainSpeed, duration = 1,texture=133479, isHeal = false, isAoe = false})
    
    -- Wand
    local speed, minWandDamage, maxWandDamage, _, _ = UnitRangedDamage("player")
    if speed > 0 then
        table.insert(spellList, {id = nil, name = "Wand",manaCost = 1, valueMin = minWandDamage, valueMax = maxWandDamage, castTime = speed, duration = 1,texture=135149, isHeal = false, isAoe = false})
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
                    local valueMin,  isHeal, duration = GetSpellValueFromTooltip(itemSpellId)
                end
                if (valueMin) then 
                    table.insert(spellList, {
                            id = itemId, 
                            name = itemName, 
                            valueMin = valueMin, 
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
    logger.warn(stringifyTable(spellList))
    return spellList
end

local function GetPlayerSpellList()
    
    return spellList 
end


local spellList = GeneratePlayerSpellList()

local function hasAura(unit,aura,atype)
    local name,_ = AuraUtil.FindAuraByName(aura, unit,atype)
    return name==aura
end




local function isSpellUsable(spellId)
    if not spellId then return true end 
    local usable,_ = IsUsableSpell(spellId)
    --print(usable)
    local start, duration, enabled = GetSpellCooldown(spellId)
    
    local timeLeft = start + duration - GetTime()
    local isOnCooldown = (timeLeft > 1.5)
    
    return  usable and not isOnCooldown
end


local function getPotential(unitHealth,spell,potential,saveMana,dtps,inCombat)
    local unitPotential = 0
    
    local isHot = spell.isHeal and spell.duration
    
    if isHot then 
        unitPotential = math.min(1,dtps/(spell.valueMin/spell.duration))*spell.valueMin
    elseif spell.isAbsorb then
        unitPotential = spell.valueMin
    else
        unitPotential = math.min(unitHealth, spell.valueMin or 0)
    end
    unitPotential = unitPotential / (not saveMana and 1 or (spell.manaCost or 1)) /(not inCombat and 1 or (spell.castTime or 1))  --or spell.duration
    
    spell.potential = unitPotential
    logger.debug(stringifyTable(spell))
    if spell.isAoe then
        return  (potential or 0) + unitPotential  -- Accumulate for AoE
    else
        return math.max(potential, unitPotential)  -- Max for single target
    end
    
end


function pickBestAction(metrics)
    if not metrics then return nil end
    
    local bestAction = nil
    local maxPotential = 0
    local saveMana = metrics.maxttd_enemies.value>metrics.ttd_mana_self
    for _, spell in pairs(spellList or {}) do
        if isSpellUsable(spell.id)   then
            local potential = 0
            local unitHealth =0;
            -- Healing logic
            if spell.isHeal then
                if (  metrics.minttd_party.value <= metrics.maxttd_enemies.value ) then
                    for _, unit in pairs(metrics.minttd_party.targets or {}) do
                        local _unit = unit.unit
                        local inCombat = UnitAffectingCombat(_unit)
                        if  UnitExists(_unit) and spell.duration<1 or not hasAura(unit.unit,spell.name,"HELPFUL") and (not spell.name=='Power Word:Shield' or not hasAura(unit.unit,'Weakened Soul','HARMFUL')) then 
                            potential = getPotential(unit.unitHealthMax-unit.unitHealth,spell,potential,saveMana,metrics.average_dtps_party,inCombat)
                        end
                    end
                end
            else
                for _, unit in pairs(metrics.maxttd_enemies.targets or {}) do
                    local _unit = unit.unit
                    if UnitExists(_unit) and spell.duration<1 or not hasAura(unit.unit,spell.name,'HARMFUL') then
                        local inCombat = UnitAffectingCombat(_unit)
                        if (  metrics.minttd_party.value >= metrics.maxttd_enemies.value ) then
                            potential = getPotential(unit.unitHealth,spell,potential,saveMana,metrics.average_dtps_party,inCombat)
                        else 
                            enemydmgpotsaved = (metrics.maxttd_enemies.value-unit.unitHealth/(metrics.min_dtps_enemies.value+(spell.valueMin/spell.castTime)))*metrics.max_dtps_party.value
                            potential = getPotential(metrics.max_missing_hp,{name=spell.name,castTime=1,manaCost=1,isAoe=true,valueMin=math.abs(enemydmgpotsaved)},potentia,saveMana,metrics.average_dtps_party,inCombat)
                        end
                        
                    end
                end
            end
            
            if potential > maxPotential then
                
                maxPotential = potential
                bestAction = spell
            end
        end
    end
    
    return bestAction
end

