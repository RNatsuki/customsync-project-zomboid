require "CustomSync"

print("[CustomSync] Client script loaded")

CustomSync.playerTargets = {}
CustomSync.trailerTargets = {}

function CustomSync.getInventorySignature(items)
    if not items then return "" end
    local parts = {}
    for _, itemData in ipairs(items) do
        local part = tostring(itemData.type) .. ":" .. tostring(itemData.count or 1) .. ":" .. tostring(itemData.condition or 100)
        if itemData.container then
            part = part .. "{" .. CustomSync.getInventorySignature(itemData.container) .. "}"
        end
        table.insert(parts, part)
    end
    return table.concat(parts, "|")
end

local function onServerCommand(module, command, args)
    if module ~= CustomSync.MOD_ID then return end

    if CustomSync.DEBUG then
        print("[CustomSync] Received command: " .. command)
    end

    if command == CustomSync.COMMAND_SYNC_PLAYERS then
        CustomSync.applyPlayerSync(args)
    elseif command == CustomSync.COMMAND_SYNC_ZOMBIES then
        CustomSync.applyZombieSync(args)
    elseif command == CustomSync.COMMAND_SYNC_VEHICLES then
        CustomSync.applyVehicleSync(args)
    elseif command == CustomSync.COMMAND_SYNC_TRAILERS then
        CustomSync.applyTrailerSync(args)
    elseif command == CustomSync.COMMAND_SYNC_INVENTORIES then
        CustomSync.applyInventorySync(args)
    elseif command == CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE then
        CustomSync.applyZombieSyncImmediate(args)
    elseif command == CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE then
        CustomSync.applyPlayerSyncImmediate(args)
    end
end

local function getVehicleById(vehicleId)
    local cell = getCell()
    if not cell then return nil end
    local vehicleList = cell:getVehicles()
    if not vehicleList then return nil end
    for i = 0, vehicleList:size() - 1 do
        local vehicle = vehicleList:get(i)
        if vehicle and vehicle:getID() == vehicleId then
            return vehicle
        end
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

local function setVehicleDirectionAngleSafe(vehicle, angle)
    if not vehicle or type(vehicle.setDirectionAngle) ~= "function" or angle == nil then return end
    pcall(function()
        vehicle:setDirectionAngle(angle)
    end)
end

