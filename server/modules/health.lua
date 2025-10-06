-- =====================================================
-- SYSTÈME DE SANTÉ - SERVEUR
-- =====================================================

Core.Health = Core.Health or {}

-- Configuration
local HealthConfig = {
    RespawnTime = 60,     -- secondes avant respawn automatique
    RespawnCost = 5000    -- coût éventuel pour respawn
}

-- =====================================================
-- FONCTIONS DE GESTION DE LA MORT
-- =====================================================

-- Met un joueur en état mort
function Core.Health.Kill(source, reason)
    local player = Core.GetPlayer(source)
    if not player then return end

    player.health = player.health or {}
    player.health.isDead = true

    TriggerClientEvent('core:client:playerDied', source, reason)

    if Config.Debug then
        print(string.format('^3[HEALTH]^0 Joueur %s est mort: %s', GetPlayerName(source), reason or "Inconnu"))
    end
end

-- =====================================================
-- RÉANIMATION / RESPAWN
-- =====================================================

-- Respawn forcé depuis le serveur
RegisterNetEvent('core:health:forceRespawn')
AddEventHandler('core:health:forceRespawn', function(pos)
    local source = source
    local player = Core.GetPlayer(source)
    if not player then return end

    player.health = player.health or {}
    player.health.isDead = false

    pos = pos or Config.DefaultSpawn

    TriggerClientEvent('core:client:playerRevived', source, pos)

    if Config.Debug then
        print(string.format('^3[HEALTH]^0 Joueur %s respawn forcé', GetPlayerName(source)))
    end
end)

-- Réanimer un autre joueur (admin / événements)
RegisterNetEvent('core:health:revivePlayer')
AddEventHandler('core:health:revivePlayer', function(target)
    local targetPlayer = Core.GetPlayer(target)
    if not targetPlayer or not targetPlayer.health or not targetPlayer.health.isDead then return end

    targetPlayer.health.isDead = false
    local coords = GetEntityCoords(GetPlayerPed(target))

    TriggerClientEvent('core:client:playerRevived', target, coords)

    if Config.Debug then
        print(string.format('^3[HEALTH]^0 Joueur %s réanimé par %s', GetPlayerName(target), GetPlayerName(source)))
    end
end)

-- Respawn demandé par le joueur (ex: via UI)
RegisterNetEvent('core:health:requestRespawn')
AddEventHandler('core:health:requestRespawn', function()
    local source = source
    local player = Core.GetPlayer(source)
    if not player or not player.health or not player.health.isDead then return end

    player.health.isDead = false
    local pos = Config.DefaultSpawn

    TriggerClientEvent('core:client:playerRevived', source, pos)

    if Config.Debug then
        print(string.format('^3[HEALTH]^0 Joueur %s a demandé un respawn', GetPlayerName(source)))
    end
end)

-- =====================================================
-- UTILITAIRES (optionnel)
-- =====================================================

-- Vérifie si un joueur est mort
function Core.Health.IsDead(source)
    local player = Core.GetPlayer(source)
    return player and player.health and player.health.isDead or false
end
