ArcaConfig = {}

ArcaConfig.Debug = false

ArcaConfig.Server = {
    MaxCharacters = 4,
    PVP = true,
    Permissions = { 'god', 'admin', 'mod' }, -- highest first, mapped to ace "arca.<perm>"
}

ArcaConfig.Player = {
    SaveInterval = 5,                 -- minutes
    DefaultSpawn = vector4(-269.4, -955.3, 31.2, 205.8),
    Money = { cash = 500, bank = 5000, crypto = 0 },
    MoneyTypes = { 'cash', 'bank', 'crypto' },
    -- hunger/thirst drop by these amounts every minute; at 0 the player slowly loses health
    StatusDecay = { hunger = 0.9, thirst = 1.0 },
    StarvationDamage = 3,             -- health lost every 10s while hunger or thirst is 0
    DefaultMetadata = {
        hunger = 100,
        thirst = 100,
        stress = 0,
        isdead = false,
        inlaststand = false,
        armor = 0,
        jailtime = 0,
    },
}

-- Compatibility layers so resources written for other frameworks run on Arca.
-- qb: arca_core also answers as 'qb-core' (exports['qb-core'], QBCore events, Player.Functions, ...)
ArcaConfig.Bridge = {
    qb = true,
}

ArcaConfig.Progress = {
    CancelKey = 73, -- X
}

ArcaConfig.TextUI = {
    Position = 'left-center', -- left-center | right-center | top-center | bottom-center
}

ArcaConfig.Radial = {
    Key = 'Z', -- default keybind, players can rebind in GTA settings
}

ArcaConfig.Notify = {
    Position = 'top-right',
    Duration = 5000,
}
