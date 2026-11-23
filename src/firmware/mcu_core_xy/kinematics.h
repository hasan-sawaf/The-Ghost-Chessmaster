#ifndef KINEMATICS_H
#define KINEMATICS_H

#include <Arduino.h>

extern int magnetUpAngle;
extern int magnetDownAngle;

void homeMachine();
void processChessSquare(String cmd);
void processCommand(char cmd);
void setMagnetAngle(int angle);
void processGCode(String cmd);
void processError(String cmd);
void checkButton();

#endif // KINEMATICS_H
