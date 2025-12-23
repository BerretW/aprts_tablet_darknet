local currentReputation = 0

-- 1. Registrace aplikace při startu
-- CreateThread(function()
--     Wait(2000) -- Počkáme až naběhne tablet
--     exports['aprts_tablet']:RegisterApp(
--         Config.AppName, 
--         Config.Label, 
--         Config.Icon, 
--         Config.Color, 
--         'aprts_darknet:client:open', -- Event, který tablet zavolá při otevření
--         nil, -- Job restriction (nil = všichni)
--         150, -- Velikost v MB
--         {'all'} -- Podporované OS (např. jen Hacker a Pro tablet)
--     )
-- end)


local APP_ID = Config.AppName
local APP_LABEL = Config.Label

CreateThread(function()
    Wait(1000)
    exports['aprts_tablet']:RegisterApp(APP_ID, APP_LABEL, Config.Icon, Config.Color, "aprts_darknet:client:open", nil, 50, 'all')
end)
-- 2. Otevření aplikace
RegisterNetEvent('aprts_darknet:client:open', function()
    -- Požádáme server o aktuální reputaci
    TriggerServerEvent('aprts_darknet:server:getData')
end)

-- 3. Přijetí dat a vykreslení HTML
RegisterNetEvent('aprts_darknet:client:receiveData', function(rep)
    currentReputation = rep
    local html = GenerateDarknetHTML(rep)
    
    -- Pošleme HTML do tabletu
    exports['aprts_tablet']:loadContent(html)
end)

-- 4. Funkce pro generování HTML (Cyberpunk styl)
function GenerateDarknetHTML(reputation)
    local jobCards = ""

    for id, job in pairs(Config.Jobs) do
        local isLocked = reputation < job.minReputation
        local opacity = isLocked and "0.5" or "1"
        local statusText = isLocked and ("<i class='fas fa-lock'></i> Vyžaduje Rep: " .. job.minReputation) or ("<span style='color:#00b894'>Dostupné</span>")
        local btnAttr = isLocked and "disabled" or string.format("onclick=\"System.pluginAction('%s', 'acceptJob', '%s')\"", Config.AppName, id)
        local btnClass = isLocked and "background:#333; color:#555;" or "background:#d63031; color:white; cursor:pointer;"
        local btnText = isLocked and "ZAMČENO" or "PŘIJMOUT"

        jobCards = jobCards .. string.format([[
            <div style="background: rgba(0,0,0,0.6); border: 1px solid #d63031; padding: 15px; margin-bottom: 15px; display:flex; justify-content:space-between; align-items:center; opacity: %s;">
                <div style="max-width: 70%%;">
                    <div style="color: #d63031; font-weight: bold; font-size: 16px; font-family: monospace;">%s</div>
                    <div style="color: #aaa; font-size: 12px; margin: 5px 0;">%s</div>
                    <div style="font-size: 11px; color: #fff;">Odměna Rep: <span style="color:#0984e3">+%s</span></div>
                </div>
                <div style="text-align:right;">
                    <div style="font-size:10px; margin-bottom:5px; font-family:monospace;">%s</div>
                    <button %s style="border:none; padding:8px 15px; font-weight:bold; font-family:monospace; %s">
                        %s
                    </button>
                </div>
            </div>
        ]], opacity, job.label, job.description, job.repReward, statusText, btnAttr, btnClass, btnText)
    end

    return string.format([[
        <div style="padding: 20px; height: 100%%; box-sizing: border-box; font-family: 'Share Tech Mono', monospace; color: #fff; background: linear-gradient(45deg, #111 25%%, #000 25%%, #000 75%%, #111 75%%, #111); background-size: 4px 4px;">
            <div style="border-bottom: 2px solid #d63031; padding-bottom: 15px; margin-bottom: 20px; display:flex; justify-content:space-between; align-items:center;">
                <div>
                    <h1 style="margin:0; color:#d63031; text-shadow:0 0 5px #d63031;">DARK_MARKET_V2</h1>
                    <span style="font-size:12px; opacity:0.7;">Anonymní tržiště práce</span>
                </div>
                <div style="text-align:right;">
                    <div style="font-size:10px; color:#aaa;">TVOJE REPUTACE</div>
                    <div style="font-size:24px; color:#d63031; font-weight:bold;">%s</div>
                </div>
            </div>

            <div style="overflow-y: auto; height: calc(100%% - 80px); padding-right:5px;">
                %s
            </div>
        </div>
    ]], reputation, jobCards)
