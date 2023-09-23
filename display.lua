-- Do not remove this comment, it is part of this aura: abilities
function()
    return  logger.logLevel > 2 and '' or tableToAlignedString(spellList)
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

