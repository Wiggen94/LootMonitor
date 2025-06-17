# LootMonitor

A sleek and customizable loot notification addon for Turtle WoW that displays fading notifications with real item icons when you loot items or coins.

![LootMonitor Demo](https://raw.githubusercontent.com/Wiggen94/lootmonitor/refs/heads/main/images/image.png)

![LootMonitor Demo](https://img.shields.io/badge/WoW-1.12.1-blue) ![Turtle WoW](https://img.shields.io/badge/Turtle%20WoW-Compatible-green) ![License](https://img.shields.io/badge/License-MIT-yellow)

## ✨ Features

### 🎯 Core Functionality
- **Real-time Loot Detection** - Automatically detects when you loot items or coins
- **Authentic Item Icons** - Shows actual game icons by searching your bags
- **Coin Support** - Displays copper, silver, and gold coins with proper icons
- **Smart Stacking** - Multiple identical items show as "Item Name x3"
- **Fallback Icons** - Intelligent icon system for items not found in bags

### 🎨 Visual Polish
- **Smooth Animations** - Fade in → Display → Fade out with scaling effects
- **Quality Colors** - Items display in their proper quality colors
- **Compact Design** - Clean, non-intrusive notifications
- **Customizable Positioning** - Drag and drop to reposition anywhere on screen

### ⚙️ Full Customization
- **Settings Panel** - Easy-to-use GUI for all options
- **Timing Controls** - Adjust fade in, display, and fade out times
- **Scale Options** - Resize notifications from 50% to 200%
- **Toggle On/Off** - Quick enable/disable functionality

## 📥 Installation

### Method 1: Download from GitHub
1. Download the latest release from [GitHub](https://github.com/Wiggen94/lootmonitor)
2. Extract the `LootMonitor` folder to your `Interface/AddOns/` directory
3. Restart WoW or reload UI (`/reload`)

### Method 2: Manual Installation
1. Clone or download this repository
2. Copy the `LootMonitor` folder to:
   ```
   World of Warcraft/Interface/AddOns/LootMonitor/
   ```
3. Ensure the folder structure looks like:
   ```
   Interface/AddOns/LootMonitor/
   ├── LootMonitor.lua
   └── LootMonitor.toc
   ```

## 🎮 Usage

### Quick Start
- Type `/lm` to open the settings panel
- Click "Test" to see a sample notification
- Click "Move" to reposition notifications
- Adjust timing and scale to your preference

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

### Settings Panel
Access via `/lm` to customize:
- **Enable/Disable** - Toggle notifications
- **Scale** (0.5x - 2.0x) - Resize notifications
- **Fade In Time** (0.1s - 2.0s) - Animation speed
- **Display Time** (1.0s - 10.0s) - How long notifications stay
- **Fade Out Time** (0.5s - 3.0s) - Fade out speed

## 🔧 Technical Details

### Compatibility
- **WoW Version**: Turtle WoW
- **Dependencies**: None

### Events Monitored
- `CHAT_MSG_LOOT` - Item loot detection
- `CHAT_MSG_MONEY` - Coin loot detection
- `ADDON_LOADED` - Initialization

### Performance
- Lightweight and efficient
- Asynchronous bag searching (0.1s delay)
- Automatic cleanup of old notifications
- Minimal memory footprint

## 🎯 Inspiration

This addon was inspired by the [LootDisplay WeakAura](https://wago.io/4omJVmrNs) but built for Turtle WoW compatibility.

## 🐛 Known Issues

- None currently reported

## 🤝 Contributing

Contributions are welcome! Please feel free to:
- Report bugs via GitHub Issues
- Suggest new features
- Submit pull requests
- Improve documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 📞 Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/Wiggen94/lootmonitor/issues)
- **Turtle WoW Forums**: [Post in the forum post](https://forum.turtle-wow.org/viewtopic.php?t=19918)
- **Discord**: Find me on the Turtle WoW Discord

---

**Enjoy your enhanced looting experience! 🎉** 
