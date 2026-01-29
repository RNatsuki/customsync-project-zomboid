require "CustomSync"

if CustomSync.DEBUG then print("[CustomSync] Server script loaded") end

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

local lastImmediateZombieSync = {}
local lastImmediatePlayerSync = {}

local function shouldThrottleImmediate(cache, id)
    if not id then return false end
    local last = cache[id]
    if last and tickCounter - last < CustomSync.IMMEDIATE_COOLDOWN_TICKS then
        return true
    end
    cache[id] = tickCounter
    return false
end

local function onInitGlobalModData()
    CustomSync.UPDATE_INTERVAL = SandboxVars.CustomSync.UpdateInterval or CustomSync.UPDATE_INTERVAL
    CustomSync.SYNC_DISTANCE = SandboxVars.CustomSync.SyncDistance or CustomSync.SYNC_DISTANCE
    CustomSync.MAX_ZOMBIES = SandboxVars.CustomSync.MaxZombies or 100
    -- CustomSync.DEBUG = debugVal == 1  -- Commented out to keep default true
    CustomSync.lastZombiePositions = {}
    CustomSync.lastPlayerPositions = {}
    CustomSync.lastZombieHealth = {}
    CustomSync.lastZombieCrawling = {}
    CustomSync.activeZombies = {}
    lastImmediateZombieSync = {}
    lastImmediatePlayerSync = {}
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

    if tickCounter % CustomSync.UPDATE_INTERVAL ~= 0 then return end

    -- Sync players
    CustomSync.syncPlayers()

    -- Sync zombies
    CustomSync.syncZombies()

    -- Sync vehicles
    CustomSync.syncVehicles()

    -- Inventories and appearance synced on update via OnContainerUpdate
end

Events.OnInitGlobalModData.Add(onInitGlobalModData)
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
            table.insert(playerData, {
                id = id,
                x = x,
                y = y,
                z = z,
                direction = player:getDirectionAngle(),
                speed = speed,
                health = player:getBodyDamage():getOverallBodyHealth(),
                animation = player:getAnimationDebug()
            })
            if CustomSync.DEBUG then
                print("[CustomSync] Server: Player " .. id .. " calculated speed: " .. speed)
            end
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Server: Syncing " .. #playerData .. " players")
    end

    -- Send to all clients
    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS, playerData)
end

function CustomSync.syncZombies()
    if CustomSync.DEBUG then print("[CustomSync] Syncing zombies...") end
    local cell = getCell()
    if not cell then return end

    local players = getOnlinePlayers()
    local playerPositions = {}
    for j = 0, players:size() - 1 do
        local player = players:get(j)
        if player then
            table.insert(playerPositions, {x = player:getX(), y = player:getY()})
        end
    end
    if #playerPositions == 0 then return end

    local zombieList = cell:getZombieList()
    if not zombieList then return end

    local zombieSyncDistanceSq = CustomSync.SYNC_DISTANCE_ZOMBIES * CustomSync.SYNC_DISTANCE_ZOMBIES

    local function nearestDistanceSq(x, y)
        local minDist = math.huge
        for _, pos in ipairs(playerPositions) do
            local distSq = CustomSync.getDistanceSq(pos.x, pos.y, x, y)
            if distSq < minDist then
                minDist = distSq
            end
        end
        return minDist
    end

    -- Update existing active zombies
    for id, data in pairs(CustomSync.activeZombies) do
        local exists = false
        local zombie = nil
        for i = 0, zombieList:size() - 1 do
            local z = zombieList:get(i)
            if z and z:getOnlineID() == id then
                zombie = z
                break
            end
        end
        if zombie and zombie:getHealth() > 0 then
            local zx, zy = zombie:getX(), zombie:getY()
            local nearestSq = nearestDistanceSq(zx, zy)
            if nearestSq <= zombieSyncDistanceSq then
                exists = true
                data.x = zx
                data.y = zy
                data.z = zombie:getZ()
                data.health = zombie:getHealth()
                data.direction = zombie:getDirectionAngle()
                data.crawling = zombie:isCrawling()
                data.lastSeenTick = tickCounter
                data.nearestDistanceSq = nearestSq
            end
        end
        if not exists then
            CustomSync.activeZombies[id] = nil
        end
    end

    -- Add new nearby zombies
    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if zombie and zombie:getHealth() > 0 then
            local id = zombie:getOnlineID()
            if not CustomSync.activeZombies[id] then
                local zx, zy = zombie:getX(), zombie:getY()
                local nearestSq = nearestDistanceSq(zx, zy)
                if nearestSq <= zombieSyncDistanceSq then
                    CustomSync.activeZombies[id] = {
                        id = id,
                        x = zx,
                        y = zy,
                        z = zombie:getZ(),
                        health = zombie:getHealth(),
                        direction = zombie:getDirectionAngle(),
                        crawling = zombie:isCrawling(),
                        lastSeenTick = tickCounter,
                        nearestDistanceSq = nearestSq
                    }
                end
            end
        end
    end

    -- Remove stale entries to avoid unbounded growth
    for id, data in pairs(CustomSync.activeZombies) do
        if not data.lastSeenTick or (tickCounter - data.lastSeenTick) > CustomSync.ZOMBIE_STALE_TICKS then
            CustomSync.activeZombies[id] = nil
        end
    end

    -- Convert to list for sending and enforce max zombies cap
    local zombies = {}
    for _, data in pairs(CustomSync.activeZombies) do
        table.insert(zombies, data)
    end

    if #zombies > CustomSync.MAX_ZOMBIES then
        table.sort(zombies, function(a, b)
            return (a.nearestDistanceSq or math.huge) < (b.nearestDistanceSq or math.huge)
        end)
        for i = CustomSync.MAX_ZOMBIES + 1, #zombies do
            local drop = zombies[i]
            if drop and drop.id then
                CustomSync.activeZombies[drop.id] = nil
            end
        end
        local limited = {}
        local limit = math.min(CustomSync.MAX_ZOMBIES, #zombies)
        for i = 1, limit do
            limited[i] = zombies[i]
        end
        zombies = limited
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #zombies .. " active zombies")
    end

    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES, zombies)
