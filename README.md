# Custom Sync

A Project Zomboid mod for Build 42 that provides comprehensive multiplayer synchronization for players, zombies, vehicles, inventories, and appearances to fix desync issues.

## Steam Workshop

Download from Steam Workshop: [Custom Sync](https://steamcommunity.com/sharedfiles/filedetails/?id=3646815505)

## Features

- **Player Synchronization**: Syncs player positions, health, and animations across clients.
- **Zombie Synchronization**: Syncs zombie positions, health, and states within sync distance.
- **Vehicle Synchronization**: Syncs vehicle positions, speed, and health within sync distance.
- **Inventory Synchronization**: Syncs player inventories, including nested containers (bags, keyrings), in real-time on changes.
- **Appearance Synchronization**: Syncs player clothing and equipped items in real-time on equip/unequip.
- **Event-Driven Sync**: Inventories and appearances sync immediately when items are added/removed or equipped/unequipped, reducing network load.
- **Death Sync**: Ensures inventories and appearances are synced before player death to prevent item loss.
- **Configurable Options**: Adjustable update interval, sync distance via sandbox menu.
- **Optimizations**: Filters entities by distance and uses event-based updates to reduce server/client load and network traffic.
- **Dynamic Updates**: Sandbox options can be changed in-game without server restart.
- **Debug Logging**: Optional debug prints for troubleshooting sync events.

## Installation

1. Subscribe to the mod on Steam Workshop or download the files manually.
2. The mod will be installed automatically in Project Zomboid.
3. Ensure the mod is enabled in the server settings or via the in-game mod menu.
4. Restart the server or reload mods.

### Requirements
- Project Zomboid Build 42
- Multiplayer server setup

## Configuration

The mod uses sandbox options for configuration. Access via the server admin menu or `media/sandbox-options.txt`.

- **UpdateInterval** (default: 600 ticks ~10 seconds): Frequency of basic synchronization updates (players, zombies, vehicles). Lower values increase sync accuracy but may impact performance.
- **SyncDistance** (default: 50 squares): Maximum distance for syncing zombies and vehicles. Entities beyond this distance are not synchronized.

Changes to these options take effect dynamically in-game without restarting the server.

## Usage

- Install and enable the mod on your server.
- Adjust settings as needed via the sandbox menu.
- The mod runs automatically:
  - Basic sync (positions) every update interval.
  - Inventory and appearance sync in real-time on changes.
- Enable debug logs in `shared.lua` by setting `DEBUG = true` to monitor sync events.
- Test by moving items, equipping/unequipping clothing, and checking if other players see the changes immediately.

## Bug Fixes

This mod addresses common multiplayer desync issues:
- Incomplete clothing appearance for other players.
- Items disappearing from bags when a player dies.
- Keys not appearing in keyrings until dropped and picked up again.

## Known Issues

- High player counts or large sync distances may still cause performance issues on low-end servers.
- Deeply nested containers (>3 levels) are not synced to prevent recursion issues.
- Appearance sync may not cover all visual aspects if not triggered by container updates.

## Contributing

Feel free to submit issues or pull requests on GitHub.

## Credits

Based on the original "Custom Sync" mod by the PZ community. Optimized for Build 42.

## License

This mod is released under the MIT License. Use at your own risk.
