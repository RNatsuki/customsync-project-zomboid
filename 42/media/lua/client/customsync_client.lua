require "CustomSync"

print("[CustomSync] Client script loaded")

CustomSync.playerTargets = {}

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

    for _, data in ipairs(playerData) do
        local player = getPlayerByOnlineID(data.id)
        if player and player ~= localPlayer then -- Don't sync self
            -- Only sync if within distance
            local px, py = localPlayer:getX(), localPlayer:getY()
            if CustomSync.isWithinSyncDistance(px, py, data.x, data.y) then
                -- Store target for interpolation
                CustomSync.playerTargets[data.id] = data
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
            if CustomSync.isWithinSyncDistance(px, py, data.x, data.y) then
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

    for _, data in ipairs(playerData) do
        local player = getPlayerByOnlineID(data.id)
        if player and player ~= localPlayer then
            local px, py = localPlayer:getX(), localPlayer:getY()
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
    for id, data in pairs(CustomSync.playerTargets) do
        local player = getPlayerByOnlineID(id)
        if player then
            local cx, cy, cz = player:getX(), player:getY(), player:getZ()
            local dx = data.x - cx
            local dy = data.y - cy
            local dz = data.z - cz
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist > 0.01 then
                local speed = SandboxVars.CustomSync.InterpolationSpeed or 0.2 -- adjust for smoothness
                local moveDist = speed
                if moveDist > dist then moveDist = dist end
                local nx = cx + (dx / dist) * moveDist
                local ny = cy + (dy / dist) * moveDist
                local nz = cz + (dz / dist) * moveDist
                player:setX(nx)
                player:setY(ny)
                player:setZ(nz)
            else
                player:setX(data.x)
                player:setY(data.y)
                player:setZ(data.z)
                if CustomSync.DEBUG then
                    print("[CustomSync] Final sync player " .. data.id .. " set to (" .. data.x .. "," .. data.y .. ")")
                end
                CustomSync.playerTargets[id] = nil
            end
        else
            -- Player no longer exists, remove target
            CustomSync.playerTargets[id] = nil
        end
    end
end

-- Removed interpolateZombies to fix hit registration
    local cell = getCell()
    if not cell then return end
    local zombieList = cell:getZombieList()
    if not zombieList then return end

    for id, data in pairs(CustomSync.zombieTargets) do
        for i = 0, zombieList:size() - 1 do
            local zombie = zombieList:get(i)
            if zombie and zombie:getOnlineID() == id then
                local cx, cy, cz = zombie:getX(), zombie:getY(), zombie:getZ()
                local dx = data.x - cx
                local dy = data.y - cy
                local dz = data.z - cz
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                if dist > 0.01 then
                    local speed = SandboxVars.CustomSync.InterpolationSpeed or 0.2 -- adjust for smoothness
                    local moveDist = speed
                    if moveDist > dist then moveDist = dist end
                    local nx = cx + (dx / dist) * moveDist
                    local ny = cy + (dy / dist) * moveDist
                    local nz = cz + (dz / dist) * moveDist
                    zombie:setX(nx)
                    zombie:setY(ny)
                    zombie:setZ(nz)
                else
                    zombie:setX(data.x)
                    zombie:setY(data.y)
                    zombie:setZ(data.z)
                    zombie:setHealth(data.health)
                    -- zombie:setCrawler(data.crawling or false)  -- Commented out as getter not available in Lua
                    zombie:setDirectionAngle(data.direction)
                    if CustomSync.DEBUG then
                        print("[CustomSync] Final sync zombie " .. data.id .. " set to (" .. data.x .. "," .. data.y .. ") health:" .. data.health .. " direction:" .. data.direction)
                    end
                    CustomSync.zombieTargets[id] = nil
                end
                break
            end
        end
    end
Events.OnServerCommand.Add(onServerCommand)
Events.OnContainerUpdate.Add(onContainerUpdate)

Events.OnTick.Add(CustomSync.interpolatePlayers)
