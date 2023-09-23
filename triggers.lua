-- Do not remove this comment, it is part of this aura: utils


-- Do not remove this comment, it is part of this aura: abilities
function()
    GeneratePlayerSpellList()
    
end

-- Do not remove this comment, it is part of this aura: chronology
-- WeakAura Custom Trigger

function(event, unit, powerType)
    if event == "UNIT_HEALTH" then
        if unit then
            UpdateRates(unit, "HEALTH", UnitHealth(unit))
        end
    elseif event == "UNIT_POWER_UPDATE" then
        if unit and (powerType == "MANA") then
            
            UpdateRates(unit, powerType, UnitPower(unit, Enum.PowerType[powerType]))
        end
    elseif event == "UNIT_TARGET" then
        
        
        if unit == "player" then
            ResetTarget("target")
            UpdateRates("target", "HEALTH", UnitHealth("target"))
            UpdateRates("player", "HEALTH", UnitHealth("player"))
        end
        
    end
    return true
    
end

-- Do not remove this comment, it is part of this aura: metrics
function()
    return true
end

-- Do not remove this comment, it is part of this aura: action
function()
    local  bestSpell = pickBestAction(generateMetrics()) 
    
    
    if bestSpell then
        local icon = bestSpell.texture
        aura_env.icon= icon
        aura_env.rank = bestSpell.rank
        return true
    end
    return false
    
end

