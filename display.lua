-- Do not remove this comment, it is part of this aura: abilities
function()
    return  logger.logLevel > 2 and '' or tableToAlignedString(spellList,{orderBy = "dps", columns = {"name",'effectType',"valueMin","dps",'targetable',"rank","castTime","duration","manaCost"}})
end

-- Do not remove this comment, it is part of this aura: core
function()
    
    return  logger.logLevel >2 and '' or tableToAlignedString(GetEveryBestSpellUnitPotential(),{orderBy = "potential",columns={"name","rank","effectType","potential","dps","unit","unitHealth","dtps","ttd"}})
end

-- Do not remove this comment, it is part of this aura: chronology
function()
    return  logger.logLevel > 1 and '' or stringifyTable(getRawData())
end




-- Do not remove this comment, it is part of this aura: metrics
function()
    return  logger.logLevel >2 and '' or stringifyTable(getMetrics())
end




-- Do not remove this comment, it is part of this aura: action
function()
    return aura_env.rank
end

