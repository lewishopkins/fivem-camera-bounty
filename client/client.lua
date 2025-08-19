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
    if Config.ANNOUNCE_ZONE_CHANGES then
        TriggerEvent('chat:addMessage', {
            color = { 34, 139, 34 },
            multiline = true,
            args = { "[Photo Bounty]", "New photo bounty available!" }
        })
    end
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

local function debugConstructVisualCone(seconds, playerCoords, camForward, distance, coneAngle)
    CreateThread(function()
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

        local function scaleVec(vec, scalar)
            return vector3(vec.x * scalar, vec.y * scalar, vec.z * scalar)
        end

        local centerEnd = playerCoords + scaleVec(camForward, distance)
        local leftEnd = playerCoords + scaleVec(rotateVec(camForward, -coneAngle), distance)
        local rightEnd = playerCoords + scaleVec(rotateVec(camForward, coneAngle), distance)

        local r, g, b = 0, 255, 0 -- green
        local duration = GetGameTimer() + (seconds * 1000) -- keep debug lines visible for specified seconds
        while GetGameTimer() < duration do
            DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, centerEnd.x, centerEnd.y, centerEnd.z, r, g, b, 255)
            DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, leftEnd.x, leftEnd.y, leftEnd.z, r, g, b, 255)
            DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, rightEnd.x, rightEnd.y, rightEnd.z, r, g, b, 255)
            Citizen.Wait(0)
        end
    end)
end


-- implement event handler camera-bounty:requestCapturedAnimals
RegisterNetEvent('camera-bounty:requestCapturedAnimals', function()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local distance = 100.0 -- max distance
    local coneAngle = 15.0 -- fixed cone angle

    local camForward = getCamForwardVector()
    local nearbyAnimals = {}
    local totalAnimalPeds = 0

    local handle, foundPed = FindFirstPed()
    local success = true
    while success do
        if foundPed ~= ped then
            local model = GetEntityModel(foundPed)
            local animalName = PedModels.Animals[model]
            if animalName then
                local animalCoords = GetEntityCoords(foundPed)
                local toAnimal = vector3(animalCoords.x - playerCoords.x, animalCoords.y - playerCoords.y, animalCoords.z - playerCoords.z)
                local dist = #(toAnimal)
                local toAnimalNorm = dist > 0 and vector3(toAnimal.x / dist, toAnimal.y / dist, toAnimal.z / dist) or vector3(0,0,0)
                local dot = toAnimalNorm.x * camForward.x + toAnimalNorm.y * camForward.y + toAnimalNorm.z * camForward.z
                local angle = math.deg(math.acos(dot))

                if dist <= distance and angle <= coneAngle then
                    totalAnimalPeds = totalAnimalPeds + 1

                    if Config.debug then
                        print(string.format("[DEBUG] Animal in cone: %s (model=%s), coords=(%.2f, %.2f, %.2f), dist=%.2f, angle=%.2f",
                            animalName, model, animalCoords.x, animalCoords.y, animalCoords.z, dist, angle))
                    end

                    table.insert(nearbyAnimals, {
                        model = model,
                        name = animalName,
                        coords = animalCoords,
                        dist = dist,
                        angle = angle
                    })
                end

            end

        end
        success, foundPed = FindNextPed(handle)
    end
    EndFindPed(handle)

    if Config.debug then
        print("[DEBUG] Total animals in cone: " .. totalAnimalPeds)
        print("Nearby animals in cone: " .. json.encode(nearbyAnimals))
        debugConstructVisualCone(60, playerCoords, camForward, distance, coneAngle)
    end

    -- Send request to server
    TriggerServerEvent('camera-bounty:requestPayment', nearbyAnimals)
end)