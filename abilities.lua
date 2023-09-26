-- learn abilities from spellbook
local function GetSpellValueFromTooltip(spellID)
    if not spellID then
        return {}
    end

    local tooltip = CreateFrame("GameTooltip", "MyScanningTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:SetSpellByID(spellID)

    local matchValues = {}
    local patterns = {
        damage = {"heal[%a%s]*for%s(%d+)", "(%d+)%s+[%a%s]*damage", "additional (%d+)%s*[%a-]*%s+damage", "by%s+(%d+)",
                  "(%d+)%%[%a%s]*damage"},
        -- healing = {"heal[%a%s]*for%s(%d+)"},
        duration = {"over%s+(%d+)%s+sec", "for%s+(%d+)%s+sec", "lasts%s+(%d+)%s+sec"},
        durationMins = {"over%s+(%d+)%s+min", "for%s+(%d+)%s+min", "lasts%s+(%d+)%s+min"},
        aoe = {"allies", "enemies", "members"},
        targets = {"member[%a]*", "target[%a]*"},
        heal = {"restor[%a]*", "heal[%a]*"},
        absorb = {"absorb[%a]*"},
        buff = {"stamina", "intellect", "strength", "agility", "spirit", "armor", "resistance", "damage caused"},
        isPct = {"%%"},
        drain = {"drain[%a]*"},
        control = {"control[%a]*"}
    }

    for i = 1, tooltip:NumLines() do
        local line = _G["MyScanningTooltipTextLeft" .. i]
        local text = string.lower(line:GetText() or '')

        for category, patternList in pairs(patterns) do
            for _, pattern in pairs(patternList) do
                local match = string.match(text, pattern)
                if match then
                    matchValues[category] = matchValues[category] or {}
                    table.insert(matchValues[category], match)
                    -- break
                end
            end
        end
    end

    local spellValueMin = matchValues.damage and sum(map(matchValues.damage, tonumber)) or 0
    local duration = matchValues.duration and tonumber(matchValues.duration[1]) or matchValues.durationMins and
                         tonumber(matchValues.durationMins[1]) * 60 or 0
    local isPct = matchValues.isPct and true or false
    local isAbsorb = matchValues.absorb and true or false
    local isHeal = matchValues.heal and true or false
    local isBuff = matchValues.buff and true or false
    local isDot = not isHeal and duration > 0 and not isPct
    local isHot = not isAbsorb and isHeal and duration > 0 and not isPct
    local isLeech = isHeal and isPct
    local isDrain = matchValues.drain and true or false
    local isControl = matchValues.control and true or false

    local effectType = isAbsorb and "ABSORB" or isLeech and "LEECH" or isHot and "HOT" or (isBuff and duration > 60) and
                           "BUFF" or isDot and "DOT" or isHeal and "HEAL" or isDrain and "DRAIN" or isControl and
                           "CONTROL" or "DIRECT"

    return {
        valueMin = spellValueMin,
        duration = duration or 1,
        isAoe = matchValues.aoe and true or false,
        effectType = effectType,
        targetable = matchValues.targets and true or false
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

local function filterRanksByEffectType(spellList, rankMap)
    local filteredList = {}
    local rankTracker = {}

    -- Iterate through spellList and track ranks for each spell name
    for spellId, spell in pairs(spellList) do
        local effect = spell.effectType
        local numRanks = rankMap[effect] or rankMap["DEFAULT"]

        if not rankTracker[spell.name] then
            rankTracker[spell.name] = {}
        end
        table.insert(rankTracker[spell.name], spell)
    end

    -- Sort each tracked spell's rank in descending order
    for spellName, spells in pairs(rankTracker) do
        table.sort(spells, function(a, b)
            return a.rank > b.rank
        end)
    end

    -- Add top ranks to the filtered list
    for spellName, spells in pairs(rankTracker) do
        local effect = spells[1].effectType
        local numRanks = rankMap[effect] or rankMap["DEFAULT"]

        for i = 1, math.min(#spells, numRanks) do
            filteredList[spells[i].id] = spells[i]
        end
    end

    return filteredList
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
            local cooldown = GetSpellBaseCooldown(spellId)
            cooldown = cooldown and cooldown / 1000 or 0
            if spellType ~= "FUTURESPELL" and tooltipVals.valueMin > 0 then
                local spell = table_merge(tooltipVals, {
                    rank = rank,
                    texture = icon,
                    name = spellName,
                    manaCost = manaCost,
                    castTime = castTime,
                    id = spellId,
                    cooldown = cooldown
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
    logger.warn(counters)
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
        cooldown = 0,
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
            cooldown = 0,
            rank = 1,
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
                        rank = 1,
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
    spellList = filterRanksByEffectType(spellList, {
        DIRECT = 2,
        DEFAULT = 1
    })

end
