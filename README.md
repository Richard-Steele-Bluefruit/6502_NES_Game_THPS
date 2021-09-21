# 6502NES Game THPS

[FCEUX](https://fceux.com/web/download.html) is the NES emulator that I used in the lightning talk.

Controls are customisable, but I think are: (F and G may be D and F... best check, I think I changed mine from defaults)

| NES controller button | Keyboard |
|-----------------------|----------|
| Start | Enter |
| A | F |
| B | G (hold down in air to grind the ledge) |
| Directions | Arrow keys |

Traffic cones trip you up. A will jump out of a grind. You will fall if landing while mid trick. Tap right to speed up.

#### Compiling

From source code location `\6502_NES_Game_THPS\THPS\`, do `..\Tools\nesasm_win32\nesasm.exe THPS.asm`

Builds the THPS.nes file that the emulator/everdrive cartridge will use

![SpriteSheet](https://github.com/Richard-Steele-Bluefruit/6502_NES_Game_THPS/blob/main/SpriteSheet.png "Sprite sheet")