end

function CustomSync.syncVehicles()
    local vehicles = {}
    local vehicleMap = {}
    local cell = getCell()
    if not cell then return end

    local players = getOnlinePlayers()
    local playerPositions = {}
    for j = 0, players:size() - 1 do
        local player = players:get(j)
        if player then
            table.insert(playerPositions, {x = player:getX(), y = player:getY()})
        end
    end
    if #playerPositions == 0 then return end

    local function nearestDistanceSq(x, y)
        local minDist = math.huge
        for _, pos in ipairs(playerPositions) do
            local distSq = CustomSync.getDistanceSq(pos.x, pos.y, x, y)
            if distSq < minDist then
                minDist = distSq
            end
        end
        return minDist
    end

    local function addVehicle(vehicle, forceInclude)
        if not vehicle then return end
        local id = vehicle:getID()
        if vehicleMap[id] then return end
        local vx, vy = vehicle:getX(), vehicle:getY()
        local distSq = nearestDistanceSq(vx, vy)
        local maxDistSq = (CustomSync.SYNC_DISTANCE_VEHICLES or CustomSync.SYNC_DISTANCE)^2
        if not forceInclude and distSq > maxDistSq then return end

        local okAngle, angle = pcall(function() return vehicle:getAngleZ() end)
        if not okAngle then angle = nil end
        local towed = vehicle.getTowedVehicle and vehicle:getTowedVehicle() or nil
        local towedId = towed and towed:getID() or nil
        local towedBy = nil
        if vehicle.getTowedBy then
            local towByVehicle = vehicle:getTowedBy()
            if towByVehicle and towByVehicle.getID then
                towedBy = towByVehicle:getID()
            end
        end

        vehicleMap[id] = true
        table.insert(vehicles, {
            id = id,
            x = vx,
            y = vy,
            z = vehicle:getZ(),
            speed = vehicle:getCurrentSpeedKmHour(),
            health = vehicle:getEngineQuality(),
            angle = angle,
            towedId = towedId,
            towedBy = towedBy
        })

        if towed and not vehicleMap[towedId] then
            addVehicle(towed, true) -- always include the trailer being towed
        end
    end

    local vehicleList = cell:getVehicles()
    if vehicleList then
        for i = 0, vehicleList:size() - 1 do
            addVehicle(vehicleList:get(i), false)
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #vehicles .. " vehicles (including trailers)")
    end

    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_VEHICLES, vehicles)
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
                table.insert(inventoryData, {
                    id = player:getOnlineID(),
                    items = items
                })
                if CustomSync.DEBUG then
                    print("[CustomSync] Serialized inventory for player " .. player:getOnlineID() .. " with " .. #items .. " items")
                end
            end
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing inventories for " .. #inventoryData .. " players")
    end
    safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_INVENTORIES, inventoryData)
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