function CustomSync.applyPlayerSync(playerData)
    if not playerData or type(playerData) ~= "table" then return end

    local localPlayer = getPlayer()
    if not localPlayer then return end

    if CustomSync.DEBUG then
        print("[CustomSync] Applying sync for " .. #playerData .. " players")
    end

    local px, py = localPlayer:getX(), localPlayer:getY()

    for _, data in ipairs(playerData) do
        local player = getPlayerByOnlineID(data.id)
        if player and player ~= localPlayer then -- Don't sync self
            -- Store target for interpolation (within sync distance to avoid teleportation)
            if CustomSync.isWithinSyncDistance(px, py, data.x, data.y) then
                CustomSync.playerTargets[data.id] = data
                if CustomSync.DEBUG then
                    print("[CustomSync] Client: Storing interpolation target for player " .. data.id .. " at (" .. data.x .. "," .. data.y .. ") speed: " .. (data.speed or "nil") .. " animation: " .. (data.animation or "nil"))
                end
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

    local zombieMap = {}
    for i = 0, zombieList:size() - 1 do
        local zomb = zombieList:get(i)
        if zomb then
            zombieMap[zomb:getOnlineID()] = zomb
        end
    end

    local zombiesToKill = {}  -- Collect zombies to set dead after iteration

    for _, data in ipairs(zombieData) do
        local zombie = zombieMap[data.id]
        if zombie then
            local px, py = localPlayer:getX(), localPlayer:getY()
            if CustomSync.isWithinSyncDistanceZombies(px, py, data.x, data.y) then
                if CustomSync.DEBUG then
                    print("[CustomSync] Applying sync to zombie " .. data.id .. " at (" .. data.x .. "," .. data.y .. ") health:" .. data.health .. " direction:" .. data.direction)
                end
                -- Set position immediately to avoid desync and hit registration issues
                zombie:setX(data.x)
                zombie:setY(data.y)
                zombie:setZ(data.z)
                zombie:setHealth(data.health)
                zombie:setDirectionAngle(data.direction)
                if data.crawling ~= nil then
                    zombie:setCrawling(data.crawling)
                end
                if data.health <= 0 then
                    table.insert(zombiesToKill, zombie)  -- Collect instead of setting immediately
                end
            end
        end
    end

    -- Set dead after iteration to avoid ConcurrentModificationException
    for _, zombie in ipairs(zombiesToKill) do
        zombie:setDead(true)
    end
end

function CustomSync.applyZombieSyncImmediate(zombieData)
    if not zombieData or type(zombieData) ~= "table" then return end
    local cell = getCell()
    if not cell then return end
    local zombieList = cell:getZombieList()
    if not zombieList then return end

    local zombieMap = {}
    for i = 0, zombieList:size() - 1 do
        local zomb = zombieList:get(i)
        if zomb then
            zombieMap[zomb:getOnlineID()] = zomb
        end
    end

    local zombiesToKill = {}  -- Collect zombies to set dead after iteration

    for _, data in ipairs(zombieData) do
        local zombie = zombieMap[data.id]
        if zombie then
            zombie:setX(data.x)
            zombie:setY(data.y)
            zombie:setZ(data.z)
            zombie:setHealth(data.health)
            zombie:setDirectionAngle(data.direction)
            if data.crawling ~= nil then
                zombie:setCrawling(data.crawling)
            end
            if data.health <= 0 then
                table.insert(zombiesToKill, zombie)  -- Collect instead of setting immediately
            end
            if CustomSync.DEBUG then
                print("[CustomSync] Immediate sync applied to zombie " .. data.id)
            end
        end
    end

    -- Set dead after iteration to avoid ConcurrentModificationException
    for _, zombie in ipairs(zombiesToKill) do
        zombie:setDead(true)
    end
end

function CustomSync.applyPlayerSyncImmediate(playerData)
    if not playerData or type(playerData) ~= "table" then return end

    local localPlayer = getPlayer()
    if not localPlayer then return end

    if CustomSync.DEBUG then
        print("[CustomSync] Applying immediate sync for " .. #playerData .. " players")
    end

    local px, py = localPlayer:getX(), localPlayer:getY()

    for _, data in ipairs(playerData) do
        local player = getPlayerByOnlineID(data.id)
        if player and player ~= localPlayer then
            -- Only sync positions within sync distance to avoid ConcurrentModificationException
            if CustomSync.isWithinSyncDistance(px, py, data.x, data.y) then
                player:setX(data.x)
                player:setY(data.y)
                player:setZ(data.z)
                if CustomSync.DEBUG then
                    print("[CustomSync] Immediate sync applied to player " .. data.id)
                end
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

    local vehicleMap = {}
    for i = 0, vehicleList:size() - 1 do
        local veh = vehicleList:get(i)
        if veh then
            vehicleMap[veh:getID()] = veh
        end
    end

    for _, data in ipairs(vehicleData) do
        local vehicle = vehicleMap[data.id]
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

function CustomSync.applyTrailerSync(trailerData)
    if not trailerData or type(trailerData) ~= "table" then return end

    local localPlayer = getPlayer()
    if not localPlayer then return end

    for _, data in ipairs(trailerData) do
        if data and data.id then
            CustomSync.trailerTargets[data.id] = data
        end
    end

    if CustomSync.DEBUG then
        print("[CustomSync] Applying trailer sync targets: " .. #trailerData)
    end
end

function CustomSync.applyInventorySync(inventoryData)
    if not inventoryData or type(inventoryData) ~= "table" then return end

    local localPlayer = getPlayer()
    if not localPlayer then return end

    if CustomSync.DEBUG then
        print("[CustomSync] Applying inventory sync for " .. #inventoryData .. " players")
    end

    for _, data in ipairs(inventoryData) do
        local player = getPlayerByOnlineID(data.id)
        if player and player ~= localPlayer and data.items then
            local signature = data.signature or CustomSync.getInventorySignature(data.items)
            if CustomSync.lastRemoteInventorySignatures[data.id] ~= signature then
                if CustomSync.DEBUG then
                    print("[CustomSync] Updating inventory for player " .. data.id .. " with " .. #data.items .. " items")
                end
                local inventory = player:getInventory()
                inventory:clear()
                CustomSync.deserializeInventory(inventory, data.items, 0)
                CustomSync.lastRemoteInventorySignatures[data.id] = signature
            end
        end
    end
end

function CustomSync.deserializeInventory(inventory, items, depth)
    depth = depth or 0
    if depth > 3 then return end  -- Prevent deep recursion
    for _, itemData in ipairs(items) do
        local item = InventoryItemFactory.CreateItem(itemData.type)
        if item then
            item:setCondition(itemData.condition)
            inventory:addItem(item)
            if itemData.container then
                CustomSync.deserializeInventory(item:getContainer(), itemData.container, depth + 1)
            end
        end
    end
end

local function onContainerUpdate(container)
    if not container then return end
    if not container.getParent then return end
    if not getPlayer then return end
    local player = getPlayer()
    if not player then return end
    local parent = container:getParent()
    local isPlayerContainer = false
    while parent do
        if parent == player then
            isPlayerContainer = true
            break
        end
        if type(parent.getParent) == "function" then
            parent = parent:getParent()
        else
            break
        end
    end
    if isPlayerContainer then
        local inventory = player:getInventory()
        if inventory then
            inventory:setDrawDirty(true)
        end
    end
end

function CustomSync.interpolatePlayers()
    if CustomSync.DEBUG then
        local count = 0
        for _ in pairs(CustomSync.playerTargets) do count = count + 1 end
        print("[CustomSync] Client: Interpolating " .. count .. " players")
    end
    local idsToRemove = {}  -- Marcar IDs a remover para evitar modificar durante iteración

    for id, data in pairs(CustomSync.playerTargets) do
        local player = getPlayerByOnlineID(id)
        if player then
            local cx, cy, cz = player:getX(), player:getY(), player:getZ()
            local dx = data.x - cx
            local dy = data.y - cy
            local dz = data.z - cz
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local shouldInterpolate = true
            if data.animation then
                local anim = tostring(data.animation):lower()
                if string.find(anim, "sit") or string.find(anim, "rest") or string.find(anim, "idle") then
                    shouldInterpolate = false
                end
            end
            if dist > 0.01 and shouldInterpolate and (dist > 0.5 or (data.speed or 0) >= 0.05) then
                local baseSpeed = SandboxVars.CustomSync.InterpolationSpeed or 1.0
                local speed = data.speed and math.min(data.speed * 20, baseSpeed * 2) or baseSpeed -- adjust multiplier for smoothness
                if CustomSync.DEBUG then
                    print("[CustomSync] Client: Using interpolation speed " .. speed .. " for player " .. data.id .. " (base: " .. baseSpeed .. ", calculated speed: " .. (data.speed or "nil") .. ")")
                end
                local moveDist = speed
                if moveDist > dist then moveDist = dist end
                local nx = cx + (dx / dist) * moveDist
                local ny = cy + (dy / dist) * moveDist
                local nz = cz + (dz / dist) * moveDist
                player:setX(nx)
                player:setY(ny)
                player:setZ(nz)
                -- Interpolate direction
                if data.direction then
                    local currentAngle = player:getDirectionAngle()
                    local targetAngle = data.direction
                    local deltaAngle = targetAngle - currentAngle
                    -- Normalize deltaAngle to [-180, 180]
                    while deltaAngle > 180 do deltaAngle = deltaAngle - 360 end
                    while deltaAngle < -180 do deltaAngle = deltaAngle + 360 end
                    local angleDist = math.abs(deltaAngle)
                    if angleDist > 0.01 then
                        local angleMove = speed * 2 -- faster rotation
                        if angleMove > angleDist then angleMove = angleDist end
                        local newAngle = currentAngle + (deltaAngle / angleDist) * angleMove
                        player:setDirectionAngle(newAngle)
                    end
                end
            else
                player:setX(data.x)
                player:setY(data.y)
                player:setZ(data.z)
                if data.direction then
                    player:setDirectionAngle(data.direction)
                end
                if data.health then
                    player:getBodyDamage():setOverallBodyHealth(data.health)
                    if CustomSync.DEBUG then
                        print("[CustomSync] Client: Updated health for player " .. data.id .. " to " .. data.health)
                    end
                end
                if CustomSync.DEBUG then
                    print("[CustomSync] Final sync player " .. data.id .. " set to (" .. data.x .. "," .. data.y .. ")")
                end
                table.insert(idsToRemove, id)  -- Marcar para remover
            end
        else
            -- Player no longer exists, remove target
            table.insert(idsToRemove, id)  -- Marcar para remover
        end
    end

    -- Limpiar después de la iteración
    for _, id in ipairs(idsToRemove) do
        CustomSync.playerTargets[id] = nil
    end
end

function CustomSync.interpolateTrailers()
    local idsToRemove = {}

    for id, data in pairs(CustomSync.trailerTargets) do
        local trailer = getVehicleById(id)
        if trailer then
            local cx, cy, cz = trailer:getX(), trailer:getY(), trailer:getZ()
            local tx, ty, tz = data.x or cx, data.y or cy, data.z or cz

            local towingVehicle = nil
            if data.parentId then
                towingVehicle = getVehicleById(data.parentId)
            end

            if towingVehicle then
                local px, py = towingVehicle:getX(), towingVehicle:getY()
                local minGap = math.max(CustomSync.TRAILER_MIN_GAP or 1.25, (data.hitchDistance or 0) * 0.8)
                local ptx = tx - px
                local pty = ty - py
                local parentDist = math.sqrt(ptx * ptx + pty * pty)

                if parentDist < minGap then
                    local dirX, dirY
                    if parentDist > 0.001 then
                        dirX = ptx / parentDist
                        dirY = pty / parentDist
                    else
                        local angle = getVehicleDirectionAngleSafe(towingVehicle) + 180
                        local rad = math.rad(angle)
                        dirX = math.cos(rad)
                        dirY = math.sin(rad)
                    end
                    tx = px + dirX * minGap
                    ty = py + dirY * minGap
                end
            end

            local dx = tx - cx
            local dy = ty - cy
            local dz = tz - cz
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

            if dist > 0.02 then
                local baseSpeed = SandboxVars.CustomSync.TrailerInterpolationSpeed or CustomSync.TRAILER_INTERPOLATION_SPEED or 0.75
                local speed = baseSpeed
                if data.speed then
                    speed = math.max(baseSpeed, math.min(math.abs(data.speed) / 30, baseSpeed * 2))
                end
                local moveDist = math.min(speed, dist)
                local nx = cx + (dx / dist) * moveDist
                local ny = cy + (dy / dist) * moveDist
                local nz = cz + (dz / dist) * moveDist
                trailer:setX(nx)
                trailer:setY(ny)
                trailer:setZ(nz)
                setVehicleDirectionAngleSafe(trailer, data.direction)
            else
                trailer:setX(tx)
                trailer:setY(ty)
                trailer:setZ(tz)
                setVehicleDirectionAngleSafe(trailer, data.direction)
                table.insert(idsToRemove, id)
            end
        else
            table.insert(idsToRemove, id)
        end
    end

    for _, id in ipairs(idsToRemove) do
        CustomSync.trailerTargets[id] = nil
    end
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnContainerUpdate.Add(onContainerUpdate)

Events.OnTick.Add(CustomSync.interpolatePlayers)
Events.OnTick.Add(CustomSync.interpolateTrailers)
