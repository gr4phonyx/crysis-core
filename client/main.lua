-- =====================================================
-- Core RP - Client Principal (Version Optimisée & Sécurisée)
-- =====================================================

Core = {} -- ⚠️ Doit toujours être en première ligne
Core.PlayerData = {}
Core.PlayerLoaded = false
local cam

-- =====================================================
-- DÉMARRAGE DU CLIENT
-- =====================================================

Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do
        Citizen.Wait(100)
    end
    Citizen.Wait(1000)
    TriggerServerEvent('core:server:playerLoaded')
end)

-- =====================================================
-- RÉCEPTION DES PERSONNAGES
-- =====================================================

RegisterNetEvent('core:client:receiveCharacters')
AddEventHandler('core:client:receiveCharacters', function(characters)
    if Config.Debug then
        print(string.format('^2[CORE]^0 Reçu %d personnage(s)', #characters))
        for i, char in ipairs(characters) do
            print(string.format('  - %s %s (ID: %s)', char.firstname, char.lastname, char.id))
        end
    end
    
    -- Ouvrir l'interface
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openCharacterSelection',
        characters = characters,
        maxCharacters = Config.MaxCharacters
    })
    
    -- Caméra de sélection
    DoScreenFadeOut(500)
    Wait(500)
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, -1042.71, -2745.87, 21.35)
    SetEntityHeading(ped, 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    SetEntityCollision(ped, false, false)

    if not cam or not DoesCamExist(cam) then
        cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end
    SetCamCoord(cam, -1040.71, -2745.87, 22.35)
    SetCamRot(cam, 0.0, 0.0, 270.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    
    DoScreenFadeIn(500)
end)

-- =====================================================
-- CHARGEMENT DU PERSONNAGE
-- =====================================================

RegisterNetEvent('core:client:loadCharacter')
AddEventHandler('core:client:loadCharacter', function(data)
    local ped = PlayerPedId()
    Core.PlayerData = data.character or {}
    Core.PlayerLoaded = true
    
    -- Fermer l'UI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    
    -- Désactiver la caméra
    if cam and DoesCamExist(cam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    
    DoScreenFadeOut(500)
    Wait(500)
    
    -- Charger l'apparence
    if data.character and data.character.skin then
        local ok, skin = pcall(json.decode, data.character.skin)
        if ok and type(skin) == "table" then
            -- TODO: appliquer le skin (fivem-appearance, etc.)
        else
            print("^1[CORE]^0 Erreur lors du chargement du skin.")
        end
    end
    
    -- Spawn du joueur
    local spawnPos
    if data.character and data.character.position then
        local ok, decoded = pcall(json.decode, data.character.position)
        if ok and type(decoded) == "table" then
            spawnPos = decoded
        end
    end
    spawnPos = spawnPos or Config.DefaultSpawn

    SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z)
    SetEntityHeading(ped, spawnPos.heading or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    SetEntityCollision(ped, true, true)
    
    DoScreenFadeIn(500)
    
    -- Message de bienvenue
    local fullName = (data.character.firstname or "?") .. " " .. (data.character.lastname or "?")
    local msg = string.format(Config.Messages.welcomeBack, fullName)
    TriggerEvent('core:client:notify', msg, 'success')
    
    if Config.Debug then
        print(string.format('^2[CORE]^0 Personnage chargé : %s %s', data.character.firstname, data.character.lastname))
    end
end)

-- =====================================================
-- GESTION DE L'ARRÊT RESSOURCE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if cam and DoesCamExist(cam) then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(cam, false)
        end
    end
end)

-- =====================================================
-- FONCTIONS UI
-- =====================================================

function CloseCharacterMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeUI" })
end

-- =====================================================
-- CALLBACKS NUI
-- =====================================================

RegisterNUICallback("selectCharacter", function(data, cb)
    if data and tonumber(data.characterId) then
        TriggerServerEvent("core:server:selectCharacter", tonumber(data.characterId))
        CloseCharacterMenu()
    else
        TriggerEvent('core:client:notify', 'Personnage invalide', 'error')
    end
    cb("ok")
end)

RegisterNUICallback("deleteCharacter", function(data, cb)
    if data and tonumber(data.characterId) then
        TriggerServerEvent("core:server:deleteCharacter", tonumber(data.characterId))
    else
        TriggerEvent('core:client:notify', 'ID invalide', 'error')
    end
    cb("ok")
end)

RegisterNUICallback("createCharacter", function(data, cb)
    if not data or not data.firstname or not data.lastname then
        TriggerEvent('core:client:notify', 'Nom ou prénom manquant', 'error')
        cb("error")
        return
    end
    if #data.firstname < 2 or #data.lastname < 2 then
        TriggerEvent('core:client:notify', 'Nom trop court', 'error')
        cb("error")
        return
    end
    TriggerServerEvent("core:server:createCharacter", data)
    cb("ok")
end)

RegisterNUICallback("closeUI", function(_, cb)
    CloseCharacterMenu()
    cb("ok")
end)

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

function Core.GetPlayerData()
    return Core.PlayerData
end

function Core.IsPlayerLoaded()
    return Core.PlayerLoaded
end

RegisterNetEvent('core:client:updateMoney')
AddEventHandler('core:client:updateMoney', function(moneyType, amount)
    if Core.PlayerData then
        Core.PlayerData[moneyType] = amount
        SendNUIMessage({
            action = 'updateMoney',
            moneyType = moneyType,
            amount = amount
        })
    end
end)

-- =====================================================
-- COMMANDES DE TEST
-- =====================================================

if Config.Debug then
    RegisterCommand('testnotify', function()
        TriggerEvent('core:client:notify', 'Test de notification !', 'success')
    end)
    
    RegisterCommand('showdata', function()
        print(json.encode(Core.PlayerData, { indent = true }))
    end)
    
    print('[CORE] Module Client chargé avec succès')
end
