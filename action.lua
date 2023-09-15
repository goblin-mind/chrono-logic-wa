-- Function to get targets based on metrics: Add this to a custom trigger
function GetMetricTargets(metric, group, operator, threshold)
    local targets = {}
    local units = getRelevantUnits(group)
    
    for _, unit in ipairs(units) do
        --print(unit)
        local guid = UnitGUID(unit)
        if metricRatesWA[guid] and metricRatesWA[guid][metric] then
            local rate = metricRatesWA[guid][metric]
            print("getRate",rate)
            if (operator == "gt" and rate > threshold) or (operator == "lt" and rate < threshold) then
                table.insert(targets, unit)
            end
        end
    end
    return targets
end
function BestDamageSpell()
    local enemies = GetMetricTargets("HEALTH", "enemy", "lt", 0)
    local bestSpell, bestEnemy, bestDPS = nil, nil, 0
    local spellId
    
    for _, enemy in ipairs(enemies) do
        --print()
        local TTD = GetTTD(enemy, "UnitHealth")
        if TTD and TTD > 0 then
            for _, spell in ipairs(GetPlayerSpellList()) do
                --print(spell)
                local castTime = spell.castTime or 0
                local spellValueMin = tonumber(spell.valueMin) or 0
                
                if castTime > 0 and spellValueMin > 0 then
                    print(enemy,spel,castTime,spellValueMin)
                    local start, duration = GetSpellCooldown(spell.id)
                    if start and duration and start + duration <= GetTime() then  -- Spell is available
                        local spellDPS = spellValueMin / castTime
                        if spellDPS > bestDPS then
                            bestDPS = spellDPS
                            bestSpell = spell.name
                            bestEnemy = enemy
                            spellId = spell.id
                        end
                    end
                end
            end
        end
    end
    
    return spellName, spellId, bestEnemy
end


function BestHealingSpell()
    local targets = GetMetricTargets("health", "party", "lt", 0)
    local bestSpell, bestUnit, bestEfficiency, urgentAction = nil, nil, 0, false
    
    for _, unit in ipairs(targets) do
        local missingHealth = UnitHealthMax(unit) - UnitHealth(unit)
        local TTD = GetTTD(unit, "UnitHealth")
        local guid = UnitGUID(unit)
        local rate = metricRatesWA[guid]["health"]
        
        for _, spell in ipairs(spellList) do
            local castTime = spell.castTime
            local spellValueMin = tonumber(spell.valueMin) or 0
            
            if spellValueMin then
                local precision = math.abs(missingHealth - spellValueMin)
                local healRate = spellValueMin / castTime
                local effectiveness = math.abs(rate - healRate)
                
                local overallScore = precision + effectiveness
                
                if TTD < castTime * 1.5 then
                    urgentAction = true
                end
                
                if overallScore < bestEfficiency or bestEfficiency == 0 then
                    bestEfficiency = overallScore
                    bestSpell = spell.name
                    bestUnit = unit
                end
            end
        end
    end
    
    if urgentAction then
        -- Your urgent action code here
    end
    
    return bestSpell, bestUnit, "inv_potion_137"
end

function GetBestAction()
    local inGroup = IsInGroup() or IsInRaid()
    local myGuid = UnitGUID("player")
    
    local myManaTTD = GetTTD(myGuid, "MANA")
    local myHealthTTD = GetTTD(myGuid, "HEALTH")
    
    local damageTargets = GetMetricTargets("HEALTH", "enemy", "gt", 0)
    local highestEnemyHealthTTD = -1
    for _, enemy in ipairs(damageTargets) do
        local enemyHealthTTD = GetTTD(enemy, "HEALTH")
        highestEnemyHealthTTD = math.max(highestEnemyHealthTTD, enemyHealthTTD)
    end
    
    local healTargets = GetMetricTargets("HEALTH", "party", "lt", 1)
    local highestPartyTTD = -1
    for _, unit in ipairs(healTargets) do
        local partyHealthTTD = GetTTD(unit, "HEALTH")
        highestPartyTTD = math.max(highestPartyTTD, partyHealthTTD)
    end
    
    local spellId = nil
    if not inGroup or (myManaTTD >= highestEnemyHealthTTD and myHealthTTD >= highestPartyTTD) then
        _,spellId, _=  BestDamageSpell()
        return spellId
    elseif highestPartyTTD < myHealthTTD then
        return 1-- nil --spellId = 12345 --best heling
    else
        return 1--nil --spellId = 12345 -- BestIdleSpell()  -- Assuming this function exists
    end
    
    -- if spellId == nil then
    --    
    --     spellId = 12345
    -- end
    
    -- return spellId
end

function BestIdleSpell()
    return 1;
end





