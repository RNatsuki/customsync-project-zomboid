require "CustomSync"

print("[CustomSync] Server script loaded")

local tickCounter = 0

-- Cache for dynamic updates
local lastUpdateInterval = CustomSync.UPDATE_INTERVAL
local lastSyncDistance = CustomSync.SYNC_DISTANCE
local lastDebug = 0

local function onInitGlobalModData()
    CustomSync.UPDATE_INTERVAL = SandboxVars.CustomSync.UpdateInterval or CustomSync.UPDATE_INTERVAL
    CustomSync.SYNC_DISTANCE = SandboxVars.CustomSync.SyncDistance or CustomSync.SYNC_DISTANCE
    -- CustomSync.DEBUG = debugVal == 1  -- Commented out to keep default true
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
            table.insert(playerData, {
                id = player:getOnlineID(),
                x = player:getX(),
                y = player:getY(),
                z = player:getZ(),
                health = player:getBodyDamage():getOverallBodyHealth(),
                animation = player:getAnimationDebug()
            })
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #playerData .. " players")
    end

    -- Send to all clients
    sendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_PLAYERS, playerData)
end

function CustomSync.syncZombies()
    print("[CustomSync] Syncing zombies...")
    local zombies = {}
    local cell = getCell()
    if not cell then return end

    local players = getOnlinePlayers()
    local zombieList = cell:getZombieList()
    local maxZombies = 50
    local count = 0

    if zombieList then
        for i = 0, zombieList:size() - 1 do
            local zombie = zombieList:get(i)
            if zombie then
                if count >= maxZombies then
                    break
                end

                local zx, zy = zombie:getX(), zombie:getY()
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
                    local success, zombieData = pcall(function()
                        return {
                            id = zombie:getOnlineID(),
                            x = zombie:getX(),
                            y = zombie:getY(),
                            z = zombie:getZ(),
                            health = zombie:getHealth(),
                            direction = zombie:getDirectionAngle()
                        }
                    end)

                    if success and zombieData then
                        if CustomSync.DEBUG then
                            print("[CustomSync] Syncing zombie " .. zombieData.id .. " at (" .. zombieData.x .. "," .. zombieData.y .. ") health:" .. zombieData.health .. " direction:" .. zombieData.direction)
                        end
                        table.insert(zombies, zombieData)
                        count = count + 1
                    else
                        if CustomSync.DEBUG then
                            print("[CustomSync] Error syncing zombie " .. tostring(zombie:getOnlineID()) .. ": " .. tostring(zombieData))
                        end
                    end
                end
            end
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #zombies .. " zombies")
    end

    -- Batch and send
    sendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_ZOMBIES, zombies)
end

function CustomSync.syncVehicles()
    local vehicles = {}
    local cell = getCell()
    if not cell then return end

    local players = getOnlinePlayers()
    local vehicleList = cell:getVehicles()
    if vehicleList then
        for i = 0, vehicleList:size() - 1 do
            local vehicle = vehicleList:get(i)
            if vehicle then
                local vx, vy = vehicle:getX(), vehicle:getY()
                local nearPlayer = false
                for j = 0, players:size() - 1 do
                    local player = players:get(j)
                    if player then
                        local px, py = player:getX(), player:getY()
                        if CustomSync.isWithinSyncDistance(px, py, vx, vy) then
                            nearPlayer = true
                            break
                        end
                    end
                end
                if nearPlayer then
                    table.insert(vehicles, {
                        id = vehicle:getID(),
                        x = vehicle:getX(),
                        y = vehicle:getY(),
                        z = vehicle:getZ(),
                        speed = vehicle:getCurrentSpeedKmHour(),
                        health = vehicle:getEngineQuality()
                    })
                end
            end
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Syncing " .. #vehicles .. " vehicles")
    end

    sendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_VEHICLES, vehicles)
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
                print("[CustomSync] Serialized inventory for player " .. player:getOnlineID() .. " with " .. #items .. " items")
            end
        end
    end

    print("[CustomSync] Syncing inventories for " .. #inventoryData .. " players")

    sendServerCommand(CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_INVENTORIES, inventoryData)
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
    local success, err = pcall(sendServerCommand, CustomSync.MOD_ID, CustomSync.COMMAND_SYNC_INVENTORIES, {data})
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
