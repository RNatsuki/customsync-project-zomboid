require "CustomSync"

if CustomSync.DEBUG then print("[CustomSync] Client script loaded") end

CustomSync.playerTargets = {}
CustomSync.vehicleTargets = CustomSync.vehicleTargets or {}
CustomSync.clientTick = CustomSync.clientTick or 0

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
    elseif command == CustomSync.COMMAND_SYNC_INVENTORIES then
        CustomSync.applyInventorySync(args)
    elseif command == CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE then
        CustomSync.applyZombieSyncImmediate(args)
    elseif command == CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE then
        CustomSync.applyPlayerSyncImmediate(args)
    end
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
            -- Store target for interpolation and map visibility (always, for global map visibility)
            data.receivedTick = CustomSync.clientTick or 0
            CustomSync.playerTargets[data.id] = data
            if CustomSync.DEBUG then
                print("[CustomSync] Client: Storing interpolation target for player " .. data.id .. " at (" .. data.x .. "," .. data.y .. ") speed: " .. (data.speed or "nil") .. " animation: " .. (data.animation or "nil"))
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

    local zombiesToKill = {}  -- Collect zombies to set dead after iteration

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

    local zombiesToKill = {}  -- Collect zombies to set dead after iteration

    for _, data in ipairs(zombieData) do
        for i = 0, zombieList:size() - 1 do
            local zombie = zombieList:get(i)
            if zombie and zombie:getOnlineID() == data.id then
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
                break
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

    local currentTick = CustomSync.clientTick or 0

    for _, data in ipairs(vehicleData) do
        data.receivedTick = currentTick
        CustomSync.vehicleTargets[data.id] = data
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
            if CustomSync.DEBUG then
                print("[CustomSync] Updating inventory for player " .. data.id .. " with " .. #data.items .. " items")
            end
            local inventory = player:getInventory()
            inventory:clear()
            CustomSync.deserializeInventory(inventory, data.items, 0)
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
    CustomSync.clientTick = (CustomSync.clientTick or 0) + 1
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
            local age = (CustomSync.clientTick or 0) - (data.receivedTick or 0)
            local staleWindow = CustomSync.PLAYER_TARGET_STALE_TICKS or 180
            if age > staleWindow then
                table.insert(idsToRemove, id)
            else
                local shouldInterpolate = true
                if data.animation then
                    local anim = tostring(data.animation):lower()
                    if string.find(anim, "sit") or string.find(anim, "rest") or string.find(anim, "idle") then
                        shouldInterpolate = false
                    end
                end
                local snapDistance = CustomSync.PLAYER_SNAP_DISTANCE or 4.0
                if dist >= snapDistance then
                    player:setX(data.x)
                    player:setY(data.y)
                    player:setZ(data.z)
                    if data.direction then
                        player:setDirectionAngle(data.direction)
                    end
                    if data.health then
                        player:getBodyDamage():setOverallBodyHealth(data.health)
                    end
                    table.insert(idsToRemove, id)
                elseif dist > 0.01 and shouldInterpolate and (dist > 0.5 or (data.speed or 0) >= 0.05) and dist <= CustomSync.SYNC_DISTANCE then
                    local baseSpeed = SandboxVars.CustomSync.InterpolationSpeed or 1.0
                    local ageFactor = math.max(0.4, 1 - (age / staleWindow))
                    local speed = data.speed and math.min(data.speed * 20, baseSpeed * 2) or baseSpeed
                    speed = speed * ageFactor -- slow down if the data is old to reduce rubber-banding
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
                    if data.direction then
                        local currentAngle = player:getDirectionAngle()
                        local targetAngle = data.direction
                        local deltaAngle = targetAngle - currentAngle
                        while deltaAngle > 180 do deltaAngle = deltaAngle - 360 end
                        while deltaAngle < -180 do deltaAngle = deltaAngle + 360 end
                        local angleDist = math.abs(deltaAngle)
                        if angleDist > 0.01 then
                            local angleMove = speed * 2
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

function CustomSync.interpolateVehicles()
    local cell = getCell()
    if not cell then return end
    local vehicleList = cell:getVehicles()
    if not vehicleList then return end

    local vehicleById = {}
    for i = 0, vehicleList:size() - 1 do
        local veh = vehicleList:get(i)
        if veh then
            vehicleById[veh:getID()] = veh
        end
    end

    local idsToRemove = {}
    local snapDistance = CustomSync.VEHICLE_SNAP_DISTANCE or 8.0
    local interpSpeed = CustomSync.VEHICLE_INTERP_SPEED or 1.5
    local staleWindow = CustomSync.PLAYER_TARGET_STALE_TICKS or 180
    local tick = CustomSync.clientTick or 0

    for id, data in pairs(CustomSync.vehicleTargets) do
        local vehicle = vehicleById[id]
        if vehicle then
            local vx, vy, vz = vehicle:getX(), vehicle:getY(), vehicle:getZ()
            local dx = data.x - vx
            local dy = data.y - vy
            local dz = data.z - vz
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local age = tick - (data.receivedTick or 0)

            if age > staleWindow then
                table.insert(idsToRemove, id)
            elseif dist >= snapDistance then
                vehicle:setX(data.x)
                vehicle:setY(data.y)
                vehicle:setZ(data.z)
                if data.angle then
                    pcall(function() vehicle:setAngleZ(data.angle) end)
                end
                table.insert(idsToRemove, id)
            elseif dist > 0.05 then
                local moveDist = interpSpeed + math.abs(data.speed or 0) * 0.02
                if moveDist > dist then moveDist = dist end
                local nx = vx + (dx / dist) * moveDist
                local ny = vy + (dy / dist) * moveDist
                local nz = vz + (dz / dist) * moveDist
                vehicle:setX(nx)
                vehicle:setY(ny)
                vehicle:setZ(nz)
                if data.angle then
                    pcall(function()
                        local current = vehicle:getAngleZ()
                        local delta = data.angle - current
                        while delta > math.pi do delta = delta - math.pi * 2 end
                        while delta < -math.pi do delta = delta + math.pi * 2 end
                        local angleMove = moveDist * 0.05
                        if angleMove > math.abs(delta) then angleMove = math.abs(delta) end
                        local newAngle = current + (delta >= 0 and angleMove or -angleMove)
                        vehicle:setAngleZ(newAngle)
                    end)
                end
            else
                vehicle:setX(data.x)
                vehicle:setY(data.y)
                vehicle:setZ(data.z)
                if data.angle then
                    pcall(function() vehicle:setAngleZ(data.angle) end)
                end
                table.insert(idsToRemove, id)
            end
        else
            table.insert(idsToRemove, id)
        end
    end

    for _, id in ipairs(idsToRemove) do
        CustomSync.vehicleTargets[id] = nil
    end
end
Events.OnServerCommand.Add(onServerCommand)
Events.OnContainerUpdate.Add(onContainerUpdate)

Events.OnTick.Add(CustomSync.interpolatePlayers)
Events.OnTick.Add(CustomSync.interpolateVehicles)
