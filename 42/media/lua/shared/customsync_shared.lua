CustomSync = {}

CustomSync.MOD_ID = "CustomSync"
-- Si se pone el intervalo en valores proximos a 1 los zombies no avanzan y se hacen tp hacia atras constantemente
CustomSync.UPDATE_INTERVAL = 600 -- ticks between updates (default)
CustomSync.SYNC_DISTANCE = 50 -- squares to sync (default)
CustomSync.DEBUG = true -- Set to false to disable debug logging

-- Commands
CustomSync.COMMAND_SYNC_PLAYERS = "syncPlayers"
CustomSync.COMMAND_SYNC_ZOMBIES = "syncZombies"
CustomSync.COMMAND_SYNC_VEHICLES = "syncVehicles"
CustomSync.COMMAND_SYNC_INVENTORIES = "syncInventories"

-- Helper functions
function CustomSync.getDistanceSq(x1, y1, x2, y2)
    return (x1 - x2)^2 + (y1 - y2)^2
end

function CustomSync.isWithinSyncDistance(x1, y1, x2, y2)
    return CustomSync.getDistanceSq(x1, y1, x2, y2) <= CustomSync.SYNC_DISTANCE^2
end
