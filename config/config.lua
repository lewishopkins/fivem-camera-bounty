Config = {}

-- Enable debug logs and visualisations when the camera is used
Config.debug = false

-- Bank details
Config.COMPANY_NAME = "Los Santos Stockshots" -- The company name
Config.BANK_DEPOSIT_MESSAGE = "Photo Bounty Reward" -- The bank reference
Config.BANK_DEPOSIT_COMPANY = "Business Account / " .. Config.COMPANY_NAME -- The bank account sending the money

-- Rewards
Config.MIN_PAYOUT = 50 -- The minimum payout
Config.MAX_PAYOUT = 300 -- The maximum payout

-- Photography zones
Config.PHOTOGRAPHY_ZONES = {
    { x = 1172.4, y = 2696.8, z = 37.1, radius = 250.0 },
}

-- How long a zone is active
-- A new zone is spawned immediately after the previous expires
Config.ZONE_DURATION_MINUTES = 3

-- announce in chat when a new zone is active?
Config.ANNOUNCE_ZONE_CHANGES = false