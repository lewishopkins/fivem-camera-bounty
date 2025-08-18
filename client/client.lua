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
    [GetHashKey("a_c_humpback")] = true,
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

-- Helper: get camera forward vector from rotation
local function getCamForwardVector()
    local rot = GetGameplayCamRot(2)
    local pitch = math.rad(rot.x)
    local yaw = math.rad(rot.z)
    local x = -math.sin(yaw) * math.cos(pitch)
    local y = math.cos(yaw) * math.cos(pitch)
    local z = math.sin(pitch)
    return vector3(x, y, z)
end

-- implement event handler camera-bounty:printNearbyAnimals
RegisterNetEvent('camera-bounty:printNearbyAnimals', function()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local distance = 100.0 -- max distance
    local coneAngle = 15.0 -- fixed cone angle

    print("[DEBUG] Searching for nearby animals within cone angle: " .. coneAngle .. " and max distance: " .. distance)
    print("[DEBUG] Player coords: " .. playerCoords.x .. ", " .. playerCoords.y .. ", " .. playerCoords.z)

    -- Get camera direction
    local camForward = getCamForwardVector()

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
                local toAnimal = vector3(animalCoords.x - playerCoords.x, animalCoords.y - playerCoords.y, animalCoords.z - playerCoords.z)
                local dist = #(toAnimal)
                -- Normalize toAnimal
                local toAnimalNorm = dist > 0 and vector3(toAnimal.x / dist, toAnimal.y / dist, toAnimal.z / dist) or vector3(0,0,0)
                -- Dot product for angle
                local dot = toAnimalNorm.x * camForward.x + toAnimalNorm.y * camForward.y + toAnimalNorm.z * camForward.z
                local angle = math.deg(math.acos(dot))
                print(string.format("[DEBUG] Found animal ped: model=%s, coords=(%.2f, %.2f, %.2f), dist=%.2f, angle=%.2f", model, animalCoords.x, animalCoords.y, animalCoords.z, dist, angle))
                if dist <= distance and angle <= coneAngle then
                    table.insert(nearbyAnimals, {
                        model = model,
                        coords = animalCoords,
                        dist = dist,
                        angle = angle
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
    print("Nearby animals in cone: " .. json.encode(nearbyAnimals))

    -- Visualize cone for development (draw for 60 seconds)
    Citizen.CreateThread(function()
        local camForward = getCamForwardVector()
        local function rotateVec(vec, angleDeg)
            local angleRad = math.rad(angleDeg)
            local cosA = math.cos(angleRad)
            local sinA = math.sin(angleRad)
            -- Only rotate in XY plane
            return vector3(
                vec.x * cosA - vec.y * sinA,
                vec.x * sinA + vec.y * cosA,
                vec.z
            )
        end

        local centerEnd = playerCoords + camForward * distance
        local leftEnd = playerCoords + rotateVec(camForward, -coneAngle) * distance
        local rightEnd = playerCoords + rotateVec(camForward, coneAngle) * distance

        local r, g, b = 0, 255, 0 -- green
        local duration = GetGameTimer() + 60000 -- keep debug lines visible for 60 seconds
        while GetGameTimer() < duration do
            DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, centerEnd.x, centerEnd.y, centerEnd.z, r, g, b, 255)
            DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, leftEnd.x, leftEnd.y, leftEnd.z, r, g, b, 255)
            DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, rightEnd.x, rightEnd.y, rightEnd.z, r, g, b, 255)
            Citizen.Wait(0)
        end
    end)
end)