-- FILE: missions/car_theft/client.lua

-- Registrujeme funkci do globální tabulky pod klíčem 'car_theft'
DarknetMissions['car_theft'] = function(mission)
    local data = mission.data -- parametry z configu
    local currentStage = 0 -- 0: Najít klíče/hotwire, 1: Ukrást auto, 2: Odstranit tracker, 3: Přelakovat, 4: Doručit
    local targetVehicle = nil
    local ownerPed = nil
    local missionBlips = {}
    local missionEntities = {}

    lib.notify({title='Darknet', description='Tvým úkolem je ukrást specifické vozidlo. GPS ti ukáže výchozí bod.', type='info'})

    -- Pomocná funkce pro nastavení blipu
    local function SetMissionBlip(coords, sprite, colour, text, isRoute)
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, sprite)
        SetBlipColour(blip, colour)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(text)
        EndTextCommandSetBlipName(blip)
        if isRoute then SetBlipRoute(blip, true) end
        table.insert(missionBlips, blip)
        return blip
    end

    -- Funkce pro úklid blipů a entit, volaná z FinishActiveMission
    mission.blips = missionBlips
    mission.entities = missionEntities

    -- SPWNUTÍ NPC MAJITELE
    ownerPed = CreatePed(2, GetHashKey("s_m_m_autoshop_01"), data.ownerLocation.x, data.ownerLocation.y, data.ownerLocation.z, data.vehicleHeading, false, true)
    FreezeEntityPosition(ownerPed, true) -- Aby se nehýbal, dokud s ním neinteragujeme
    SetBlockingOfNonTemporaryEvents(ownerPed, true)
    SetEntityInvincible(ownerPed, true)
    table.insert(missionEntities, ownerPed)
    
    SetMissionBlip(data.ownerLocation, 1, 5, "Majitel klíčů / Cíl krádeže", true) -- Žlutý blip pro majitele

    -- Hlavní smyčka mise
    CreateThread(function()
        while activeMission and activeMission.id == mission.id do
            local sleep = 500
            local plyPed = PlayerPedId()
            local plyCoords = GetEntityCoords(plyPed)

            if currentStage == 0 then -- Najít klíče od majitele
                local distToOwner = #(plyCoords - data.ownerLocation)
                if distToOwner < 20.0 then
                    sleep = 0
                    DrawMarker(2, data.ownerLocation.x, data.ownerLocation.y, data.ownerLocation.z, 0,0,0, 0,0,0, 0.5,0.5,0.5, 255,255,0,150, false, true, 2, false, nil, nil, false)

                    if distToOwner < 1.5 then
                        lib.showTextUI('[E] Získat klíče od majitele')
                        if IsControlJustPressed(0, 38) then
                            lib.hideTextUI()
                            
                            -- Animace pro získání klíčů
                            if data.animDictKeys and data.animClipKeys then
                                lib.requestAnimDict(data.animDictKeys)
                                TaskPlayAnim(plyPed, data.animDictKeys, data.animClipKeys, 8.0, -8.0, 2000, 0, 0, false, false, false)
                            end

                            if lib.progressBar({
                                duration = 3000,
                                label = 'Získávání klíčů...',
                                useWhileDead = false,
                                canCancel = true,
                                disable = { move = true },
                            }) then
                                ClearPedTasks(plyPed)
                                lib.notify({title='Darknet', description='Klíče získány. Teď pro auto!', type='success'})
                                
                                -- Úklid ownera a jeho blipu
                                SetEntityAsNoLongerNeeded(ownerPed)
                                DeletePed(ownerPed)
                                ownerPed = nil
                                for _, blip in ipairs(missionBlips) do RemoveBlip(blip) end
                                missionBlips = {}

                                -- Spawn auta
                                RequestModel(data.vehicleModel)
                                while not HasModelLoaded(data.vehicleModel) do Wait(0) end
                                targetVehicle = CreateVehicle(data.vehicleModel, data.vehicleSpawnCoords.x, data.vehicleSpawnCoords.y, data.vehicleSpawnCoords.z, data.vehicleHeading, true, true)
                                SetVehicleOnGroundProperly(targetVehicle)
                                SetVehicleEngineOn(targetVehicle, false, true, false)
                                SetVehicleDoorsLocked(targetVehicle, 2) -- Zamknout auto
                                SetModelAsNoLongerNeeded(data.vehicleModel)
                                table.insert(missionEntities, targetVehicle)
                                
                                SetMissionBlip(data.vehicleSpawnCoords, 1, 6, "Ukrást vozidlo", true) -- Červený blip pro auto
                                currentStage = 1
                            else
                                ClearPedTasks(plyPed)
                                lib.notify({title='Darknet', description='Získání klíčů se nepodařilo.', type='error'})
                                FinishActiveMission(false)
                                break
                            end
                        end
                    else
                        lib.hideTextUI()
                    end
                end

            elseif currentStage == 1 then -- Ukrást auto
                local distToVehicle = targetVehicle and #(plyCoords - GetEntityCoords(targetVehicle)) or 9999
                if distToVehicle < 20.0 then
                    sleep = 0
                    DrawMarker(2, GetEntityCoords(targetVehicle).x, GetEntityCoords(targetVehicle).y, GetEntityCoords(targetVehicle).z, 0,0,0, 0,0,0, 0.5,0.5,0.5, 255,0,0,150, false, true, 2, false, nil, nil, false)

                    if distToVehicle < 2.5 then
                        if IsVehicleSeatFree(targetVehicle, -1) then -- Pokud je sedadlo řidiče volné
                            lib.showTextUI('[E] Nastoupit do vozidla')
                            if IsControlJustPressed(0, 38) then
                                lib.hideTextUI()
                                
                                -- Pokud jsou klíče, auto se odemkne
                                SetVehicleDoorsLocked(targetVehicle, 1) -- Odemknout auto
                                TaskEnterVehicle(plyPed, targetVehicle, -1, -1, 1.0, 1)
                                Wait(2000) -- Čas na nástup

                                if IsPedInVehicle(plyPed, targetVehicle, false) then
                                    lib.notify({title='Darknet', description='Jsi v autě! Nyní se zaměř na další krok.', type='success'})
                                    
                                    -- Odstraníme blip kradeného vozidla
                                    for _, blip in ipairs(missionBlips) do RemoveBlip(blip) end
                                    missionBlips = {}

                                    if data.hasTracker then
                                        SetMissionBlip(GetEntityCoords(targetVehicle), 501, 1, "Deaktivovat tracker", false) -- Blip pro tracker (na autě)
                                        currentStage = 2
                                    elseif data.resprayLocation then
                                        SetMissionBlip(data.resprayLocation, 72, 4, "Přelakovat vozidlo", true) -- Blip pro lakovnu
                                        currentStage = 3
                                    else
                                        SetMissionBlip(data.dropoffLocation, 501, 2, "Doručit vozidlo", true) -- Zelený blip pro doručení
                                        currentStage = 4
                                    end
                                else
                                    lib.notify({title='Darknet', description='Nastoupení se nepodařilo.', type='error'})
                                end
                            end
                        else
                            lib.hideTextUI()
                        end
                    end
                end

            elseif currentStage == 2 then -- Odstranit tracker (volitelné)
                if not IsPedInVehicle(plyPed, targetVehicle, false) then
                     lib.notify({title='Darknet', description='Nastup si do vozidla!', type='warning'})
                     Wait(1000)
                end
                
                local distToVehicle = targetVehicle and #(plyCoords - GetEntityCoords(targetVehicle)) or 9999
                if distToVehicle < 5.0 and IsPedInVehicle(plyPed, targetVehicle, false) then
                    lib.showTextUI('[E] Deaktivovat tracker')
                    if IsControlJustPressed(0, 38) then
                        lib.hideTextUI()
                        -- Animace pro deaktivaci
                        if data.animDictHotwire and data.animClipHotwire then
                            lib.requestAnimDict(data.animDictHotwire)
                            TaskPlayAnim(plyPed, data.animDictHotwire, data.animClipHotwire, 8.0, -8.0, data.trackerDisableDuration, 0, 0, false, false, false)
                        end

                        if lib.progressBar({
                            duration = data.trackerDisableDuration or 7000,
                            label = 'Deaktivuji tracker...',
                            useWhileDead = false,
                            canCancel = true,
                            disable = { move = true },
                        }) then
                            ClearPedTasks(plyPed)
                            lib.notify({title='Darknet', description='Tracker deaktivován!', type='success'})
                            for _, blip in ipairs(missionBlips) do RemoveBlip(blip) end
                            missionBlips = {}
                            if data.resprayLocation then
                                SetMissionBlip(data.resprayLocation, 72, 4, "Přelakovat vozidlo", true) -- Blip pro lakovnu
                                currentStage = 3
                            else
                                SetMissionBlip(data.dropoffLocation, 501, 2, "Doručit vozidlo", true) -- Zelený blip pro doručení
                                currentStage = 4
                            end
                        else
                            ClearPedTasks(plyPed)
                            lib.notify({title='Darknet', description='Deaktivace trackeru selhala!', type='error'})
                            FinishActiveMission(false)
                            break
                        end
                    end
                else
                    lib.hideTextUI()
                end

            elseif currentStage == 3 then -- Přelakovat auto (volitelné)
                local distToRespray = #(plyCoords - data.resprayLocation)
                if distToRespray < 20.0 then
                    sleep = 0
                    DrawMarker(2, data.resprayLocation.x, data.resprayLocation.y, data.resprayLocation.z, 0,0,0, 0,0,0, 0.5,0.5,0.5, 0,0,255,150, false, true, 2, false, nil, nil, false)

                    if distToRespray < 2.5 and IsPedInVehicle(plyPed, targetVehicle, false) then
                        lib.showTextUI('[E] Přelakovat vozidlo')
                        if IsControlJustPressed(0, 38) then
                            lib.hideTextUI()
                            
                            if lib.progressBar({
                                duration = data.resprayDuration or 3000,
                                label = 'Přelakovávám vozidlo...',
                                useWhileDead = false,
                                canCancel = true,
                                disable = { move = true },
                            }) then
                                SetVehicleCustomPrimaryColour(targetVehicle, 0, 0, 0) -- Nastavíme černou (nebo jinou neutrální)
                                SetVehicleDirtLevel(targetVehicle, 0.0) -- Očistíme vozidlo
                                lib.notify({title='Darknet', description='Vozidlo přelakováno!', type='success'})
                                
                                for _, blip in ipairs(missionBlips) do RemoveBlip(blip) end
                                missionBlips = {}
                                SetMissionBlip(data.dropoffLocation, 501, 2, "Doručit vozidlo", true) -- Zelený blip pro doručení
                                currentStage = 4
                            else
                                lib.notify({title='Darknet', description='Přelakování zrušeno.', type='error'})
                            end
                        end
                    else
                        lib.hideTextUI()
                        if distToRespray < 2.5 and not IsPedInVehicle(plyPed, targetVehicle, false) then
                            lib.showTextUI('Musíš být ve vozidle, abys ho přelakoval.')
                        end
                    end
                end

            elseif currentStage == 4 then -- Doručit auto
                local distToDropoff = #(plyCoords - data.dropoffLocation)
                if distToDropoff < 20.0 then
                    sleep = 0
                    DrawMarker(2, data.dropoffLocation.x, data.dropoffLocation.y, data.dropoffLocation.z, 0,0,0, 0,0,0, 0.5,0.5,0.5, 0,255,0,150, false, true, 2, false, nil, nil, false)

                    if distToDropoff < 2.5 and IsPedInVehicle(plyPed, targetVehicle, false) then
                        lib.showTextUI('[E] Doručit vozidlo')
                        if IsControlJustPressed(0, 38) then
                            lib.hideTextUI()
                            if lib.progressBar({
                                duration = 2000,
                                label = 'Doručuji vozidlo...',
                                useWhileDead = false,
                                canCancel = true,
                                disable = { move = true },
                            }) then
                                lib.notify({title='Darknet', description='Vozidlo doručeno!', type='success'})
                                SetEntityAsNoLongerNeeded(targetVehicle)
                                DeleteVehicle(targetVehicle)
                                targetVehicle = nil
                                FinishActiveMission(true)
                                break
                            else
                                lib.notify({title='Darknet', description='Doručení zrušeno.', type='error'})
                            end
                        end
                    else
                        lib.hideTextUI()
                        if distToDropoff < 2.5 and not IsPedInVehicle(plyPed, targetVehicle, false) then
                            lib.showTextUI('Musíš být ve vozidle, abys ho doručil.')
                        end
                    end
                end
            end
            Wait(sleep)
        end
        lib.hideTextUI()
        -- Zajištění úklidu i při předčasném ukončení
        if targetVehicle then
            SetEntityAsNoLongerNeeded(targetVehicle)
            DeleteVehicle(targetVehicle)
        end
        if ownerPed then
            SetEntityAsNoLongerNeeded(ownerPed)
            DeletePed(ownerPed)
        end
        for _, blip in ipairs(missionBlips) do RemoveBlip(blip) end
    end)
end