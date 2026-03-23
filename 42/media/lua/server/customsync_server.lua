require "CustomSync"

print("[CustomSync] Server script loaded")

local function safeSendServerCommand(modId, command, data)
    if zombie.network.GameServer and zombie.network.GameServer.udpEngine then
        sendServerCommand(modId, command, data)
    end
end

local tickCounter = 0

-- Cache for dynamic updates
local lastUpdateInterval = CustomSync.UPDATE_INTERVAL
local lastSyncDistance = CustomSync.SYNC_DISTANCE
local lastMaxZombies = 100
local lastDebug = 0
local lastImmediateZombieCooldown = CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN

local function isStateDeltaExceeded(current, previous, epsilon)
    if not previous then return true end
    local dx = (current.x or 0) - (previous.x or 0)
    local dy = (current.y or 0) - (previous.y or 0)
    local dz = (current.z or 0) - (previous.z or 0)
    if (dx * dx + dy * dy + dz * dz) > (epsilon * epsilon) then
        return true
    end
    if math.abs((current.direction or 0) - (previous.direction or 0)) > 1.0 then
        return true
    end
    if math.abs((current.health or 0) - (previous.health or 0)) > 0.1 then
        return true
    end
    if current.crawling ~= previous.crawling then
        return true
    end
    if current.animation ~= previous.animation then
        return true
    end
    return false
end

local function minDistanceSqToPlayers(x, y, playerPositions)
    local minDist = nil
    for _, pos in ipairs(playerPositions) do
        local dist = CustomSync.getDistanceSq(pos.x, pos.y, x, y)
        if not minDist or dist < minDist then
            minDist = dist
        end
    end
    return minDist or math.huge
end

local function getVehicleTowingSafe(vehicle)
    if not vehicle or type(vehicle.getVehicleTowing) ~= "function" then
        return nil
    end
    local ok, towed = pcall(function()
        return vehicle:getVehicleTowing()
    end)
    if ok and towed then
        return towed
    end
    return nil
end

local function getVehicleDirectionAngleSafe(vehicle)
    if not vehicle then return 0 end
    if type(vehicle.getDirectionAngle) == "function" then
        local ok, angle = pcall(function()
            return vehicle:getDirectionAngle()
        end)
        if ok and type(angle) == "number" then
            return angle
        end
    end
    return 0
end

local function getVehicleSpeedKmHourSafe(vehicle)
    if not vehicle then return 0 end
    if type(vehicle.getCurrentSpeedKmHour) == "function" then
        local ok, speed = pcall(function()
            return vehicle:getCurrentSpeedKmHour()
        end)
        if ok and type(speed) == "number" then
            return speed
        end
    end
    return 0
end

local function shouldSendImmediateZombieSync(id, force)
    if force then return true end
    local cooldown = CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN or 0
    if cooldown <= 0 then return true end
    local lastTick = CustomSync.lastImmediateZombieSyncTick[id] or -100000
    if (tickCounter - lastTick) < cooldown then
        return false
    end
    return true
end

local function sendImmediateZombieSync(zombie, force)
    if not zombie then return false end
    local id = zombie:getOnlineID()
    if not shouldSendImmediateZombieSync(id, force) then
        return false
    end
    local zombieData = {
        id = id,
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
        health = zombie:getHealth(),
        direction = zombie:getDirectionAngle(),
        crawling = zombie:isCrawling()
    }
    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
    CustomSync.lastImmediateZombieSyncTick[id] = tickCounter
    return true
end

