-- =====================================================
-- Core RP - Serveur Principal
-- =====================================================

Core = Core or {}
Core.Players = Core.Players or {}
Core.DB = Core.DB or {}

-- =====================================================
-- DÉMARRAGE DU SERVEUR
-- =====================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^2============================================^0')
        print('^2   Core RP - Démarré avec succès !^0')
        print('^2   Version: 2.0.0^0')
        print('^2   Systèmes: Chat, Inventaire, Santé^0')
        print('^2============================================^0')
        
        -- Vérifier la connexion MySQL
        MySQL.ready(function()
            print('^2[CORE]^0 Connexion MySQL établie')
        end)
    end
end)

-- =====================================================
-- CONNEXION DU JOUEUR
-- =====================================================

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    local identifiers = GetPlayerIdentifiers(source)
    local identifier, steam, license, discord = nil, nil, nil, nil
    
    deferrals.defer()
    Wait(0)
    deferrals.update(string.format('Bonjour %s, vérification en cours...', name))
    
    for _, id in ipairs(identifiers) do
        if string.match(id, 'steam:') then
            steam = id
        elseif string.match(id, 'license:') then
            license = id
            identifier = id
        elseif string.match(id, 'discord:') then
            discord = id
        end
    end
    
    -- Fallback si license manquant
    if not identifier and steam then
        identifier = steam
    end

    if not identifier then
        deferrals.done('❌ Erreur: Impossible de récupérer votre identifiant')
        return
    end
    
    Core.DB.GetUser(identifier, function(user)
        if not user then
            deferrals.update('Création de votre profil...')
            Core.DB.CreateUser(identifier, steam, license, discord, function(userId)
                if Config.Whitelist then
                    deferrals.done('❌ ' .. Config.Messages.notWhitelisted)
                else
                    deferrals.done()
                end
            end)
        else
            if user.banned == 1 then
                deferrals.done('❌ Vous êtes banni: ' .. (user.ban_reason or 'Aucune raison'))
                return
            end
            
            if Config.Whitelist and user.whitelist == 0 then
                deferrals.done('❌ ' .. Config.Messages.notWhitelisted)
                return
            end
            
            Core.DB.UpdateLastConnection(identifier)
            deferrals.update('Chargement de vos données...')
            deferrals.done()
        end
    end)
end)

-- =====================================================
-- CHARGEMENT DU JOUEUR
-- =====================================================

