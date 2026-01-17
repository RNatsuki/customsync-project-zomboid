CustomSync = {}

CustomSync.MOD_ID = "CustomSync"
-- Intervalo reducido para sync más frecuente, con throttling para evitar lag
CustomSync.UPDATE_INTERVAL = 60 -- ticks between updates (reduced for better sync)
CustomSync.SYNC_DISTANCE = 50 -- squares to sync (default)
CustomSync.SYNC_DISTANCE_PLAYERS = 200 -- squares to sync players for map visibility
CustomSync.SYNC_DISTANCE_ZOMBIES = 100 -- squares to sync zombies for consistency
CustomSync.MIN_MOVE_DISTANCE = 1.0 -- Minimum distance to trigger sync (throttling)
CustomSync.DEBUG = true -- Set to false to disable debug logging

-- Commands
CustomSync.COMMAND_SYNC_PLAYERS = "syncPlayers"
CustomSync.COMMAND_SYNC_ZOMBIES = "syncZombies"
CustomSync.COMMAND_SYNC_VEHICLES = "syncVehicles"
CustomSync.COMMAND_SYNC_INVENTORIES = "syncInventories"
CustomSync.COMMAND_SYNC_ZOMBIES_IMMEDIATE = "syncZombiesImmediate"
CustomSync.COMMAND_SYNC_PLAYERS_IMMEDIATE = "syncPlayersImmediate"

-- Helper functions
function CustomSync.getDistanceSq(x1, y1, x2, y2)
    return (x1 - x2)^2 + (y1 - y2)^2
end

function CustomSync.isWithinSyncDistance(x1, y1, x2, y2)
    return CustomSync.getDistanceSq(x1, y1, x2, y2) <= CustomSync.SYNC_DISTANCE^2
end

function CustomSync.isWithinSyncDistancePlayers(x1, y1, x2, y2)
    return CustomSync.getDistanceSq(x1, y1, x2, y2) <= CustomSync.SYNC_DISTANCE_PLAYERS^2
end

function CustomSync.isWithinSyncDistanceZombies(x1, y1, x2, y2)
    return CustomSync.getDistanceSq(x1, y1, x2, y2) <= CustomSync.SYNC_DISTANCE_ZOMBIES^2
end

CustomSync.lastZombiePositions = {}
CustomSync.lastPlayerPositions = {}
CustomSync.activeZombies = {}
