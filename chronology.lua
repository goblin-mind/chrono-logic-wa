local function filter(tbl, condition)
    local out = {}
    for i, v in ipairs(tbl) do
        if condition(v) then
            table.insert(out, v)
        end
    end
    return out
end
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
        metricRatesWA = metricRatesWA
    }
end

function UpdateRates(unit, metric, value)
    local guid = unit
    local timestamp = GetTime()
    -- Initialization code ...

    -- Initialize if nil
    if not metricDataWA then
        metricDataWA = {}
    end
    if not metricRatesWA then
        metricRatesWA = {}
    end
    if not metricIntervals then
        metricIntervals = {}
    end

    -- Check GUID
    if not guid then
        return
    end
    if not metricDataWA[guid] then
        metricDataWA[guid] = {}
    end
    if not metricRatesWA[guid] then
        metricRatesWA[guid] = {}
    end
    if not metricIntervals[guid] then
        metricIntervals[guid] = {}
    end

    -- Check metric
    if not metricDataWA[guid][metric] then
        metricDataWA[guid][metric] = {}
    end

    table.insert(metricDataWA[guid][metric], {
        value = value,
        timestamp = timestamp
    })
    logger.trace("senseValue:", unit, metric, value, 'time:' .. timestamp)
    -- Remove samples older than 3 seconds
    local currentTime = timestamp
    if (metricRatesWA[guid][metric] and metricRatesWA[guid][metric] >= 0) then
        metricDataWA[guid][metric] = filter(metricDataWA[guid][metric], function(sample)
            return currentTime - sample.timestamp <= 2
        end)
    end

    local lastValue = nil
    local lastTimestamp = nil
    local minInterval = math.huge
    -- Calculate average rate (per second) considering positive and negative deltas
    local sum = 0
    local totalTime = 0

    local criticalSeries = metricDataWA[guid][metric]
    for i = 2, #criticalSeries do
        local deltaValue = criticalSeries[i].value - criticalSeries[i - 1].value
        local deltaTime = criticalSeries[i].timestamp - criticalSeries[i - 1].timestamp
        sum = sum + deltaValue
        totalTime = totalTime + deltaTime

        if deltaValue < 0 then
            minInterval = math.min(minInterval, deltaTime)
        end
    end

    local avgRate = (totalTime > 0) and (sum / totalTime) or 0
    metricIntervals[guid][metric] = minInterval
    metricRatesWA[guid][metric] = avgRate
    logger.trace("senseRate:", unit, metric, metricRatesWA[guid][metric])
end

local function isHealer(unitID)
    local _, unitClass = UnitClass(unitID)
    return unitClass == "PRIEST" or unitClass == "DRUID" or unitClass == "PALADIN" or unitClass == "SHAMAN"
end
local _metrics = {}
function getMetrics()
    return _metrics
end
local function getTTD(unitHealth, rate)

    return unitHealth > 0 and ((rate ~= 0) and (unitHealth / -rate) or math.huge) or 0
end
local function maxBy(targets, metric)
    return reduce(map(targets, metric), math.max, -math.huge)
end

local function minBy(targets, metric)
    return reduce(map(targets, metric), math.min, math.huge)
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
        if UnitExists(_unit) then
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
                inCombat = UnitAffectingCombat(_unit)
            }
            metrics.targets[UnitGUID(_unit)] = unit
        end
    end
    local friendlyTargets = filter(metrics.targets, function(x)
        return x.isFriend
    end);
    local enemyTargets = filter(metrics.targets, function(x)
        return not x.isFriend
    end)

    metrics.maxttd_enemies = maxBy(enemyTargets, 'ttd')
    metrics.minttd_party = minBy(friendlyTargets, 'ttd')
    metrics.ttd_mana_self = metrics.targets[UnitGUID('player')] and metrics.targets[UnitGUID('player')].manaTTD
    metrics.self_dtinterval = metrics.targets[UnitGUID('player')] and metrics.targets[UnitGUID('player')].dti

    _metrics = metrics
    return metrics

end

