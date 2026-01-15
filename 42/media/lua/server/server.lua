require "CustomSync"

local tickCounter = 0

-- Cache for dynamic updates
local lastUpdateInterval = CustomSync.UPDATE_INTERVAL
local lastSyncDistance = CustomSync.SYNC_DISTANCE
local lastEnableVehicleRespawn = CustomSync.ENABLE_VEHICLE_RESPAWN

local function onInitGlobalModData()
    CustomSync.UPDATE_INTERVAL = SandboxVars.CustomSync.UpdateInterval or CustomSync.UPDATE_INTERVAL
    CustomSync.SYNC_DISTANCE = SandboxVars.CustomSync.SyncDistance or CustomSync.SYNC_DISTANCE
    CustomSync.ENABLE_VEHICLE_RESPAWN = SandboxVars.CustomSync.EnableVehicleRespawn
    if CustomSync.ENABLE_VEHICLE_RESPAWN == nil then CustomSync.ENABLE_VEHICLE_RESPAWN = true end

    -- Update cache
    lastUpdateInterval = CustomSync.UPDATE_INTERVAL
    lastSyncDistance = CustomSync.SYNC_DISTANCE
    lastEnableVehicleRespawn = CustomSync.ENABLE_VEHICLE_RESPAWN
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
    if SandboxVars.CustomSync.EnableVehicleRespawn ~= nil and SandboxVars.CustomSync.EnableVehicleRespawn ~= lastEnableVehicleRespawn then
        CustomSync.ENABLE_VEHICLE_RESPAWN = SandboxVars.CustomSync.EnableVehicleRespawn
        lastEnableVehicleRespawn = CustomSync.ENABLE_VEHICLE_RESPAWN
        if CustomSync.DEBUG then
            print("[CustomSync] Updated ENABLE_VEHICLE_RESPAWN to " .. tostring(CustomSync.ENABLE_VEHICLE_RESPAWN))
        end
    end

    if tickCounter % CustomSync.UPDATE_INTERVAL ~= 0 then return end

    -- Sync players
    CustomSync.syncPlayers()

    -- Sync zombies
    CustomSync.syncZombies()

    -- Sync vehicles
    CustomSync.syncVehicles()
end

Events.OnInitGlobalModData.Add(onInitGlobalModData)
function CustomSync.syncPlayers()
    local players = getOnlinePlayers()
    local playerData = {}

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            -- Save vehicle state for respawn
            if CustomSync.ENABLE_VEHICLE_RESPAWN then
                local vehicle = player:getVehicle()
                if vehicle then
                    local seat = vehicle:getSeat(player)
                    ModData[CustomSync.MOD_ID .. "_vehicle_" .. player:getUsername()] = {
                        vehicleId = vehicle:getID(),
                        seat = seat
                    }
                    if CustomSync.DEBUG then
                        print("[CustomSync] Saved vehicle data for " .. player:getUsername() .. ": ID " .. vehicle:getID() .. ", seat " .. seat)
                    end
                else
                    ModData[CustomSync.MOD_ID .. "_vehicle_" .. player:getUsername()] = nil
                    if CustomSync.DEBUG then
                        print("[CustomSync] Cleared vehicle data for " .. player:getUsername())
                    end
                end
            end

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
    local zombies = {}
    local cell = getCell()
    if not cell then return end

    local players = getOnlinePlayers()
    local zombieList = cell:getZombieList()
    if zombieList then
        for i = 0, zombieList:size() - 1 do
            local zombie = zombieList:get(i)
            if zombie then
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
                    table.insert(zombies, {
                        id = zombie:getOnlineID(),
                        x = zombie:getX(),
                        y = zombie:getY(),
                        z = zombie:getZ(),
                        health = zombie:getHealth(),
                        state = zombie:getCurrentState()
                    })
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

Events.OnInitGlobalModData.Add(onInitGlobalModData)
Events.OnTick.Add(onTick)

local function onCreatePlayer(playerIndex, player)
    if not CustomSync.ENABLE_VEHICLE_RESPAWN then return end

    local username = player:getUsername()
    local data = ModData[CustomSync.MOD_ID .. "_vehicle_" .. username]
    if data and data.vehicleId then
        -- Find the vehicle
        local cell = getCell()
        if cell then
            local vehicles = cell:getVehicles()
            if vehicles then
                for i = 0, vehicles:size() - 1 do
                    local veh = vehicles:get(i)
                    if veh and veh:getID() == data.vehicleId then
                        veh:enter(player, data.seat or 0)
                        ModData[CustomSync.MOD_ID .. "_vehicle_" .. username] = nil
                        if CustomSync.DEBUG then
                            print("[CustomSync] Respawned " .. username .. " in vehicle ID " .. data.vehicleId .. ", seat " .. (data.seat or 0))
                        end
                        break
                    end
                end
            end
        end
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
