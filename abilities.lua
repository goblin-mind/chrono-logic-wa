--learn abilities from spellbook
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
        if match then
            spellValueMin = spellValueMin + tonumber(match)
            return true
        end
        return false
    end
    
    local  spellValueMax, isHeal, isAoe, duration,isAbsorb,isBuff,isPct
    local attributeBuffs = {"stamina", "intellect", "strength", "agility", "spirit", "armor", "resistance"}  -- Add more attributes as needed
    
    for i = 1, tooltip:NumLines() do
        local line = _G["MyScanningTooltipTextLeft" .. i]
        local text = line:GetText()
        text = string.lower(text or '')
        -- logger.debug(text)
        local _ = addMatchedValue(text,"(%d+)%s+to%s+%d+%s+[%a%s]*damage") or addMatchedValue(text,"(%d+)%s+[%a%s]*damage")
        addMatchedValue(text,"additional (%d+)%s*[%a-]*%s+damage")
        addMatchedValue(text,"by%s+(%d+)")
        addMatchedValue(text,"(%d+)%%[%a%s]*damage")
        
        duration = string.match(text, "over%s+(%d+)%s+sec") or string.match(text, "for%s+(%d+)%s+sec")
        if not duration then
            duration = string.match(text, "(%d+)%s+min") 
            duration = tonumber(duration or 0)*60
        end
        
        isPct = isPct or string.find(text, "%%")
        isAbsorb = isAbsorb or string.find(text, "absorb[%a]*") and true
        isHeal = isHeal or (string.find(text, "restor[%a]*") or string.find(text, "heal[%a]*") or isAbsorb) and true
        isAoe = isAoe or string.match(text, "allies|enemies|members")
        
        -- Detecting generic attribute buffs
        for _, attr in ipairs(attributeBuffs) do
            isBuff = isBuff or string.find(text, attr) and true
            if isBuff then
                buffAmount = string.match(text, "(%d+)%s+to%s+(%d+)")  -- Add more patterns as needed
                break
            end
        end
        
        if spellValueMin>0 then            
            break
        end
    end
    
    return {valueMin=tonumber(spellValueMin), isHeal=isHeal,isBuff=isBuff, duration=tonumber(duration)or 1, isAoe=isAoe, isAbsorb=isAbsorb,isPct=isPct}
end

spellList = {}

function GetPlayerSpellList()
    return spellList
end


function GeneratePlayerSpellList()
    logger.info("GeneratePlayerSpellList")
    -- Spells
    local i = 1
    while true do
        local spellName, _, spellId = GetSpellBookItemName(i, "spell")
        
        if not spellList[spellId] and not IsPassiveSpell(spellId) then
            local spellType,_ = GetSpellBookItemInfo(i, "spell")
            local tooltipVals = GetSpellValueFromTooltip(spellId)
            local castTime = math.max(CalculateSpellCastTime(spellId) or 1,1)
            
            
            local manaCost = 0;
            local costInfo = GetSpellPowerCost(spellId)
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
            if spellType ~= "FUTURESPELL" and tooltipVals.valueMin > 0 then
                spellList[spellId] = table_merge(tooltipVals, {rank=rank,texture = icon, name = spellName, manaCost = manaCost, castTime = castTime or 1.5})
            end
        end
        i = i + 1
    end
    
    -- Create a table to hold counters for each spell name
    local counters = {}
    
    -- Create an array to sort your table by name and then by manaCost
    local sortedKeys = {}
    for spellId, spell in pairs(spellList) do
        table.insert(sortedKeys, spellId)
    end
    
    table.sort(sortedKeys, function(a, b)
            return spellList[a].manaCost < spellList[b].manaCost
            
    end)
    
    
    -- Assign ranks
    for _, spellId in ipairs(sortedKeys) do
        local spell = spellList[spellId]
        if not counters[spell.name] then
            counters[spell.name] = 0
        end
        counters[spell.name] = counters[spell.name] + 1
        spell.rank = counters[spell.name]
    end
    
    -- Melee
    local minDamage, maxDamage, _, _, _ = UnitDamage("player")
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    spellList['m1'] = { name = "Melee",manaCost = 1, valueMin = minDamage, valueMax = maxDamage, castTime = mainSpeed, duration = 1,texture=133479}
    
    -- Wand
    local speed, minWandDamage, maxWandDamage, _, _ = UnitRangedDamage("player")
    if speed > 0 then
        spellList['r1'] = {name = "Wand",manaCost =0, valueMin = minWandDamage, valueMax = maxWandDamage, castTime = speed, duration = 1,texture=135149}
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
                    spellList[itemId] ={
                        name = itemName, 
                        valueMin = valueMin, 
                        castTime = 1, 
                        manaCost = 1,
                        duration = duration, 
                        isHeal = isHeal, 
                        texture = 12345
                    }
                end
            end
        end
    end
end