local function cleanupStaleCaches()
    local players = getOnlinePlayers()
    local activePlayers = {}
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            activePlayers[player:getOnlineID()] = true
        end
    end

    for id, _ in pairs(CustomSync.lastPlayerPositions) do
        if not activePlayers[id] then
            CustomSync.lastPlayerPositions[id] = nil
            CustomSync.lastBroadcastPlayers[id] = nil
            CustomSync.lastInventorySignatures[id] = nil
            CustomSync.lastCollisionSyncTick[id] = nil
        end
    end

    -- Fix 2: Purge zombie caches against live zombie list, not just activeZombies
    local cell = getCell()
    local liveZombieIds = {}
    if cell then
        local zombieList = cell:getZombieList()
        if zombieList then
            for i = 0, zombieList:size() - 1 do
                local z = zombieList:get(i)
                if z then
                    liveZombieIds[z:getOnlineID()] = true
                end
            end
        end
    end

    for id, _ in pairs(CustomSync.lastZombieHealth or {}) do
        if not liveZombieIds[id] then
            CustomSync.lastZombieHealth[id] = nil
            CustomSync.lastZombieCrawling[id] = nil
            CustomSync.lastZombiePositions[id] = nil
            CustomSync.lastImmediateZombieSyncTick[id] = nil
            CustomSync.lastZombieUpdateTick[id] = nil
        end
    end

    -- Also clean activeZombies against live list
    for id, _ in pairs(CustomSync.activeZombies) do
        if not liveZombieIds[id] then
            CustomSync.activeZombies[id] = nil
        end
    end

    if cell then
        local vehicleList = cell:getVehicles()
        local liveVehicles = {}
        if vehicleList then
            for i = 0, vehicleList:size() - 1 do
                local vehicle = vehicleList:get(i)
                if vehicle then
                    liveVehicles[vehicle:getID()] = true
                end
            end
        end
        for id, _ in pairs(CustomSync.lastTrailerPositions or {}) do
            if not liveVehicles[id] then
                CustomSync.lastTrailerPositions[id] = nil
            end
        end
    end
end

local function onInitGlobalModData()
    CustomSync.UPDATE_INTERVAL = SandboxVars.CustomSync.UpdateInterval or CustomSync.UPDATE_INTERVAL
    CustomSync.SYNC_DISTANCE = SandboxVars.CustomSync.SyncDistance or CustomSync.SYNC_DISTANCE
    CustomSync.SYNC_DISTANCE_ZOMBIES = CustomSync.SYNC_DISTANCE
    CustomSync.MAX_ZOMBIES = SandboxVars.CustomSync.MaxZombies or 100
    CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN = SandboxVars.CustomSync.ImmediateZombieCooldown or CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN
    -- CustomSync.DEBUG = debugVal == 1  -- Commented out to keep default true
    CustomSync.lastZombiePositions = {}
    CustomSync.lastPlayerPositions = {}
    CustomSync.lastBroadcastPlayers = {}
    CustomSync.lastBroadcastVehicles = {}
    CustomSync.lastTrailerPositions = {}
    CustomSync.lastInventorySignatures = {}
    CustomSync.lastZombieHealth = {}
    CustomSync.lastZombieCrawling = {}
    CustomSync.lastImmediateZombieSyncTick = {}
    CustomSync.lastZombieUpdateTick = {}
    CustomSync.lastCollisionSyncTick = {}
end

