local QBCore = exports['qb-core']:GetCoreObject()

-- ==============================================================================
-- 1. ZÍSKÁNÍ DAT (Router)
-- Klient nám posílá své Serial Number, které získal z GetTabletData()
-- ==============================================================================
RegisterNetEvent('aprts_darknet:server:getData', function(view, clientSerial)
    local src = source
    local serial = clientSerial

    if not serial then return end 

    -- 1. Zjistíme reputaci
    local repResult = exports.oxmysql:singleSync('SELECT reputation FROM tablet_darknet_rep WHERE tablet_serial = ?', {serial})
    local rep = repResult and repResult.reputation or 0

    local response = {
        view = view,
        reputation = rep
    }

    -- 2. Načteme zakázky podle view
    if view == 'market' then
        response.marketJobs = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE status = "open" AND creator_serial != ?', {serial})

    elseif view == 'myjobs' then
        response.postedJobs = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE creator_serial = ? AND status != "completed"', {serial})
        local active = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE worker_serial = ? AND status = "active"', {serial})
        response.activeJob = active[1]
    end

    -- 3. Pošleme data zpět
    TriggerClientEvent('aprts_darknet:client:updateData', src, response)
end)

-- ==============================================================================
-- 2. SYSTÉMOVÉ ZAKÁZKY (Kontrola reputace před startem)
-- ==============================================================================
RegisterNetEvent('aprts_darknet:server:tryStartSystemJob', function(jobId, clientSerial)
    local src = source
    local serial = clientSerial
    local jobCfg = Config.Jobs[jobId]

    if not serial or not jobCfg then return end

    local repResult = exports.oxmysql:singleSync('SELECT reputation FROM tablet_darknet_rep WHERE tablet_serial = ?', {serial})
    local currentRep = repResult and repResult.reputation or 0

    if currentRep >= jobCfg.minReputation then
        TriggerClientEvent('aprts_darknet:client:startSystemJob', src, jobId)
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Nedostatečná reputace zařízení.'})
    end
end)

-- ==============================================================================
-- 3. HRÁČSKÉ ZAKÁZKY - VYTVOŘENÍ
-- ==============================================================================
RegisterNetEvent('aprts_darknet:server:createCustomJob', function(data, clientSerial)
    local src = source
    local serial = clientSerial
    if not serial then return end

    -- Kontrola reputace
    local repResult = exports.oxmysql:singleSync('SELECT reputation FROM tablet_darknet_rep WHERE tablet_serial = ?', {serial})
    local rep = repResult and repResult.reputation or 0

    if rep < Config.CustomJobRepLimit then
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Nedostatečná reputace pro vypsání zakázky.'})
        return
    end

    -- Vložení do DB
    exports.oxmysql:insert('INSERT INTO darknet_custom_jobs (creator_serial, title, description, reward) VALUES (?, ?, ?, ?)', {
        serial, data.title, data.description, tonumber(data.reward)
    })
    
    TriggerClientEvent('ox_lib:notify', src, {type='success', description='Zakázka zapsána do sítě.'})
    
    -- Okamžitý refresh UI pro klienta
    local myPosted = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE creator_serial = ? AND status != "completed"', {serial})
    local active = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE worker_serial = ? AND status = "active"', {serial})

    TriggerClientEvent('aprts_darknet:client:updateData', src, {
        view = 'myjobs',
        reputation = rep,
        postedJobs = myPosted,
        activeJob = active[1]
    })
end)

