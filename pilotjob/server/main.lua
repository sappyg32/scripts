local ESX = exports.es_extended:getSharedObject()

RegisterNetEvent('pilotjob:reward', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    amount = tonumber(amount) or Config.Payout
    if amount <= 0 or amount > 100000 then return end

    local paid = false
    if GetResourceState('ox_inventory') == 'started' then
        paid = exports.ox_inventory:AddItem(src, 'money', amount)
    end
    if not paid then
        xPlayer.addAccountMoney('bank', amount)
    end

    TriggerClientEvent('esx:showNotification', src,
        ('You were paid ~g~$%s~s~ for the flight.'):format(amount))
end)
