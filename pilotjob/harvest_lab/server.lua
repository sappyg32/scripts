local ox_inventory = exports.ox_inventory

---------------------------------------------------------------------
-- Give harvested item
---------------------------------------------------------------------
lib.callback.register('harvest:giveItem', function(source, item, amount)
    local added = ox_inventory:AddItem(source, item, amount)
    return added and true or false
end)

---------------------------------------------------------------------
-- Processing
---------------------------------------------------------------------
lib.callback.register('harvest:process', function(source, costItem, costAmount, rewardItem, rewardAmount)
    local removed = ox_inventory:RemoveItem(source, costItem, costAmount)
    if not removed then return false end

    if not ox_inventory:AddItem(source, rewardItem, rewardAmount) then
        -- roll back so the player doesn't lose their input
        ox_inventory:AddItem(source, costItem, costAmount)
        return false
    end

    return true
end)

---------------------------------------------------------------------
-- Selling
---------------------------------------------------------------------
lib.callback.register('harvest:sell', function(source, item, amount, payout)
    local removed = ox_inventory:RemoveItem(source, item, amount)
    if not removed then return false end

    if not ox_inventory:AddItem(source, 'money', payout) then
        ox_inventory:AddItem(source, item, amount)   -- roll back
        return false
    end

    return true
end)
