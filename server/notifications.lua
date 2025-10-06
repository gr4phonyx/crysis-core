-- =====================================================
-- SYSTÈME DE NOTIFICATIONS SERVEUR
-- =====================================================

Core.Notification = Core.Notification or {}

--[[ 
    Envoie une notification à un joueur spécifique
    @param source number - L'ID du joueur
    @param message string - Le message à afficher
    @param type string - Type: 'success', 'error', 'warning', 'info'
    @param duration number - Durée en millisecondes (optionnel)
]]
function Core.Notification.Send(source, message, type, duration)
    if not source or not message then
        print('^1[CORE ERROR]^0 Notification.Send: source ou message manquant')
        return
    end
    
    type = type or 'info'
    duration = duration or 5000
    
    TriggerClientEvent('core:client:notify', source, message, type, duration)
    
    if Config.Debug then
        local playerName = GetPlayerName(source) or 'Unknown'
        print(string.format('^3[NOTIFICATION]^0 %s [%s] -> %s: %s', 
            string.upper(type), source, playerName, message))
    end
end

-- Raccourcis pour les types de notifications
function Core.Notification.Success(source, message, duration)
    Core.Notification.Send(source, message, 'success', duration)
end

function Core.Notification.Error(source, message, duration)
    Core.Notification.Send(source, message, 'error', duration)
end

function Core.Notification.Warning(source, message, duration)
    Core.Notification.Send(source, message, 'warning', duration)
end

function Core.Notification.Info(source, message, duration)
    Core.Notification.Send(source, message, 'info', duration)
end

-- Envoie une notification à tous les joueurs
function Core.Notification.Broadcast(message, type, duration)
    if not message then
        print('^1[CORE ERROR]^0 Notification.Broadcast: message manquant')
        return
    end
    
    type = type or 'info'
    duration = duration or 5000
    
    TriggerClientEvent('core:client:notify', -1, message, type, duration)
    
    if Config.Debug then
        print(string.format('^3[NOTIFICATION BROADCAST]^0 %s: %s', string.upper(type), message))
    end
end

-- Envoie une notification à plusieurs joueurs
function Core.Notification.SendToMultiple(sources, message, type, duration)
    if not sources or type(sources) ~= 'table' then
        print('^1[CORE ERROR]^0 Notification.SendToMultiple: sources doit être une table')
        return
    end
    type = type or 'info'
    duration = duration or 5000

    for _, source in ipairs(sources) do
        Core.Notification.Send(source, message, type, duration)
    end
end

-- Envoie une notification à tous les joueurs sauf un
function Core.Notification.BroadcastExcept(excludeSource, message, type, duration)
    if not excludeSource or not message then
        print('^1[CORE ERROR]^0 Notification.BroadcastExcept: paramètres manquants')
        return
    end

    type = type or 'info'
    duration = duration or 5000

    local players = GetPlayers()
    for _, source in ipairs(players) do
        local playerId = tonumber(source)
        if playerId and playerId ~= excludeSource then
            Core.Notification.Send(playerId, message, type, duration)
        end
    end
end

-- Envoie une notification à tous les joueurs dans un rayon
function Core.Notification.SendInRadius(coords, radius, message, type, duration)
    if not coords or not radius or not message or not coords.x or not coords.y or not coords.z then
        print('^1[CORE ERROR]^0 Notification.SendInRadius: paramètres invalides')
        return
    end

    type = type or 'info'
    duration = duration or 5000

    local players = GetPlayers()
    for _, source in ipairs(players) do
        local playerId = tonumber(source)
        if playerId then
            local ped = GetPlayerPed(playerId)
            if ped and DoesEntityExist(ped) then
                local playerCoords = GetEntityCoords(ped)
                local distance = #(vector3(coords.x, coords.y, coords.z) - playerCoords)
                if distance <= radius then
                    Core.Notification.Send(playerId, message, type, duration)
                end
            end
        end
    end

    if Config.Debug then
        print(string.format('^3[NOTIFICATION RADIUS]^0 %s dans un rayon de %dm: %s', 
            string.upper(type), radius, message))
    end
end

-- Événement pour compatibilité
RegisterNetEvent('core:server:notify')
AddEventHandler('core:server:notify', function(target, message, type, duration)
    local source = source
    if target ~= source then
        print(string.format('^1[CORE ERROR]^0 Joueur %s a tenté d\'envoyer une notification à %s', source, target))
        return
    end
    Core.Notification.Send(target, message, type, duration)
end)

-- Commandes admin/debug (console seulement)
if Config.Debug then
    RegisterCommand('notifyall', function(source, args)
        if source == 0 then
            local message = table.concat(args, " ")
            if message ~= "" then
                Core.Notification.Broadcast(message, 'info')
                print('^2[ADMIN]^0 Notification envoyée à tous les joueurs')
            else
                print('^1[ADMIN]^0 Usage: notifyall <message>')
            end
        end
    end, true)

    RegisterCommand('notifyplayer', function(source, args)
        if source == 0 then
            local targetId = tonumber(args[1])
            table.remove(args, 1)
            local message = table.concat(args, " ")
            if targetId and message ~= "" then
                Core.Notification.Send(targetId, message, 'info')
                print(string.format('^2[ADMIN]^0 Notification envoyée au joueur %s', targetId))
            else
                print('^1[ADMIN]^0 Usage: notifyplayer <id> <message>')
            end
        end
    end, true)

    RegisterCommand('testnotifyserver', function(source)
        if source ~= 0 then
            Core.Notification.Success(source, 'Test de notification serveur !')
        end
    end, false)
end

if Config.Debug then
    print('^2[CORE]^0 Module Notifications Serveur chargé')
end
