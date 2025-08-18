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


-- test: animals
-- List of all common GTA V animal models
local animalModels = {
    [GetHashKey("a_c_boar")] = true,
    [GetHashKey("a_c_cat_01")] = true,
    [GetHashKey("a_c_chickenhawk")] = true,
    [GetHashKey("a_c_chimp")] = true,
    [GetHashKey("a_c_chop")] = true,
    [GetHashKey("a_c_cormorant")] = true,
    [GetHashKey("a_c_cow")] = true,
    [GetHashKey("a_c_coyote")] = true,
    [GetHashKey("a_c_crow")] = true,
    [GetHashKey("a_c_deer")] = true,
    [GetHashKey("a_c_dolphin")] = true,
    [GetHashKey("a_c_fish")] = true,
    [GetHashKey("a_c_hen")] = true,
    [GetHashKey("a_c_husky")] = true,
    [GetHashKey("a_c_mtlion")] = true,
    [GetHashKey("a_c_pig")] = true,
    [GetHashKey("a_c_pigeon")] = true,
    [GetHashKey("a_c_poodle")] = true,
    [GetHashKey("a_c_pug")] = true,
    [GetHashKey("a_c_rabbit_01")] = true,
    [GetHashKey("a_c_rat")] = true,
    [GetHashKey("a_c_retriever")] = true,
    [GetHashKey("a_c_rhesus")] = true,
    [GetHashKey("a_c_rottweiler")] = true,
    [GetHashKey("a_c_seagull")] = true,
    [GetHashKey("a_c_sharkhammer")] = true,
    [GetHashKey("a_c_sharktiger")] = true,
    [GetHashKey("a_c_shepherd")] = true,
    [GetHashKey("a_c_stingray")] = true,
    [GetHashKey("a_c_westy")] = true,
}

-- implement event handler camera-bounty:printNearbyAnimals
RegisterNetEvent('camera-bounty:printNearbyAnimals', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local radius = 50.0 -- medium radius

    print("[DEBUG] Searching for nearby animals within radius: " .. radius)
    print("[DEBUG] Player coords: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z)

    local nearbyAnimals = {}
    local totalAnimalPeds = 0
    local handle, foundPed = FindFirstPed()
    local success = true
    while success do
        if foundPed ~= ped then
            local model = GetEntityModel(foundPed)
            local animalCoords = GetEntityCoords(foundPed)
            if animalModels[model] then
                totalAnimalPeds = totalAnimalPeds + 1
                local dist = Vdist(coords.x, coords.y, coords.z, animalCoords.x, animalCoords.y, animalCoords.z)
                print(string.format("[DEBUG] Found animal ped: model=%s, coords=(%.2f, %.2f, %.2f), dist=%.2f", model, animalCoords.x, animalCoords.y, animalCoords.z, dist))
                if dist <= radius then
                    table.insert(nearbyAnimals, {
                        model = model,
                        coords = animalCoords
                    })
                end
            else
                print(string.format("[DEBUG] Found non-animal ped: model=%s, coords=(%.2f, %.2f, %.2f)", model, animalCoords.x, animalCoords.y, animalCoords.z))
            end
        end
        success, foundPed = FindNextPed(handle)
    end
    EndFindPed(handle)

    print("[DEBUG] Total animal peds found: " .. totalAnimalPeds)
    print("Nearby animals: " .. json.encode(nearbyAnimals))
end)
