-- =====================================================
-- Gestion de la base de données
-- =====================================================

Core = Core or {}
Core.DB = {}

-- Fonction pour exécuter une requête (asynchrone)
function Core.DB.Execute(query, params, cb)
    cb = cb or function() end
    MySQL.query(query, params or {}, function(result)
        cb(result)
    end)
end

-- Fonction pour récupérer une seule ligne
function Core.DB.FetchOne(query, params, cb)
    cb = cb or function() end
    MySQL.single(query, params or {}, function(result)
        cb(result)
    end)
end

-- Fonction pour récupérer plusieurs lignes
function Core.DB.FetchAll(query, params, cb)
    cb = cb or function() end
    MySQL.query(query, params or {}, function(result)
        cb(result)
    end)
end

-- Fonction pour insérer et récupérer l'ID
function Core.DB.Insert(query, params, cb)
    cb = cb or function() end
    MySQL.insert(query, params or {}, function(id)
        cb(id)
    end)
end

-- Fonction pour mettre à jour
function Core.DB.Update(query, params, cb)
    cb = cb or function() end
    MySQL.update(query, params or {}, function(affectedRows)
        cb(affectedRows)
    end)
end

-- =====================================================
-- Fonctions pour la gestion des utilisateurs
-- =====================================================

function Core.DB.GetUser(identifier, cb)
    if not identifier then
        print('^1[CORE ERROR]^0 GetUser appelé avec identifier nil')
        cb(nil)
        return
    end
    Core.DB.FetchOne('SELECT * FROM users WHERE identifier = ?', {identifier}, cb)
end

function Core.DB.CreateUser(identifier, steam, license, discord, cb)
    cb = cb or function() end
    if not identifier then
        print('^1[CORE ERROR]^0 CreateUser appelé avec identifier nil')
        cb(nil)
        return
    end
    local query = [[
        INSERT INTO users (identifier, steam, license, discord, whitelist) 
        VALUES (?, ?, ?, ?, 0)
    ]]
    Core.DB.Insert(query, {identifier, steam, license, discord}, cb)
end

function Core.DB.UpdateLastConnection(identifier)
    if not identifier then return end
    Core.DB.Update('UPDATE users SET last_connection = NOW() WHERE identifier = ?', {identifier})
end

-- =====================================================
-- Fonctions pour la gestion des personnages
-- =====================================================

function Core.DB.GetCharacters(userId, cb)
    if not userId then cb({}) return end
    Core.DB.FetchAll('SELECT * FROM characters WHERE user_id = ? ORDER BY last_played DESC', {userId}, cb)
end

function Core.DB.GetCharacter(characterId, cb)
    if not characterId then cb(nil) return end
    Core.DB.FetchOne('SELECT * FROM characters WHERE id = ?', {characterId}, cb)
end

function Core.DB.CreateCharacter(data, cb)
    cb = cb or function() end
    if not data or not data.userId then
        print('^1[CORE ERROR]^0 CreateCharacter appelé avec des données invalides')
        cb(nil)
        return
    end

    -- Normaliser les strings
    local firstname = data.firstname:sub(1,1):upper() .. data.firstname:sub(2):lower()
    local lastname = data.lastname:sub(1,1):upper() .. data.lastname:sub(2):lower()
    local position = data.position or '{}'
    local skin = data.skin or '{}'
    local nationality = (data.nationality or 'FR'):upper()

    local query = [[
        INSERT INTO characters 
        (user_id, firstname, lastname, dateofbirth, sex, height, cash, bank, position, skin, nationality) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    Core.DB.Insert(query, {
        data.userId,
        firstname,
        lastname,
        data.dateofbirth,
        data.sex,
        data.height,
        data.cash or Config.StartingMoney.cash,
        data.bank or Config.StartingMoney.bank,
        position,
        json.encode(skin),
        nationality
    }, cb)
end

function Core.DB.UpdateCharacter(characterId, data, cb)
    cb = cb or function() end
    if not characterId or not data then
        print('^1[CORE ERROR]^0 UpdateCharacter appelé avec des données invalides')
        cb(0)
        return
    end

    local query = [[
        UPDATE characters 
        SET cash = ?, bank = ?, position = ?, job = ?, job_grade = ?, skin = ?, is_dead = ?
        WHERE id = ?
    ]]
    Core.DB.Update(query, {
        data.cash,
        data.bank,
        data.position or '{}',
        data.job,
        data.job_grade,
        json.encode(data.skin or {}),
        data.isDead or 0,
        characterId
    }, cb)
end

function Core.DB.DeleteCharacter(characterId, cb)
    cb = cb or function() end
    if not characterId then cb(0) return end
    Core.DB.Execute('DELETE FROM characters WHERE id = ?', {characterId}, cb)
end

function Core.DB.UpdateMoney(characterId, moneyType, amount, cb)
    cb = cb or function() end
    local allowedTypes = {cash = true, bank = true}
    if not allowedTypes[moneyType] then
        print('^1[CORE ERROR]^0 Type d\'argent invalide: ' .. tostring(moneyType))
        cb(0)
        return
    end
    amount = tonumber(amount) or 0
    local query = string.format('UPDATE characters SET %s = ? WHERE id = ?', moneyType)
    Core.DB.Update(query, {amount, characterId}, cb)
end

-- =====================================================
-- Fonctions pour l'inventaire
-- =====================================================

function Core.DB.GetInventory(characterId, cb)
    if not characterId then cb({}) return end
    Core.DB.FetchAll('SELECT * FROM inventory WHERE character_id = ? ORDER BY slot', {characterId}, cb)
end

function Core.DB.AddItem(characterId, itemName, quantity, slot, metadata, cb)
    cb = cb or function() end
    quantity = tonumber(quantity) or 1
    slot = tonumber(slot) or 1
    if not characterId or not itemName then cb(nil) return end

    local query = [[
        INSERT INTO inventory (character_id, item_name, quantity, slot, metadata) 
        VALUES (?, ?, ?, ?, ?)
    ]]
    Core.DB.Insert(query, {characterId, itemName, quantity, slot, json.encode(metadata or {})}, cb)
end

function Core.DB.UpdateItem(itemId, quantity, cb)
    cb = cb or function() end
    quantity = tonumber(quantity) or 0
    if not itemId then cb(0) return end
    Core.DB.Update('UPDATE inventory SET quantity = ? WHERE id = ?', {quantity, itemId}, cb)
end

function Core.DB.RemoveItem(itemId, cb)
    cb = cb or function() end
    if not itemId then cb(0) return end
    Core.DB.Execute('DELETE FROM inventory WHERE id = ?', {itemId}, cb)
end

-- Debug
if Config.Debug then
    print('[CORE] Module Database chargé')
end
