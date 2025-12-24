Config = {}
Config.AppName = 'darknet'
Config.Label = 'Silk Road'
Config.Color = '#2d3436'
Config.Icon = 'fas fa-user-secret'
Config.CustomJobRepLimit = 100 

Config.Jobs = {
    -- === TYP: DELIVERY ===
    ['drug_run_1'] = {
        label = "Dovoz: Přístav",
        description = "Vyzvedni balík v přístavu.",
        minReputation = 0,
        repReward = 10,
        payout = 500,
        
        type = "delivery", -- Odkazuje na missions/delivery/client.lua
        
        -- Parametry pro tento typ
        location = vector3(141.42802429199, -3004.9709472656, 7.0309224128723),
        blipText = "Předání zboží"
    },

    -- === TYP: HEIST (Varianta 1: Bankomat) ===
    ['atm_hack_fleeca'] = {
        label = "Hack: ATM Fleeca",
        description = "Nabourej se do bankomatu u dálnice.",
        minReputation = 20,
        repReward = 25,
        payout = 1500,

        type = "heist", -- Odkazuje na missions/heist/client.lua

        -- Parametry
        targetCoords = vector3(-2962.60, 482.17, 15.70),
        hackDifficulty = 'easy', -- easy, medium, hard
        duration = 5000, -- Jak dlouho trvá akce
        requiredItem = 'laptop' -- (Volitelné)
    },

    -- === TYP: HEIST (Varianta 2: Sejf v obchodě) ===
    ['shop_safe_robbery'] = {
        label = "Loupež: Sejf 24/7",
        description = "Otevři sejf v obchodě v Sandy Shores.",
        minReputation = 150,
        repReward = 80,
        payout = 5000,

        type = "heist", -- Stejný kód jako výše!

        -- Jiné parametry
        targetCoords = vector3(1959.25, 3741.53, 32.34),
        hackDifficulty = 'hard',
        duration = 15000,
        requiredItem = 'advanced_lockpick'
    },
     ['weed_street_sale'] = {
        label = "Dealer: Chamberlain Hills",
        description = "Mám 5 balíčků. Zbav se jich v okolí Chamberlain Hills. Nenápadně.",
        minReputation = 10,
        repReward = 25,
        payout = 1500, -- Výplata až když prodáš všechno

        type = "drug_sale",

        -- Parametry mise
        location = vector3(140.35, -1950.47, 20.75), -- Střed oblasti
        radius = 50.0,          -- Jak velká je oblast prodeje
        item = "joint",    -- Co prodáváš (musí být v inventáři)
        totalAmount = 5,        -- Kolik kusů musíš prodat celkem (1 NPC = 1 kus)
        rejectionChance = 30,   -- 30% šance, že NPC zavolá policii nebo zaútočí
        
        -- Volitelné: Animace prodeje
        animDict = "mp_common",
        animClip = "givetake2_a"
    },
}