-- ==============================================================================
-- 4. HRÁČSKÉ ZAKÁZKY - PŘIJETÍ
-- ==============================================================================
RegisterNetEvent('aprts_darknet:server:acceptCustomJob', function(jobId, clientSerial)
    local src = source
    local serial = clientSerial
    if not serial then return end

    -- Kontrola aktivní zakázky
    local activeCheck = exports.oxmysql:singleSync('SELECT count(*) as count FROM darknet_custom_jobs WHERE worker_serial = ? AND status = "active"', {serial})
    if activeCheck.count > 0 then
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Toto zařízení již zpracovává jinou zakázku.'})
        return
    end

    -- Update DB
    local changed = exports.oxmysql:update('UPDATE darknet_custom_jobs SET worker_serial = ?, status = "active" WHERE id = ? AND status = "open"', {
        serial, jobId
    })

    if changed > 0 then
        TriggerClientEvent('ox_lib:notify', src, {type='success', description='Zakázka přijata.'})

        -- Okamžitý refresh UI
        local repResult = exports.oxmysql:singleSync('SELECT reputation FROM tablet_darknet_rep WHERE tablet_serial = ?', {serial})
        local rep = repResult and repResult.reputation or 0
        local myPosted = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE creator_serial = ? AND status != "completed"', {serial})
        local active = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE worker_serial = ? AND status = "active"', {serial})

        TriggerClientEvent('aprts_darknet:client:updateData', src, {
            view = 'myjobs',
            reputation = rep,
            postedJobs = myPosted,
            activeJob = active[1]
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Zakázka již není dostupná.'})
        -- Refresh marketu
        local marketJobs = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE status = "open" AND creator_serial != ?', {serial})
        TriggerClientEvent('aprts_darknet:client:updateData', src, { view = 'market', marketJobs = marketJobs })
    end
end)

-- ==============================================================================
-- 5. CHAT SYSTÉM
-- ==============================================================================
lib.callback.register('aprts_darknet:server:getChatMessages', function(source, jobId, clientSerial)
    local serial = clientSerial
    local job = exports.oxmysql:singleSync('SELECT * FROM darknet_custom_jobs WHERE id = ?', {jobId})
    
    if job and (job.creator_serial == serial or job.worker_serial == serial) then
        return exports.oxmysql:executeSync('SELECT * FROM darknet_messages WHERE job_id = ? ORDER BY created_at ASC', {jobId})
    end
    return {}
end)

RegisterNetEvent('aprts_darknet:server:sendChat', function(jobId, message, clientSerial)
    local src = source
    local serial = clientSerial
    if not serial then return end

    exports.oxmysql:insert('INSERT INTO darknet_messages (job_id, sender_serial, message) VALUES (?, ?, ?)', {
        jobId, serial, message
    })

    local msgObj = {
        job_id = jobId,
        sender_serial = serial,
        message = message,
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }
    TriggerClientEvent('aprts_darknet:client:chatMessage', -1, msgObj)
end)

-- ==============================================================================
-- 6. UKONČENÍ ZAKÁZKY (Smazání)
-- ==============================================================================
RegisterNetEvent('aprts_darknet:server:finishCustomJob', function(jobId, clientSerial)
    local src = source
    local serial = clientSerial
    
    local job = exports.oxmysql:singleSync('SELECT * FROM darknet_custom_jobs WHERE id = ? AND creator_serial = ?', {jobId, serial})
    
    if job then
        exports.oxmysql:execute('DELETE FROM darknet_messages WHERE job_id = ?', {jobId})
        exports.oxmysql:update('UPDATE darknet_custom_jobs SET status = "completed" WHERE id = ?', {jobId})
        
        TriggerClientEvent('ox_lib:notify', src, {type='success', description='Zakázka uzavřena.'})
        
        -- Refresh
        local myPosted = exports.oxmysql:executeSync('SELECT * FROM darknet_custom_jobs WHERE creator_serial = ? AND status != "completed"', {serial})
        TriggerClientEvent('aprts_darknet:client:updateData', src, { view = 'myjobs', postedJobs = myPosted })
    end
end)


-- ==============================================================================
-- 7. (CHYBĚJÍCÍ EVENT) DOKONČENÍ SYSTÉMOVÉ ZAKÁZKY
-- Voláno z client.lua funkcí FinishActiveMission
-- ==============================================================================
RegisterNetEvent('aprts_darknet:server:claimSystemReward', function(jobId, clientSerial)
    local src = source
    local serial = clientSerial
    local jobCfg = Config.Jobs[jobId]

    if not serial or not jobCfg then return end

    -- Získáme hráče pro výplatu peněz
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- 1. Připsat reputaci tabletu
    exports.oxmysql:execute('INSERT INTO tablet_darknet_rep (tablet_serial, reputation) VALUES (?, ?) ON DUPLICATE KEY UPDATE reputation = reputation + ?', {
        serial, jobCfg.repReward, jobCfg.repReward
    })

    -- 2. Dát peníze hráči
    if jobCfg.payout and jobCfg.payout > 0 then
        Player.Functions.AddMoney('cash', jobCfg.payout, "darknet-job")
    end

    TriggerClientEvent('ox_lib:notify', src, {type='success', description='Zakázka splněna. Reputace +'..jobCfg.repReward..' | Hotovost $'..jobCfg.payout})
end)


-- ==============================================================================
-- 8. EXPORT: COMPLETE JOB (Pro externí scripty)
-- ==============================================================================
exports('CompleteJob', function(src, jobId, success)
    local jobCfg = Config.Jobs[jobId]
    if not jobCfg then return false end

    -- Získáme všechny itemy hráče z Ox Inventory
    local items = exports.ox_inventory:GetInventoryItems(src)
    if not items then return false end

    -- Fallback: Hledání tabletu v inventáři
    local serial = nil
    
    for _, item in pairs(items) do
        -- Kontrola názvu itemu (tablet, aprts_tablet...)
        if item and (item.name == 'tablet' or item.name == 'aprts_tablet') then
             -- OX Inventory ukládá data do .metadata
             if item.metadata then
                -- Zkusíme různé varianty, jak ox ukládá sériová čísla
                if item.metadata.series then serial = item.metadata.series end
                if item.metadata.serial then serial = item.metadata.serial end
                if item.metadata.serialNumber then serial = item.metadata.serialNumber end
             end
             
             if serial then break end
        end
    end

    if not serial then 
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Chyba: Nemáš u sebe tablet pro připsání reputace!'})
        return false 
    end

    if success then
        exports.oxmysql:execute('INSERT INTO tablet_darknet_rep (tablet_serial, reputation) VALUES (?, ?) ON DUPLICATE KEY UPDATE reputation = reputation + ?', {
            serial, jobCfg.repReward, jobCfg.repReward
        })
        
        -- Peníze dáváme stále přes QBCore, protože Ox spravuje itemy, ne nutně cash (záleží na nastavení)
        -- Pokud máš peníze jako item v inventáři ('money'), použij exports.ox_inventory:AddItem(src, 'money', amount)
        if jobCfg.payout then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                Player.Functions.AddMoney('cash', jobCfg.payout, "darknet-job")
            end
        end

        TriggerClientEvent('ox_lib:notify', src, {type='success', description='Reputace zařízení zvýšena.'})
        return true
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Mise selhala.'})
        return false
    end
end)

-- ==============================================================================
-- 9. POMOCNÉ EVENTY PRO MISE (QBCore)
-- ==============================================================================

-- 1. Dát item hráči na začátku mise
RegisterNetEvent('aprts_darknet:server:giveMissionItem', function(item, amount)
    local src = source
    
    -- Použijeme export ox_inventory
    local canCarry = exports.ox_inventory:CanCarryItem(src, item, amount)
    
    if canCarry then
        exports.ox_inventory:AddItem(src, item, amount)
        -- Notifikaci "Obdržel jsi..." řeší ox_lib/inventory automaticky, ale pro jistotu:
        -- TriggerClientEvent('ox_lib:notify', src, {type='success', description='Obdržel jsi zboží.'})
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Máš plné kapsy! Zboží se nevešlo.'})
    end
end)

-- 2. Zkontrolovat a odebrat item při prodeji (Callback)
lib.callback.register('aprts_darknet:server:checkAndRemoveItem', function(source, item, amount)
    -- ox_inventory:RemoveItem vrátí true pouze pokud se item podařilo odebrat (hráč ho měl dostatek)
    local success = exports.ox_inventory:RemoveItem(source, item, amount)
    return success
end)