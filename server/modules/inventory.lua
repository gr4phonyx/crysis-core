-- =====================================================
-- SYSTÈME D'INVENTAIRE - SERVEUR (SÉCURISÉ)
-- =====================================================

Core.Inventory = Core.Inventory or {}

-- Configuration
local InventoryConfig = {
    MaxSlots = 30,
    MaxWeight = 50.0,
    EnableDrops = true,
    DropLifetime = 300
}

-- Cache des items et drops
local ItemsCache = {}
local WorldDrops = {} 
local NextDropId = 1

-- =====================================================
-- FONCTIONS BASE DE DONNÉES - ITEMS
-- =====================================================

function Core.Inventory.LoadItems()
    local query = "SELECT * FROM items"
    
    MySQL.query(query, {}, function(items)
        ItemsCache = {}
        for _, item in ipairs(items) do
            ItemsCache[item.name] = {
                name = item.name,
                label = item.label,
                description = item.description,
                weight = item.weight,
                maxStack = item.max_stack,
                usable = item.usable == 1,
                type = item.type,
                metadata = item.metadata and json.decode(item.metadata) or {},
                image = item.image
            }
        end
        
        if Config.Debug then
            print(string.format('^2[INVENTORY]^0 %d items chargés', #items))
        end
    end)
end

function Core.Inventory.GetItem(itemName)
    return ItemsCache[itemName]
end

function Core.Inventory.GetAllItems()
    return ItemsCache
end

-- =====================================================
-- FONCTIONS BASE DE DONNÉES - INVENTAIRE JOUEUR
-- =====================================================

function Core.Inventory.LoadPlayerInventory(characterId, cb)
    local query = [[
        SELECT * FROM player_inventory
        WHERE character_id = ? ORDER BY slot ASC
    ]]
    
    MySQL.query(query, {characterId}, function(result)
        local inventory = {}
        for _, row in ipairs(result) do
            local item = Core.Inventory.GetItem(row.item_name)
            if item then
                table.insert(inventory, {
                    id = row.id,
                    slot = row.slot,
                    name = row.item_name,
                    label = item.label,
                    quantity = row.quantity,
                    weight = row.weight or item.weight,
                    metadata = row.metadata and json.decode(row.metadata) or {},
                    image = item.image,
                    usable = item.usable,
                    type = item.type,
                    description = item.description
                })
            end
        end
        if cb then cb(inventory) end
    end)
end

function Core.Inventory.SaveInventoryItem(characterId, itemName, quantity, slot, metadata, cb)
    local playerItem = Core.Inventory.GetItem(itemName)
    if not playerItem then 
        if cb then cb(false) end
        return 
    end

    MySQL.single("SELECT id FROM player_inventory WHERE character_id = ? AND slot = ?", 
        {characterId, slot}, function(existing)
        if existing then
            MySQL.execute([[
                UPDATE player_inventory
                SET item_name = ?, quantity = ?, metadata = ?, weight = ?, updated_at = NOW()
                WHERE character_id = ? AND slot = ?
            ]], {
                itemName,
                quantity,
                json.encode(metadata or {}),
                playerItem.weight,
                characterId,
                slot
            }, function(affectedRows)
                if cb then cb(affectedRows > 0) end
            end)
        else
            MySQL.insert([[
                INSERT INTO player_inventory (character_id, item_name, quantity, slot, metadata, weight)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], {
                characterId,
                itemName,
                quantity,
                slot,
                json.encode(metadata or {}),
                playerItem.weight
            }, function(insertId)
                if cb then cb(insertId ~= nil) end
            end)
        end
    end)
end

function Core.Inventory.RemoveInventoryItem(characterId, slot, cb)
    MySQL.execute("DELETE FROM player_inventory WHERE character_id = ? AND slot = ?", {characterId, slot}, function(affectedRows)
        if cb then cb(affectedRows > 0) end
    end)
end

function Core.Inventory.ClearInventory(characterId, cb)
    MySQL.execute("DELETE FROM player_inventory WHERE character_id = ?", {characterId}, function(affectedRows)
        if cb then cb(affectedRows) end
    end)
end

-- =====================================================
-- GESTION DE L'INVENTAIRE
-- =====================================================

function Core.Inventory.GetPlayerWeight(source)
    local player = Core.GetPlayer(source)
    if not player or not player.inventory then return 0 end

    local totalWeight = 0
    for _, item in pairs(player.inventory) do
        totalWeight = totalWeight + (item.weight * item.quantity)
    end
    return totalWeight
end

function Core.Inventory.CanCarryItem(source, itemName, quantity)
    local item = Core.Inventory.GetItem(itemName)
    if not item then return false, "Item inexistant" end
    
    local currentWeight = Core.Inventory.GetPlayerWeight(source)
    local itemWeight = item.weight * quantity
    
    if (currentWeight + itemWeight) > InventoryConfig.MaxWeight then
        return false, "Inventaire trop lourd"
    end
    
    return true, nil
end

function Core.Inventory.FindEmptySlot(inventory)
    local usedSlots = {}
    for _, item in pairs(inventory) do usedSlots[item.slot] = true end
    for slot = 1, InventoryConfig.MaxSlots do
        if not usedSlots[slot] then return slot end
    end
    return nil
end

function Core.Inventory.AddItem(source, itemName, quantity, metadata, cb)
    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then 
        if cb then cb(false) end 
        return 
    end

    local item = Core.Inventory.GetItem(itemName)
    if not item then
        Core.Notification.Error(source, 'Item inexistant')
        if cb then cb(false) end
        return
    end

    quantity = quantity or 1
    local canCarry, reason = Core.Inventory.CanCarryItem(source, itemName, quantity)
    if not canCarry then
        Core.Notification.Error(source, reason)
        if cb then cb(false) end
        return
    end

    local added = false

    -- Stackable
    if item.maxStack > 1 then
        for _, invItem in pairs(player.inventory) do
            if invItem.name == itemName and invItem.quantity < item.maxStack then
                local spaceLeft = item.maxStack - invItem.quantity
                local toAdd = math.min(quantity, spaceLeft)
                invItem.quantity = invItem.quantity + toAdd
                quantity = quantity - toAdd

                Core.Inventory.SaveInventoryItem(player.currentCharacter.id, itemName, invItem.quantity, invItem.slot, invItem.metadata)

                if quantity == 0 then
                    added = true
                    break
                end
            end
        end
    end

    -- Slot vide
    while quantity > 0 do
        local emptySlot = Core.Inventory.FindEmptySlot(player.inventory)
        if not emptySlot then
            Core.Notification.Error(source, 'Inventaire plein')
            if cb then cb(false) end
            return
        end
        local toAdd = math.min(quantity, item.maxStack)
        Core.Inventory.SaveInventoryItem(player.currentCharacter.id, itemName, toAdd, emptySlot, metadata, function(success)
            if success then
                Core.Inventory.LoadPlayerInventory(player.currentCharacter.id, function(inv)
                    player.inventory = inv
                    TriggerClientEvent('core:client:updateInventory', source, inv)
                    Core.Notification.Success(source, string.format('Ajouté: %dx %s', toAdd, item.label))
                end)
            end
        end)
        quantity = quantity - toAdd
        added = true
    end

    if cb then cb(added) end
end

function Core.Inventory.RemoveItem(source, itemName, quantity, cb)
    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then 
        if cb then cb(false) end 
        return 
    end
    
    quantity = quantity or 1
    local remaining = quantity

    for _, invItem in pairs(player.inventory) do
        if invItem.name == itemName and remaining > 0 then
            if invItem.quantity > remaining then
                invItem.quantity = invItem.quantity - remaining
                Core.Inventory.SaveInventoryItem(player.currentCharacter.id, itemName, invItem.quantity, invItem.slot, invItem.metadata)
                remaining = 0
                break
            else
                remaining = remaining - invItem.quantity
                Core.Inventory.RemoveInventoryItem(player.currentCharacter.id, invItem.slot)
            end
        end
    end

    if remaining == 0 then
        Core.Inventory.LoadPlayerInventory(player.currentCharacter.id, function(inv)
            player.inventory = inv
            TriggerClientEvent('core:client:updateInventory', source, inv)
            local item = Core.Inventory.GetItem(itemName)
            Core.Notification.Info(source, string.format('Retiré: %dx %s', quantity, item.label))
        end)
        if cb then cb(true) end
    else
        Core.Notification.Error(source, 'Item insuffisant')
        if cb then cb(false) end
    end
end

function Core.Inventory.HasItem(source, itemName, quantity)
    local player = Core.GetPlayer(source)
    if not player or not player.inventory then return false end
    quantity = quantity or 1
    local total = 0
    for _, invItem in pairs(player.inventory) do
        if invItem.name == itemName then total = total + invItem.quantity end
    end
    return total >= quantity
end

-- =====================================================
-- ✅ EVENT MANQUANT AJOUTÉ - UTILISER UN ITEM
-- =====================================================

RegisterNetEvent('core:inventory:useItem')
AddEventHandler('core:inventory:useItem', function(itemName)
    local source = source
    local player = Core.GetPlayer(source)
    
    if not player or not player.currentCharacter then return end
    
    local item = Core.Inventory.GetItem(itemName)
    if not item then return end
    
    if not item.usable then 
        Core.Notification.Error(source, 'Cet item n\'est pas utilisable')
        return
    end
    
    -- ✅ SÉCURITÉ CRITIQUE: Vérifier que le joueur possède l'item
    if not Core.Inventory.HasItem(source, itemName, 1) then
        Core.Notification.Error(source, 'Vous n\'avez pas cet item')
        
        if Config.Debug then
            print(string.format('^1[SECURITY]^0 Joueur %s a tenté d\'utiliser %s sans le posséder!', 
                GetPlayerName(source), itemName))
        end
        return
    end
    
    -- Déclencher les effets de l'item
    if itemName == 'bread' then
        -- Retire l'item après utilisation
        Core.Inventory.RemoveItem(source, itemName, 1, function(success)
            if success then
                -- Ajouter de la faim (exemple)
                TriggerEvent('core:health:addHunger', source, 20)
            end
        end)
        
    elseif itemName == 'water' then
        Core.Inventory.RemoveItem(source, itemName, 1, function(success)
            if success then
                TriggerEvent('core:health:addThirst', source, 30)
            end
        end)
        
    elseif itemName == 'bandage' then
        Core.Inventory.RemoveItem(source, itemName, 1, function(success)
            if success then
                -- Soigner 30 HP
                local player = Core.GetPlayer(source)
                if player and player.health then
                    local newHealth = math.min(player.health.health + 30, player.health.maxHealth)
                    TriggerClientEvent('core:client:setEntityHealth', source, newHealth)
                    Core.Notification.Success(source, 'Vous avez utilisé un bandage (+30 HP)')
                end
            end
        end)
        
    elseif itemName == 'medkit' then
        Core.Inventory.RemoveItem(source, itemName, 1, function(success)
            if success then
                -- Soigner complètement
                local player = Core.GetPlayer(source)
                if player and player.health then
                    TriggerClientEvent('core:client:setEntityHealth', source, player.health.maxHealth)
                    Core.Notification.Success(source, 'Vous êtes complètement soigné')
                end
            end
        end)
    end
    
    -- Déclencher l'événement pour d'autres scripts
    TriggerEvent('core:inventory:itemUsed', source, itemName, item)
    TriggerClientEvent('core:client:useItem', source, itemName, item)
    
    if Config.Debug then
        print(string.format('^3[INVENTORY]^0 %s utilise %s', GetPlayerName(source), itemName))
    end
end)

-- =====================================================
-- DROPS AU SOL
-- =====================================================

RegisterNetEvent('core:inventory:dropItem')
AddEventHandler('core:inventory:dropItem', function(itemName, quantity)
    local source = source
    local player = Core.GetPlayer(source)
    
    if not player or not Core.Inventory.HasItem(source, itemName, quantity) then 
        Core.Notification.Error(source, 'Vous n\'avez pas cet item')
        return 
    end

    Core.Inventory.RemoveItem(source, itemName, quantity, function(success)
        if success then
            local coords = GetEntityCoords(GetPlayerPed(source))
            local dropId = NextDropId
            NextDropId = NextDropId + 1

            WorldDrops[dropId] = {
                id = dropId,
                item = itemName,
                quantity = quantity,
                position = coords,
                timestamp = os.time()
            }

            TriggerClientEvent('core:client:createDrop', -1, dropId, WorldDrops[dropId])
            Core.Notification.Info(source, 'Objet jeté')
        end
    end)
end)

RegisterNetEvent('core:inventory:pickupDrop')
AddEventHandler('core:inventory:pickupDrop', function(dropId)
    local source = source
    local drop = WorldDrops[dropId]
    if not drop then return end

    -- ✅ SÉCURITÉ: Vérifier la distance
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if #(playerCoords - drop.position) > 3.0 then 
        if Config.Debug then
            print(string.format('^1[SECURITY]^0 Joueur %s trop loin du drop %s', 
                GetPlayerName(source), dropId))
        end
        return 
    end

    Core.Inventory.AddItem(source, drop.item, drop.quantity, nil, function(success)
        if success then
            WorldDrops[dropId] = nil
            TriggerClientEvent('core:client:removeDrop', -1, dropId)
        end
    end)
end)

-- Nettoyage automatique des drops
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        local currentTime = os.time()
        for id, drop in pairs(WorldDrops) do
            if (currentTime - drop.timestamp) > InventoryConfig.DropLifetime then
                WorldDrops[id] = nil
                TriggerClientEvent('core:client:removeDrop', -1, id)
            end
        end
    end
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

AddEventHandler('core:server:characterLoaded', function(source, characterId)
    Core.Inventory.LoadPlayerInventory(characterId, function(inventory)
        local player = Core.GetPlayer(source)
        if player then
            player.inventory = inventory
            TriggerClientEvent('core:client:updateInventory', source, inventory)
        end
    end)
end)

-- Charger les items au démarrage
Core.Inventory.LoadItems()

if Config.Debug then
    print('^2[CORE]^0 Module Inventaire chargé (Sécurisé)')
end