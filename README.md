# LootMonitor

A sleek and customizable loot notification addon for Turtle WoW (1.12.1) that displays fading notifications with real item icons when you loot items or coins.

![LootMonitor Demo](https://raw.githubusercontent.com/Wiggen94/lootmonitor/refs/heads/main/images/image.png)

![WoW Version](https://img.shields.io/badge/WoW-1.12.1-blue) ![Turtle WoW](https://img.shields.io/badge/Turtle%20WoW-Compatible-green) ![License](https://img.shields.io/badge/License-MIT-yellow) ![Version](https://img.shields.io/badge/Version-2.0-orange)

## ✨ Features

### 🎯 Core Functionality
- **Real-time Loot Detection** — Automatically detects when you loot items or coins
- **Authentic Item Icons** — Shows actual game icons by searching your bags
- **Coin Support** — Displays copper, silver, and gold coins with proper icons
- **Smart Stacking** — Multiple identical items show as "Item Name x3"
- **Quality Colors** — Items display in their proper quality colors (white/green/blue/purple/orange)

### 🎨 Visual Polish
- **Animation Styles** — Choose from fade, slide, or bounce animations
- **Quest Item Glow** — Optional yellow pulsing glow around quest item notifications
- **Compact Design** — Clean, non-intrusive notifications
- **Customizable Positioning** — Drag and drop to reposition anywhere on screen
- **Scalable** — Resize notifications from 50% to 200%

### 🎛️ Smart Filtering
- **Quality Filter** — Show only items of certain quality tiers (e.g. hide all gray/white loot)
- **Minimum Quality** — Set a threshold, only show items at or above that quality
- **Blacklist** — Hide specific items you never want to see
- **Whitelist** — Always show specific items, overriding all other filters

### 📊 History & Statistics
- **Loot History** — Tracks all looted items with timestamps (configurable size, default 100)
- **Session Stats** — Keeps count of total items looted this session
- **Total Count Display** — Shows how many of a looted item you have in your bags

### 🖱️ Click Interactions
- **Hover for Tooltip** — Mouse over a notification to see the item tooltip
- **Click to Link** — Click a notification to insert the item link into chat
- **Minimap Button** — Draggable minimap button for quick settings access with session stats tooltip

### ⚙️ Settings Panel
- GUI accessible via `/lm` or `/lootmonitor`
- Timing controls (fade in, display duration, fade out)
- Animation style selection
- Quality filter configuration
- Blacklist/whitelist management

## 📥 Installation

1. Download the latest release from [GitHub](https://github.com/Wiggen94/lootmonitor)
2. Extract the `LootMonitor` folder to your `Interface/AddOns/` directory
3. Restart WoW or reload UI (`/reload`)

The folder structure should be:
```
Interface/AddOns/LootMonitor/
├── LootMonitor.lua
├── LootMonitor.toc
└── README.md
```

## 🎮 Usage

### Commands
| Command | Description |
|---------|-------------|
| `/lm` or `/lootmonitor` | Open settings panel |
| `/lm toggle` | Toggle notifications on/off |
| `/lm clear` | Clear active notifications |
| `/lm test` | Create test notification |
| `/lm move` | Enter move mode to reposition |
| `/lm settings` | Open settings panel |
| `/lm help` | Show all commands |

### Settings
Access via `/lm` to customize:
- **Enable/Disable** — Toggle notifications
- **Scale** (0.5x–2.0x) — Resize notifications
- **Fade In Time** (0.1s–2.0s)
- **Display Time** (1.0s–10.0s)
- **Fade Out Time** (0.5s–3.0s)
- **Animation Style** — fade, slide, or bounce
- **Quest Item Glow** — Toggle glow effect for quest items
- **Show Total Count** — Show bag count alongside notification

## 📋 Changelog

### Version 2.0
- **Quality Filtering** — Filter notifications by item quality tiers
- **Blacklist/Whitelist** — Hide junk, always show valuables
- **Loot History** — Persistent tracking of all looted items
- **Session Stats** — Items looted counter
- **Click Interactions** — Hover tooltip + click to link in chat
- **Minimap Button** — Draggable quick access with stats tooltip
- **Animation Styles** — Fade, slide, and bounce
- **Performance** — Local references, precompiled patterns, API caching

### Version 1.1
- Quest item glow effect
- Total count display
- Redesigned settings panel
- Enhanced reset functionality

### Version 1.0
- Initial release — fading loot notifications with item icons

## 🔧 Technical Details

### Compatibility
- **WoW Version**: Turtle WoW (1.12.1)
- **Dependencies**: None

### Events Monitored
- `CHAT_MSG_LOOT` — Item loot detection
- `CHAT_MSG_MONEY` — Coin loot detection  
- `CHAT_MSG_SYSTEM` — System loot messages
- `ADDON_LOADED` — Initialization
- `PLAYER_LOGOUT` — Save position on logout

### Performance
- Local references for all string/table/math functions (Lua 5.0 optimization)
- Precompiled regex patterns
- Rate limiting on message processing
- OnUpdate frame cap to prevent resource exhaustion
- Automatic cleanup of old notifications and history entries

## 🎯 Inspiration

This addon was inspired by the [LootDisplay WeakAura](https://wago.io/4omJVmrNs) but built for Turtle WoW compatibility.

## 🤝 Contributing

Contributions are welcome. Please:
- Report bugs via [GitHub Issues](https://github.com/Wiggen94/lootmonitor/issues)
- Suggest features or improvements
- Submit pull requests

## 📄 License

MIT — See [LICENSE](LICENSE) for details.

## 📞 Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/Wiggen94/lootmonitor/issues)
- **Turtle WoW Forums**: [Forum post](https://forum.turtle-wow.org/viewtopic.php?t=19918)
- **Discord**: Find me on the Turtle WoW Discord

---

**Enjoy your enhanced looting experience! 🎉**
