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

local currentZone = nil
local playersCompletedZone = {}
local zoneCount = 0

local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local pickRandomZone = function()
    print('[CameraBounty][SERVER] pickRandomZone called')
    return PHOTOGRAPHY_ZONES[math.random(#PHOTOGRAPHY_ZONES)] -- TODO prevent last active zone from being used
end

Citizen.CreateThread(function()
    print('[CameraBounty][SERVER] Citizen.CreateThread started')
    while true do
        zoneCount = zoneCount + 1
        playersCompletedZone = {}
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

    -- if player has already claimed this bounty, exit out of this method
    print('[CameraBounty][SERVER] checking if player has completed bounty...')
    if playersCompletedZone[src] and tableContains(playersCompletedZone[src], currentZone.id) then
        print('[CameraBounty][SERVER] Player has already claimed this bounty')
        return
    end
    print('[CameraBounty][SERVER] Player has not completed bounty.')

    if isPlayerInPhotographyZone(coords) then
        print('[CameraBounty][SERVER] Player is in the photography zone')

        local payout = calculatePayout()
        print(('[CameraBounty][SERVER] Player payout: %d'):format(payout))

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
    end
end)

-- Allow client to request latest bounty area upon joining server
RegisterNetEvent('camera-bounty:requestActiveZone', function()
    print('[CameraBounty][SERVER] Player requested active zone')
    local src = source
    if currentZone then
        -- Only send zone if player hasn't completed it
        if not (playersCompletedZone[src] and tableContains(playersCompletedZone[src], currentZone.id)) then
            TriggerClientEvent('camera-bounty:setActiveZone', src, currentZone.x, currentZone.y, currentZone.z, currentZone.radius, currentZone.id)
        else
            print(('[CameraBounty][SERVER] Player %d has already completed zone %d, not sending zone'):format(src, currentZone.id))
        end
    end
end)