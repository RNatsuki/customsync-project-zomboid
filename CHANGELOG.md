## Changelog

### v1.3.2 - January 18, 2026
- **Dynamic Speed Calculation**: Replaced static moveSpeed with calculated speed based on actual position changes per sync interval, allowing interpolation to adapt to real player movement velocity for smoother syncing.
- **Error Handling**: Added type checks and pcall for position calculations to prevent crashes with invalid or corrupted data.

### v1.3.1 - January 18, 2026
- **Improved Player Synchronization**: Added distance check to only interpolate player positions within 50 squares, preventing sudden teleportation from distant locations.
- **Enhanced Interpolation Speed**: Increased default interpolation speed from 0.2 to 0.5 for smoother and more responsive player movements.
- **Direction Synchronization**: Added real-time sync and interpolation for player direction angles, ensuring smooth rotations and better visual consistency.
- **Angular Interpolation**: Implemented normalized angular interpolation for directions, handling wrap-around at 360 degrees for seamless turning.
- **Dynamic Interpolation Based on Movement Speed**: Adjusted interpolation speed dynamically based on the player's current movement speed for more accurate and responsive syncing.
- **Health Synchronization**: Added health sync to ensure player health states are updated when reaching sync targets, maintaining consistency across clients.

### v1.3.0 - January 17, 2026
- **Global Player Position Sync for Maps**: Removed distance restrictions for player synchronization to ensure all players appear on maps regardless of location, improving visibility in world maps and minimaps.
- **Enhanced Zombie Consistency**: Implemented an active zombie database on the server to track nearby zombies, updating positions in real-time and removing dead or distant ones, ensuring all clients see zombies in the same locations.
- **Increased Zombie Sync Distance and Frequency**: Raised zombie sync distance to 100 squares and reduced update interval to 60 ticks for better consistency and responsiveness.
- **Optimized Zombie Sync Limits**: Increased default maximum zombies per sync from 50 to 100 for broader coverage.
- **Player Sync Distance for Maps**: Added SYNC_DISTANCE_PLAYERS (200 squares) for extended player visibility on maps without affecting physical movement limits.

### v1.2.1 - January 17, 2026
- **Server Startup Crash Fix**: Added safety checks to prevent NullPointerException when sending server commands during world initialization before GameServer and udpEngine are available.

### v1.2.0 - January 16, 2026
- **Improved Zombie Damage and Death Handling**: Fixed issues with hits not registering and zombies dying improperly. Removed zombie interpolation to ensure accurate positions, preventing desync during attacks.
- **Crawling State Synchronization**: Added real-time sync for zombie crawling state to maintain correct hitboxes and positions for downed zombies.
- **Immediate Sync on State Changes**: Implemented OnZombieUpdate for instant sync when zombie health or crawling state changes, reducing lag and improving responsiveness.
- **Death Sync Enhancements**: Added OnZombieDead event for immediate sync on zombie death, and setDead() in client to ensure proper death animations.
- **Optimized Sync for Crawling Zombies**: Crawling zombies now sync without throttling for precise positioning, fixing issues with stomping or hitting downed zombies.
- **Performance Improvements**: Added distance checks in OnZombieUpdate and table cleanup for dead zombies to reduce memory usage and network traffic.
- **Bug Fixes**: Resolved zombie revival, duplicate bodies, and "hitting air" issues by improving sync timing and state management.

### v1.1.0 - Initial Release
- Basic sync for players, zombies, vehicles, and inventories.
- Configurable settings via sandbox menu.
- Distance-based filtering for performance.
