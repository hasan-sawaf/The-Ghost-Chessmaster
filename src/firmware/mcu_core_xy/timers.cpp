#include "timers.h"
#include "config.h"
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// Define variables declared in TimerManager.h
TimerState currentTimerState = T_NOT_STARTED;
HardwarePhase currentPhase = PHASE_1_START_CAM;
bool cvConnected = false;
unsigned long lastScrollTime = 0;
int scrollPos = 0;

bool confirmState = false;
unsigned long confirmLastTick = 0;
int confirmCountdown = 15;

String errorScrollText = "";
int errorScrollPos = 0;
unsigned long lastErrorScrollTime = 0;

// LCD initialization (I2C address 0x27, 16 columns, 2 rows)
LiquidCrystal_I2C timerLcd(0x27, 16, 2);

long timerWhiteTime = 300;
long timerBlackTime = 300;
unsigned long timerLastTick = 0;

long initialGameTime = 300;
int incrementTime = 2;

// Helper function declarations
void displayTimerTime();
void printFormattedTime(long timeInSeconds);

void printFormattedTime(long timeInSeconds) {
  int minutes = timeInSeconds / 60;
  int seconds = timeInSeconds % 60;
  
  if (minutes < 10) timerLcd.print("0");
  timerLcd.print(minutes);
  timerLcd.print(":");
  if (seconds < 10) timerLcd.print("0");
  timerLcd.print(seconds);
}

void displayTimerTime() {
  if (currentPhase != PHASE_3_PLAYING) return;
  if (initialGameTime == 0) {
    timerLcd.setCursor(0, 0);
    timerLcd.print("NO TIMER (INF)  ");
    timerLcd.setCursor(0, 1);
    timerLcd.print("00:00");
    timerLcd.setCursor(5, 1);
    if (currentTimerState == T_WHITE_TURN) timerLcd.print("<  ");
    else timerLcd.print("   ");
    timerLcd.setCursor(9, 1);
    timerLcd.print("00:00");
    timerLcd.setCursor(14, 1);
    if (currentTimerState == T_BLACK_TURN) timerLcd.print("< ");
    else timerLcd.print("  ");
    return;
  }
  timerLcd.setCursor(0, 1);
  printFormattedTime(timerWhiteTime);
  
  timerLcd.setCursor(5, 1);
  if (currentTimerState == T_WHITE_TURN) timerLcd.print("<  ");
  else if (currentTimerState == T_GAME_OVER && timerWhiteTime == 0) timerLcd.print(" X ");
  else timerLcd.print("   ");
  
  timerLcd.setCursor(9, 1);
  printFormattedTime(timerBlackTime);

  timerLcd.setCursor(14, 1);
  if (currentTimerState == T_BLACK_TURN) timerLcd.print("< ");
  else if (currentTimerState == T_GAME_OVER && timerBlackTime == 0) timerLcd.print(" X");
  else timerLcd.print("  ");
}

void setupTimer() {
  timerLcd.init();
  timerLcd.backlight();
  
  currentPhase = PHASE_1_START_CAM;
  restoreTimerDisplay();
}

void updateTimerClock() {
  if (errorState) {
    if (millis() - lastErrorScrollTime >= 350) {
      lastErrorScrollTime = millis();
      int textLen = errorScrollText.length();
      if (textLen > 16) {
        String dispStr = "";
        for (int i = 0; i < 16; i++) {
          int idx = (errorScrollPos + i) % textLen;
          dispStr += errorScrollText.charAt(idx);
        }
        timerLcd.setCursor(0, 1);
        timerLcd.print(dispStr);
        errorScrollPos = (errorScrollPos + 1) % textLen;
      } else {
        timerLcd.setCursor(0, 1);
        timerLcd.print(errorScrollText);
      }
    }
    return;
  }

  // Phase 1: Start Cam display (Static)
  if (currentPhase == PHASE_1_START_CAM) {
    return;
  }

  // Phase Wait CV: Wait for CV confirmation (Static)
  if (currentPhase == PHASE_WAIT_CV) {
    return;
  }

  // Phase 2: Ready (Scrolling text NOW PRESS AGAIN TO START THE GAME)
  if (currentPhase == PHASE_2_READY) {
    if (millis() - lastScrollTime >= 300) {
      lastScrollTime = millis();
      String msg = "NOW PRESS AGAIN TO START THE GAME    ";
      int len = msg.length();
      String dispStr = "";
      for (int i = 0; i < 16; i++) {
        int idx = (scrollPos + i) % len;
        dispStr += msg.charAt(idx);
      }
      timerLcd.setCursor(0, 1);
      timerLcd.print(dispStr);
      scrollPos = (scrollPos + 1) % len;
    }
    return;
  }

  // Phase 3 Exit Confirmation countdown
  if (currentPhase == PHASE_3_CONFIRM_EXIT) {
    if (millis() - confirmLastTick >= 1000) {
      confirmLastTick += 1000;
      confirmCountdown--;
      
      timerLcd.setCursor(0, 0);
      timerLcd.print("EXIT GAME? YES:B1");
      timerLcd.setCursor(0, 1);
      timerLcd.print("NO:B2   Secs: ");
      if (confirmCountdown < 10) timerLcd.print("0");
      timerLcd.print(confirmCountdown);
      
      if (confirmCountdown <= 0) {
        confirmState = false;
        currentPhase = PHASE_3_PLAYING;
        timerLastTick = millis();
        restoreTimerDisplay();
      }
    }
    return;
  }

  // Phase 3 Playing countdown
  if (currentPhase == PHASE_3_PLAYING && (currentTimerState == T_WHITE_TURN || currentTimerState == T_BLACK_TURN)) {
    if (initialGameTime == 0) {
      // Infinite time / No timer: do not decrement
      return;
    }
    if (millis() - timerLastTick >= 1000) {
      timerLastTick += 1000;
      
      if (currentTimerState == T_WHITE_TURN) {
        timerWhiteTime--;
        if (timerWhiteTime <= 0) { 
          timerWhiteTime = 0; 
          currentTimerState = T_GAME_OVER; 
        }
      } else if (currentTimerState == T_BLACK_TURN) {
        timerBlackTime--;
        if (timerBlackTime <= 0) { 
          timerBlackTime = 0; 
          currentTimerState = T_GAME_OVER; 
        }
      }
      displayTimerTime();
    }
  }
}

