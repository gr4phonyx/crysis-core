-- =====================================================
-- MODULE SANTÉ CLIENT (Version Sécurisée & Optimisée)
-- =====================================================

Core = Core or {}
Core.Health = Core.Health or {}

local playerHealth = {
    health = 200,
    maxHealth = 200,
    armor = 0,
    maxArmor = 100,
    hunger = 100,
    thirst = 100,
    stress = 0,
    isDead = false
}

local isDead = false
local respawnInterval = 60 -- secondes avant téléportation hôpital
local lastRespawnRequest = 0
local respawnCooldown = 5000 -- 5 sec entre 2 requêtes respawn

-- =====================================================
-- MISE À JOUR HUD
-- =====================================================

RegisterNetEvent("core:client:updateHealth", function(data)
    if not data or type(data) ~= "table" then return end
    playerHealth = data
    if GetResourceState(GetCurrentResourceName()) == "started" then
        SendNUIMessage({ action = "updateHealth", health = playerHealth })
    end
end)

-- =====================================================
-- GESTION DE LA MORT
-- =====================================================

RegisterNetEvent("core:client:playerDied", function(reason)
    local ped = PlayerPedId()
    isDead = true
    playerHealth.isDead = true

    -- Bloquer le joueur sans respawn
    SetEntityHealth(ped, 1)
    SetEntityInvincible(ped, true)
    ClearPedTasksImmediately(ped)
    
    -- ✅ CORRECTION: Ne pas téléporter sous la map, juste freeze
    FreezeEntityPosition(ped, true)
    SetPlayerControl(PlayerId(), false, 0)

    -- Effets visuels
    StartScreenEffect("DeathFailOut", 0, true)

    -- Afficher UI de mort
    SendNUIMessage({ action = "showDeathScreen", reason = reason or "Inconnu", timer = respawnInterval })

    -- Désactiver contrôles
    Citizen.CreateThread(function()
        while isDead do
            Citizen.Wait(0)
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) -- caméra souris
            EnableControlAction(0, 2, true)
        end
    end)

    -- Timer respawn
    Citizen.CreateThread(function()
        local timer = respawnInterval
        while timer > 0 and isDead do
            Citizen.Wait(1000)
            timer = timer - 1
            SendNUIMessage({ action = "updateRespawnTimer", time = timer })
            if not isDead then break end
        end

        if isDead then
            SendNUIMessage({ action = "enableRespawn" })
        end
    end)
end)

RegisterNetEvent("core:client:playerRevived", function(position)
    local ped = PlayerPedId()
    isDead = false
    playerHealth.isDead = false

    StopScreenEffect("DeathFailOut")
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    ClearPedTasksImmediately(ped)

    if position then
        SetEntityCoords(ped, position.x, position.y, position.z)
    end

    SetEntityHealth(ped, playerHealth.maxHealth)
    SetPedArmour(ped, playerHealth.armor)

    SendNUIMessage({ action = "hideDeathScreen" })
end)

-- =====================================================
-- SYNC HEALTH SERVEUR (✅ SÉCURISÉ)
-- =====================================================

RegisterNetEvent("core:client:setEntityHealth", function(h)
    local ped = PlayerPedId()
    playerHealth.health = h
    if DoesEntityExist(ped) then
        SetEntityHealth(ped, h)
    end
end)

RegisterNetEvent("core:client:setPedArmour", function(a)
    local ped = PlayerPedId()
    playerHealth.armor = a
    if DoesEntityExist(ped) then
        SetPedArmour(ped, a)
    end
end)

-- =====================================================
-- NUI CALLBACKS
-- =====================================================

RegisterNUICallback("requestRespawn", function(_, cb)
    local now = GetGameTimer()
    if now - lastRespawnRequest < respawnCooldown then
        TriggerEvent("core:client:notify", "Patiente avant de redemander un respawn.", "warning")
        cb("too_soon")
        return
    end
    lastRespawnRequest = now
    TriggerServerEvent("core:health:requestRespawn")
    cb("ok")
end)

RegisterNUICallback("callMedic", function(_, cb)
    TriggerServerEvent("core:health:callMedic")
    cb("ok")
end)

-- =====================================================
-- ✅ SURVEILLANCE PASSIVE (optimisé)
-- Détecte les changements mais NE LES ENVOIE PAS au serveur
-- Le serveur est la SOURCE DE VÉRITÉ
-- =====================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- ✅ Optimisé: 5 secondes au lieu de 1
        if not isDead then
            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then goto continue end

            local health = GetEntityHealth(ped)
            local armor = GetPedArmour(ped)

            -- ✅ SÉCURITÉ: On détecte juste les changements anormaux
            -- Le serveur gère la vraie valeur via TriggerEvent
            if health <= 0 and not isDead then
                TriggerServerEvent("core:health:playerDied", "Mort détectée")
            end

            -- Mettre à jour l'affichage local
            playerHealth.health = health
            playerHealth.armor = armor
        end
        ::continue::
    end
end)

if Config.Debug then
    print("^2[CORE]^0 Module Santé Client chargé")
end