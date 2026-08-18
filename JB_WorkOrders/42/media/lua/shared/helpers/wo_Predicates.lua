local Predicates = {
    ChopTree = function(item) return not item:isBroken() and item:hasTag(ItemTag.CHOP_TREE) end,
    WoodSaw  = function(item) return not item:isBroken() and item:hasTag(ItemTag.SAW) end,
    CutPlant = function(item) return not item:isBroken() and item:hasTag(ItemTag.CUT_PLANT) end,
    DigStump = function(item) return not item:isBroken() and item:hasTag(ItemTag.REMOVE_STUMP) end,
    -- pickaxes are different, of course
    Digging = function(item)
        if item:isBroken() then return false end
        return item:hasTag(ItemTag.HAMMER) or item:hasTag(ItemTag.SLEDGEHAMMER) or item:hasTag(ItemTag.CLUB_HAMMER) or
            item:hasTag(ItemTag.PICK_AXE) or item:getType() == "PickAxe" or item:hasTag(ItemTag.STONE_MAUL)
    end,
}

return Predicates
