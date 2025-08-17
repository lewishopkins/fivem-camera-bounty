local activeBlips = {}

local function createBlipWithRadius(x, y, z, radius, id)
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
    activeBlips[id] = { blip = blip, radiusBlip = radiusBlip }
end

RegisterNetEvent('camera-bounty:setActiveZone', function(x, y, z, radius, id)
    print('[CameraBounty][CLIENT] Received active zone')
    createBlipWithRadius(x, y, z, radius, id)

    TriggerEvent('chat:addMessage', {
        color = { 34, 139, 34 },
        multiline = true,
        args = { "[Photo Bounty]", "New photo bounty available!" }
    })
end)

RegisterNetEvent('camera-bounty:removeZone', function(id)
    print(('[CameraBounty][CLIENT] Removing zone with id=%d'):format(id))
    if activeBlips[id] then
        RemoveBlip(activeBlips[id].blip)
        RemoveBlip(activeBlips[id].radiusBlip)
        activeBlips[id] = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for id in activeBlips do
            RemoveBlip(activeBlips[id].blip)
            RemoveBlip(activeBlips[id].radiusBlip)
        end
        print('[CameraBounty][CLIENT] All bounty blips removed on resource stop.')
    end
end)

Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do
        Citizen.Wait(100)
    end
    print("[CameraBounty][CLIENT] Requesting active zone")
    TriggerServerEvent('camera-bounty:requestActiveZone')
end)