end

-- 5. NUI Callback (Kliknutí na tlačítko v tabletu)
-- Tablet pošle event: 'darknet:handleAction' (protože název appky je darknet)
RegisterNetEvent('darknet:handleAction', function(action, jobId)
    if action == 'acceptJob' then
        TriggerServerEvent('aprts_darknet:server:tryStartJob', jobId)
    end
end)

-- 6. Spuštění logiky Jobu (Pokud server dovolí)
RegisterNetEvent('aprts_darknet:client:startJobSuccess', function(jobId)
    local job = Config.Jobs[jobId]
    if not job then return end

    -- Zavřeme tablet
    TriggerEvent('aprts_tablet:sendNui', { action = "close" })

    -- Spustíme externí export
    if job.exportResource and job.exportName then
        -- Dynamické volání exportu: exports['resource']['name']()
        if exports[job.exportResource] and exports[job.exportResource][job.exportName] then
            exports[job.exportResource][job.exportName]()
            
            lib.notify({
                title = 'Darknet',
                description = 'Zakázka přijata. Zkontroluj GPS.',
                type = 'success'
            })
        else
            print('^1[Darknet] Chyba: Export '..job.exportResource..' neexistuje!^0')
        end
    end
end)


AddEventHandler('explosionEvent', function(sender, ev)
    -- ev obsahuje data o výbuchu: ev.posX, ev.posY, ev.explosionType atd.

    -- ID 2 je Sticky Bomb (C4), ID 4 je taky Sticky Bomb (často se liší podle verze hry/situace)
    -- ID 82 je Gas Canister. Pro jistotu kontrolujeme běžné typy výbušnin.
    local validExplosives = { [2] = true, [4] = true, [1] = true } 
    print(json.encode(ev, {indent=true}))
    -- if validExplosives[ev.explosionType] then
    --     local explosionCoords = vector3(ev.posX, ev.posY, ev.posZ)
        
    --     -- Hledáme objekt bankomatu v okruhu 2 metrů od výbuchu
    --     -- prop_atm_02, prop_atm_03, prop_fleeca_atm jsou názvy modelů bankomatů
    --     local atmObject = GetClosestObjectOfType(explosionCoords.x, explosionCoords.y, explosionCoords.z, 2.0, GetHashKey('prop_atm_02'), false, false, false)
        
    --     -- Pokud jsme nenašli tento typ, zkusíme jiný (nebo si uděláš pole modelů a projdeš je smyčkou)
    --     if atmObject == 0 then
    --         atmObject = GetClosestObjectOfType(explosionCoords.x, explosionCoords.y, explosionCoords.z, 2.0, GetHashKey('prop_atm_03'), false, false, false)
    --     end

    --     -- Pokud byl nalezen bankomat
    --     if atmObject ~= 0 then
    --         -- Zde už víš, že hráč odpálil bombu u bankomatu!
    --         print("Bankomat byl zasažen výbuchem!")
            
    --         -- Příklad akce:
    --         TriggerServerEvent("moje_vykradacka:vyplatitPeniaze")
            
    --         -- Vizuální efekt: Můžeš objekt bankomatu smazat a spawnout místo něj "zničený" model
    --         -- nebo na něj aplikovat oheň.
    --     end
    -- end
end)