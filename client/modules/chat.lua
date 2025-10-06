-- =====================================================
-- SYSTÈME DE CHAT - CLIENT (Version Sécurisée & Optimisée)
-- =====================================================

Core = Core or {}
Core.Chat = Core.Chat or {}

local chatOpen = false
local chatHistory = {}
local maxHistory = 100
local lastMessageTime = 0
local spamCooldown = 500 -- en ms

-- =====================================================
-- GESTION DE L'INTERFACE
-- =====================================================

function Core.Chat.OpenChat()
    if chatOpen then return end

    chatOpen = true
    SetNuiFocus(true, true)

    if GetResourceState(GetCurrentResourceName()) ~= "started" then
        print("^3[CORE WARNING]^0 NUI non initialisée, chat ignoré.")
        return
    end

    SendNUIMessage({
        action = "openChat",
        history = chatHistory
    })
end

function Core.Chat.CloseChat()
    if not chatOpen then return end

    chatOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeChat" })
end

function Core.Chat.ToggleChat()
    if chatOpen then
        Core.Chat.CloseChat()
    else
        Core.Chat.OpenChat()
    end
end

-- =====================================================
-- RÉCEPTION DES MESSAGES
-- =====================================================

RegisterNetEvent("core:client:receiveMessage", function(message)
    if not message or type(message) ~= "table" then return end

    -- Nettoyer le texte pour éviter crash affichage
    message.message = tostring(message.message or ""):gsub("<", "&lt;"):gsub(">", "&gt;")

    -- Ajouter à l'historique
    table.insert(chatHistory, message)

    -- Limiter l'historique
    if #chatHistory > maxHistory then
        table.remove(chatHistory, 1)
    end

    -- Envoi au NUI
    if GetResourceState(GetCurrentResourceName()) == "started" then
        SendNUIMessage({
            action = "newMessage",
            message = message
        })
    end

    if Config.Debug then
        print(string.format("^3[CHAT]^0 [%s] %s: %s",
            message.channelName or "Général",
            message.sender or "???",
            message.message or ""))
    end
end)

RegisterNetEvent("core:client:receiveHistory", function(history)
    chatHistory = history or {}
    if GetResourceState(GetCurrentResourceName()) == "started" then
        SendNUIMessage({
            action = "loadHistory",
            history = chatHistory
        })
    end
end)

-- =====================================================
-- CALLBACKS NUI
-- =====================================================

RegisterNUICallback("sendMessage", function(data, cb)
    cb("ok")

    if not data or not data.channel or not data.message then return end

    local msg = tostring(data.message):gsub("^%s*(.-)%s*$", "%1") -- trim
    if msg == "" or #msg > 250 then
        TriggerEvent("core:client:notify", "Message invalide ou trop long.", "error")
        return
    end

    -- Anti-spam
    local now = GetGameTimer()
    if now - lastMessageTime < spamCooldown then
        TriggerEvent("core:client:notify", "Ralentis un peu le rythme !", "warning")
        return
    end
    lastMessageTime = now

    TriggerServerEvent("core:chat:sendMessage", data.channel, msg)
end)

RegisterNUICallback("closeChat", function(_, cb)
    Core.Chat.CloseChat()
    cb("ok")
end)

-- =====================================================
-- CONTRÔLES
-- =====================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- T pour ouvrir le chat
        if IsControlJustPressed(0, 245) then -- T
            Core.Chat.OpenChat()
        end

        -- ESC pour fermer
        if chatOpen and IsControlJustPressed(0, 322) then -- ESC
            Core.Chat.CloseChat()
        end
    end
end)

-- =====================================================
-- DEBUG
-- =====================================================

if Config.Debug then
    print("^2[CORE]^0 Module Chat Client chargé avec succès")
end
