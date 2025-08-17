local activeBlip = nil

local function createBlipWithRadius(x, y, z, radius, id)
    print(('[CameraBounty][CLIENT] createBlipWithRadius called: x=%.2f, y=%.2f, z=%.2f, radius=%.2f, id=%s'):format(x, y, z, radius, tostring(id)))
    -- Create the main blip (icon)
    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, 184) -- camera icon
    SetBlipColour(blip, 25)   -- forest green
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Photo Bounty")
    EndTextCommandSetBlipName(blip)

    -- Create the radius blip
    local radiusBlip = AddBlipForRadius(x, y, z, radius)
    SetBlipColour(radiusBlip, 25) -- Match color to main blip
    SetBlipAlpha(radiusBlip, 128) -- Half transparency

    -- Store blips in the activeBlips table
    activeBlip = { blip = blip, radiusBlip = radiusBlip, id = id }
    print('[CameraBounty][CLIENT] activeBlip set')
end

RegisterNetEvent('camera-bounty:setActiveZone', function(x, y, z, radius, id)
    print('[CameraBounty][CLIENT] Event: camera-bounty:setActiveZone received')
    createBlipWithRadius(x, y, z, radius, id)
    TriggerEvent('chat:addMessage', {
        color = { 34, 139, 34 },
        multiline = true,
        args = { "[Photo Bounty]", "New photo bounty available!" }
    })
    print('[CameraBounty][CLIENT] Chat message sent for new bounty')
end)

RegisterNetEvent('camera-bounty:removeZone', function(id)
    print(('[CameraBounty][CLIENT] Event: camera-bounty:removeZone received for id=%s'):format(tostring(id)))
    if activeBlip then
        print(('[CameraBounty][CLIENT] activeBlip exists, id=%s'):format(tostring(activeBlip.id)))
        if activeBlip.id == id then
            RemoveBlip(activeBlip.blip)
            RemoveBlip(activeBlip.radiusBlip)
            activeBlip = nil
        else
            print('[CameraBounty][CLIENT] activeBlip.id does not match event id')
        end
    else
        print('[CameraBounty][CLIENT] No activeBlip to remove')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    print(('[CameraBounty][CLIENT] Event: onResourceStop for resourceName=%s'):format(resourceName))
    local currentResource = GetCurrentResourceName()
    if resourceName == currentResource then
        if activeBlip and activeBlip.blip and activeBlip.radiusBlip then
            print('[CameraBounty][CLIENT] Blip found. Removing active blip on resource stop')
            RemoveBlip(activeBlip.blip)
            RemoveBlip(activeBlip.radiusBlip)
            activeBlip = nil
        else
            print('[CameraBounty][CLIENT] No active blip to remove on resource stop')
        end
        print('[CameraBounty][CLIENT] All bounty blips removed on resource stop.')
    else
        print('[CameraBounty][CLIENT] Resource stop does not match current resource')
    end
end)

Citizen.CreateThread(function()
    print('[CameraBounty][CLIENT] Citizen.CreateThread started')
    while not NetworkIsSessionStarted() do
        Citizen.Wait(100)
    end
    TriggerServerEvent('camera-bounty:requestActiveZone')
end)