Config = {}

-- Configuration générale
Config.ServerName = "Mon Serveur RP"
Config.Locale = 'fr'

-- Configuration de la connexion
Config.Whitelist = true -- Activer/désactiver la whitelist
Config.MaxPlayers = 64

-- Configuration de l'identité
Config.EnableIdentity = true
Config.MaxCharacters = 1 -- Nombre de personnages par joueur

-- Configuration de l'argent de départ
Config.StartingMoney = {
    cash = 5000,    -- Argent liquide
    bank = 25000    -- Argent en banque
}

-- Configuration du spawn par défaut (utilisé si aucune nationalité ou position sauvegardée)
Config.DefaultSpawn = {
    x = -1035.71, 
    y = -2731.87, 
    z = 12.75, 
    heading = 0.0
}

-- Configuration du spawn par nationalité
Config.SpawnsByNationality = {
    FR = { x = -1035.71, y = -2731.87, z = 12.75, heading = 0.0 }, -- France
    US = { x = 200.0, y = -900.0, z = 30.0, heading = 90.0 }        -- USA
}

-- Configuration de la base de données
Config.Database = {
    table_users = 'users',
    table_characters = 'characters',
    table_inventory = 'inventory',
    table_vehicles = 'vehicles'
}

-- Messages
Config.Messages = {
    notWhitelisted = "Vous n'êtes pas whitelist sur ce serveur !",
    welcomeBack = "Bienvenue %s !",
    maxCharacters = "Vous avez atteint le nombre maximum de personnages !",
    characterCreated = "Personnage créé avec succès !",
    characterDeleted = "Personnage supprimé !",
}

-- Debug mode
Config.Debug = true