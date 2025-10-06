-- =====================================================
-- SYSTÈME D'INVENTAIRE - CLIENT (SÉCURISÉ)
-- =====================================================

Core = Core or {}
Core.Inventory = Core.Inventory or {}

local inventoryOpen = false
local playerInventory = {}
local worldDrops = {}

-- =====================================================
-- GESTION DE L'INTERFACE
-- =====================================================

function Core.Inventory.OpenInventory()
    if inventoryOpen then return end
    
    inventoryOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInventory',
        inventory = playerInventory,
        maxWeight = 50.0,
        currentWeight = Core.Inventory.GetTotalWeight()
    })
end

function Core.Inventory.CloseInventory()
    if not inventoryOpen then return end
    
    inventoryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeInventory'
    })
end

function Core.Inventory.GetTotalWeight()
    local totalWeight = 0
    
    for _, item in pairs(playerInventory) do
        totalWeight = totalWeight + (item.weight * item.quantity)
    end
    
    return totalWeight
end

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

RegisterNetEvent('core:client:updateInventory')
AddEventHandler('core:client:updateInventory', function(inventory)
    playerInventory = inventory or {}
    
    SendNUIMessage({
        action = 'updateInventory',
        inventory = playerInventory,
        currentWeight = Core.Inventory.GetTotalWeight()
    })
end)

RegisterNetEvent('core:client:useItem')
AddEventHandler('core:client:useItem', function(itemName, itemData)
    -- Gérer l'utilisation des items spécifiques
    if itemName == 'bread' then
        -- Manger du pain
        Core.Notification.Info('Vous mangez du pain')
        Core.Inventory.PlayEatAnimation()
        
    elseif itemName == 'water' then
        -- Boire de l'eau
        Core.Notification.Info('Vous buvez de l\'eau')
        Core.Inventory.PlayDrinkAnimation()
        
    elseif itemName == 'bandage' then
        Core.Notification.Info('Vous utilisez un bandage')
        
    elseif itemName == 'medkit' then
        Core.Notification.Info('Vous utilisez un kit médical')
        
    elseif itemName == 'phone' then
        -- Ouvrir le téléphone
        Core.Notification.Info('Ouverture du téléphone...')
        -- TODO: Ajouter votre système de téléphone
    end
end)

-- =====================================================
-- ANIMATIONS
-- =====================================================

function Core.Inventory.PlayEatAnimation()
    local playerPed = PlayerPedId()
    
    RequestAnimDict('mp_player_inteat@burger')
    while not HasAnimDictLoaded('mp_player_inteat@burger') do
        Citizen.Wait(0)
    end
    
    TaskPlayAnim(playerPed, 'mp_player_inteat@burger', 'mp_player_int_eat_burger', 8.0, -8.0, 3000, 49, 0, false, false, false)
    
    Citizen.Wait(3000)
    ClearPedTasks(playerPed)
end

function Core.Inventory.PlayDrinkAnimation()
    local playerPed = PlayerPedId()
    
    RequestAnimDict('mp_player_intdrink')
    while not HasAnimDictLoaded('mp_player_intdrink') do
        Citizen.Wait(0)
    end
    
    TaskPlayAnim(playerPed, 'mp_player_intdrink', 'loop_bottle', 8.0, -8.0, 2000, 49, 0, false, false, false)
    
    Citizen.Wait(2000)
    ClearPedTasks(playerPed)
end

-- =====================================================
-- DROPS AU SOL
-- =====================================================

RegisterNetEvent('core:client:createDrop')
AddEventHandler('core:client:createDrop', function(dropId, dropData)
    worldDrops[dropId] = dropData
    
    -- Créer un marker visuel
    Citizen.CreateThread(function()
        while worldDrops[dropId] do
            Citizen.Wait(0)
            
            local coords = dropData.position
            DrawMarker(27, coords.x, coords.y, coords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
            
            -- Afficher texte si proche
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - coords)
            
            if distance < 2.0 then
                DrawText3D(coords.x, coords.y, coords.z + 0.5, string.format('[E] Ramasser %s x%d', dropData.item, dropData.quantity))
                
                if IsControlJustPressed(0, 38) then -- E
                    TriggerServerEvent('core:inventory:pickupDrop', dropId)
                end
            end
        end
    end)
end)

RegisterNetEvent('core:client:removeDrop')
AddEventHandler('core:client:removeDrop', function(dropId)
    worldDrops[dropId] = nil
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- =====================================================
-- CALLBACKS NUI (✅ SÉCURISÉS)
-- =====================================================

RegisterNUICallback('useItem', function(data, cb)
    if data.itemName then
        -- ✅ SÉCURITÉ: Le serveur vérifie que le joueur possède l'item
        TriggerServerEvent('core:inventory:useItem', data.itemName)
    end
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    if data.itemName and data.quantity then
        -- ✅ SÉCURITÉ: Le serveur vérifie que le joueur possède l'item
        TriggerServerEvent('core:inventory:dropItem', data.itemName, data.quantity)
    end
    cb('ok')
end)

RegisterNUICallback('closeInventory', function(data, cb)
    Core.Inventory.CloseInventory()
    cb('ok')
end)

-- =====================================================
-- CONTRÔLES (✅ OPTIMISÉ)
-- =====================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- F2 pour ouvrir l'inventaire
        if IsControlJustPressed(0, 289) then -- F2
            if inventoryOpen then
                Core.Inventory.CloseInventory()
            else
                Core.Inventory.OpenInventory()
            end
        end
    end
end)

if Config.Debug then
    print('^2[CORE]^0 Module Inventaire Client chargé')
end