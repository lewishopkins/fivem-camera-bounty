local activeBlip = nil

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
    activeBlip = { blip = blip, radiusBlip = radiusBlip, id = id }
end

RegisterNetEvent('camera-bounty:setActiveZone', function(x, y, z, radius, id)
    createBlipWithRadius(x, y, z, radius, id)
    TriggerEvent('chat:addMessage', {
        color = { 34, 139, 34 },
        multiline = true,
        args = { "[Photo Bounty]", "New photo bounty available!" }
    })
end)

RegisterNetEvent('camera-bounty:removeZone', function(id)
    if activeBlip then
        if activeBlip.id == id then
            RemoveBlip(activeBlip.blip)
            RemoveBlip(activeBlip.radiusBlip)
            activeBlip = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    local currentResource = GetCurrentResourceName()
    if resourceName == currentResource then
        if activeBlip and activeBlip.blip and activeBlip.radiusBlip then
            RemoveBlip(activeBlip.blip)
            RemoveBlip(activeBlip.radiusBlip)
            activeBlip = nil
        end
    end
end)

Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do
        Citizen.Wait(100)
    end
    TriggerServerEvent('camera-bounty:requestActiveZone')
end)