local function getSideBenefitPotential(unit, spell, targets)
    return math.abs((unit.ttd - unit.unitHealth / (unit.dtps + (spell.valueMin / spell.castTime))) *
                        (UnitGUID(unit.unit .. 'target') and targets[UnitGUID(unit.unit .. 'target')] and
                            targets[UnitGUID(unit.unit .. 'target')].dtps or 0))
end

local function getPotential(potential, unit, spell, effectiveCastTime, effectiveManaCost, targets)
    local unitSpellPotential = 0
    if UnitExists(unit.unit) then
        if spell.effectType == "ABSORB" then
            if not hasAura(unit.unit, spell.name, "HELPFUL") and
                (not spell.name == 'Power Word:Shield' or not hasAura(unit.unit, 'Weakened Soul', 'HARMFUL')) then
                unitSpellPotential = spell.valueMin * (effectiveCastTime / unit.ttd)
            end
        elseif spell.effectType == "BUFF" then
            if unit.isFriend and not unit.inCombat and not hasAura(unit.unit, spell.name, "HELPFUL") then
                unitSpellPotential = spell.valueMin or 1
            end
        elseif spell.effectType == "HOT" then

            if unit.isFriend and not hasAura(unit.unit, spell.name, "HELPFUL") then
                unitSpellPotential = unit.dtps / spell.dps * spell.valueMin
            end
        elseif spell.effectType == "LEECH" then
            if not hasAura(unit.unit, spell.name, 'HARMFUL') then
                local dmgPotential = unit and unit.unitHealth or 0
                unitSpellPotential = math.min(unit.unitHealthMax - unit.unitHealth, dmgPotential)
            end
        elseif spell.effectType == "HEAL" then
            if unit.isFriend then
                unitSpellPotential = math.min(unit.unitHealthMax - unit.unitHealth, spell.valueMin)
            end
        elseif spell.effectType == "DOT" then
            if not hasAura(unit.unit, spell.name, 'HARMFUL') then
                unitSpellPotential = math.min(spell.dps * unit.ttd, spell.valueMin)
                unitSpellPotential = math.min(unit.unitHealth, unitSpellPotential)
            end
        else
            unitSpellPotential = math.min(unit.unitHealth, spell.valueMin)
            -- additional benefit
            unitSpellPotential = unitSpellPotential + unit.dtps / spell.dps *
                                     getSideBenefitPotential(unit, spell, targets)
        end
    end

    unitSpellPotential = unitSpellPotential / effectiveCastTime / effectiveManaCost
    logger.debug("getPotential:", potential, unit.unit, spell.name, effectiveCastTime, effectiveManaCost,
        unitSpellPotential)
    return unitSpellPotential
end

local function findMax(targets, metric)
    local max_val = -math.huge
    local max_target = nil

    for _, target in pairs(targets) do
        local val = target[metric]

        if val > max_val then
            max_val = val
            max_target = target
        end
    end

    return max_target
end

function pickBestAction(metrics, survivalFactor)
    if not metrics then
        return nil
    end

    local maxPotential = 0
    local saveMana = metrics.maxttd_enemies > metrics.ttd_mana_self
    local pumpToHealRatio = metrics.minttd_party >= math.huge and 1 or
                                (metrics.minttd_party / metrics.maxttd_enemies / survivalFactor)

    local everyBestSpellUnitPotential = map(spellList, function(spell)
        local spellId = spell.id

        if isSpellUsable(spellId) then
            local potential = 0
            local unitHealth = 0;

            local everySpellUnitPotential = map(metrics.targets, function(unit)
                print('map spell-unit')
                local effectiveCastTime = (spell.castTime or 1)
                local inCombat = UnitAffectingCombat(unit.unit)
                if spell.castTime > 0 then
                    effectiveCastTime = effectiveCastTime + effectiveCastTime / metrics.self_dtinterval * 0.5
                    effectiveCastTime = (inCombat and effectiveCastTime or (1 / spell.castTime))
                end
                local effectiveManaCost = (saveMana and (spell.manaCost or 1) or 1)

                local pot = getPotential(potential, unit, spell, effectiveCastTime, effectiveManaCost, metrics.targets)

                local res = table_merge(spell, unit, {
                    potential = pot
                })
                logger.debug('SpellUnitPotential:', res)
                return res

            end)

            local bestSpellUnitPotential = {}
            if spell.isAoe then
                logger.debug('everySpellUnitPotential',everySpellUnitPotential)
                bestSpellUnitPotential = table_merge(spell, {
                    potential = sum(map(everySpellUnitPotential,'potential'))
                })
            else
                bestSpellUnitPotential = findMax(everySpellUnitPotential, 'potential')
            end

            logger.debug('BestUnitSpellPotential:', bestSpellUnitPotential)
            return bestSpellUnitPotential;

        end
    end)

    local bestBestSpellUnitPotential = findMax(everyBestSpellUnitPotential, 'potential')
    logger.info("bestBestSpellUnitPotential", bestBestSpellUnitPotential)
    return bestBestSpellUnitPotential
end

