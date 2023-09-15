
local function GetSpellValueFromTooltip(spellID)
    
    if not spellID then
        return nil, nil
    end
    local tooltip = CreateFrame("GameTooltip", "MyScanningTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:SetSpellByID(spellID)
    local spellValueMin, spellValueMax, overTime
    for i = 1, tooltip:NumLines() do
        local line = _G["MyScanningTooltipTextLeft" .. i]
        local text = line:GetText()
        
        
        spellValueMin, spellValueMax = string.match(text, "(%d+)%s+to%s+(%d+)")
        if not (spellValueMin and spellValueMax) then
            spellValueMin = string.match(text, "restores%s+(%d+)%s+health")
        end
        
        overTime = string.match(text, "over%s+(%d+)%s+sec")
        
        if spellValueMin and not overTime then
            break
        end
    end
    
    if overTime and text and not string.find(text, "and an additional") then
        spellValueMin = spellValueMin / overTime
        spellValueMax = spellValueMax and spellValueMax / overTime or nil
    end     
    
    return spellValueMin, spellValueMax
end

-- Function to calculate spell cast time
local function CalculateSpellCastTime(spellID)
    local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
    if not castTime then
        return math.huge
    end
    return (castTime / 1000) 
end



local function GeneratePlayerSpellList()
    local i = 1
    local spellList = {}
    while true do
        local spellName, _, spellId = GetSpellBookItemName(i, "spell")
        local spellType,_ = GetSpellBookItemInfo(i, "spell")
        local valueMin = GetSpellValueFromTooltip(spellId)
        local castTime = CalculateSpellCastTime(spellId)
        
        if not spellName then
            break
        end
        
        
        if spellType ~= "FUTURESPELL" and valueMin then
            print(spellName,valueMin)
            table.insert(spellList, {id = spellId, name = spellName, valueMin = valueMin, castTime=castTime})
        end
        i = i + 1
    end
    return spellList
end

local spellList = GeneratePlayerSpellList()

function GetPlayerSpellList()
    return spellList 
end
-- Helper function to filter a table based on a condition
function filter(tbl, condition)
    local out = {}
    for i, v in ipairs(tbl) do
        if condition(v) then
            table.insert(out, v)
        end
    end
    return out
end


