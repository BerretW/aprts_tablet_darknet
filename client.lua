local APP_ID = Config.AppName
local currentTabletSerial = nil
activeMission = nil 

-- Globální tabulka pro registrace misí (aby k ní měly přístup soubory ve složce missions/)
DarknetMissions = {} 

CreateThread(function()
    Wait(1000)
    exports['aprts_tablet']:RegisterApp(APP_ID, Config.Label, Config.Icon, Config.Color, APP_ID..':open', nil, 50, 'all')
end)

local function LoadWebFile(fileName)
    return LoadResourceFile(GetCurrentResourceName(), 'web/' .. fileName)
end

-- 1. Otevření aplikace
RegisterNetEvent(APP_ID..':open', function()
    local tabletData = exports['aprts_tablet']:GetTabletData()
    if not tabletData then return end
    
    -- Uložíme sériové číslo
    currentTabletSerial = tabletData.serial
    
    -- Kontrola připojení
    if not tabletData.wifi or not tabletData.wifi.isConnected then
        exports['aprts_tablet']:loadContent([[
            <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; height:100%; color:white; text-align:center; font-family:monospace;">
                <i class="fas fa-signal" style="font-size:50px; margin-bottom:20px; color:#d63031;"></i>
                <h2>OFFLINE</h2>
                <p>Připojení k síti selhalo.</p>
            </div>
        ]])
        return
    end

    local html = LoadWebFile('index.html')
    if html then
        html = html:gsub('{{SERIAL}}', currentTabletSerial or "UNKNOWN")
        TriggerEvent('aprts_tablet:loadContent', html)
    end
end)

-- 2. Handlery akcí z UI
RegisterNetEvent(APP_ID..':handleAction', function(action, data)
    
    if action == 'fetchData' then
        TriggerServerEvent('aprts_darknet:server:getData', data.view, currentTabletSerial)

    elseif action == 'acceptSystemJob' then
        -- Pokud už máš misi, nepovolí další
        if activeMission then
            lib.notify({title='Darknet', description='Nejdřív dokonči aktuální zakázku!', type='error'})
            return
        end
        TriggerServerEvent('aprts_darknet:server:tryStartSystemJob', data.jobId, currentTabletSerial)

    elseif action == 'createCustomJob' then
        TriggerServerEvent('aprts_darknet:server:createCustomJob', data, currentTabletSerial)

    elseif action == 'acceptCustomJob' then
        if activeMission then
            lib.notify({title='Darknet', description='Nejdřív dokonči aktuální zakázku!', type='error'})
            return
        end
        TriggerServerEvent('aprts_darknet:server:acceptCustomJob', data.jobId, currentTabletSerial)

    elseif action == 'fetchChat' then
        local msgs = lib.callback.await('aprts_darknet:server:getChatMessages', false, data.jobId, currentTabletSerial)
        exports['aprts_tablet']:SendNui({ action = "darknet_updateChat", messages = msgs, jobId = data.jobId })

    elseif action == 'sendChat' then
        TriggerServerEvent('aprts_darknet:server:sendChat', data.jobId, data.message, currentTabletSerial)

    elseif action == 'finishCustomJob' then
        TriggerServerEvent('aprts_darknet:server:finishCustomJob', data.jobId, currentTabletSerial)
    end
end)

-- 3. Aktualizace dat v UI (Sloučení DB a Lokálních dat)
RegisterNetEvent('aprts_darknet:client:updateData', function(data)
    
    -- Pokud máme aktivní Systémovou Misi (z Configu), vložíme ji do dat pro UI
    -- Tím zajistíme, že se zobrazí v "Moje zakázky"
    if activeMission then
        local systemJobObj = {
            id = activeMission.id,           -- ID z configu
            title = activeMission.data.label,
            description = activeMission.data.description,
            reward = activeMission.data.payout or 0,
            status = 'active',
            isSystemJob = true               -- Příznak pro JS, aby skryl chat
        }

        -- Přepíšeme activeJob (protože hráč může mít jen jednu aktivní práci)
        data.activeJob = systemJobObj
    end

    exports['aprts_tablet']:SendNui({ 
        action = "darknet_updateData", 
        view = data.view, 
        reputation = data.reputation, 
        systemJobs = Config.Jobs, 
        marketJobs = data.marketJobs, 
        postedJobs = data.postedJobs, 
        activeJob = data.activeJob 
    })
end)

RegisterNetEvent('aprts_darknet:client:chatMessage', function(msg)
    exports['aprts_tablet']:SendNui({ action = "darknet_newChatMessage", message = msg })
end)


-- =============================================================================
-- LOGIKA SPOUŠTĚNÍ MISÍ (DISPEČER)
-- =============================================================================

RegisterNetEvent('aprts_darknet:client:startSystemJob', function(jobId)
    local jobData = Config.Jobs[jobId]
    if not jobData then return end

    -- Volitelné: Zavřít tablet
    -- TriggerEvent('aprts_tablet:sendNui', { action = "close" })

    -- Nastavíme aktivní misi
    activeMission = {
        id = jobId,
        type = jobData.type,
        data = jobData
    }

    -- IHNED AKTUALIZUJEME UI, aby zakázka zmizela z nabídky a objevila se v "Moje zakázky"
    -- Pošleme request na server o data 'myjobs', ten nám je vrátí a v updateData se tam přidá i tato activeMission
    TriggerServerEvent('aprts_darknet:server:getData', 'myjobs', currentTabletSerial)

    -- Spustíme logiku mise ze složky missions/
    if DarknetMissions[jobData.type] then
        DarknetMissions[jobData.type](activeMission)
    else
        print("^1[Darknet] Chyba: Neznámý typ mise '"..tostring(jobData.type).."' v Configu!^0")
        activeMission = nil
    end
end)

-- Globální funkce pro dokončení (volají ji moduly: delivery/client.lua, heist/client.lua atd.)
function FinishActiveMission(success)
    if not activeMission then return end
    
    local jobId = activeMission.id
    
    -- Úklid blipů a entit
    if activeMission.blips then
        for _, b in pairs(activeMission.blips) do RemoveBlip(b) end
    end
    if activeMission.entities then
        for _, e in pairs(activeMission.entities) do DeleteEntity(e) end
    end

    -- Vymazání aktivní mise
    activeMission = nil
    
    if success then
        TriggerServerEvent('aprts_darknet:server:claimSystemReward', jobId, currentTabletSerial)
    else
        lib.notify({title='Darknet', description='Mise zrušena / selhala.', type='error'})
    end

    -- REFRESH UI: Aby se zakázka vrátila do nabídky a zmizela z "Moje zakázky"
    -- Malý timeout, aby se stihla zapsat reputace do DB
    SetTimeout(500, function()
        TriggerServerEvent('aprts_darknet:server:getData', 'system', currentTabletSerial)
    end)
end