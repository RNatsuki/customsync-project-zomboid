require "CustomSync"

local function onServerCommand(module, command, args)
    if module ~= CustomSync.MOD_ID then return end

    if command == CustomSync.COMMAND_SYNC_PLAYERS then
        CustomSync.applyPlayerSync(args)
    elseif command == CustomSync.COMMAND_SYNC_ZOMBIES then
        CustomSync.applyZombieSync(args)
    elseif command == CustomSync.COMMAND_SYNC_VEHICLES then
        CustomSync.applyVehicleSync(args)
    end
end

function CustomSync.applyPlayerSync(playerData)
    if not playerData or type(playerData) ~= "table" then return end

    local localPlayer = getPlayer()
    if not localPlayer then return end

    if CustomSync.DEBUG then
        print("[CustomSync] Applying sync for " .. #playerData .. " players")
    end

    for _, data in ipairs(playerData) do
        local player = getPlayerByOnlineID(data.id)
        if player and player ~= localPlayer then -- Don't sync self
            -- Only sync if within distance
            local px, py = localPlayer:getX(), localPlayer:getY()
            if CustomSync.isWithinSyncDistance(px, py, data.x, data.y) then
                player:setX(data.x)
                player:setY(data.y)
                player:setZ(data.z)
                -- Note: Health and animation syncing might need careful handling to avoid conflicts
            end
        end
    end
end

function CustomSync.applyZombieSync(zombieData)
    if not zombieData or type(zombieData) ~= "table" then return end

    local localPlayer = getPlayer()
    if not localPlayer then return end

    if CustomSync.DEBUG then
        print("[CustomSync] Applying sync for " .. #zombieData .. " zombies")
    end

    local cell = getCell()
    if not cell then return end

    local zombieList = cell:getZombieList()
    if not zombieList then return end

    for _, data in ipairs(zombieData) do
        local zombie = nil
        for i = 0, zombieList:size() - 1 do
            local zomb = zombieList:get(i)
            if zomb and zomb:getOnlineID() == data.id then
                zombie = zomb
                break
            end
        end

        if zombie then
            local px, py = localPlayer:getX(), localPlayer:getY()
            if CustomSync.isWithinSyncDistance(px, py, data.x, data.y) then
                zombie:setX(data.x)
                zombie:setY(data.y)
                zombie:setZ(data.z)
                zombie:setHealth(data.health)
                -- State might need more handling
            end
        end
    end
end

function CustomSync.applyVehicleSync(vehicleData)
    if not vehicleData or type(vehicleData) ~= "table" then return end

    local localPlayer = getPlayer()
    if not localPlayer then return end

    if CustomSync.DEBUG then
        print("[CustomSync] Applying sync for " .. #vehicleData .. " vehicles")
    end

    local cell = getCell()
    if not cell then return end

    local vehicleList = cell:getVehicles()
    if not vehicleList then return end

    for _, data in ipairs(vehicleData) do
        local vehicle = nil
        for i = 0, vehicleList:size() - 1 do
            local veh = vehicleList:get(i)
            if veh and veh:getID() == data.id then
                vehicle = veh
                break
            end
        end

        if vehicle then
            local px, py = localPlayer:getX(), localPlayer:getY()
            if CustomSync.isWithinSyncDistance(px, py, data.x, data.y) then
                vehicle:setX(data.x)
                vehicle:setY(data.y)
                vehicle:setZ(data.z)
                -- Speed and health
            end
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)

