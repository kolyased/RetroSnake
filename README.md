# RetroSnake

RetroSnake is a classic Snake game for iPhone built with Swift and SpriteKit.

The project focuses on a simple retro arcade experience: a dark screen, neon green board, pixel-style snake, score tracking, pause menu, settings, sound, and English/Russian UI language switching.

## Features

- Classic Snake gameplay on a grid
- Portrait iPhone-first layout
- Main menu with best score
- Pause overlay with Continue, Settings, Restart, and Main Menu
- Game Over screen with score, best score, restart, and main menu
- Swipe controls and on-screen arrow buttons
- Sound settings with ON/OFF toggle and volume from 1 to 10
- Background music, eat sound, and game over sound
- English and Russian language switch
- Best score saved with `UserDefaults`
- Custom app icon

## Tech Stack

- Swift
- SpriteKit
- AVFoundation
- Xcode
- No third-party libraries

## Requirements

- Xcode 16 or newer
- iOS Simulator or a real iPhone
- Portrait orientation

## How to Run

1. Clone the repository:

   ```bash
   git clone https://github.com/kolyased/RetroSnake.git
   ```

2. Open the project:

   ```bash
   open RetroSnake/RetroSnake.xcodeproj
   ```

3. Select an iPhone simulator or a connected iPhone.
4. Press `Cmd + R` in Xcode.

## Controls

- Swipe up, down, left, or right to change direction.
- Use the on-screen arrow buttons for touch controls.
- Tap the pause button in the top-left corner during gameplay.

## Audio Files

The game uses bundled audio resources:

- `background.mp3`
- `eat.wav`
- `gameover.wav`

If you replace them, keep the same filenames so `AudioManager` can load them.

## App Icon

The app icon is stored in:

```text
RetroSnake/Assets.xcassets/AppIcon.appiconset
```

## Notes

The game is intentionally small and focused. It does not include ads, in-app purchases, backend services, or extra menus.
