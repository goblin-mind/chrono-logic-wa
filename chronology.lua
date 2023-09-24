
local function filter(tbl, condition)
    local out = {}
    for i, v in ipairs(tbl) do
        if condition(v) then
            table.insert(out, v)
        end
    end
    return out
end
--chronology
local metricDataWA = metricDataWA or {}
local metricRatesWA = metricRatesWA or {}
local metricIntervals = metricIntervals or {}
function ResetTarget(unit)
    logger.debug("ResetTarget:",unit)
    
    metricDataWA[unit] = {}
    metricRatesWA[unit] = {}
    
    UpdateRates(unit,'HEALTH',UnitHealth(unit))
    C_Timer.After(1,function() UpdateRates(unit,'HEALTH',UnitHealth(unit)) end)
end

function getRawData() 
    return {metricDataWA=metricDataWA, metricRatesWA=metricRatesWA}
end

function UpdateRates(unit, metric, value)
    local guid = unit
    local timestamp = GetTime()
    -- Initialization code ...
    
    -- Initialize if nil
    if not metricDataWA then metricDataWA = {} end
    if not metricRatesWA then metricRatesWA = {} end
    if not metricIntervals then metricIntervals = {} end
    
    -- Check GUID
    if not guid then return end
    if not metricDataWA[guid] then metricDataWA[guid] = {} end
    if not metricRatesWA[guid] then metricRatesWA[guid] = {} end
    if not metricIntervals[guid] then metricIntervals[guid] = {} end
    
    -- Check metric
    if not metricDataWA[guid][metric] then
        metricDataWA[guid][metric] = {}
    end
    
    
    table.insert(metricDataWA[guid][metric], {value = value, timestamp = timestamp})
    logger.debug("senseValue:", unit,metric, value,'time:'..timestamp)
    -- Remove samples older than 3 seconds
    local currentTime = timestamp
    if (metricRatesWA[guid][metric] and metricRatesWA[guid][metric]>=0)then
        metricDataWA[guid][metric] = filter(metricDataWA[guid][metric], function(sample)
                return currentTime - sample.timestamp <= 5
        end)
    end
    
    local lastValue = nil
    local lastTimestamp = nil
    local minInterval = math.huge
    -- Calculate average rate (per second) considering positive and negative deltas
    local sum = 0
    local totalTime = 0
    for i = 2, #metricDataWA[guid][metric] do
        local deltaValue = metricDataWA[guid][metric][i].value - metricDataWA[guid][metric][i-1].value
        local deltaTime = metricDataWA[guid][metric][i].timestamp - metricDataWA[guid][metric][i-1].timestamp
        sum = sum + deltaValue
        totalTime = totalTime + deltaTime
        
        if deltaValue < 0 then
            minInterval = math.min(minInterval, deltaTime)
        end
    end
    
    
    
    local avgRate = (totalTime > 0) and (sum / totalTime) or 0
    metricIntervals[guid][metric] = minInterval
    metricRatesWA[guid][metric] = avgRate
    logger.debug("senseRate:", unit, metric, metricRatesWA[guid][metric])
end


local function isHealer(unitID)
    local _, unitClass = UnitClass(unitID)
    return unitClass == "PRIEST" or unitClass == "DRUID" or unitClass == "PALADIN" or unitClass == "SHAMAN"
end
local _metrics = {}
function getMetrics()
    return _metrics
end
function generateMetrics()
    local metrics = {
        minttd_party = {value = math.huge, targets = {}},
        max_dtps_party = {value = 0},
        maxttd_enemies = {value = 0, targets = {}},
        min_dtps_enemies = {value = math.huge},
        ttd_mana_self = 0,
        ttd_otherhealers = 0,
        average_dtps_party = 0,
        max_missing_hp = 0,
        party_num_hp50_dtpsgt0 = 0,
        enemy_num_hp50_dtpsgt0 = 0,
        friendly_targets = {},
        party_mindtinterval=math.huge
    }
    
    local totalDtpsParty = 0
    local partyCount = 0
    local max_missing_hp = 0
    for _unit, metricTable in pairs(metricRatesWA or {}) do
        local unitHealth = UnitHealth(_unit) or 0
        local unitHealthMax = UnitHealthMax(_unit) or 1
        local missingHp = unitHealthMax - unitHealth
        local unitPower = UnitPower(_unit, 0) or 0
        local rate = metricTable and metricTable['HEALTH'] or 0
        local ttd = (rate ~= 0) and (unitHealth / -rate) or math.huge
        local unit = {unit=_unit,unitHealth=unitHealth,unitHealthMax=unitHealthMax}
        if UnitIsFriend("player", _unit) then
            table.insert(metrics.friendly_targets,unit)
            if max_missing_hp>metrics.max_missing_hp then 
                --todo check dead
                metrics.max_missing_hp = max_missing_hp
            end
            if rate <= 0 then
                if ttd < metrics.minttd_party.value then
                    metrics.minttd_party.value = ttd
                    metrics.minttd_party.targets = {unit}
                    
                elseif ttd == metrics.minttd_party.value then
                    table.insert(metrics.minttd_party.targets, unit)
                end
                
                local dtps = -rate
                if dtps > metrics.max_dtps_party.value then
                    metrics.max_dtps_party.value = dtps
                end
                
                totalDtpsParty = totalDtpsParty + dtps
                partyCount = partyCount + 1
            end
            local dtinterval = metricIntervals[_unit]["HEALTH"]
            if dtinterval and dtinterval<metrics.party_mindtinterval then
                metrics.party_mindtinterval = dtinterval
            end
            
            if unitHealth / unitHealthMax <= 0.5 and rate > 0 then
                metrics.party_num_hp50_dtpsgt0 = metrics.party_num_hp50_dtpsgt0 + 1
            end
            if isHealer(_unit) then
                local healerManaRate = metricTable and metricTable['MANA'] or 0
                if healerManaRate < 0 and unitPower > 0 then
                    local ttd = unitPower / -healerManaRate
                    if ttd < metrics.ttd_otherhealers or metrics.ttd_otherhealers == 0 then
                        metrics.ttd_otherhealers = ttd
                    end
                end
            end
        else
            
            if rate <= 0 then
                local dtps = -rate
                if dtps < metrics.min_dtps_enemies.value then
                    metrics.min_dtps_enemies.value = dtps
                end
                
                if ttd > metrics.maxttd_enemies.value then
                    metrics.maxttd_enemies.value = ttd
                    metrics.maxttd_enemies.targets = {unit}
                elseif ttd == metrics.maxttd_enemies.value then
                    table.insert(metrics.maxttd_enemies.targets, unit)
                end
            end
            
            if unitHealth / unitHealthMax <= 0.5 and rate < 0 then
                metrics.enemy_num_hp50_dtpsgt0 = metrics.enemy_num_hp50_dtpsgt0 + 1
            end
        end
    end
    
    if partyCount > 0 then
        metrics.average_dtps_party = totalDtpsParty / partyCount
    end
    
    local selfManaRate = metricRatesWA["player"] and metricRatesWA["player"]["MANA"] or 0
    local selfPower = UnitPower("player", 0) or 0
    
    
    if selfManaRate < 0 and selfPower > 0 then
        metrics.ttd_mana_self = selfPower / -selfManaRate
    else
        metrics.ttd_mana_self = math.huge
    end
    _metrics = metrics
    return metrics
    
end

