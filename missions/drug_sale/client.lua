DarknetMissions['drug_sale'] = function(mission)
    local data = mission.data
    local soldCount = 0
    local targetAmount = data.totalAmount or 5
    local interactedPeds = {} 

    -- 1. Získáme zboží
    TriggerServerEvent('aprts_darknet:server:giveMissionItem', data.item, targetAmount)
    
    lib.notify({
        title = 'Darknet', 
        description = 'Máš zboží ('..targetAmount..'ks). Najdi zákazníky a buď přesvědčivý.', 
        type = 'info', 
        duration = 10000
    })

    -- 2. Blipy
    local blip = AddBlipForCoord(data.location.x, data.location.y, data.location.z)
    SetBlipSprite(blip, 501)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Oblast prodeje")
    EndTextCommandSetBlipName(blip)

    local radiusBlip = AddBlipForRadius(data.location.x, data.location.y, data.location.z, data.radius)
    SetBlipColour(radiusBlip, 1)
    SetBlipAlpha(radiusBlip, 80)

    mission.blips = { blip, radiusBlip }

    -- Pomocná funkce na hledání NPC
    local function GetClosestCivilian()
        local plyPed = PlayerPedId()
        local plyCoords = GetEntityCoords(plyPed)
        local pool = GetGamePool('CPed')
        local closestDist = 3.0
        local closestPed = nil

        for _, ped in ipairs(pool) do
            if not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) and not IsPedInAnyVehicle(ped, true) and IsPedHuman(ped) then
                if not interactedPeds[ped] then
                    local dist = #(plyCoords - GetEntityCoords(ped))
                    if dist < closestDist then
                        closestDist = dist
                        closestPed = ped
                    end
                end
            end
        end
        return closestPed
    end

    -- Hlavní smyčka
    CreateThread(function()
        while activeMission and activeMission.id == mission.id do
            local sleep = 1000
            local plyPed = PlayerPedId()
            local plyCoords = GetEntityCoords(plyPed)
            local distToZone = #(plyCoords - data.location)
            
            if distToZone < (data.radius + 20.0) then
                sleep = 500
                local targetPed = GetClosestCivilian()

                if targetPed then
                    sleep = 0
                    local pedCoords = GetEntityCoords(targetPed)
                    
                    -- Značka nad hlavou
                    DrawMarker(0, pedCoords.x, pedCoords.y, pedCoords.z + 1.1, 0,0,0, 0,0,0, 0.2,0.2,0.1, 255,255,255,200, true, true, 2, false, nil, nil, false)

                    lib.showTextUI('[E] Nabídnout zboží (' .. soldCount .. '/' .. targetAmount .. ')')

                    if IsControlJustPressed(0, 38) then
                        interactedPeds[targetPed] = true 
                        lib.hideTextUI()

                        -- 1. PŘÍPRAVA (Otočení, Zastavení)
                        FreezeEntityPosition(targetPed, true) -- Aby neutekl při kecání
                        TaskTurnPedToFaceEntity(plyPed, targetPed, 1000)
                        TaskTurnPedToFaceEntity(targetPed, plyPed, 1000)
                        Wait(1000)

                        -- Přehrání animace "rozhovoru"
                        lib.requestAnimDict("misscarsteal4@actor")
                        TaskPlayAnim(plyPed, "misscarsteal4@actor", "actor_berating_loop", 8.0, -8.0, -1, 49, 0, false, false, false)
                        
                        -- 2. PRVNÍ DOJEM (RNG)
                        -- Zjistíme, jestli má NPC vůbec zájem, nebo jestli volá policajty
                        local chance = math.random(1, 100)
                        local rejectionChance = data.rejectionChance or 30 -- 30% že tě rovnou pošle pryč

                        if chance <= rejectionChance then
                            -- === ODMÍTNUTÍ HNED NA ZAČÁTKU ===
                            ClearPedTasks(plyPed)
                            FreezeEntityPosition(targetPed, false)
                            
                            if math.random() > 0.5 then
                                lib.notify({type='warning', description='NPC: "Nemám zájem, vypadni!"'})
                                TaskReactAndFleePed(targetPed, plyPed)
                                -- Zde případně alert policii
                            else
                                lib.notify({type='error', description='NPC: "Zavolám na tebe švestky!"'})
                                TaskUseMobilePhone(targetPed, 1, 1)
                                -- Zde URČITĚ alert policii
                            end

                        else
                            -- === MÁ ZÁJEM -> ZAČÍNÁ VYJEDNÁVÁNÍ (MINIHRA) ===
                            lib.notify({type='info', description='Zákazník má zájem. Přesvědč ho!'})
                            
                            -- Skill Check (Série 3 až 4 kláves, střední obtížnost)
                            -- Hráč musí mačkat klávesy (W, A, S, D) včas
                            local negotiationResult = lib.skillCheck(
                                {'easy', 'easy'}, -- Sekvence obtížnosti
                                {'w'} -- Povolené klávesy
                            )

                            ClearPedTasks(plyPed) -- Ukončit animaci mluvení

                            if negotiationResult then
                                -- === ÚSPĚCH: PRODEJ ===
                                
                                -- Animace předání
                                lib.requestAnimDict("mp_common")
                                TaskPlayAnim(plyPed, "mp_common", "givetake2_a", 8.0, -8.0, 2000, 0, 0, false, false, false)
                                TaskPlayAnim(targetPed, "mp_common", "givetake2_a", 8.0, -8.0, 2000, 0, 0, false, false, false)
                                
                                Wait(1000) -- Čas na animaci

                                local success = lib.callback.await('aprts_darknet:server:checkAndRemoveItem', false, data.item, 1)
                                
                                if success then
                                    soldCount = soldCount + 1
                                    lib.notify({type='success', description='Úspěšně prodáno. ('..soldCount..'/'..targetAmount..')'})
                                    
                                    FreezeEntityPosition(targetPed, false)
                                    TaskWanderStandard(targetPed, 10.0, 10)

                                    if soldCount >= targetAmount then
                                        Wait(1000)
                                        FinishActiveMission(true)
                                        break
                                    end
                                else
                                    lib.notify({type='error', description='Nemáš u sebe zboží!'})
                                    FreezeEntityPosition(targetPed, false)
                                    FinishActiveMission(false)
                                    break
                                end
                            else
                                -- === SELHÁNÍ MINIGAME ===
                                lib.notify({type='error', description='Nepřesvědčil jsi ho. Obchod padá.'})
                                FreezeEntityPosition(targetPed, false)
                                TaskWanderStandard(targetPed, 10.0, 10)
                            end
                        end
                        
                        Wait(1500) -- Prodleva před dalším
                    end
                else
                    lib.hideTextUI()
                end
            else
                if distToZone > (data.radius + 50.0) then
                    lib.showTextUI('Vrať se do oblasti prodeje!')
                else
                    lib.hideTextUI()
                end
            end
            Wait(sleep)
        end
        lib.hideTextUI()
    end)
end