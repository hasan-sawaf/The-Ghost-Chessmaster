#include "kinematics.h"
#include "config.h"
#include "timers.h"

void homeMachine()
{
    Serial.println("Action: Homing Start");

    // 1. Move Up (Y-axis) until limit hit
    stepper_right.setSpeed(-400);
    stepper_left.setSpeed(400);
    while (digitalRead(LIMIT_UP_PIN) == HIGH)
    {
        stepper_right.runSpeed();
        stepper_left.runSpeed();
    }
    delay(200);

    // 2. Move Right (X-axis) until limit hit
    stepper_right.setSpeed(-400);
    stepper_left.setSpeed(-400);
    while (digitalRead(LIMIT_RIGHT_PIN) == HIGH)
    {
        stepper_right.runSpeed();
        stepper_left.runSpeed();
    }

    // 3. Reset internal coordinate system to 0,0
    stepper_right.setCurrentPosition(0);
    stepper_left.setCurrentPosition(0);
    stepper_right.moveTo(0);
    stepper_left.moveTo(0);
    Serial.println("HOME REACHED");
    wasMoving = true;
}

void processChessSquare(String cmd)
{
    int colIdx = cmd.charAt(2) - 'A';
    int rowIdx = cmd.charAt(3) - '1';

    // From handwritten notes: A=53.6cm, B=46.8cm ... H=8.0cm
    const float CHESS_X[8] = {52.5, 46.0, 39.8, 33.5, 27.0, 20.5, 14.0, 7.6};
    // From handwritten notes: 1=48.0cm, 2=42.4cm ... 8=9.0cm
    const float CHESS_Y[8] = {46.8, 41.4, 36.0, 30.6, 24.8, 19.5, 14.0, 8.7};

    float tx = CHESS_X[colIdx] * (350.0 / 600.0);
    float ty = CHESS_Y[rowIdx] * (410.0 / 600.0);

    stepper_left.moveTo((tx - ty) * STEPS_PER_MM);
    stepper_right.moveTo((tx + ty) * STEPS_PER_MM);
    wasMoving = true;
}

int magnetUpAngle = 90;
int magnetDownAngle = 0;

void setMagnetAngle(int angle)
{
    magnetUpAngle = constrain(angle, 0, 180);
    Serial.print("STATUS: MAGNET_ANGLE_SET ");
    Serial.println(magnetUpAngle);
}

void processCommand(char cmd)
{
    cmd = toupper(cmd);
    if (cmd == '9')
    {
        myServo.write(magnetUpAngle);
        Serial.println("STATUS: MAGNET_UP"); // Notifies Python
    }
    else if (cmd == '0')
    {
        myServo.write(magnetDownAngle);
        Serial.println("STATUS: MAGNET_DOWN"); // Notifies Python
    }
    else if (cmd == ' ' || cmd == 'X')
    {
        // Emergency Stop overrides
        stepper_right.moveTo(stepper_right.currentPosition());
        stepper_left.moveTo(stepper_left.currentPosition());
    }
}

void processGCode(String cmd)
{
    // Evaluates Python generated direct coordinates for Gutter Paths
    int xIdx = cmd.indexOf('X');
    int yIdx = cmd.indexOf('Y');
    if (xIdx != -1 && yIdx != -1)
    {
        float x = cmd.substring(xIdx + 1, yIdx).toFloat();
        float y = cmd.substring(yIdx + 1).toFloat();
        stepper_left.moveTo((x - y) * STEPS_PER_MM);
        stepper_right.moveTo((x + y) * STEPS_PER_MM);
        wasMoving = true;
    }
}

void processError(String cmd)
{
    String reason = "";
    if (cmd.length() > 2 && cmd.charAt(1) == ':') {
        reason = cmd.substring(2);
    } else if (cmd.length() > 1) {
        reason = cmd.substring(1);
    } else {
        reason = "Illegal Move";
    }
    
    displayErrorMessage(reason);
    errorState = true;
}

