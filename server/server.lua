require 'config'

local currentZone = nil
local zoneCount = 0

local ZONE_DURATION_MINUTES = Config.ZONE_DURATION_MINUTES

-- The company which appears in the player's transactions
local COMPANY_NAME = Config.COMPANY_NAME
local BANK_DEPOSIT_MESSAGE = Config.BANK_DEPOSIT_MESSAGE
local BANK_DEPOSIT_COMPANY = Config.BANK_DEPOSIT_COMPANY

-- Payout configuration per photo
local MIN_PAYOUT = Config.MIN_PAYOUT
local MAX_PAYOUT = Config.MAX_PAYOUT

-- diminishing returns (grind prevention): the percentage drop off per photo (10%)
-- resets when the server restarts
local DIMINISHING_RETURNS = Config.DIMINISHING_RETURNS

-- RNG photography zones
local photographyZones = Config.PHOTOGRAPHY_ZONES

local pickRandomZone = function()
    print('[CameraBounty][SERVER] pickRandomZone called')
    return photographyZones[math.random(#photographyZones)] -- TODO prevent last active zone from being used
end

Citizen.CreateThread(function()
    print('[CameraBounty][SERVER] Citizen.CreateThread started')
    while true do
        zoneCount = zoneCount + 1
        currentZone = pickRandomZone()
        currentZone.id = zoneCount
        print(('[CameraBounty][SERVER] New active zone: x=%.2f, y=%.2f, z=%.2f, radius=%.2f, id=%d'):format(currentZone.x, currentZone.y, currentZone.z, currentZone.radius, currentZone.id))
        TriggerClientEvent('camera-bounty:setActiveZone', -1, currentZone.x, currentZone.y, currentZone.z, currentZone.radius, currentZone.id)
        print('[CameraBounty][SERVER] TriggerClientEvent camera-bounty:setActiveZone sent to all clients')

        Citizen.Wait(ZONE_DURATION_MINUTES * 60 * 1000)

        -- Zone expired
        print(('[CameraBounty][SERVER] Zone expired, dispatching removal event for id=%d'):format(currentZone.id))
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

local calculatePayout = function()
    if not currentZone then return 0 end

    local payout = MIN_PAYOUT
    print(('[CameraBounty][SERVER] Base payout: %d'):format(payout))

    -- what percent is the player close to the center of the zone?
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local dx = playerCoords.x - currentZone.x
    local dy = playerCoords.y - currentZone.y
    local dz = playerCoords.z - currentZone.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    local maxDistance = currentZone.radius
    local percent = 1 - (distance / maxDistance)
    percent = math.max(0, math.min(percent, 1))
    print(('[CameraBounty][SERVER] Player proximity percent: %.2f'):format(percent * 100))

    -- player gets 70% of the payout based on proximity
    payout = payout + (percent * 0.7 * (MAX_PAYOUT - MIN_PAYOUT))
    print(('[CameraBounty][SERVER] Proximity-based payout: %.2f'):format(payout))

    -- TODO: wildlife check, reward bonus.
    -- in the meantime, let's reward a random bonus of up to 30% of the max payout.
    local randomBonus = math.random(0, 30)
    payout = payout + (randomBonus / 100 * MAX_PAYOUT)
    print(('[CameraBounty][SERVER] Random bonus applied: %d%%'):format(randomBonus))

    -- TODO: Save player earnings on the server, apply diminishing returns

    -- Make sure value hasn't breached the maximum
    -- and is a round number
    payout = math.floor(math.min(payout, MAX_PAYOUT))

    print(('[CameraBounty][SERVER] Final payout: %d'):format(payout))

    return payout
end

RegisterNetEvent('npwd:UploadPhoto', function(reqObj, x, y)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    if isPlayerInPhotographyZone(coords) then
        print('[CameraBounty][SERVER] Player is in the photography zone')

        local payout = calculatePayout()
        print(('[CameraBounty][SERVER] Player payout: %d'):format(payout))

        -- Get citizenid from Qbox/QBcore
        local Player = exports['qbx_core']:GetPlayer(src)
        local citizenid = Player and Player.PlayerData and Player.PlayerData.citizenid or tostring(src)
        local playerName = GetPlayerName(src)

        -- Pay the player to their bank account
        exports['Renewed-Banking']:handleTransaction(
            citizenid,
            BANK_DEPOSIT_COMPANY,
            payout,
            BANK_DEPOSIT_MESSAGE,
            COMPANY_NAME,
            playerName,
            'deposit'
        )


        -- send player a payout notification
        TriggerClientEvent('chat:addMessage', src, {
            color = { 0, 255, 0 },
            args = { "[Photo Bounty]", "You earned $" .. payout .. " for your photo!" }
        })
    end
end)

-- Allow client to request latest bounty area upon joining server
RegisterNetEvent('camera-bounty:requestActiveZone', function()
    local src = source
    if currentZone then
        TriggerClientEvent('camera-bounty:setActiveZone', src, currentZone.x, currentZone.y, currentZone.z, currentZone.radius, currentZone.id)
    end
end)