local function onTick()
    tickCounter = tickCounter + 1

    -- Check for dynamic updates to sandbox vars
    if SandboxVars.CustomSync.UpdateInterval and SandboxVars.CustomSync.UpdateInterval ~= lastUpdateInterval then
        CustomSync.UPDATE_INTERVAL = SandboxVars.CustomSync.UpdateInterval
        lastUpdateInterval = CustomSync.UPDATE_INTERVAL
        if CustomSync.DEBUG then
            print("[CustomSync] Updated UPDATE_INTERVAL to " .. CustomSync.UPDATE_INTERVAL)
        end
    end
    if SandboxVars.CustomSync.SyncDistance and SandboxVars.CustomSync.SyncDistance ~= lastSyncDistance then
        CustomSync.SYNC_DISTANCE = SandboxVars.CustomSync.SyncDistance
        CustomSync.SYNC_DISTANCE_ZOMBIES = CustomSync.SYNC_DISTANCE
        lastSyncDistance = CustomSync.SYNC_DISTANCE
        if CustomSync.DEBUG then
            print("[CustomSync] Updated SYNC_DISTANCE to " .. CustomSync.SYNC_DISTANCE)
        end
    end
    if SandboxVars.CustomSync.MaxZombies and SandboxVars.CustomSync.MaxZombies ~= lastMaxZombies then
        CustomSync.MAX_ZOMBIES = SandboxVars.CustomSync.MaxZombies
        lastMaxZombies = CustomSync.MAX_ZOMBIES
        if CustomSync.DEBUG then
            print("[CustomSync] Updated MAX_ZOMBIES to " .. CustomSync.MAX_ZOMBIES)
        end
    end
    if SandboxVars.CustomSync.DebugLogs and SandboxVars.CustomSync.DebugLogs ~= lastDebug then
        lastDebug = SandboxVars.CustomSync.DebugLogs
        CustomSync.DEBUG = lastDebug == 1
        print("[CustomSync] Debug logging " .. (CustomSync.DEBUG and "enabled" or "disabled"))
    end
    if SandboxVars.CustomSync.ImmediateZombieCooldown and SandboxVars.CustomSync.ImmediateZombieCooldown ~= lastImmediateZombieCooldown then
        CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN = SandboxVars.CustomSync.ImmediateZombieCooldown
        lastImmediateZombieCooldown = CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN
        if CustomSync.DEBUG then
            print("[CustomSync] Updated ZOMBIE_IMMEDIATE_COOLDOWN to " .. CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN)
        end
    end

    -- Fix 2: Increase cleanup frequency from every 600 ticks to every 300 ticks
    if tickCounter % 300 == 0 then
        cleanupStaleCaches()
    end

    if tickCounter % CustomSync.UPDATE_INTERVAL ~= 0 then return end

    -- Fix 3: Build playerPositions once and share across all sync functions
    local players = getOnlinePlayers()
    local playerPositions = {}
    for j = 0, players:size() - 1 do
        local player = players:get(j)
        if player then
            table.insert(playerPositions, {x = player:getX(), y = player:getY()})
        end
    end

    -- Sync players
    CustomSync.syncPlayers()

    -- Sync zombies
    CustomSync.syncZombies(playerPositions)

    -- Sync vehicles
    CustomSync.syncVehicles(playerPositions)

    -- Sync trailers (towed vehicles) with parent relationship data
    CustomSync.syncTrailers(playerPositions)

    -- Inventories and appearance synced on update via OnContainerUpdate
end

function CustomSync.syncPlayers()
    local players = getOnlinePlayers()
    local playerData = {}

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local id = player:getOnlineID()
            local x = player:getX()
            local y = player:getY()
            local z = player:getZ()
            if type(x) ~= "number" then x = 0 end
            if type(y) ~= "number" then y = 0 end
            if type(z) ~= "number" then z = 0 end
            local lastPos = CustomSync.lastPlayerPositions[id]
            if lastPos then
                lastPos.x = tonumber(lastPos.x) or 0
                lastPos.y = tonumber(lastPos.y) or 0
                lastPos.z = tonumber(lastPos.z) or 0
            end
            local speed = 0
            if lastPos then
                local success, dist = pcall(function() return math.sqrt((x - lastPos.x)^2 + (y - lastPos.y)^2 + (z - lastPos.z)^2) end)
                if success then
                    speed = dist / CustomSync.UPDATE_INTERVAL  -- units per tick
                end
            end
            CustomSync.lastPlayerPositions[id] = {x = x, y = y, z = z}
            local state = {
                id = id,
                x = x,
                y = y,
                z = z,
                direction = player:getDirectionAngle(),
                speed = speed,
                health = player:getBodyDamage():getOverallBodyHealth(),
                animation = player:getAnimationDebug()
            }
            if isStateDeltaExceeded(state, CustomSync.lastBroadcastPlayers[id], CustomSync.PLAYER_DELTA_EPSILON or 0.02) then
                table.insert(playerData, state)
                CustomSync.lastBroadcastPlayers[id] = state
            end
            if CustomSync.DEBUG then
                print("[CustomSync] Server: Player " .. id .. " calculated speed: " .. speed)
            end
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Server: Syncing " .. #playerData .. " players")
    end

    -- Send to all clients
    if #playerData > 0 then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS, playerData)
    end
end

