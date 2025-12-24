-- Registrujeme funkci do globální tabulky pod klíčem 'heist'
DarknetMissions['heist'] = function(mission)
    local data = mission.data -- parametry z configu
    
    lib.notify({title='Darknet', description='Cíl označen na GPS. Připrav se.', type='info'})

    -- 1. Vytvoření Blipu
    local blip = AddBlipForCoord(data.targetCoords.x, data.targetCoords.y, data.targetCoords.z)
    SetBlipSprite(blip, 161) -- Ikonka lebky nebo terče
    SetBlipColour(blip, 1)
    SetBlipRoute(blip, true)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Cíl: " .. data.label)
    EndTextCommandSetBlipName(blip)

    -- Uložíme blip do mise, aby ho Main Client mohl smazat při FinishActiveMission
    mission.blips = { blip }

    -- 2. Loop
    CreateThread(function()
        while activeMission and activeMission.id == mission.id do
            local sleep = 1000
            local plyPed = PlayerPedId()
            local plyCoords = GetEntityCoords(plyPed)
            local dist = #(plyCoords - data.targetCoords)

            if dist < 20.0 then
                sleep = 0
                DrawMarker(2, data.targetCoords.x, data.targetCoords.y, data.targetCoords.z, 0,0,0, 0,0,0, 0.3, 0.3, 0.3, 200, 50, 50, 150, false, true, 2, false, nil, nil, false)

                if dist < 1.5 then
                    lib.showTextUI('[E] Začít prolamování')
                    
                    if IsControlJustPressed(0, 38) then
                        -- Kontrola itemu (pokud je vyžadován)
                        if data.requiredItem then
                            local hasItem = exports.ox_inventory:Search('count', data.requiredItem)
                            if hasItem < 1 then
                                lib.notify({type='error', description='Potřebuješ: '..data.requiredItem})
                                goto skip
                            end
                        end

                        -- Minigame (Skill Check)
                        local difficulty = data.hackDifficulty or 'easy'
                        local input = lib.skillCheck(difficulty, {'w', 'a', 's', 'd'}) 
                        
                        if input then
                            -- Progress Bar
                            if lib.progressBar({
                                duration = data.duration or 5000,
                                label = 'Nabourávání systému...',
                                useWhileDead = false,
                                canCancel = true,
                                disable = { move = true, car = true, combat = true },
                                anim = { dict = 'anim@heists@ornate_bank@hack', clip = 'hack_loop' }
                            }) then
                                -- ÚSPĚCH
                                FinishActiveMission(true)
                                break -- Ukončí loop
                            else
                                lib.notify({type='error', description='Akce zrušena.'})
                            end
                        else
                            lib.notify({type='error', description='Hackování selhalo!'})
                            -- Zde by se mohla volat policie
                        end
                        
                        ::skip::
                    end
                else
                    lib.hideTextUI()
                end
            end
            Wait(sleep)
        end
        lib.hideTextUI()
    end)
end