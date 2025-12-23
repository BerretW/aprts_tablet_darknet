local QBCore = exports['qb-core']:GetCoreObject()

-- Pomocná funkce pro získání ID
local function GetIdentifier(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid or nil
end

-- 1. Získání dat pro Darknet (Reputace)
RegisterNetEvent('aprts_darknet:server:getData', function()
    local src = source
    local ident = GetIdentifier(src)
    if not ident then return end

    local result = exports.oxmysql:singleSync('SELECT reputation FROM player_darknet_rep WHERE identifier = ?', {ident})
    local rep = result and result.reputation or 0

    TriggerClientEvent('aprts_darknet:client:receiveData', src, rep)
end)

-- 2. Zahájení jobu (Kontrola reputace na serveru pro jistotu)
RegisterNetEvent('aprts_darknet:server:tryStartJob', function(jobId)
    local src = source
    local ident = GetIdentifier(src)
    local jobCfg = Config.Jobs[jobId]

    if not ident or not jobCfg then return end

    local result = exports.oxmysql:singleSync('SELECT reputation FROM player_darknet_rep WHERE identifier = ?', {ident})
    local currentRep = result and result.reputation or 0

    if currentRep >= jobCfg.minReputation then
        -- Povoleno -> Pošleme klientovi pokyn spustit export
        TriggerClientEvent('aprts_darknet:client:startJobSuccess', src, jobId)
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Nemáš dostatečnou reputaci!'})
    end
end)

-- 3. Dokončení jobu (Voláno přes export z jiného scriptu nebo event)
-- Použití z jiného server scriptu: exports['aprts_tablet_darknet']:CompleteJob(source, 'package_run', true)
exports('CompleteJob', function(src, jobId, success)
    local jobCfg = Config.Jobs[jobId]
    if not jobCfg then return false end

    local ident = GetIdentifier(src)
    if not ident then return false end

    if success then
        -- 1. Přidat reputaci
        exports.oxmysql:execute('INSERT INTO player_darknet_rep (identifier, reputation) VALUES (?, ?) ON DUPLICATE KEY UPDATE reputation = reputation + ?', {
            ident, jobCfg.repReward, jobCfg.repReward
        })

        -- 2. Dát peníze (pokud jsou definovány v configu)
        if jobCfg.payout and jobCfg.payout > 0 then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                Player.Functions.AddMoney('cash', jobCfg.payout, "darknet-job")
            end
        end

        TriggerClientEvent('ox_lib:notify', src, {type='success', description='Zakázka splněna! Reputace +'..jobCfg.repReward})
    else
        -- Možnost odebrat reputaci při selhání?
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Zakázka selhala.'})
    end
end)

