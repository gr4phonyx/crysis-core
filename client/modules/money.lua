-- =====================================================
-- SYSTÈME D'ARGENT - SERVEUR
-- =====================================================

Core.Money = Core.Money or {}

local dailyTransfers = {} -- Cache des transferts journaliers

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

local function IsValidMoneyType(moneyType)
    return Config.Money.Types[moneyType] ~= nil
end

local function GetMoneyConfig(moneyType)
    return Config.Money.Types[moneyType]
end

local function LogTransaction(characterId, transactionType, moneyType, amount, balanceBefore, balanceAfter, targetCharId, reason, metadata)
    if not Config.Money.History.enabled then return end
    
    local query = [[
        INSERT INTO money_transactions 
        (character_id, transaction_type, money_type, amount, balance_before, balance_after, target_character_id, reason, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    MySQL.insert(query, {
        characterId,
        transactionType,
        moneyType,
        amount,
        balanceBefore,
        balanceAfter,
        targetCharId,
        reason,
        json.encode(metadata or {})
    })
end

local function SendDiscordLog(source, action, moneyType, amount, target, reason)
    if not Config.Money.Discord.enabled or Config.Money.Discord.webhook == "" then return end
    if amount < Config.Money.Discord.logThreshold then return end
    
    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then return end
    
    local char = player.currentCharacter
    local playerName = char.firstname .. " " .. char.lastname
    
    local color = Config.Money.Discord.color[action] or 0
    local targetName = target or "N/A"
    
    local embed = {
        {
            ["title"] = "💰 Transaction: " .. action:upper(),
            ["color"] = color,
            ["fields"] = {
                {["name"] = "Joueur", ["value"] = playerName .. " (ID: " .. source .. ")", ["inline"] = true},
                {["name"] = "Type", ["value"] = moneyType, ["inline"] = true},
                {["name"] = "Montant", ["value"] = amount .. "€", ["inline"] = true},
                {["name"] = "Cible", ["value"] = targetName, ["inline"] = true},
                {["name"] = "Raison", ["value"] = reason or "Aucune", ["inline"] = false}
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
        }
    }
    
    PerformHttpRequest(Config.Money.Discord.webhook, function() end, 'POST', json.encode({
        username = "Money System",
        embeds = embed
    }), {['Content-Type'] = 'application/json'})
end

-- =====================================================
-- FONCTIONS PRINCIPALES
-- =====================================================

function Core.Money.Get(source, moneyType)
    if not IsValidMoneyType(moneyType) then return 0 end
    
    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then return 0 end
    
    return player.currentCharacter[moneyType] or 0
end

function Core.Money.Set(source, moneyType, amount, reason)
    if not IsValidMoneyType(moneyType) then return false end
    
    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then return false end
    
    amount = math.max(0, tonumber(amount) or 0)
    local moneyConfig = GetMoneyConfig(moneyType)
    
    -- Vérifier limite max
    if amount > moneyConfig.max then
        Core.Notification.Error(source, string.format(Config.Money.Messages.maxCashReached, moneyConfig.max))
        return false
    end
    
    local oldAmount = player.currentCharacter[moneyType] or 0
    player.currentCharacter[moneyType] = amount
    
    -- Mise à jour BDD
    Core.DB.Execute(
        string.format('UPDATE characters SET %s = ? WHERE id = ?', moneyType),
        {amount, player.currentCharacter.id}
    )
    
    -- Log transaction
    LogTransaction(
        player.currentCharacter.id,
        'set',
        moneyType,
        amount,
        oldAmount,
        amount,
        nil,
        reason
    )
    
    -- Notification client
    TriggerClientEvent('core:client:updateMoney', source, moneyType, amount)
    
    if Config.Debug then
        print(string.format('^3[MONEY]^0 %s: SET %s = %d (raison: %s)', 
            GetPlayerName(source), moneyType, amount, reason or 'aucune'))
    end
    
    return true
end

function Core.Money.Add(source, moneyType, amount, reason)
    if not IsValidMoneyType(moneyType) then return false end
    if not amount or amount <= 0 then return false end
    
    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then return false end
    
    local currentAmount = player.currentCharacter[moneyType] or 0
    local newAmount = currentAmount + amount
    local moneyConfig = GetMoneyConfig(moneyType)
    
    -- Vérifier limite max
    if newAmount > moneyConfig.max then
        Core.Notification.Error(source, string.format(Config.Money.Messages.maxCashReached, moneyConfig.max))
        return false
    end
    
    player.currentCharacter[moneyType] = newAmount
    
    -- Mise à jour BDD
    Core.DB.Execute(
        string.format('UPDATE characters SET %s = ? WHERE id = ?', moneyType),
        {newAmount, player.currentCharacter.id}
    )
    
    -- Log transaction
    LogTransaction(
        player.currentCharacter.id,
        'add',
        moneyType,
        amount,
        currentAmount,
        newAmount,
        nil,
        reason
    )
    
    -- Discord log
    SendDiscordLog(source, 'add', moneyType, amount, nil, reason)
    
    -- Notification client
    TriggerClientEvent('core:client:updateMoney', source, moneyType, newAmount)
    
    if Config.Debug then
        print(string.format('^2[MONEY]^0 %s: +%d %s (raison: %s)', 
            GetPlayerName(source), amount, moneyType, reason or 'aucune'))
    end
    
    return true
end

function Core.Money.Remove(source, moneyType, amount, reason)
    if not IsValidMoneyType(moneyType) then return false end
    if not amount or amount <= 0 then return false end
    
    local player = Core.GetPlayer(source)
    if not player or not player.currentCharacter then return false end
    
    local currentAmount = player.currentCharacter[moneyType] or 0
    
    -- Vérifier si assez d'argent
    if currentAmount < amount then
        Core.Notification.Error(source, Config.Money.Messages.insufficientFunds)
        return false
    end
    
    local newAmount = currentAmount - amount
    player.currentCharacter[moneyType] = newAmount
    
    -- Mise à jour BDD
    Core.DB.Execute(
        string.format('UPDATE characters SET %s = ? WHERE id = ?', moneyType),
        {newAmount, player.currentCharacter.id}
    )
    
    -- Log transaction
    LogTransaction(
        player.currentCharacter.id,
        'remove',
        moneyType,
        amount,
        currentAmount,
        newAmount,
        nil,
        reason
    )
    
    -- Discord log
    SendDiscordLog(source, 'remove', moneyType, amount, nil, reason)
    
    -- Notification client
    TriggerClientEvent('core:client:updateMoney', source, moneyType, newAmount)
    
    if Config.Debug then
        print(string.format('^1[MONEY]^0 %s: -%d %s (raison: %s)', 
            GetPlayerName(source), amount, moneyType, reason or 'aucune'))
    end
    
    return true
end

function Core.Money.Transfer(source, target, moneyType, amount, reason)
    if not IsValidMoneyType(moneyType) then return false end
    if not amount or amount <= 0 then
        Core.Notification.Error(source, Config.Money.Messages.invalidAmount)
        return false
    end
    
    -- Vérifier limite de sécurité
    if amount > Config.Money.Security.maxTransactionAmount then
        Core.Notification.Error(source, Config.Money.Messages.transactionBlocked)
        return false
    end
    
    -- Vérifier que source != target
    if source == target then
        Core.Notification.Error(source, Config.Money.Messages.cannotTransferToSelf)
        return false
    end
    
    local playerSource = Core.GetPlayer(source)
    local playerTarget = Core.GetPlayer(target)
    
    if not playerSource or not playerTarget then
        Core.Notification.Error(source, Config.Money.Messages.playerNotFound)
        return false
    end
    
    if not playerSource.currentCharacter or not playerTarget.currentCharacter then
        return false
    end
    
    local moneyConfig = GetMoneyConfig(moneyType)
    
    -- Vérifier si transfert autorisé
    if not moneyConfig.transferable then
        Core.Notification.Error(source, "Ce type d'argent n'est pas transférable")
        return false
    end
    
    -- Calculer les frais
    local fees = 0
    if Config.Money.TransferFees.enabled then
        -- Vérifier si le joueur est exempté de frais
        local playerGroup = Core.GetPlayerGroup and Core.GetPlayerGroup(source) or 'user'
        local isExempt = false
        
        for _, group in ipairs(Config.Money.TransferFees.exemptGroups) do
            if playerGroup == group then
                isExempt = true
                break
            end
        end
        
        if not isExempt then
            fees = math.floor(amount * (Config.Money.TransferFees.percentage / 100))
            fees = math.max(Config.Money.TransferFees.min, math.min(fees, Config.Money.TransferFees.max))
        end
    end
    
    local totalDeducted = amount + fees
    
    -- Vérifier limite journalière
    local today = os.date("%Y-%m-%d")
    dailyTransfers[source] = dailyTransfers[source] or {}
    dailyTransfers[source][today] = (dailyTransfers[source][today] or 0) + amount
    
    if dailyTransfers[source][today] > Config.Money.Security.dailyTransferLimit then
        Core.Notification.Error(source, "Limite de transfert journalier atteinte")
        return false
    end
    
    -- Retirer l'argent + frais du source
    if not Core.Money.Remove(source, moneyType, totalDeducted, "Transfert vers " .. GetPlayerName(target)) then
        return false
    end
    
    -- Ajouter l'argent au target
    if not Core.Money.Add(target, moneyType, amount, "Transfert de " .. GetPlayerName(source)) then
        -- Rollback si échec
        Core.Money.Add(source, moneyType, totalDeducted, "Rollback transfert échoué")
        return false
    end
    
    -- Log transaction croisée
    LogTransaction(
        playerSource.currentCharacter.id,
        'transfer_out',
        moneyType,
        amount,
        playerSource.currentCharacter[moneyType] + totalDeducted,
        playerSource.currentCharacter[moneyType],
        playerTarget.currentCharacter.id,
        reason,
        {fees = fees}
    )
    
    LogTransaction(
        playerTarget.currentCharacter.id,
        'transfer_in',
        moneyType,
        amount,
        playerTarget.currentCharacter[moneyType] - amount,
        playerTarget.currentCharacter[moneyType],
        playerSource.currentCharacter.id,
        reason
    )
    
    -- Discord log
    local targetName = playerTarget.currentCharacter.firstname .. " " .. playerTarget.currentCharacter.lastname
    SendDiscordLog(source, 'transfer', moneyType, amount, targetName, reason)
    
    -- Notifications
    Core.Notification.Success(source, string.format(Config.Money.Messages.transferSuccess, amount, fees))
    Core.Notification.Success(target, string.format(Config.Money.Messages.transferReceived, amount, GetPlayerName(source)))
    
    if Config.Debug then
        print(string.format('^5[MONEY]^0 TRANSFER: %s -> %s: %d %s (frais: %d)', 
            GetPlayerName(source), GetPlayerName(target), amount, moneyType, fees))
    end
    
    return true
end

-- =====================================================
-- HISTORIQUE
-- =====================================================

function Core.Money.GetHistory(characterId, limit)
    limit = limit or 50
    
    local query = [[
        SELECT * FROM money_history_view
        WHERE character_id = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]]
    
    return MySQL.query.await(query, {characterId, limit}) or {}
end

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

RegisterNetEvent('core:money:requestTransfer')
AddEventHandler('core:money:requestTransfer', function(target, moneyType, amount)
    local source = source
    Core.Money.Transfer(source, target, moneyType, amount, "Transfert joueur à joueur")
end)

-- =====================================================
-- COMMANDES ADMIN
-- =====================================================

RegisterCommand('givemoney', function(source, args)
    if source == 0 or (Core.HasPermission and Core.HasPermission(source, 'money.give')) then
        local targetId = tonumber(args[1])
        local moneyType = args[2]
        local amount = tonumber(args[3])
        
        if not targetId or not moneyType or not amount then
            print("Usage: /givemoney [id] [cash/bank/black_money/crypto] [montant]")
            return
        end
        
        if Core.Money.Add(targetId, moneyType, amount, "Admin give money") then
            print(string.format("✅ Ajouté %d %s à %s", amount, moneyType, GetPlayerName(targetId)))
        else
            print("❌ Échec")
        end
    end
end, true)

RegisterCommand('removemoney', function(source, args)
    if source == 0 or (Core.HasPermission and Core.HasPermission(source, 'money.remove')) then
        local targetId = tonumber(args[1])
        local moneyType = args[2]
        local amount = tonumber(args[3])
        
        if not targetId or not moneyType or not amount then
            print("Usage: /removemoney [id] [cash/bank/black_money/crypto] [montant]")
            return
        end
        
        if Core.Money.Remove(targetId, moneyType, amount, "Admin remove money") then
            print(string.format("✅ Retiré %d %s à %s", amount, moneyType, GetPlayerName(targetId)))
        else
            print("❌ Échec")
        end
    end
end, true)

RegisterCommand('setmoney', function(source, args)
    if source == 0 or (Core.HasPermission and Core.HasPermission(source, 'money.set')) then
        local targetId = tonumber(args[1])
        local moneyType = args[2]
        local amount = tonumber(args[3])
        
        if not targetId or not moneyType or not amount then
            print("Usage: /setmoney [id] [cash/bank/black_money/crypto] [montant]")
            return
        end
        
        if Core.Money.Set(targetId, moneyType, amount, "Admin set money") then
            print(string.format("✅ Défini %s de %s à %d", moneyType, GetPlayerName(targetId), amount))
        else
            print("❌ Échec")
        end
    end
end, true)

-- Nettoyage quotidien du cache
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(86400000) -- 24h
        dailyTransfers = {}
        if Config.Debug then
            print('^2[MONEY]^0 Cache des transferts journaliers nettoyé')
        end
    end
end)

if Config.Debug then
    print('^2[CORE]^0 Module Money chargé')
end