local function getPotential(unitHealth,spell,potential,saveMana,dtps,inCombat,dtinterval)
    local unitPotential = 0
    
    local isHot = spell.isHeal and spell.duration
    local effectiveCastTime = (spell.castTime or 1)
    effectiveCastTime = effectiveCastTime+effectiveCastTime/dtinterval*0.5
    logger.debug("effectiveCastTime",effectiveCastTime,dtinterval)
    local isDot = spell.castTime and spell.duration and spell.castTime<=1.5 and spell.duration>1 and not spell.isPct
    if spell.isAbsorb then
        unitPotential = spell.valueMin
    elseif isHot then 
        unitPotential = math.min(1,dtps/(spell.valueMin/spell.duration))*spell.valueMin
    elseif isDot then
        unitPotential = (spell.valueMin or 0) 
        if dtps>0 then unitPotential = unitPotential / spell.duration * (unitHealth/dtps) end
        unitPotential = math.min(unitHealth, unitPotential)
    else
        unitPotential = math.min(unitHealth, spell.valueMin or 0) / (not inCombat and (1/spell.castTime) or effectiveCastTime)  
    end
    unitPotential = unitPotential / (not saveMana and 1 or (spell.manaCost or 1)) --or spell.duration
    
    spell.potential = unitPotential
    logger.debug("getPotential:",(spell.name or 'unknown'),(unitPotential or 0))
    if spell.isAoe then
        return  (potential or 0) + unitPotential  -- Accumulate for AoE
    else
        return math.max(potential, unitPotential)  -- Max for single target
    end
    
end


function pickBestAction(metrics)
    if not metrics then return nil end
    local survivalFactor = 20 
    local bestAction = nil
    local maxPotential = 0
    local saveMana = metrics.maxttd_enemies.value>metrics.ttd_mana_self
    local pumpToHealRatio = metrics.minttd_party.value>=math.huge and 1 or (metrics.minttd_party.value / metrics.maxttd_enemies.value/survivalFactor)
    for spellId, spell in pairs(spellList or {}) do
        if isSpellUsable(spellId)   then
            local potential = 0
            local unitHealth =0;
            
            -- Healing logic
            --print(metrics.minttd_party.value , metrics.maxttd_enemies.value )
            if spell.isHeal then
                
                -- if (  metrics.minttd_party.value <= metrics.maxttd_enemies.value ) then
                for _, unit in pairs(metrics.minttd_party.targets or {}) do
                    local _unit = unit.unit
                    local inCombat = UnitAffectingCombat(_unit)
                    if  UnitExists(_unit) and spell.duration<1 or not hasAura(unit.unit,spell.name,"HELPFUL") and (not spell.name=='Power Word:Shield' or not hasAura(unit.unit,'Weakened Soul','HARMFUL')) then 
                        --todo specify vampiric spells
                        if (spell.isPct) then 
                            --todo improve this
                            local leechTarget =  metrics.maxttd_enemies.targets[1]
                            local dmgPotential = leechTarget and leechTarget.unitHealth or 0
                            if leechTarget and dmgPotential then
                                logger.warn("leech check",spell.name or 'unknown_spell',leechTarget.unit or 'uknown target',dmgPotential or 'unknown_dmg')
                            end
                            if (dmgPotential and dmgPotential>0 and not hasAura(leechTarget.unit,spell.name,'HARMFUL')) then
                                potential = getPotential(dmgPotential,table_merge(table_merge({},spell),{isHot=true,valueMin=dmgPotential}),potential,saveMana,metrics.average_dtps_party,inCombat,metrics.party_mindtinterval) 
                                logger.warn("leech potential",potential)
                            end
                        else
                            potential = getPotential(unit.unitHealthMax-unit.unitHealth,spell,potential,saveMana,metrics.average_dtps_party,inCombat,metrics.party_mindtinterval)
                        end
                    end
                end
                
                potential = potential / pumpToHealRatio
                logger.debug("heal potential",spell.name,potential,pumpToHealRatio)
                --end
            elseif spell.isBuff and spell.duration > 60 then 
                for _, unit in pairs(metrics.friendly_targets or {}) do
                    local _unit = unit.unit
                    local inCombat = UnitAffectingCombat(_unit)
                    if UnitIsFriend("player", _unit) and not inCombat and not hasAura(unit.unit,spell.name,"HELPFUL") then
                        logger.debug("buff potential",spell.name,_unit)
                        potential = spell.valueMin or 1
                    end
                end
                
            else
                for _, unit in pairs(metrics.maxttd_enemies.targets or {}) do
                    local _unit = unit.unit
                    if UnitExists(_unit) and spell.duration<1 or not hasAura(unit.unit,spell.name,'HARMFUL') then
                        local inCombat = UnitAffectingCombat(_unit)
                        
                        potential = getPotential(unit.unitHealth,spell,potential,saveMana,metrics.average_dtps_party,inCombat,metrics.party_mindtinterval) 
                        if (  pumpToHealRatio<1 )  then
                            enemydmgpotsaved = (metrics.maxttd_enemies.value-unit.unitHealth/(metrics.min_dtps_enemies.value+(spell.valueMin/spell.castTime)))*metrics.max_dtps_party.value
                            potential = getPotential(metrics.max_missing_hp,{name=spell.name,castTime=1,manaCost=1,isAoe=true,valueMin=math.abs(enemydmgpotsaved)},potential,saveMana,metrics.average_dtps_party,inCombat,metrics.party_mindtinterval)
                        end
                        
                    end
                end
                potential = potential * pumpToHealRatio
            end
            
            if potential > maxPotential then
                
                maxPotential = potential
                bestAction = spell
            end
        end
    end
    if bestAction and maxPotential>0 then
        logger.info("pickBestAction",bestAction.name,maxPotential,pumpToHealRatio)
    end
    return bestAction
end

