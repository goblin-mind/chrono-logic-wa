-- Do not remove this comment, it is part of this aura: abilities
function()
    return  logger.logLevel > 3 and '' or tableToAlignedString(spellList,{orderBy = "dps", columns = {'id',"name",'effectType',"valueMin","dps",'targetable',"rank","castTime","duration","manaCost","cooldown"}})
end

-- Do not remove this comment, it is part of this aura: core
function()
    
    return  logger.logLevel >3 and '' or tableToAlignedString(GetEveryBestSpellUnitPotential(),{orderBy = "potential",columns={"name","rank","effectType","potential","dps","unit","unitHealth","dtps","ttd"}})
end

-- Do not remove this comment, it is part of this aura: chronology
function()
    return  logger.trace(getRawData())
end




-- Do not remove this comment, it is part of this aura: metrics
function()
    return  logger.debug(getMetrics())
end




-- Do not remove this comment, it is part of this aura: action
function()
    return aura_env.rank..'\n'..aura_env.targetname
end

