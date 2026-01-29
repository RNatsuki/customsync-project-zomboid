CustomSync = {}

CustomSync.MOD_ID = "CustomSync"
-- Intervalo reducido para sync más frecuente, con throttling para evitar lag
CustomSync.UPDATE_INTERVAL = 30 -- ticks between updates (reduced for better sync)
CustomSync.SYNC_DISTANCE = 100 -- squares to sync (increased for better coverage)
CustomSync.SYNC_DISTANCE_PLAYERS = 200 -- squares to sync players for map visibility
CustomSync.SYNC_DISTANCE_ZOMBIES = 100 -- squares to sync zombies for consistency
CustomSync.SYNC_DISTANCE_VEHICLES = 140 -- squares to sync vehicles/trailers
CustomSync.MIN_MOVE_DISTANCE = 1.0 -- Minimum distance to trigger sync (throttling)
CustomSync.MAX_ZOMBIES = 100 -- Hard cap of zombies to broadcast to keep packets light
CustomSync.ZOMBIE_STALE_TICKS = 600 -- Remove inactive zombie entries after this many ticks
CustomSync.IMMEDIATE_COOLDOWN_TICKS = 5 -- Throttle repeated immediate syncs for same entity
CustomSync.PLAYER_TARGET_STALE_TICKS = 180 -- Drop interpolation targets if no updates arrive
CustomSync.PLAYER_SNAP_DISTANCE = 4.0 -- Snap instead of interpolate when too far apart
CustomSync.VEHICLE_SNAP_DISTANCE = 8.0 -- Snap vehicle/trailer positions when far apart
CustomSync.VEHICLE_INTERP_SPEED = 1.5 -- Base interpolation speed for vehicles
CustomSync.DEBUG = false -- Set to false to disable debug logging

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
