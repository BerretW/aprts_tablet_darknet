Config = {}

-- Pokud používáš QBCore, nech true. Pro ESX dej false (a uprav server.lua pokud je třeba)
Config.Framework = "QBCore" 

Config.AppName = 'darknet'
Config.Label = 'Silk Road'
Config.Icon = 'fas fa-user-secret'
Config.Color = '#2d3436'

-- Definice nelegálních zakázek
Config.Jobs = {
    ['package_run'] = {
        label = "Rychlá zásilka",
        description = "Vyzvedni balíček na molu a doruč ho do Paleta. Žádné otázky.",
        minReputation = 0,      -- Potřebná reputace pro odemčení
        repReward = 15,         -- Kolik reputace dostane za splnění
        payout = 500,           -- (Volitelné) Peníze může dávat i externí script
        
        -- Co se má stát, když hráč klikne na PŘIJMOUT?
        -- Příklad: exports['my_illegal_jobs']:StartPackageRun()
        exportResource = 'my_illegal_jobs', 
        exportName = 'StartPackageRun' 
    },

    ['car_theft'] = {
        label = "Krádež: Infernus",
        description = "Klient chce Infernus v červené barvě. Najdi ho a dovez do přístavu.",
        minReputation = 50,     -- Vyžaduje 50 reputace
        repReward = 35,
        payout = 2000,
        
        exportResource = 'my_illegal_jobs',
        exportName = 'StartCarTheft'
    },

    ['assassination'] = {
        label = "Čistič",
        description = "Někdo mluvil. Postarej se o to, aby už nemluvil. Cíl: Vinewood Hills.",
        minReputation = 200,    -- High level job
        repReward = 100,
        payout = 10000,
        
        exportResource = 'my_illegal_jobs',
        exportName = 'StartHitmanMission'
    }
}