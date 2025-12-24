DarknetMissions['delivery'] = function(mission)
    local data = mission.data
    
    lib.notify({title='Darknet', description='Doruč zásilku na určené místo.', type='info'})

    local blip = AddBlipForCoord(data.location.x, data.location.y, data.location.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipRoute(blip, true)
    
    mission.blips = { blip }

    CreateThread(function()
        print('Starting delivery mission loop')
        print(activeMission.id, mission.id)
        while activeMission and activeMission.id == mission.id do
            local sleep = 1000
            local plyCoords = GetEntityCoords(PlayerPedId())
            local dist = #(plyCoords - data.location)
            print(dist)
            if dist < 20.0 then
                sleep = 0
                DrawMarker(2, data.location.x, data.location.y, data.location.z, 0,0,0, 0,0,0, 0.5,0.5,0.5, 50,200,50,150, false, true, 2, false, nil, nil, false)
                
                if dist < 2.0 then
                    lib.showTextUI('[E] Předat zásilku')
                    if IsControlJustPressed(0, 38) then
                        -- Animace předání
                        if lib.progressBar({
                            duration = 2000,
                            label = 'Předávání...',
                            useWhileDead = false,
                            canCancel = true,
                            disable = { move = true },
                            anim = { dict = 'random@domestic', clip = 'pickup_low' }
                        }) then
                            FinishActiveMission(true)
                            break
                        end
                    end
                else
                    lib.hideTextUI()
                end
            end
            Wait(sleep)
        end
        lib.hideTextUI()
        print('Ending delivery mission loop')
    end)
    
end