#ifndef TIMER_MANAGER_H
#define TIMER_MANAGER_H

#include <Arduino.h>

// --- TIMER STATES ---
enum TimerState { T_NOT_STARTED, T_WHITE_TURN, T_BLACK_TURN, T_PAUSED, T_GAME_OVER };

// --- HARDWARE PHASES ---
enum HardwarePhase {
    PHASE_1_START_CAM,
    PHASE_WAIT_CV,
    PHASE_2_READY,
    PHASE_3_PLAYING,
    PHASE_3_CONFIRM_EXIT
};

// --- GLOBAL TIMER STATES ---
extern TimerState currentTimerState;
extern HardwarePhase currentPhase;
extern bool cvConnected;
extern unsigned long lastScrollTime;
extern int scrollPos;

extern bool confirmState;
extern unsigned long confirmLastTick;
extern int confirmCountdown;

extern String errorScrollText;
extern int errorScrollPos;
extern unsigned long lastErrorScrollTime;

extern long timerWhiteTime;
extern long timerBlackTime;
extern unsigned long timerLastTick;

extern long initialGameTime;
extern int incrementTime;

// --- TIMER FUNCTIONS ---
void setupTimer();
void updateTimerClock();
void timerStartWhite();
void timerStartBlack();
void timerPause();
void timerReset();
void timerOnButtonPress();
void displayErrorMessage(String message);
void restoreTimerDisplay();
void startExitConfirmation();
void setTimerSettings(long minutes, int increment);
void setExactTimer(long w_sec, long b_sec);
void showCustomMessage(String line1, String line2);
void updateCustomMessageLine2(String line2);


#endif // TIMER_MANAGER_H
