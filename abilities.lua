-- learn abilities from spellbook
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
    local function addMatchedValue(text, pattern)
        local match = string.match(text, pattern)
        if match then
            spellValueMin = spellValueMin + tonumber(match)
            return true
        end
        return false
    end

    local spellValueMax, isHeal, isAoe, duration, isAbsorb, isBuff, isPct
    local attributeBuffs = {"stamina", "intellect", "strength", "agility", "spirit", "armor", "resistance",
                            "damage caused"} -- Add more attributes as needed

    for i = 1, tooltip:NumLines() do
        local line = _G["MyScanningTooltipTextLeft" .. i]
        local text = line:GetText()
        text = string.lower(text or '')
        -- logger.debug(text)
        local _ = addMatchedValue(text, "(%d+)%s+to%s+%d+%s+[%a%s]*damage") or
                      addMatchedValue(text, "(%d+)%s+[%a%s]*damage")
        addMatchedValue(text, "additional (%d+)%s*[%a-]*%s+damage")
        addMatchedValue(text, "by%s+(%d+)")
        addMatchedValue(text, "(%d+)%%[%a%s]*damage")

        duration = string.match(text, "over%s+(%d+)%s+sec") or string.match(text, "for%s+(%d+)%s+sec")
        if not duration then
            duration = string.match(text, "(%d+)%s+min")
            duration = tonumber(duration or 0) * 60
        else
            duration = tonumber(duration)
        end
        -- qualifiers --todo consider eliminating in favor of types
        isPct = isPct or string.find(text, "%%")
        isAoe = isAoe or string.match(text, "allies|enemies|members") and true

        isAbsorb = isAbsorb or string.find(text, "absorb[%a]*") and true
        isHeal = isHeal or (string.find(text, "restor[%a]*") or string.find(text, "heal[%a]*") or isAbsorb) and true

        -- Detecting generic attribute buffs
        for _, attr in ipairs(attributeBuffs) do
            isBuff = isBuff or string.find(text, attr) and true
            if isBuff then
                buffAmount = string.match(text, "(%d+)%s+to%s+(%d+)") -- Add more patterns as needed
                break
            end
        end

        if spellValueMin > 0 then
            break
        end
    end

    local isDot = not isHeal and duration > 0 and not isPct
    local isHot = not isAbsorb and isHeal and duration > 0 and not isPct
    local isLeech = isPct
    -- type
    local effectType = "DIRECT"
    if isAbsorb then
        effectType = "ABSORB"
    elseif isLeech then
        effectType = "LEECH"
        -- todo find another way to aggregate than faking aoe
        isAoe = true
    elseif isHot then
        effectType = "HOT"
    elseif isBuff then -- spell.duration > 60
        effectType = "BUFF"
    elseif isDot then
        effectType = "DOT"
    elseif isHeal then
        effectType = "HEAL"
    end

    return {
        valueMin = tonumber(spellValueMin),
        isHeal = isHeal,
        isBuff = isBuff,
        duration = tonumber(duration) or 1,
        isAoe = isAoe,
        isAbsorb = isAbsorb,
        isPct = isPct,
        effectType = effectType
    }
end

spellList = {}

function GetPlayerSpellList()
    return spellList
end

local function enrichSpell(spell)
    spell.dps = spell.valueMin /
                    ((spell.effectType == 'HOT' or spell.effectType == 'DOT') and (spell.duration + spell.castTime) or
                        spell.castTime)
    return spell

end

function GeneratePlayerSpellList()
    -- Spells
    local i = 1
    while true do
        local spellName, _, spellId = GetSpellBookItemName(i, "spell")

        if not spellList[spellId] and not IsPassiveSpell(spellId) then
            local spellType, _ = GetSpellBookItemInfo(i, "spell")
            local tooltipVals = GetSpellValueFromTooltip(spellId)
            local castTime = math.max(CalculateSpellCastTime(spellId) or 1.5, 1.5)

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
                local spell = table_merge(tooltipVals, {
                    rank = rank,
                    texture = icon,
                    name = spellName,
                    manaCost = manaCost,
                    castTime = castTime,
                    id = spellId
                })

                spellList[spellId] = enrichSpell(spell)
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
    spellList['m1'] = {
        name = "Melee",
        dps = minDamage / mainSpeed,
        manaCost = 0,
        effectType = 'AUTO',
        valueMin = minDamage,
        valueMax = maxDamage,
        castTime = mainSpeed,
        duration = 1,
        texture = 133479,
        id = 'm1'
    }

    -- Wand
    local speed, minWandDamage, maxWandDamage, _, _ = UnitRangedDamage("player")
    if speed > 0 then
        spellList['r1'] = {
            name = "Wand",
            dps = minWandDamage / speed,
            manaCost = 0,
            effectType = 'AUTO',
            valueMin = minWandDamage,
            valueMax = maxWandDamage,
            castTime = speed,
            duration = 1,
            texture = 135149,
            id = 'r1'
        }
    end
    -- Items
    local maxSlots = 18 -- Max bag slots in WoW Classic
    for bag = 0, 4 do
        for slot = 1, maxSlots do
            local itemId = C_Container.GetContainerItemID(bag, slot)
            if itemId then
                local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemId)
                local itemMin, itemMax, isItemHeal, itemOverTime = 10, 20, false, nil -- Dummy values; can be replaced
                local itemSpellId = select(2, GetItemSpell(itemId)) -- Gets spell ID if the item casts a spell

                if itemSpellId then
                    local valueMin, isHeal, duration = GetSpellValueFromTooltip(itemSpellId)
                end
                if (valueMin) then
                    spellList[itemId] = {
                        name = itemName,
                        valueMin = valueMin,
                        castTime = 1.5,
                        manaCost = 1,
                        duration = duration,
                        isHeal = isHeal,
                        texture = 12345,
                        id = itemId
                    }
                end
            end
        end
    end
end