void checkButton()
{
    unsigned long now = millis();
    bool canPress = (lastGlobalButtonPress == 0) || (now - lastGlobalButtonPress > 2000);

    // Special logic when waiting for exit confirmation (confirmState is active)
    if (confirmState)
    {
        // Button 1 (A1) -> Confirm YES (Exit Game and Home)
        int currentButtonState = digitalRead(BUTTON_PIN);
        if (currentButtonState == LOW && lastButtonState == HIGH && (now - lastButtonPress > 50))
        {
            if (canPress)
            {
                confirmState = false;
                timerReset();
                Serial.println("close"); // Tell Python to close game
                homeMachine(); // Block until fully homed
                if (cvConnected) {
                    currentPhase = PHASE_2_READY;
                    scrollPos = 0;
                    lastScrollTime = millis();
                } else {
                    currentPhase = PHASE_1_START_CAM;
                }
                restoreTimerDisplay();
                lastGlobalButtonPress = now;
            }
            lastButtonPress = now;
        }
        lastButtonState = currentButtonState;

        // Button 2 (A2) -> Cancel NO (Keep game)
        int currentButton2State = digitalRead(BUTTON2_PIN);
        if (currentButton2State == LOW && lastButton2State == HIGH && (now - lastButton2Press > 50))
        {
            if (canPress)
            {
                confirmState = false;
                currentPhase = PHASE_3_PLAYING;
                timerLastTick = millis();
                restoreTimerDisplay();
                lastGlobalButtonPress = now;
            }
            lastButton2Press = now;
        }
        lastButton2State = currentButton2State;

        // Button 3 (A3) -> Ignore during confirmation
        int currentButton3State = digitalRead(BUTTON3_PIN);
        if (currentButton3State == LOW && lastButton3State == HIGH && (now - lastButton3Press > 50))
        {
            lastButton3Press = now;
        }
        lastButton3State = currentButton3State;

        return; // Bypass normal button flow
    }

    // Normal button checking (confirmState is false)

    // Button 1 (A1)
    int currentButtonState = digitalRead(BUTTON_PIN);

    if (currentButtonState == LOW && lastButtonState == HIGH && (now - lastButtonPress > 50))
    {
        if (canPress && !errorState && currentPhase == PHASE_3_PLAYING)
        {
            // Stop white timer, add 1s increment, and transition to black timer
            timerOnButtonPress();

            // THIS MUST BE "e" TO MATCH YOUR PYTHON CODE
            Serial.println("e");

            lastGlobalButtonPress = now;
        }
        lastButtonPress = now;
    }

    lastButtonState = currentButtonState;

    // Button 2 (A2) -> Recapture Base / Reset Error / Cancel
    int currentButton2State = digitalRead(BUTTON2_PIN);

    if (currentButton2State == LOW && lastButton2State == HIGH && (now - lastButton2Press > 150))
    {
        if (errorState)
        {
            errorState = false;
            restoreTimerDisplay();
        }
        Serial.println("r");
        lastButton2Press = now;
        lastGlobalButtonPress = now;
    }

    lastButton2State = currentButton2State;

    // Button 3 (A3) (White Button)
    int currentButton3State = digitalRead(BUTTON3_PIN);

    if (currentButton3State == LOW && lastButton3State == HIGH && (now - lastButton3Press > 50))
    {
        if (canPress)
        {
            if (currentPhase == PHASE_1_START_CAM)
            {
                // Send "s" to Python to connect camera
                Serial.println("s");
                currentPhase = PHASE_WAIT_CV;
                restoreTimerDisplay();
            }
            else if (currentPhase == PHASE_2_READY)
            {
                // Send "start_game" to Python to start game
                Serial.println("start_game");
            }
            else if (currentPhase == PHASE_3_PLAYING)
            {
                if (errorState)
                {
                    errorState = false; // Dismiss illegal move screen
                }
                startExitConfirmation();
            }
            lastGlobalButtonPress = now;
        }
        lastButton3Press = now;
    }

    lastButton3State = currentButton3State;
}