RegisterNetEvent('core:server:playerLoaded')
AddEventHandler('core:server:playerLoaded', function()
    local source = source
    local identifier = GetPlayerIdentifierByType(source, 'license')
    
    if Config.Debug then
        print(string.format('^3[CORE]^0 Joueur %s (source: %s) demande son chargement', GetPlayerName(source), source))
    end
    
    if not identifier then
        print('^1[CORE ERROR]^0 Impossible de récupérer l\'identifier du joueur ' .. source)
        return
    end
    
    Core.DB.GetUser(identifier, function(user)
        if user then
            Core.DB.GetCharacters(user.id, function(characters)
                local cleanedCharacters = {}
                for i, char in ipairs(characters) do
                    table.insert(cleanedCharacters, {
                        id = char.id,
                        firstname = char.firstname,
                        lastname = char.lastname,
                        dateofbirth = char.dateofbirth,
                        sex = char.sex,
                        height = char.height,
                        cash = char.cash,
                        bank = char.bank,
                        job = char.job or 'unemployed',
                        job_grade = char.job_grade or 0,
                        nationality = char.nationality or 'FR'
                    })
                end
                
                Core.Players[source] = {
                    source = source,
                    identifier = identifier,
                    userId = user.id,
                    characters = cleanedCharacters,
                    currentCharacter = nil
                }
                
                if Config.Debug then
                    print(string.format('^2[CORE]^0 Joueur %s chargé avec %d personnage(s)', GetPlayerName(source), #cleanedCharacters))
                end
                
                TriggerClientEvent('core:client:receiveCharacters', source, cleanedCharacters)
            end)
        else
            print('^1[CORE ERROR]^0 Utilisateur non trouvé dans la BDD: ' .. identifier)
        end
    end)
end)

-- =====================================================
-- SÉLECTION DE PERSONNAGE
-- =====================================================

RegisterNetEvent('core:server:selectCharacter')
AddEventHandler('core:server:selectCharacter', function(characterId)
    local source = source
    local player = Core.Players[source]
    if not player then return end
    
    Core.DB.GetCharacter(characterId, function(character)
        if character and character.user_id == player.userId then
            player.currentCharacter = character
            
            Core.DB.GetInventory(characterId, function(inventory)
                player.inventory = inventory
                
                TriggerClientEvent('core:client:loadCharacter', source, {
                    character = character,
                    inventory = inventory
                })
                
                TriggerEvent('core:server:characterLoaded', source, character.id)
                
                if Config.Debug then
                    print(string.format('^2[CORE]^0 %s a chargé le personnage: %s %s', 
                        GetPlayerName(source), character.firstname, character.lastname))
                end
            end)
        end
    end)
end)

-- =====================================================
-- CRÉATION DE PERSONNAGE
-- =====================================================

local function validateCharacterData(data)
    if not data.firstname or not data.lastname then return false, "Prénom et nom requis" end
    if string.len(data.firstname) < 2 or string.len(data.firstname) > 50 then return false, "Prénom invalide" end
    if string.len(data.lastname) < 2 or string.len(data.lastname) > 50 then return false, "Nom invalide" end
    if string.match(data.firstname, "[^%a%s%-]") then return false, "Prénom contient des caractères invalides" end
    if string.match(data.lastname, "[^%a%s%-]") then return false, "Nom contient des caractères invalides" end
    
    if not data.dateofbirth then return false, "Date de naissance requise" end
    local year, month, day = data.dateofbirth:match("(%d+)%-(%d+)%-(%d+)")
    if not year or not month or not day then return false, "Date invalide" end
    local age = os.date("%Y") - tonumber(year)
    if age < 16 or age > 100 then return false, "Âge invalide (16-100 ans)" end
    
    if not data.height or data.height < 150 or data.height > 220 then return false, "Taille invalide" end
    if not data.sex or (data.sex ~= 'M' and data.sex ~= 'F') then return false, "Sexe invalide" end
    
    if not data.nationality then return false, "Nationalité requise" end
    local nationality = string.upper(data.nationality)
    if not Config.SpawnsByNationality[nationality] then return false, "Nationalité non reconnue" end
    
    return true, nil
end

RegisterNetEvent('core:server:createCharacter')
AddEventHandler('core:server:createCharacter', function(data)
    local source = source
    local player = Core.Players[source]
    if not player then 
        print('^1[CORE ERROR]^0 Joueur non trouvé pour la création')
        return 
    end
    
    local isValid, errorMsg = validateCharacterData(data)
    if not isValid then
        Core.Notification.Error(source, errorMsg)
        return
    end
    
    if #player.characters >= Config.MaxCharacters then
        Core.Notification.Error(source, Config.Messages.maxCharacters)
        return
    end
    
    local spawnPosition = Config.SpawnsByNationality[string.upper(data.nationality)] or Config.DefaultSpawn
    
    local characterData = {
        userId = player.userId,
        firstname = data.firstname,
        lastname = data.lastname,
        dateofbirth = data.dateofbirth,
        sex = data.sex,
        height = data.height,
        cash = Config.StartingMoney.cash,
        bank = Config.StartingMoney.bank,
        position = json.encode(spawnPosition),
        skin = json.encode(data.skin or {}),
        nationality = string.upper(data.nationality)
    }
    
    Core.DB.CreateCharacter(characterData, function(characterId)
        if characterId then
            Core.Notification.Success(source, Config.Messages.characterCreated)
            
            Core.DB.GetCharacters(player.userId, function(characters)
                local cleanedCharacters = {}
                for i, char in ipairs(characters) do
                    table.insert(cleanedCharacters, {
                        id = char.id,
                        firstname = char.firstname,
                        lastname = char.lastname,
                        dateofbirth = char.dateofbirth,
                        sex = char.sex,
                        height = char.height,
                        cash = char.cash,
                        bank = char.bank,
                        job = char.job or 'unemployed',
                        job_grade = char.job_grade or 0,
                        nationality = char.nationality or 'FR'
                    })
                end
                player.characters = cleanedCharacters
                TriggerClientEvent('core:client:receiveCharacters', source, cleanedCharacters)
            end)
        else
            Core.Notification.Error(source, 'Erreur lors de la création du personnage')
        end
    end)
end)

-- =====================================================
-- SUPPRESSION DE PERSONNAGE
-- =====================================================

RegisterNetEvent('core:server:deleteCharacter')
AddEventHandler('core:server:deleteCharacter', function(characterId)
    local source = source
    local player = Core.Players[source]
    if not player then return end
    
    Core.DB.GetCharacter(characterId, function(character)
        if character and character.user_id == player.userId then
            -- Vérifier si le personnage est chargé
            for _, p in pairs(Core.Players) do
                if p.currentCharacter and p.currentCharacter.id == characterId then
                    Core.Notification.Error(source, 'Ce personnage est actuellement chargé par un joueur')
                    return
                end
            end

            Core.DB.DeleteCharacter(characterId, function()
                Core.Notification.Success(source, Config.Messages.characterDeleted)
                
                Core.DB.GetCharacters(player.userId, function(characters)
                    local cleanedCharacters = {}
                    for i, char in ipairs(characters) do
                        table.insert(cleanedCharacters, {
                            id = char.id,
                            firstname = char.firstname,
                            lastname = char.lastname,
                            dateofbirth = char.dateofbirth,
                            sex = char.sex,
                            height = char.height,
                            cash = char.cash,
                            bank = char.bank,
                            job = char.job or 'unemployed',
                            job_grade = char.job_grade or 0,
                            nationality = char.nationality or 'FR'
                        })
                    end
                    player.characters = cleanedCharacters
                    TriggerClientEvent('core:client:receiveCharacters', source, cleanedCharacters)
                end)
            end)
        else
            Core.Notification.Error(source, 'Vous ne pouvez pas supprimer ce personnage')
        end
    end)
end)

-- =====================================================
-- ÉVÉNEMENTS SANTÉ
-- =====================================================

RegisterNetEvent('core:health:addHunger')
AddEventHandler('core:health:addHunger', function(amount)
    local source = source
    local player = Core.GetPlayer(source)
    if player and player.health then
        Core.Health.SetHunger(source, player.health.hunger + amount)
    end
end)

RegisterNetEvent('core:health:addThirst')
AddEventHandler('core:health:addThirst', function(amount)
    local source = source
    local player = Core.GetPlayer(source)
    if player and player.health then
        Core.Health.SetThirst(source, player.health.thirst + amount)
    end
end)

RegisterNetEvent('core:health:setHunger')
AddEventHandler('core:health:setHunger', function(value)
    local source = source
    Core.Health.SetHunger(source, value)
end)

RegisterNetEvent('core:health:setThirst')
AddEventHandler('core:health:setThirst', function(value)
    local source = source
    Core.Health.SetThirst(source, value)
end)

RegisterNetEvent('core:health:damageTaken')
AddEventHandler('core:health:damageTaken', function(damage)
    local source = source
    Core.Health.Damage(source, damage, 'Dégâts reçus')
end)

-- =====================================================
-- DÉCONNEXION DU JOUEUR
-- =====================================================

AddEventHandler('playerDropped', function(reason)
    local source = source
    local player = Core.Players[source]
    
    if player and player.currentCharacter then
        local ped = GetPlayerPed(source)
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        local updateData = {
            cash = player.currentCharacter.cash,
            bank = player.currentCharacter.bank,
            position = json.encode({x = coords.x, y = coords.y, z = coords.z, heading = heading}),
            job = player.currentCharacter.job,
            job_grade = player.currentCharacter.job_grade,
            skin = player.currentCharacter.skin,
            isDead = player.currentCharacter.is_dead
        }
        
        Core.DB.UpdateCharacter(player.currentCharacter.id, updateData, function()
            if Config.Debug then
                print(string.format('^3[CORE]^0 Joueur %s déconnecté et sauvegardé', GetPlayerName(source)))
            end
        end)
    end
    
    Core.Players[source] = nil
end)

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

function Core.GetPlayer(source)
    return Core.Players[source]
end

function GetPlayerIdentifierByType(source, idType)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.match(id, idType .. ':') then
            return id
        end
    end
    return nil
end

if Config.Debug then
    print('[CORE] Module Main chargé')
end