function CustomSync.syncPlayerInventory(player)
    if not player then return end
    local inventory = player:getInventory()
    local items = CustomSync.serializeInventory(inventory, 0)
    local data = {
        id = player:getOnlineID(),
        items = items
    }
    if CustomSync.DEBUG then
        print("[CustomSync] Sending inventory sync for player " .. player:getOnlineID() .. " with " .. #items .. " items")
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
        CustomSync.syncPlayerInventory(player)
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
            print("[CustomSync] Syncing inventory for player " .. player:getOnlineID())
            CustomSync.syncPlayerInventory(player)
        end
    end
end

Events.OnContainerUpdate.Add(onContainerUpdate)

-- New event handlers for improved sync

local function onHitZombie(zombie, character, handWeapon, damage)
    if not zombie or not character then return end
    -- Immediate sync for hit zombie
    local zombieData = {
        id = zombie:getOnlineID(),
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
        health = zombie:getHealth(),
        direction = zombie:getDirectionAngle(),
        crawling = zombie:isCrawling()
    }
    if not shouldThrottleImmediate(lastImmediateZombieSync, zombieData.id) then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
        if CustomSync.DEBUG then
            print("[CustomSync] Immediate sync for hit zombie " .. zombieData.id)
        end
    elseif CustomSync.DEBUG then
        print("[CustomSync] Throttled hit sync for zombie " .. zombieData.id)
    end
end

Events.OnHitZombie.Add(onHitZombie)

local function onZombieDead(zombie)
    if not zombie then return end
    -- Ensure client kills the zombie when it dies on server
    local zombieData = {
        id = zombie:getOnlineID(),
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
        health = 0,
        direction = zombie:getDirectionAngle(),
        crawling = zombie:isCrawling()
    }
    if not shouldThrottleImmediate(lastImmediateZombieSync, zombieData.id) then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
        if CustomSync.DEBUG then
            print("[CustomSync] Zombie died, sending death sync for " .. zombieData.id)
        end
    elseif CustomSync.DEBUG then
        print("[CustomSync] Throttled death sync for zombie " .. zombieData.id)
    end
end

Events.OnZombieDead.Add(onZombieDead)

local function onZombieUpdate(zombie)
    if not zombie then return end
    local id = zombie:getOnlineID()
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
            -- Health or crawling changed, send immediate sync
            local zombieData = {
                id = id,
                x = zombie:getX(),
                y = zombie:getY(),
                z = zombie:getZ(),
                health = currentHealth,
                direction = zombie:getDirectionAngle(),
                crawling = currentCrawling
            }
            if not shouldThrottleImmediate(lastImmediateZombieSync, id) then
                safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
                if CustomSync.DEBUG then
                    print("[CustomSync] State changed for zombie " .. id .. " health:" .. lastHealth .. "->" .. currentHealth .. " crawling:" .. tostring(lastCrawling) .. "->" .. tostring(currentCrawling))
                end
            elseif CustomSync.DEBUG then
                print("[CustomSync] Throttled state change sync for zombie " .. id)
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
        if not shouldThrottleImmediate(lastImmediatePlayerSync, playerId) then
            safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE, {playerData})
            if CustomSync.DEBUG then
                print("[CustomSync] Immediate sync for player " .. playerId)
            end
        elseif CustomSync.DEBUG then
            print("[CustomSync] Throttled immediate player sync for " .. playerId)
        end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

local function onAIStateChange(character, newState, oldState)
    if not character or not instanceof(character, "IsoZombie") then return end
    -- Sync zombie on state change (e.g., from idle to attacking)
    local zombieData = {
        id = character:getOnlineID(),
        x = character:getX(),
        y = character:getY(),
        z = character:getZ(),
        health = character:getHealth(),
        direction = character:getDirectionAngle()
    }
    if not shouldThrottleImmediate(lastImmediateZombieSync, zombieData.id) then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
        if CustomSync.DEBUG then
            print("[CustomSync] Sync on AI state change for zombie " .. zombieData.id .. " to state " .. tostring(newState))
        end
    elseif CustomSync.DEBUG then
        print("[CustomSync] Throttled AI state sync for zombie " .. zombieData.id)
    end
end

Events.OnAIStateChange.Add(onAIStateChange)

