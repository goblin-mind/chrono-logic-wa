-- chronology
local metricDataWA = metricDataWA or {}
local metricRatesWA = metricRatesWA or {}
local metricIntervals = metricIntervals or {}

function ResetTarget(unit)
    logger.debug("ResetTarget:", unit)
    
    metricDataWA[unit] = {}
    metricRatesWA[unit] = {}
    
    UpdateRates(unit, 'HEALTH', UnitHealth(unit))
    C_Timer.After(1, function()
            UpdateRates(unit, 'HEALTH', UnitHealth(unit))
    end)
end

function getRawData()
    return {
        metricDataWA = metricDataWA,
        metricRatesWA = metricRatesWA,
        metricIntervals = metricIntervals
    }
end

function UpdateRates(unit, metric, value)
    local timestamp = GetTime()
    
    metricDataWA, metricRatesWA, metricIntervals = metricDataWA or {}, metricRatesWA or {}, metricIntervals or {}
    
    local guid = unit or ""
    metricDataWA[guid], metricRatesWA[guid], metricIntervals[guid] = metricDataWA[guid] or {},
    metricRatesWA[guid] or {}, metricIntervals[guid] or {}
    
    metricDataWA[guid][metric] = metricDataWA[guid][metric] or {}
    table.insert(metricDataWA[guid][metric], {
            value = value,
            timestamp = timestamp
    })
    
    logger.trace("senseValue:", unit, metric, value, 'time:' .. timestamp)
    
    metricDataWA[guid][metric] = filter(metricDataWA[guid][metric], function(sample)
            return timestamp - sample.timestamp <= 2
    end)
    
    local sum, totalTime, minInterval = 0, 0, math.huge
    local series = metricDataWA[guid][metric]
    for i = 2, #series do
        local deltaValue, deltaTime = series[i].value - series[i - 1].value,
        series[i].timestamp - series[i - 1].timestamp
        sum, totalTime = sum + deltaValue, totalTime + deltaTime
        if deltaValue < 0 then
            minInterval = math.min(minInterval, deltaTime)
        end
    end
    
    metricIntervals[guid][metric], metricRatesWA[guid][metric] = minInterval, (totalTime > 0) and (sum / totalTime) or 0
    logger.trace("senseRate:", unit, metric, metricRatesWA[guid][metric])
end

-- aggregated metrics
local _metrics = {}

local function getTTD(unitHealth, rate)
    return unitHealth > 0 and ((rate ~= 0) and (unitHealth / -rate) or math.huge) or 0
end

function getMetrics()
    return _metrics
end

function generateMetrics()
    local metrics = {
        targets = {},
        maxttd_enemies = 0,
        minttd_party = math.huge,
        ttd_mana_self = math.huge,
        self_dtinterval = math.huge
    }
    
    local totalDtpsParty = 0
    local partyCount = 0
    for _unit, metricTable in pairs(metricRatesWA or {}) do
        local exists = UnitExists(_unit)
        local guid = exists and UnitGUID(_unit) or '0'
        if exists then
            local unitHealth = UnitHealth(_unit) or 0
            local unitHealthMax = UnitHealthMax(_unit) or 1
            local unitPower = UnitPower(_unit, 0) or 0
            local dti = metricIntervals[_unit] and metricIntervals[_unit]["HEALTH"] or math.huge
            local hrate = metricTable and metricTable['HEALTH'] or 0
            local mrate = metricTable and metricTable['MANA'] or 0
            local unit = {
                unit = _unit,
                unitHealth = unitHealth,
                unitHealthMax = unitHealthMax,
                manaTTD = getTTD(unitPower, mrate),
                ttd = getTTD(unitHealth, hrate),
                dtps = -hrate,
                dti = dti,
                isFriend = UnitIsFriend("player", _unit),
                inCombat = UnitAffectingCombat(_unit),
                exists = exists,
                unitName = UnitName(_unit)
            }
            metrics.targets[guid] = unit
        end
    end
    local friendlyTargets = filter(metrics.targets, function(x)
            return x.isFriend
    end);
    local enemyTargets = filter(metrics.targets, function(x)
            return not x.isFriend
    end)
    
    metrics.maxttd_enemies = maxVal(enemyTargets, 'ttd') or metrics.maxttd_enemies
    metrics.minttd_party = minVal(friendlyTargets, 'ttd') or metrics.minttd_party
    metrics.ttd_mana_self = metrics.targets[UnitGUID('player')] and metrics.targets[UnitGUID('player')].manaTTD or
    metrics.ttd_mana_self
    metrics.self_dtinterval = metrics.targets[UnitGUID('player')] and metrics.targets[UnitGUID('player')].dti or
    metrics.self_dtinterval
    
    _metrics = metrics
    return metrics
    
end

