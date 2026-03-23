CustomSync = {}

CustomSync.MOD_ID = "CustomSync"
-- Intervalo reducido para sync más frecuente, con throttling para evitar lag
CustomSync.UPDATE_INTERVAL = 30 -- ticks between updates (reduced for better sync)
CustomSync.SYNC_DISTANCE = 100 -- squares to sync (increased for better coverage)
CustomSync.SYNC_DISTANCE_PLAYERS = 200 -- squares to sync players for map visibility
CustomSync.SYNC_DISTANCE_ZOMBIES = 100 -- squares to sync zombies for consistency
CustomSync.MIN_MOVE_DISTANCE = 1.0 -- Minimum distance to trigger sync (throttling)
CustomSync.ZOMBIE_IMMEDIATE_COOLDOWN = 5 -- ticks to throttle immediate zombie sync spam
CustomSync.PLAYER_DELTA_EPSILON = 0.02 -- minimum movement delta before rebroadcasting a player
CustomSync.VEHICLE_DELTA_EPSILON = 0.05 -- minimum movement delta before rebroadcasting a vehicle
CustomSync.TRAILER_INTERPOLATION_SPEED = 0.75 -- client interpolation speed for trailer correction
CustomSync.TRAILER_MIN_GAP = 1.25 -- minimum desired distance between towing vehicle and trailer
CustomSync.ZOMBIE_UPDATE_THROTTLE = 10 -- ticks between per-zombie onZombieUpdate checks (reduces O(zombies*players) per tick)
CustomSync.COLLISION_COOLDOWN = 30 -- ticks between collision sync events per player (prevents horde spam)
CustomSync.MAX_ACTIVE_ZOMBIES_FACTOR = 1.5 -- cap activeZombies at MAX_ZOMBIES * this factor
CustomSync.DEBUG = false -- Set to false to disable debug logging

-- Commands
CustomSync.COMMAND_SYNC_PLAYERS = "syncPlayers"
CustomSync.COMMAND_SYNC_ZOMBIES = "syncZombies"
CustomSync.COMMAND_SYNC_VEHICLES = "syncVehicles"
CustomSync.COMMAND_SYNC_TRAILERS = "syncTrailers"
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
CustomSync.lastBroadcastPlayers = {}
CustomSync.lastBroadcastVehicles = {}
CustomSync.lastTrailerPositions = {}
CustomSync.lastInventorySignatures = {}
CustomSync.lastRemoteInventorySignatures = {}
CustomSync.lastImmediateZombieSyncTick = {}
CustomSync.lastZombieUpdateTick = {} -- per-zombie tick for onZombieUpdate throttle
CustomSync.lastCollisionSyncTick = {} -- per-player tick for collision cooldown
CustomSync.activeZombies = {}
