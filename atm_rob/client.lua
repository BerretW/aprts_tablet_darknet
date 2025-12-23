

-- 1. Render smyčka pro ATM a jejich stav na základě HP
CreateThread(function()
    while true do
        local sleep = 1000
        for _, atm in pairs(Config.ATM) do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local dist = #(playerCoords - vector3(atm.coords.x, atm.coords.y, atm.coords.z))

            if dist < 50.0 then
                if not DoesEntityExist(atm.entity) then
                    atm.entity = CreateObject(GetHashKey(atm.model), atm.coords.x, atm.coords.y, atm.coords.z - 1.0,
                        false, false, false)
                    SetEntityHeading(atm.entity, atm.coords.w)
                    FreezeEntityPosition(atm.entity, true)
                    SetEntityInvincible(atm.entity, true)
                end
            else
                if DoesEntityExist(atm.entity) then
                    DeleteEntity(atm.entity)
                end
            end
        end
        Wait(sleep)
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