void timerStartWhite() {
  currentTimerState = T_WHITE_TURN;
  timerLastTick = millis();
  displayTimerTime();
}

void timerStartBlack() {
  currentTimerState = T_BLACK_TURN;
  timerLastTick = millis();
  displayTimerTime();
}

void timerPause() {
  currentTimerState = T_PAUSED;
  displayTimerTime();
}

void timerReset() {
  timerWhiteTime = initialGameTime;
  timerBlackTime = initialGameTime;
  currentTimerState = T_NOT_STARTED;
}

void timerOnButtonPress() {
  if (currentTimerState == T_WHITE_TURN) {
    if (initialGameTime > 0) {
      timerWhiteTime += incrementTime;
    }
    timerStartBlack();
  }
}

void setTimerSettings(long minutes, int increment) {
  initialGameTime = minutes * 60;
  incrementTime = increment;
  if (currentPhase != PHASE_3_PLAYING) {
    timerWhiteTime = initialGameTime;
    timerBlackTime = initialGameTime;
  }
}

void setExactTimer(long w_sec, long b_sec) {
  timerWhiteTime = w_sec;
  timerBlackTime = b_sec;
  if (currentPhase == PHASE_3_PLAYING) {
    displayTimerTime();
  }
}

void showCustomMessage(String line1, String line2) {
  timerLcd.clear();
  timerLcd.setCursor(0, 0);
  timerLcd.print(line1);
  timerLcd.setCursor(0, 1);
  timerLcd.print(line2);
}

void updateCustomMessageLine2(String line2) {
  timerLcd.setCursor(0, 1);
  timerLcd.print("                ");
  timerLcd.setCursor(0, 1);
  timerLcd.print(line2);
}

void displayErrorMessage(String message) {
  errorScrollText = message + " (press button 2 to recapture)     ";
  errorScrollPos = 0;
  lastErrorScrollTime = millis();
  
  timerLcd.clear();
  timerLcd.setCursor(0, 0);
  timerLcd.print("ILLEGAL MOVE!");
  timerLcd.setCursor(0, 1);
  if (errorScrollText.length() > 16) {
    timerLcd.print(errorScrollText.substring(0, 16));
  } else {
    timerLcd.print(errorScrollText);
  }
}

void restoreTimerDisplay() {
  timerLcd.clear();
  if (currentPhase == PHASE_1_START_CAM) {
    timerLcd.setCursor(0, 0);
    timerLcd.print("PRESS BUTTON 3");
    timerLcd.setCursor(0, 1);
    timerLcd.print("TO START CAMERA");
  } else if (currentPhase == PHASE_WAIT_CV) {
    timerLcd.setCursor(0, 0);
    timerLcd.print("START CAMERA");
    timerLcd.setCursor(0, 1);
    timerLcd.print("CONNECTING...");
  } else if (currentPhase == PHASE_2_READY) {
    timerLcd.setCursor(0, 0);
    timerLcd.print("CAMERA IS ON");
    scrollPos = 0;
    lastScrollTime = millis();
  } else if (currentPhase == PHASE_3_PLAYING) {
    timerLcd.setCursor(0, 0);
    if (initialGameTime == 0) {
      timerLcd.print("NO TIMER (INF)  ");
    } else {
      timerLcd.print("White    Black");
    }
    displayTimerTime();
  }
}

void startExitConfirmation() {
  confirmState = true;
  confirmCountdown = 15;
  confirmLastTick = millis();
  currentPhase = PHASE_3_CONFIRM_EXIT;
  
  timerLcd.clear();
  timerLcd.setCursor(0, 0);
  timerLcd.print("EXIT GAME? YES:B1");
  timerLcd.setCursor(0, 1);
  timerLcd.print("NO:B2   Secs: 15");
}
