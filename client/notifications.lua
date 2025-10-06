-- =====================================================
-- SYSTÈME DE NOTIFICATIONS CLIENT (Version Sécurisée & Optimisée)
-- =====================================================

Core = Core or {}
Core.Notification = Core.Notification or {}

local lastNotify = 0
local allowedTypes = {
    success = true,
    error = true,
    warning = true,
    info = true
}

--[[ 
    Affiche une notification à l'écran via NUI
    @param message string - Le message à afficher
    @param type string - success | error | warning | info
    @param duration number - Durée d'affichage en ms (par défaut 5000)
]]
function Core.Notification.Show(message, type, duration)
    if not message or message == "" then
        print("^1[CORE ERROR]^0 Notification: Message manquant ou vide")
        return
    end

    -- Anti-spam léger
    local now = GetGameTimer()
    if now - lastNotify < 100 then return end
    lastNotify = now

    type = (allowedTypes[type] and type) or "info"
    duration = tonumber(duration) or 5000

    if GetResourceState(GetCurrentResourceName()) ~= "started" then
        print("^3[CORE WARNING]^0 Notification ignorée : UI non initialisée")
        return
    end

    SendNUIMessage({
        action = "notify",
        message = message,
        type = type,
        duration = duration
    })

    if Config.Debug then
        local colorCodes = {
            success = "^2",
            error = "^1",
            warning = "^3",
            info = "^5"
        }
        local color = colorCodes[type] or "^0"
        print(string.format("%s[NOTIFICATION %s]^0 %s", color, string.upper(type), message))
    end
end

-- =====================================================
-- RACCOURCIS DE TYPE
-- =====================================================

function Core.Notification.Success(message, duration)
    Core.Notification.Show(message, "success", duration)
end

function Core.Notification.Error(message, duration)
    Core.Notification.Show(message, "error", duration)
end

function Core.Notification.Warning(message, duration)
    Core.Notification.Show(message, "warning", duration)
end

function Core.Notification.Info(message, duration)
    Core.Notification.Show(message, "info", duration)
end

-- =====================================================
-- INTÉGRATION AVEC LE SYSTÈME EXISTANT
-- =====================================================

RegisterNetEvent("core:client:notify", function(message, type, duration)
    Core.Notification.Show(message, type, duration)
end)

-- =====================================================
-- COMMANDES DE TEST (Debug uniquement)
-- =====================================================

if Config.Debug then
    RegisterCommand("testnotify", function()
        Core.Notification.Success("Test de notification de succès !")
    end)

    RegisterCommand("testerror", function()
        Core.Notification.Error("Test de notification d'erreur !")
    end)

    RegisterCommand("testwarn", function()
        Core.Notification.Warning("Test de notification d'avertissement !")
    end)

    RegisterCommand("testinfo", function()
        Core.Notification.Info("Test de notification d'information !")
    end)

    RegisterCommand("testcustom", function(_, args)
        local message = table.concat(args, " ") or "Notification personnalisée"
        Core.Notification.Show(message, "info", 10000)
    end)

    RegisterCommand("testspam", function()
        for i = 1, 10 do
            Citizen.SetTimeout(i * 300, function()
                Core.Notification.Info("Notification #" .. i)
            end)
        end
    end)

    print("^2[CORE]^0 Module Notifications chargé avec succès")
end