function CustomSync.syncZombies(playerPositions)
    if CustomSync.DEBUG then
        print("[CustomSync] Syncing zombies...")
    end
    local cell = getCell()
    if not cell then return end

    local zombieList = cell:getZombieList()
    if not zombieList then return end

    -- Fix 3: Use shared playerPositions from onTick, fallback to building if called standalone
    if not playerPositions then
        local players = getOnlinePlayers()
        playerPositions = {}
        for j = 0, players:size() - 1 do
            local player = players:get(j)
            if player then
                table.insert(playerPositions, {x = player:getX(), y = player:getY()})
            end
        end
    end

    local zombieMap = {}
    for i = 0, zombieList:size() - 1 do
        local z = zombieList:get(i)
        if z then
            zombieMap[z:getOnlineID()] = z
        end
    end

    -- Update existing active zombies
    for id, data in pairs(CustomSync.activeZombies) do
        local exists = false
        local zombie = zombieMap[id]
        if zombie and zombie:getHealth() > 0 then
            local zx, zy = zombie:getX(), zombie:getY()
            local near = false
            for _, pos in ipairs(playerPositions) do
                if CustomSync.isWithinSyncDistanceZombies(pos.x, pos.y, zx, zy) then
                    near = true
                    break
                end
            end
            if near then
                exists = true
                data.x = zx
                data.y = zy
                data.z = zombie:getZ()
                data.health = zombie:getHealth()
                data.direction = zombie:getDirectionAngle()
                data.crawling = zombie:isCrawling()
            end
        end
        if not exists then
            CustomSync.activeZombies[id] = nil
        end
    end

    -- Fix 6: Cap activeZombies growth — count current entries
    local activeCount = 0
    for _ in pairs(CustomSync.activeZombies) do activeCount = activeCount + 1 end
    local maxActive = math.floor((CustomSync.MAX_ZOMBIES or 100) * (CustomSync.MAX_ACTIVE_ZOMBIES_FACTOR or 1.5))

    -- Add new nearby zombies (skip if already at cap)
    if activeCount < maxActive then
        for id, zombie in pairs(zombieMap) do
            if zombie and zombie:getHealth() > 0 and not CustomSync.activeZombies[id] then
                local zx, zy = zombie:getX(), zombie:getY()
                local near = false
                for _, pos in ipairs(playerPositions) do
                    if CustomSync.isWithinSyncDistanceZombies(pos.x, pos.y, zx, zy) then
                        near = true
                        break
                    end
                end
                if near then
                    CustomSync.activeZombies[id] = {
                        id = id,
                        x = zx,
                        y = zy,
                        z = zombie:getZ(),
                        health = zombie:getHealth(),
                        direction = zombie:getDirectionAngle(),
                        crawling = zombie:isCrawling()
                    }
                    activeCount = activeCount + 1
                    if activeCount >= maxActive then break end
                end
            end
        end
    end

    -- Convert to list for sending
    local zombies = {}
    local zombieCandidates = {}
    for id, data in pairs(CustomSync.activeZombies) do
        table.insert(zombieCandidates, data)
    end

    if #zombieCandidates > (CustomSync.MAX_ZOMBIES or 100) then
        table.sort(zombieCandidates, function(a, b)
            local da = minDistanceSqToPlayers(a.x, a.y, playerPositions)
            local db = minDistanceSqToPlayers(b.x, b.y, playerPositions)
            return da < db
        end)
    end

    local limit = math.min(#zombieCandidates, CustomSync.MAX_ZOMBIES or 100)
    for i = 1, limit do
        local data = zombieCandidates[i]
        local lastState = CustomSync.lastZombiePositions[data.id]
        if isStateDeltaExceeded(data, lastState, 0.05) then
            local snapshot = {
                id = data.id,
                x = data.x,
                y = data.y,
                z = data.z,
                health = data.health,
                direction = data.direction,
                crawling = data.crawling
            }
            table.insert(zombies, snapshot)
            CustomSync.lastZombiePositions[data.id] = snapshot
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #zombies .. " zombies (active=" .. #zombieCandidates .. ", cap=" .. tostring(CustomSync.MAX_ZOMBIES) .. ")")
    end

    if #zombies > 0 then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES, zombies)
    end
end

function CustomSync.syncVehicles(playerPositions)
    local vehicles = {}
    local cell = getCell()
    if not cell then return end

    -- Fix 3: Use shared playerPositions, fallback to building if called standalone
    if not playerPositions then
        local players = getOnlinePlayers()
        playerPositions = {}
        for j = 0, players:size() - 1 do
            local player = players:get(j)
            if player then
                table.insert(playerPositions, {x = player:getX(), y = player:getY()})
            end
        end
    end

    local vehicleList = cell:getVehicles()
    if vehicleList then
        for i = 0, vehicleList:size() - 1 do
            local vehicle = vehicleList:get(i)
            if vehicle then
                local vx, vy = vehicle:getX(), vehicle:getY()
                local nearPlayer = false
                for _, pos in ipairs(playerPositions) do
                    if CustomSync.isWithinSyncDistance(pos.x, pos.y, vx, vy) then
                        nearPlayer = true
                        break
                    end
                end
                if nearPlayer then
                    local state = {
                        id = vehicle:getID(),
                        x = vehicle:getX(),
                        y = vehicle:getY(),
                        z = vehicle:getZ(),
                        speed = getVehicleSpeedKmHourSafe(vehicle),
                        health = vehicle:getEngineQuality()
                    }
                    if isStateDeltaExceeded(state, CustomSync.lastBroadcastVehicles[state.id], CustomSync.VEHICLE_DELTA_EPSILON or 0.05) then
                        table.insert(vehicles, state)
                        CustomSync.lastBroadcastVehicles[state.id] = state
                    end
                end
            end
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #vehicles .. " vehicles")
    end

    if #vehicles > 0 then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_VEHICLES, vehicles)
    end
end

function CustomSync.syncTrailers(playerPositions)
    local trailers = {}
    local cell = getCell()
    if not cell then return end

    -- Fix 3: Use shared playerPositions, fallback to building if called standalone
    if not playerPositions then
        local players = getOnlinePlayers()
        playerPositions = {}
        for j = 0, players:size() - 1 do
            local player = players:get(j)
            if player then
                table.insert(playerPositions, {x = player:getX(), y = player:getY()})
            end
        end
    end

    local vehicleList = cell:getVehicles()
    if not vehicleList then return end

    for i = 0, vehicleList:size() - 1 do
        local towingVehicle = vehicleList:get(i)
        if towingVehicle then
            local trailer = getVehicleTowingSafe(towingVehicle)
            if trailer then
                local tx, ty = trailer:getX(), trailer:getY()
                local px, py = towingVehicle:getX(), towingVehicle:getY()
                local nearPlayer = false
                for _, pos in ipairs(playerPositions) do
                    if CustomSync.isWithinSyncDistance(pos.x, pos.y, tx, ty) or CustomSync.isWithinSyncDistance(pos.x, pos.y, px, py) then
                        nearPlayer = true
                        break
                    end
                end

                if nearPlayer then
                    local dx = tx - px
                    local dy = ty - py
                    local hitchDistance = math.sqrt(dx * dx + dy * dy)

                    local state = {
                        id = trailer:getID(),
                        parentId = towingVehicle:getID(),
                        x = tx,
                        y = ty,
                        z = trailer:getZ(),
                        direction = getVehicleDirectionAngleSafe(trailer),
                        speed = getVehicleSpeedKmHourSafe(towingVehicle),
                        hitchDistance = hitchDistance
                    }

                    if isStateDeltaExceeded(state, CustomSync.lastTrailerPositions[state.id], 0.03) then
                        table.insert(trailers, state)
                        CustomSync.lastTrailerPositions[state.id] = state
                    end
                end
            end
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #trailers .. " trailers")
    end

    if #trailers > 0 then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_TRAILERS, trailers)
    end
end

function CustomSync.syncInventories()
    local players = getOnlinePlayers()
    local inventoryData = {}

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local inventory = player:getInventory()
            if inventory then
                local items = CustomSync.serializeInventory(inventory, 0)
                local signature = CustomSync.buildInventorySignature(items)
                local playerId = player:getOnlineID()
                if CustomSync.lastInventorySignatures[playerId] ~= signature then
                    CustomSync.lastInventorySignatures[playerId] = signature
                    table.insert(inventoryData, {
                        id = playerId,
                        items = items,
                        signature = signature
                    })
                    if CustomSync.DEBUG then
                        print("[CustomSync] Serialized inventory delta for player " .. playerId .. " with " .. #items .. " items")
                    end
                end
            end
        end
    end

    if CustomSync.DEBUG and #inventoryData > 0 then
        print("[CustomSync] Syncing inventories for " .. #inventoryData .. " players")
    end

    if #inventoryData > 0 then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_INVENTORIES, inventoryData)
    end
end

function CustomSync.serializeInventory(inventory, depth)
    depth = depth or 0
    if depth > 3 then return {} end  -- Prevent deep recursion and reduce data
    local items = {}
    local itemList = inventory:getItems()
    for j = 0, itemList:size() - 1 do
        local item = itemList:get(j)
        if item then
            local itemData = {
                type = item:getFullType(),
                count = item:getCount() or 1,
                condition = item:getCondition() or 100
            }
            if item:getContainer() then
                itemData.container = CustomSync.serializeInventory(item:getContainer(), depth + 1)
            end
            table.insert(items, itemData)
        end
    end
    return items
end

function CustomSync.buildInventorySignature(items)
    if not items then return "" end
    local parts = {}
    for _, itemData in ipairs(items) do
        local part = tostring(itemData.type) .. ":" .. tostring(itemData.count or 1) .. ":" .. tostring(itemData.condition or 100)
        if itemData.container then
            part = part .. "{" .. CustomSync.buildInventorySignature(itemData.container) .. "}"
        end
        table.insert(parts, part)
    end
    return table.concat(parts, "|")
end

function CustomSync.syncPlayerInventory(player, force)
    if not player then return end
    local inventory = player:getInventory()
    local items = CustomSync.serializeInventory(inventory, 0)
    local signature = CustomSync.buildInventorySignature(items)
    local playerId = player:getOnlineID()
    if not force and CustomSync.lastInventorySignatures[playerId] == signature then
        return
    end
    CustomSync.lastInventorySignatures[playerId] = signature
    local data = {
        id = playerId,
        items = items,
        signature = signature
    }
    if CustomSync.DEBUG then
        print("[CustomSync] Sending inventory sync for player " .. playerId .. " with " .. #items .. " items")
    end
    local success, err = pcall(safeSendServerCommand, CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_INVENTORIES, {data})
    if not success then
        print("[CustomSync] Error syncing player inventory: " .. tostring(err))
    end
end

Events.OnInitGlobalModData.Add(onInitGlobalModData)
Events.OnTick.Add(onTick)

local function onPlayerDeath(player)
    if player then
        if CustomSync.DEBUG then
            print("[CustomSync] Player " .. player:getOnlineID() .. " died, syncing inventory")
        end
        -- Force sync inventory immediately on death
        CustomSync.syncPlayerInventory(player, true)
    end
end

Events.OnPlayerDeath.Add(onPlayerDeath)

local function onContainerUpdate(container)
    if not container or not container.getParent then return end
    local parent = container:getParent()
    if not parent or not instanceof then return end
    if instanceof(parent, "IsoPlayer") then
        local player = parent
        if container == player:getInventory() then
            if CustomSync.DEBUG then
                print("[CustomSync] Inventory changed for player " .. player:getOnlineID())
            end
            CustomSync.syncPlayerInventory(player, false)
        end
    end
end

Events.OnContainerUpdate.Add(onContainerUpdate)

-- New event handlers for improved sync

local function onHitZombie(zombie, character, handWeapon, damage)
    if not zombie or not character then return end
    if sendImmediateZombieSync(zombie, false) and CustomSync.DEBUG then
        print("[CustomSync] Immediate sync for hit zombie " .. zombie:getOnlineID())
    end
end

Events.OnHitZombie.Add(onHitZombie)

local function onZombieDead(zombie)
    if not zombie then return end
    -- Ensure client kills the zombie when it dies on server (force bypass cooldown)
    local zombieData = {
        id = zombie:getOnlineID(),
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
        health = 0,
        direction = zombie:getDirectionAngle(),
        crawling = zombie:isCrawling()
    }
    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
    CustomSync.lastImmediateZombieSyncTick[zombieData.id] = tickCounter
    if CustomSync.DEBUG then
        print("[CustomSync] Zombie died, sending death sync for " .. zombieData.id)
    end
end

Events.OnZombieDead.Add(onZombieDead)

local function onZombieUpdate(zombie)
    if not zombie then return end
    local id = zombie:getOnlineID()

    -- Fix 1: Throttle per-zombie — only process every ZOMBIE_UPDATE_THROTTLE ticks
    local throttle = CustomSync.ZOMBIE_UPDATE_THROTTLE or 10
    local lastTick = CustomSync.lastZombieUpdateTick[id] or 0
    if (tickCounter - lastTick) < throttle then
        return
    end
    CustomSync.lastZombieUpdateTick[id] = tickCounter

    local currentHealth = zombie:getHealth()
    local currentCrawling = zombie:isCrawling()
    local lastHealth = CustomSync.lastZombieHealth[id]
    local lastCrawling = CustomSync.lastZombieCrawling[id]
    if (lastHealth and lastHealth ~= currentHealth) or (lastCrawling ~= nil and lastCrawling ~= currentCrawling) then
        -- Check if zombie is near a player
        local zx, zy = zombie:getX(), zombie:getY()
        local players = getOnlinePlayers()
        local nearPlayer = false
        for j = 0, players:size() - 1 do
            local player = players:get(j)
            if player then
                local px, py = player:getX(), player:getY()
                if CustomSync.isWithinSyncDistance(px, py, zx, zy) then
                    nearPlayer = true
                    break
                end
            end
        end
        if nearPlayer then
            -- Health or crawling changed, send immediate sync (throttled)
            if sendImmediateZombieSync(zombie, false) and CustomSync.DEBUG then
                print("[CustomSync] State changed for zombie " .. id .. " health:" .. lastHealth .. "->" .. currentHealth .. " crawling:" .. tostring(lastCrawling) .. "->" .. tostring(currentCrawling))
            end
        end
    end
    CustomSync.lastZombieHealth[id] = currentHealth
    CustomSync.lastZombieCrawling[id] = currentCrawling
end

Events.OnZombieUpdate.Add(onZombieUpdate)

local function onPlayerUpdate(player)
    if not player then return end
    -- Throttled sync for player movement
    local playerId = player:getOnlineID()
    local lastPos = CustomSync.lastPlayerPositions[playerId]
    local currentPos = {x = player:getX(), y = player:getY()}
    if not lastPos or CustomSync.getDistanceSq(lastPos.x, lastPos.y, currentPos.x, currentPos.y) > CustomSync.MIN_MOVE_DISTANCE^2 then
        CustomSync.lastPlayerPositions[playerId] = currentPos
        local playerData = {
            id = playerId,
            x = currentPos.x,
            y = currentPos.y,
            z = player:getZ(),
            health = player:getBodyDamage():getOverallBodyHealth(),
            animation = player:getAnimationDebug()
        }
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE, {playerData})
        if CustomSync.DEBUG then
            print("[CustomSync] Immediate sync for player " .. playerId)
        end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

local function onAIStateChange(character, newState, oldState)
    if not character or not instanceof(character, "IsoZombie") then return end
    if sendImmediateZombieSync(character, false) and CustomSync.DEBUG then
        print("[CustomSync] Sync on AI state change for zombie " .. character:getOnlineID() .. " to state " .. tostring(newState))
    end
end

Events.OnAIStateChange.Add(onAIStateChange)

local function onWeaponSwingHitPoint(character, weapon, hitX, hitY, hitZ)
    if not character or not weapon or type(hitX) ~= "number" or type(hitY) ~= "number" then return end
    -- Fix 5: Check if hitting a zombie, cap to max 5 syncs per swing event
    local cell = getCell()
    if cell then
        local zombieList = cell:getZombieList()
        if zombieList then
            local syncCount = 0
            for i = 0, zombieList:size() - 1 do
                local zombie = zombieList:get(i)
                if zombie then
                    local zx, zy = zombie:getX(), zombie:getY()
                    if type(zx) == "number" and type(zy) == "number" and CustomSync.getDistanceSq(zx, zy, hitX, hitY) < 4 then -- Within 2 squares
                        local sent = sendImmediateZombieSync(zombie, false)
                        if sent then
                            syncCount = syncCount + 1
                            if CustomSync.DEBUG then
                                print("[CustomSync] Sync on weapon swing hit for zombie " .. zombie:getOnlineID())
                            end
                            if syncCount >= 5 then break end
                        end
                    end
                end
            end
        end
    end
end

Events.OnWeaponSwingHitPoint.Add(onWeaponSwingHitPoint)

-- Additional event handlers for further sync improvements

local function onCharacterCollide(character1, character2)
    if not character1 or not character2 then return end
    -- Check if one is player and one is zombie
    local player, zombie
    if instanceof(character1, "IsoPlayer") and instanceof(character2, "IsoZombie") then
        player = character1
        zombie = character2
    elseif instanceof(character1, "IsoZombie") and instanceof(character2, "IsoPlayer") then
        player = character2
        zombie = character1
    else
        return -- Not player-zombie collision
    end

    -- Fix 4: Per-player collision cooldown to prevent horde spam
    local playerId = player:getOnlineID()
    local cooldown = CustomSync.COLLISION_COOLDOWN or 30
    local lastCollisionTick = CustomSync.lastCollisionSyncTick[playerId] or 0
    if (tickCounter - lastCollisionTick) < cooldown then
        return
    end
    CustomSync.lastCollisionSyncTick[playerId] = tickCounter

    -- Immediate sync for both to correct positions after collision
    local playerData = {
        id = playerId,
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        health = player:getBodyDamage():getOverallBodyHealth(),
        animation = player:getAnimationDebug()
    }
    local zombieData = {
        id = zombie:getOnlineID(),
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
        health = zombie:getHealth(),
        direction = zombie:getDirectionAngle(),
        crawling = zombie:isCrawling()
    }
    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE, {playerData})
    if shouldSendImmediateZombieSync(zombieData.id, false) then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
        CustomSync.lastImmediateZombieSyncTick[zombieData.id] = tickCounter
    end
    if CustomSync.DEBUG then
        print("[CustomSync] Sync on character collision between player " .. playerData.id .. " and zombie " .. zombieData.id)
    end
end

Events.OnCharacterCollide.Add(onCharacterCollide)

local function onPlayerGetDamage(player, damageType, damageAmount)
    if not player then return end
    -- Immediate sync for player health after taking damage
    local bodyDamage = player:getBodyDamage()
    local health = bodyDamage and bodyDamage:getOverallBodyHealth() or 100 -- Default to 100 if null
    local playerData = {
        id = player:getOnlineID(),
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        health = health,
        animation = player:getAnimationDebug()
    }
    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE, {playerData})
    if CustomSync.DEBUG then
        print("[CustomSync] Sync on player get damage for " .. playerData.id .. " damage: " .. tostring(damageAmount))
    end
end

Events.OnPlayerGetDamage.Add(onPlayerGetDamage)

local function onWeaponSwing(character, weapon)
    if not character or not weapon then return end
    -- Fix 5: Sync nearby zombies when swinging weapon, cap to max 5
    local cell = getCell()
    if cell then
        local zombieList = cell:getZombieList()
        if zombieList then
            local cx, cy = character:getX(), character:getY()
            if type(cx) ~= "number" or type(cy) ~= "number" then return end
            local syncCount = 0
            for i = 0, zombieList:size() - 1 do
                local zombie = zombieList:get(i)
                if zombie then
                    local zx, zy = zombie:getX(), zombie:getY()
                    if type(zx) == "number" and type(zy) == "number" and CustomSync.getDistanceSq(zx, zy, cx, cy) < 16 then -- Within 4 squares
                        local sent = sendImmediateZombieSync(zombie, false)
                        if sent then
                            syncCount = syncCount + 1
                            if CustomSync.DEBUG then
                                print("[CustomSync] Sync on weapon swing for zombie " .. zombie:getOnlineID())
                            end
                            if syncCount >= 5 then break end
                        end
                    end
                end
            end
        end
    end
end

Events.OnWeaponSwing.Add(onWeaponSwing)

local function onPlayerAttackFinished(player, weapon, damage, square)
    if not player or not weapon or not square then return end
    -- Sync zombies in the attacked square or nearby
    local sx, sy = square:getX(), square:getY()
    if type(sx) ~= "number" or type(sy) ~= "number" then return end
    local cell = getCell()
    if cell then
        local zombieList = cell:getZombieList()
        if zombieList then
            for i = 0, zombieList:size() - 1 do
                local zombie = zombieList:get(i)
                if zombie then
                    local zx, zy = zombie:getX(), zombie:getY()
                    if type(zx) == "number" and type(zy) == "number" and CustomSync.getDistanceSq(zx, zy, sx, sy) < 4 then -- Within 2 squares
                        local sent = sendImmediateZombieSync(zombie, false)
                        if sent and CustomSync.DEBUG then
                            print("[CustomSync] Sync on player attack finished for zombie " .. zombie:getOnlineID())
                        end
                    end
                end
            end
        end
    end
end

Events.OnPlayerAttackFinished.Add(onPlayerAttackFinished)
