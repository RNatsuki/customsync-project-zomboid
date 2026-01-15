# Custom Sync Optimizer

A Project Zomboid mod for Build 42 that optimizes multiplayer synchronization to reduce desync issues in player, zombie, and vehicle positions.

## Features

- **Player Synchronization**: Syncs player positions, health, and animations across clients.
- **Zombie Synchronization**: Syncs zombie positions, health, and states within sync distance.
- **Vehicle Synchronization**: Syncs vehicle positions, speed, and health within sync distance.
- **Vehicle Respawn**: Automatically respawns players in their vehicles after disconnect/reconnect (configurable).
- **Configurable Options**: Adjustable update interval, sync distance, and vehicle respawn toggle via sandbox menu.
- **Optimizations**: Filters entities by distance to reduce server/client load and network traffic.
- **Dynamic Updates**: Sandbox options can be changed in-game without server restart.

## Installation

1. Download the mod files.
2. Place the `customsync` folder in your Project Zomboid mods directory (e.g., `Zomboid/mods/`).
3. Ensure the mod is enabled in the server settings or via the in-game mod menu.
4. Restart the server or reload mods.

### Requirements
- Project Zomboid Build 42
- Multiplayer server setup

## Configuration

The mod uses sandbox options for configuration. Access via the server admin menu or `media/sandbox-options.txt`.

- **UpdateInterval** (default: 600 ticks ~10 seconds): Frequency of synchronization updates. Lower values increase sync accuracy but may impact performance.
- **SyncDistance** (default: 50 squares): Maximum distance for syncing zombies and vehicles. Entities beyond this distance are not synchronized.
- **EnableVehicleRespawn** (default: true): Enables automatic vehicle respawn on player reconnect.

Changes to these options take effect dynamically in-game without restarting the server.

## Usage

- Install and enable the mod on your server.
- Adjust settings as needed via the sandbox menu.
- The mod runs automatically, syncing entities on each update interval.
- Debug logs can be enabled in `shared.lua` by setting `DEBUG = true`.

## Known Issues

- Vehicle seat detection may default to seat 0 if `getSeat()` fails.
- High player counts or large sync distances may still cause performance issues on low-end servers.

## Contributing

Feel free to submit issues or pull requests on GitHub.

## Credits

Based on the original "Custom Sync" mod by the PZ community. Optimized for Build 42.

## License

This mod is released under the MIT License. Use at your own risk.
