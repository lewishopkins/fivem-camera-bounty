local ZONE_DURATION_MINUTES = 3
local COMPANY_NAME = "Los Santos Stockshots"
local BANK_DEPOSIT_MESSAGE = "Photo Bounty Reward"
local BANK_DEPOSIT_COMPANY = "Business Account / " .. COMPANY_NAME
local MIN_PAYOUT = 50
local MAX_PAYOUT = 300
local DIMINISHING_RETURNS = 0.1
local PHOTOGRAPHY_ZONES = {
    { x = 1172.4, y = 2696.8, z = 37.1, radius = 250.0 },
}

-- state
local currentZone = nil
local eligiblePlayers = {} -- Players who have captured a photo in the current zone and are eligible for a reward
local playersCompletedZone = {} -- Players who have received their reward
local zoneCount = 0

local animalModels = AnimalModels

local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local pickRandomZone = function()
    return PHOTOGRAPHY_ZONES[math.random(#PHOTOGRAPHY_ZONES)] -- TODO prevent last active zone from being used
end

Citizen.CreateThread(function()
    while true do
        zoneCount = zoneCount + 1
        playersCompletedZone = {}
        eligiblePlayers = {}
        currentZone = pickRandomZone()
        currentZone.id = zoneCount
        TriggerClientEvent('camera-bounty:setActiveZone', -1, currentZone.x, currentZone.y, currentZone.z, currentZone.radius, currentZone.id)

        Citizen.Wait(ZONE_DURATION_MINUTES * 60 * 1000)

        -- Zone expired
        TriggerClientEvent('camera-bounty:removeZone', -1, currentZone.id)
        currentZone = nil
    end
end)

local isPlayerInPhotographyZone = function(playerCoords)
    if not currentZone then return false end
    local px, py = playerCoords.x or playerCoords[1], playerCoords.y or playerCoords[2]
    local zx, zy = currentZone.x, currentZone.y
    local distance = math.sqrt((px - zx)^2 + (py - zy)^2)
    return distance <= currentZone.radius
end

local calculatePayout = function(photographedAnimalsCount)
    if not currentZone then return 0 end

    -- player starts with a flat 10% of the max payout
    local payout = 0.1 * MAX_PAYOUT

    print(("[Camera Bounty] Player %d initial payout: %.2f"):format(source, payout))

    -- player gets 50% if they photographed an animal
    if photographedAnimalsCount > 0 then
        payout = payout + (0.5 * MAX_PAYOUT)
        print(("[Camera Bounty] Player %d additional payout for photographing animals: %.2f"):format(source, 0.5 * MAX_PAYOUT))
    end

    -- what percent is the player close to the center of the zone?
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local dx = playerCoords.x - currentZone.x
    local dy = playerCoords.y - currentZone.y
    local dz = playerCoords.z - currentZone.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    local maxDistance = currentZone.radius
    local percent = 1 - (distance / maxDistance)
    percent = math.max(0, math.min(percent, 1))

    -- player gets up to 40% additional payout based on proximity
    local proximityBonus = percent * 0.4 * (MAX_PAYOUT - MIN_PAYOUT)
    payout = payout + proximityBonus

    print(("[Camera Bounty] Player %d proximity bonus: %.2f"):format(source, proximityBonus))

    -- Make sure value hasn't breached the maximum
    -- and is a round number
    payout = math.floor(math.min(payout, MAX_PAYOUT))
    print(("[Camera Bounty] Player %d final payout: %d"):format(source, payout))
    -- and is not less than the minimum
    payout = math.max(payout, MIN_PAYOUT)
    print(("[Camera Bounty] Player %d final payout (after min check): %d"):format(source, payout))

    return payout
end

-- Player capture photo
RegisterNetEvent('npwd:UploadPhoto', function(reqObj, x, y)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    -- if player has already claimed this bounty, exit out of this method
    if playersCompletedZone[src] and tableContains(playersCompletedZone[src], currentZone.id) then
        return
    end

    if isPlayerInPhotographyZone(coords) then

        -- Player is now eligible for payout
        -- add to eligiblePlayers list
        eligiblePlayers[zoneCount] = eligiblePlayers[zoneCount] or {}
        table.insert(eligiblePlayers[zoneCount], src)

        -- Give client go-ahead to request payment by sending us list of photographed animals
        TriggerClientEvent('camera-bounty:requestCapturedAnimals', src)
    end
end)

-- Client calls server with array of animals captured in photo
RegisterNetEvent('camera-bounty:requestPayment', function(capturedAnimals)
    local src = source
    -- Process the captured animals array
    if Config.debug then
        print(("[Camera Bounty] Player %d submitted captured animals: %s"):format(src, json.encode(capturedAnimals)))
        for _, animal in ipairs(capturedAnimals) do
            print(("[Camera Bounty] Player %d captured animal: %s"):format(src, json.encode(animal)))
        end
    end

    -- anti-scum: if player isn't in eligiblePlayers or is in playersCompletedZone, reject
    if not (eligiblePlayers[currentZone.id] and tableContains(eligiblePlayers[currentZone.id], src))
        or (playersCompletedZone[src] and tableContains(playersCompletedZone[src], currentZone.id)) then
            print(("[Camera Bounty] Player %d is not eligible for payout"):format(src))
        return
    end

    print(("[Camera Bounty] Player %d is eligible for payout"):format(src))
    local payout = calculatePayout(#capturedAnimals)
    print(("[Camera Bounty] Player %d payout: %d"):format(src, payout))

    -- Get citizenid from Qbox/QBcore
    local Player = exports['qbx_core']:GetPlayer(src)
    local citizenid = Player and Player.PlayerData and Player.PlayerData.citizenid or tostring(src)
    local characterName = Player and Player.PlayerData and Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname and Player.PlayerData.charinfo.firstname .. ' ' .. (Player.PlayerData.charinfo.lastname or '') or GetPlayerName(src)

    -- add them to the claimed
    playersCompletedZone[src] = playersCompletedZone[src] or {}
    table.insert(playersCompletedZone[src], currentZone.id)

    -- remove bounty zone from map on client
    TriggerClientEvent('camera-bounty:removeZone', src, currentZone.id)

    -- Pay the player to their bank account
    exports['Renewed-Banking']:handleTransaction(
        citizenid,
        BANK_DEPOSIT_COMPANY,
        payout,
        BANK_DEPOSIT_MESSAGE,
        COMPANY_NAME,
        characterName,
        'deposit'
    )

    -- send player a payout notification
    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 255, 0 },
        args = { "[Photo Bounty]", "You earned $" .. payout .. " for your photo!" }
    })
end)

-- Allow client to request latest bounty area upon joining server
RegisterNetEvent('camera-bounty:requestActiveZone', function()
    local src = source
    if currentZone then
        -- Only send zone if player hasn't completed it
        if not (playersCompletedZone[src] and tableContains(playersCompletedZone[src], currentZone.id)) then
            TriggerClientEvent('camera-bounty:setActiveZone', src, currentZone.x, currentZone.y, currentZone.z, currentZone.radius, currentZone.id)
        end
    end
end)