## Changelog

### v1.2.1 - January 17, 2026
- **Server Startup Crash Fix**: Added safety checks to prevent NullPointerException when sending server commands during world initialization before udpEngine is available.

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