local function onWeaponSwingHitPoint(character, weapon, hitX, hitY, hitZ)
    if not character or not weapon or type(hitX) ~= "number" or type(hitY) ~= "number" then return end
    -- Check if hitting a zombie and sync nearby zombies
    local cell = getCell()
    if cell then
        local zombieList = cell:getZombieList()
        if zombieList then
            for i = 0, zombieList:size() - 1 do
                local zombie = zombieList:get(i)
                if zombie then
                    local zx, zy = zombie:getX(), zombie:getY()
                    if type(zx) == "number" and type(zy) == "number" and CustomSync.getDistanceSq(zx, zy, hitX, hitY) < 4 then -- Within 2 squares
                        local zombieData = {
                            id = zombie:getOnlineID(),
                            x = zx,
                            y = zy,
                            z = zombie:getZ(),
                            health = zombie:getHealth(),
                            direction = zombie:getDirectionAngle()
                        }
                        if not shouldThrottleImmediate(lastImmediateZombieSync, zombieData.id) then
                            safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
                            if CustomSync.DEBUG then
                                print("[CustomSync] Sync on weapon swing hit for zombie " .. zombieData.id)
                            end
                        elseif CustomSync.DEBUG then
                            print("[CustomSync] Throttled weapon swing hit sync for zombie " .. zombieData.id)
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
    -- Immediate sync for both to correct positions after collision
    local playerData = {
        id = player:getOnlineID(),
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
        direction = zombie:getDirectionAngle()
    }
    if not shouldThrottleImmediate(lastImmediatePlayerSync, playerData.id) then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE, {playerData})
    end
    if not shouldThrottleImmediate(lastImmediateZombieSync, zombieData.id) then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
    end
    if CustomSync.DEBUG then
        print("[CustomSync] Sync on character collision between player " .. playerData.id .. " and zombie " .. zombieData.id)
    end
end

Events.OnCharacterCollide.Add(onCharacterCollide)

local function onPlayerMove(player)
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
        if not shouldThrottleImmediate(lastImmediatePlayerSync, playerId) then
            safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE, {playerData})
            if CustomSync.DEBUG then
                print("[CustomSync] Sync on player move for " .. playerId)
            end
        elseif CustomSync.DEBUG then
            print("[CustomSync] Throttled move sync for player " .. playerId)
        end
    end
end

Events.OnPlayerMove.Add(onPlayerMove)

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
    if not shouldThrottleImmediate(lastImmediatePlayerSync, playerData.id) then
        safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE, {playerData})
        if CustomSync.DEBUG then
            print("[CustomSync] Sync on player get damage for " .. playerData.id .. " damage: " .. tostring(damageAmount))
        end
    elseif CustomSync.DEBUG then
        print("[CustomSync] Throttled damage sync for player " .. playerData.id)
    end
end

Events.OnPlayerGetDamage.Add(onPlayerGetDamage)

local function onWeaponSwing(character, weapon)
    if not character or not weapon then return end
    -- Sync nearby zombies when swinging weapon
    local cell = getCell()
    if cell then
        local zombieList = cell:getZombieList()
        if zombieList then
            for i = 0, zombieList:size() - 1 do
                local zombie = zombieList:get(i)
                if zombie then
                    local zx, zy = zombie:getX(), zombie:getY()
                    local cx, cy = character:getX(), character:getY()
                    if type(zx) == "number" and type(zy) == "number" and type(cx) == "number" and type(cy) == "number" and CustomSync.getDistanceSq(zx, zy, cx, cy) < 16 then -- Within 4 squares
                        local zombieData = {
                            id = zombie:getOnlineID(),
                            x = zx,
                            y = zy,
                            z = zombie:getZ(),
                            health = zombie:getHealth(),
                            direction = zombie:getDirectionAngle()
                        }
                        if not shouldThrottleImmediate(lastImmediateZombieSync, zombieData.id) then
                            safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
                            if CustomSync.DEBUG then
                                print("[CustomSync] Sync on weapon swing for zombie " .. zombieData.id)
                            end
                        elseif CustomSync.DEBUG then
                            print("[CustomSync] Throttled weapon swing sync for zombie " .. zombieData.id)
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
                        local zombieData = {
                            id = zombie:getOnlineID(),
                            x = zx,
                            y = zy,
                            z = zombie:getZ(),
                            health = zombie:getHealth(),
                            direction = zombie:getDirectionAngle()
                        }
                        if not shouldThrottleImmediate(lastImmediateZombieSync, zombieData.id) then
                            safeSendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE, {zombieData})
                            if CustomSync.DEBUG then
                                print("[CustomSync] Sync on player attack finished for zombie " .. zombieData.id)
                            end
                        elseif CustomSync.DEBUG then
                            print("[CustomSync] Throttled attack-finished sync for zombie " .. zombieData.id)
                        end
                    end
                end
            end
        end
    end
end

Events.OnPlayerAttackFinished.Add(onPlayerAttackFinished)
