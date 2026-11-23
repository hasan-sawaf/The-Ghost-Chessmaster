#include "config.h"
#include "timers.h"
#include "kinematics.h"

// Define the global objects
AccelStepper stepper_right(MOTOR_INTERFACE, STEP_PIN_RIGHT, DIR_PIN_RIGHT);
AccelStepper stepper_left(MOTOR_INTERFACE, STEP_PIN_LEFT, DIR_PIN_LEFT);
Servo myServo;

// Initialize global state variables
bool wasMoving = false;
unsigned long lastReport = 0;
bool errorState = false;

int lastButtonState = HIGH;
unsigned long lastButtonPress = 0;
int lastButton2State = HIGH;
unsigned long lastButton2Press = 0;
int lastButton3State = HIGH;
unsigned long lastButton3Press = 0;
unsigned long lastGlobalButtonPress = 0;

void setup()
{
    Serial.begin(115200);
    pinMode(LIMIT_UP_PIN, INPUT_PULLUP);
    pinMode(LIMIT_RIGHT_PIN, INPUT_PULLUP);

    pinMode(BUTTON_PIN, INPUT_PULLUP);
    pinMode(BUTTON2_PIN, INPUT_PULLUP);
    pinMode(BUTTON3_PIN, INPUT_PULLUP);

    stepper_right.setMaxSpeed(500);
    stepper_right.setAcceleration(500);
    stepper_left.setMaxSpeed(500);
    stepper_left.setAcceleration(500);

    myServo.attach(SERVO_PIN);
    myServo.write(0);

    setupTimer();
    homeMachine();
}

void loop()
{
    // 1. Check for incoming Serial commands
    if (Serial.available())
    {
        String cmdStr = Serial.readStringUntil('\n');
        cmdStr.trim();
        if (cmdStr.length() > 0)
        {
            char peekChar = cmdStr.charAt(0);
            if (peekChar == 'G')
                processGCode(cmdStr);
            else if (peekChar == 'C')
                processChessSquare(cmdStr);
            else if (peekChar == 'H')
            {
                homeMachine();
                if (cvConnected) {
                    currentPhase = PHASE_2_READY;
                } else {
                    currentPhase = PHASE_1_START_CAM;
                }
            }
            else if (peekChar == 'E')
                processError(cmdStr);
            else if (peekChar == 'W')
            {
                if (errorState) { errorState = false; restoreTimerDisplay(); }
                timerStartWhite();
                currentPhase = PHASE_3_PLAYING;
            }
            else if (peekChar == 'B')
            {
                if (errorState) { errorState = false; restoreTimerDisplay(); }
                timerStartBlack();
                currentPhase = PHASE_3_PLAYING;
            }
            else if (peekChar == 'P')
                timerPause();
            else if (peekChar == 'R')
            {
                if (errorState) { errorState = false; restoreTimerDisplay(); }
                timerReset();
                if (cvConnected) {
                    currentPhase = PHASE_2_READY;
                } else {
                    currentPhase = PHASE_1_START_CAM;
                }
            }
            else if (peekChar == 'T')
            {
                int space1 = cmdStr.indexOf(' ');
                if (space1 != -1)
                {
                    int space2 = cmdStr.indexOf(' ', space1 + 1);
                    long minutes = cmdStr.substring(space1 + 1, space2 == -1 ? cmdStr.length() : space2).toInt();
                    int increment = 0;
                    if (space2 != -1)
                    {
                        increment = cmdStr.substring(space2 + 1).toInt();
                    }
                    setTimerSettings(minutes, increment);
                }
            }
            else if (peekChar == 'S')
            {
                int space1 = cmdStr.indexOf(' ');
                if (space1 != -1)
                {
                    int space2 = cmdStr.indexOf(' ', space1 + 1);
                    long w_sec = cmdStr.substring(space1 + 1, space2 == -1 ? cmdStr.length() : space2).toInt();
                    long b_sec = 0;
                    if (space2 != -1)
                    {
                        b_sec = cmdStr.substring(space2 + 1).toInt();
                    }
                    setExactTimer(w_sec, b_sec);
                }
            }
            else if (peekChar == 'M')
            {
                if (cmdStr.startsWith("M1 ")) {
                    showCustomMessage(cmdStr.substring(3), "");
                } else if (cmdStr.startsWith("M2 ")) {
                    updateCustomMessageLine2(cmdStr.substring(3));
                } else if (cmdStr.startsWith("M0")) {
                    restoreTimerDisplay();
                }
            }
            else if (peekChar == 'V')
            {
                int space = cmdStr.indexOf(' ');
                if (space != -1)
                {
                    int stateVal = cmdStr.substring(space + 1).toInt();
                    if (stateVal == 1)
                    {
                        cvConnected = true;
                        if (currentPhase == PHASE_1_START_CAM || currentPhase == PHASE_WAIT_CV)
                        {
                            currentPhase = PHASE_2_READY;
                            restoreTimerDisplay();
                        }
                    }
                    else
                    {
                        cvConnected = false;
                        if (currentPhase == PHASE_2_READY || currentPhase == PHASE_3_PLAYING || currentPhase == PHASE_3_CONFIRM_EXIT)
                        {
                            currentPhase = PHASE_1_START_CAM;
                            restoreTimerDisplay();
                        }
                    }
                }
            }
            else if (peekChar == 'A')
            {
                int space = cmdStr.indexOf(' ');
                int angle = 90;
                if (space != -1)
                {
                    angle = cmdStr.substring(space + 1).toInt();
                }
                else if (cmdStr.length() > 1)
                {
                    angle = cmdStr.substring(1).toInt();
                }
                setMagnetAngle(angle);
            }
            else
                processCommand(peekChar);
        }
    }

    // 2. Keep motors running smoothly
    stepper_right.run();
    stepper_left.run();

    // 3. Check the physical button
    checkButton();

    // 4. Update the Chess Timer clock
    updateTimerClock();

    // 5. Telemetry broadcast (Every 200ms)
    if (millis() - lastReport > 200)
    {
        long curL = stepper_left.currentPosition();
        long curR = stepper_right.currentPosition();
        float x_mm = (curL + curR) / (2.0 * STEPS_PER_MM);
        float y_mm = (curR - curL) / (2.0 * STEPS_PER_MM);

        Serial.print("X:");
        Serial.print(x_mm);
        Serial.print("|Y:");
        Serial.println(y_mm);
        lastReport = millis();
    }

    // Status for GUI pathing orchestration (Triggers Python sequence)
    if (stepper_right.distanceToGo() == 0 && stepper_left.distanceToGo() == 0)
    {
        if (wasMoving)
        {
            Serial.println("STATUS: IDLE");
            wasMoving = false;
        }
    }
    else
    {
        wasMoving = true;
    }
}
