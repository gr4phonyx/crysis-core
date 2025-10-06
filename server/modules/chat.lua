-- =====================================================
-- SYSTÈME DE CHAT - SERVEUR
-- =====================================================

Core.Chat = Core.Chat or {}

local ChatConfig = {
    MaxMessageLength = 256,
    DefaultRange = 20.0,
    ShoutRange = 40.0,
    WhisperRange = 5.0,
    SaveMessages = true,
    MaxHistoryDays = 30
}

local Channels = {
    ['local'] = { name = 'Local', color = '#FFFFFF', range = ChatConfig.DefaultRange },
    ['shout'] = { name = 'Crier', color = '#FF6B6B', range = ChatConfig.ShoutRange },
    ['whisper'] = { name = 'Chuchoter', color = '#A0A0A0', range = ChatConfig.WhisperRange },
    ['me'] = { name = 'Action', color = '#C77DFF', range = ChatConfig.DefaultRange },
    ['do'] = { name = 'Description', color = '#9BF6FF', range = ChatConfig.DefaultRange },
    ['ooc'] = { name = 'HRP', color = '#FFD60A', range = false },
    ['admin'] = { name = 'Admin', color = '#FF0000', range = false, adminOnly = true },
    ['annonce'] = { name = 'Annonce', color = '#00FF00', range = false, adminOnly = true }
}

-- =====================================================
-- BASE DE DONNÉES
-- =====================================================

function Core.Chat.SaveMessage(characterId, channel, message, position)
    if not ChatConfig.SaveMessages then return end
    if not characterId or not channel or not message then return end

    local query = [[
        INSERT INTO chat_messages (character_id, channel, message, position)
        VALUES (?, ?, ?, ?)
    ]]
    
    MySQL.insert(query, {characterId, channel, message, json.encode(position or {})})
end

function Core.Chat.GetHistory(characterId, limit)
    limit = limit or 50
    if not characterId then return {} end

    local query = [[
        SELECT cm.*, c.firstname, c.lastname
        FROM chat_messages cm
        JOIN characters c ON cm.character_id = c.id
        WHERE cm.character_id = ?
        ORDER BY cm.created_at DESC
        LIMIT ?
    ]]
    
    return MySQL.query.await(query, {characterId, limit}) or {}
end

function Core.Chat.CleanOldMessages()
    local query = [[
        DELETE FROM chat_messages
        WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]]
    
    MySQL.execute(query, {ChatConfig.MaxHistoryDays}, function(affectedRows)
        if Config.Debug then
            print(string.format('^2[CHAT]^0 Supprimé %d anciens messages', affectedRows))
        end
    end)
end

-- =====================================================
-- ENVOI DE MESSAGES
-- =====================================================

function Core.Chat.SendMessage(source, channel, message)
    if not message or message == '' then return end
    if string.len(message) > ChatConfig.MaxMessageLength then
        Core.Notification.Error(source, 'Message trop long (max ' .. ChatConfig.MaxMessageLength .. ' caractères)')
        return
    end

    local channelData = Channels[channel]
    if not channelData then
        Core.Notification.Error(source, 'Canal invalide')
        return
    end

    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then return end

    local char = player.currentCharacter
    local senderName = char.firstname .. ' ' .. char.lastname
    local coords = GetEntityCoords(GetPlayerPed(source))

    local chatMessage = {
        channel = channel,
        channelName = channelData.name,
        color = channelData.color,
        sender = senderName,
        senderId = source,
        characterId = char.id,
        message = message,
        position = {x = coords.x, y = coords.y, z = coords.z},
        timestamp = os.time()
    }

    Core.Chat.SaveMessage(char.id, channel, message, chatMessage.position)

    if Config.Debug then
        print(string.format('^3[CHAT]^0 [%s] %s: %s', channelData.name, senderName, message))
    end

    if channelData.range then
        Core.Chat.SendToProximity(source, chatMessage, channelData.range)
    else
        TriggerClientEvent('core:client:receiveMessage', -1, chatMessage)
    end
end

function Core.Chat.SendToProximity(source, message, range)
    if not source or not message or not range then return end

    local coords = GetEntityCoords(GetPlayerPed(source))
    if not coords then return end

    for _, playerId in ipairs(GetPlayers()) do
        local targetId = tonumber(playerId)
        if targetId then
            local targetPed = GetPlayerPed(targetId)
            if targetPed and DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(coords - targetCoords)
                if distance <= range then
                    message.volume = math.max(0.3, 1.0 - (distance / range))
                    TriggerClientEvent('core:client:receiveMessage', targetId, message)
                end
            end
        end
    end
end

-- =====================================================
-- COMMANDES CHAT
-- =====================================================

local function registerChatCommand(cmd, channel, usage)
    RegisterCommand(cmd, function(source, args)
        if #args == 0 then
            Core.Notification.Error(source, usage)
            return
        end
        local message = table.concat(args, ' ')
        Core.Chat.SendMessage(source, channel, message)
    end, false)
end

registerChatCommand('me', 'me', 'Usage: /me [action]')
registerChatCommand('do', 'do', 'Usage: /do [description]')
registerChatCommand('s', 'shout', 'Usage: /s [message]')
registerChatCommand('w', 'whisper', 'Usage: /w [message]')
registerChatCommand('ooc', 'ooc', 'Usage: /ooc [message]')

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

RegisterNetEvent('core:chat:sendMessage')
AddEventHandler('core:chat:sendMessage', function(channel, message)
    local source = source
    Core.Chat.SendMessage(source, channel, message)
end)

RegisterNetEvent('core:chat:requestHistory')
AddEventHandler('core:chat:requestHistory', function()
    local source = source
    local player = Core.GetPlayer(source)
    if player and player.currentCharacter then
        local history = Core.Chat.GetHistory(player.currentCharacter.id)
        TriggerClientEvent('core:client:receiveHistory', source, history)
    end
end)

-- =====================================================
-- NETTOYAGE AUTOMATIQUE
-- =====================================================

if ChatConfig.SaveMessages then
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(24 * 60 * 60 * 1000)
            Core.Chat.CleanOldMessages()
        end
    end)
end

if Config.Debug then
    print('^2[CORE]^0 Module Chat chargé')
end
