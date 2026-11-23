# MCU CoreXY Firmware (`mcu_core_xy`)

Arduino/ESP32 firmware controlling the CoreXY motorized chess gantry, sub-board neodymium magnet servo lifter, homing limit switches, physical game buttons, and `16x2` I2C LCD game clock.

## Required Libraries
Install via Arduino Library Manager:
- **AccelStepper**
- **Servo** (standard Arduino Servo library)
- **LiquidCrystal_I2C** (I2C address `0x27`, `16x2`)
- **Wire** (built-in)

## Pin Configuration (`config.h`)

| Signal | Pin | Notes |
| :--- | :--- | :--- |
| Right Stepper STEP / DIR | `2` / `5` | `AccelStepper` driver interface (`1`) |
| Left Stepper STEP / DIR | `3` / `6` | `AccelStepper` driver interface (`1`) |
| Limit Switch UP / RIGHT | `10` / `9` | `INPUT_PULLUP` |
| Magnet Lifter Servo | `A0` | Raises/lowers sub-board magnet |
| Physical Buttons 1 / 2 / 3 | `A1` / `A2` / `A3` | `INPUT_PULLUP` |
| I2C LCD Display | SDA / SCL (`0x27`) | `16x2` character LCD |

## Serial Protocol (`115200` baud)
- `G...` — G-code coordinate movement command
- `C...` — Chess square movement command
- `H` — Home CoreXY gantry using limit switches
- `W` / `B` / `P` / `R` — Start White timer / Black timer / Pause / Reset
- `T <minutes> <increment>` — Configure game timer & increment
- `S <white_sec> <black_sec>` — Synchronize exact remaining clock times
- `E <message>` — Display scrolling error notice on LCD
