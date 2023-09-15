

-- PARTY KNOWLEDGE
local soloUnit = {"player"}
local partyUnits = {"player", "party1", "party2", "party3", "party4"}
local function generateRaidUnits()
    local units = {"player"}
    for i = 1, 40 do
        table.insert(units, string.format("raid%d", i))
    end
    return units
end
local raidUnits = generateRaidUnits()

local function addUnit(result,toinsert)
    
    if UnitExists(toinsert) and UnitIsDead(toinsert)~=nil then
        
        table.insert(result,toinsert )
    end
    return result
end


function getRelevantUnits(group)
    
    local _result = {}
    local result ={}
    
    if UnitExists("raid1") then
        _result = raidUnits
    elseif UnitExists("party1") then
        _result = partyUnits
    else
        _result =  soloUnit
        
    end
    
    -- Add enemy targets
    if group == "enemy" then
        for _, unit in ipairs(_result) do
            result = addUnit(result,unit .. "target")
        end
        --result = addUnit(result, "target")
        return result;
    else
        print("notenemy?")
        
        return _result;
    end
    
end

