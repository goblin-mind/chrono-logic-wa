-- Initialize global data storage
local metricDataWA = metricDataWA or {}
metricRatesWA = metricRatesWA or {}


maxUnits = 80  -- Maximum number of unique units to keep track of
unitList = {}  -- List to keep track of unit order


function ResetTarget(guid,unit)
    print("ResetTarget:",guid)
    if guid then
        
        
        
        metricDataWA[guid] = {}
        metricRatesWA[guid] = {}
        
    end
    UpdateRates('target','HEALTH',UnitHealth('target'),math.huge)
    
end


function UpdateRates(unit, metric, value)
    local guid = UnitGUID(unit)
    local timestamp = GetTime()
    -- Initialization code ...
    
    -- Initialize if nil
    if not metricDataWA then metricDataWA = {} end
    if not metricRatesWA then metricRatesWA = {} end
    if not unitList then unitList = {} end
    
    -- Check GUID
    if not guid then return end
    if not metricDataWA[guid] then metricDataWA[guid] = {} end
    if not metricRatesWA[guid] then metricRatesWA[guid] = {} end
    
    -- Check metric
    if not metricDataWA[guid][metric] then
        metricDataWA[guid][metric] = {}
    end
    
    
    table.insert(metricDataWA[guid][metric], {value = value, timestamp = timestamp})
    print("senseValue:", guid, unit, value,timestamp)
    -- Remove samples older than 3 seconds
    local currentTime = timestamp
    if (metricRatesWA[guid][metric]~=0)then
        metricDataWA[guid][metric] = filter(metricDataWA[guid][metric], function(sample)
                return currentTime - sample.timestamp <= 3
        end)
    end
    
    -- Calculate average rate (per second) considering positive and negative deltas
    local sum = 0
    local totalTime = 0
    for i = 2, #metricDataWA[guid][metric] do
        local deltaValue = metricDataWA[guid][metric][i].value - metricDataWA[guid][metric][i-1].value
        local deltaTime = metricDataWA[guid][metric][i].timestamp - metricDataWA[guid][metric][i-1].timestamp
        sum = sum + deltaValue
        totalTime = totalTime + deltaTime
    end
    
    local avgRate = (totalTime > 0) and (sum / totalTime) or 0
    
    metricRatesWA[guid][metric] = avgRate
    print("senseRate:", guid, unit, metric, metricRatesWA[guid][metric])
end


-- Function to calculate Time to Death based on stored decay rates
function GetTTD(unit,metric)
    local guid = UnitGUID(unit)
    -- Ensure metricRatesWA is initialized and has data for the unit and metric
    if not metricRatesWA or not metricRatesWA[guid] or not metricRatesWA[guid][metric] then
        return math.huge  -- Return infinite time if data is not available
    end
    
    local decayRate = metricRatesWA[guid][metric]
    
    if decayRate >= 0 then 
        return math.huge  -- If health is stable or increasing, return infinite TTD
    end
    
    local currentHealth = metric=='health' and UnitHealth(unit)or UnitPower(unit)
    return currentHealth / math.abs(decayRate)
end

