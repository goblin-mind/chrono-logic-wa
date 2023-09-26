-- Do not remove this comment, it is part of this aura: abilities
function()
    --PLAYER_LOGIN, PLAYER_ENTERING_WORLD, ADDON_LOADED
    GeneratePlayerSpellList()
end

-- Do not remove this comment, it is part of this aura: chronology
-- WeakAura Custom Trigger
function(event, unit, powerType)
    --UNIT_HEALTH,UNIT_POWER_UPDATE,UNIT_TARGET
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
    --UNIT_HEALTH,UNIT_POWER_UPDATE,UNIT_TARGET
    return generateMetrics() and true
end

-- Do not remove this comment, it is part of this aura: action
function()
    --UNIT_COMBAT,SPELL_UPDATE_USABLE,PLAYER_REGEN_ENABLED,UNIT_TARGET
    local  bestSpell = pickBestAction(getMetrics(),aura_env.config['survivalFactor']) 
    
    
    if bestSpell then
        local icon = bestSpell.texture
        --print("best spell found", stringifyTable(bestSpell),icon )
        aura_env.icon= icon
        aura_env.targetname = bestSpell.unitName
        aura_env.rank = bestSpell.rank
        return true
    end
    return false
    
end
