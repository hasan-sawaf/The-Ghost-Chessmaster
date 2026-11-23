#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>
#include <AccelStepper.h>
#include <Servo.h>

// --- STEEPER MOTOR DRIVER PINS ---
#define DIR_PIN_RIGHT 5
#define STEP_PIN_RIGHT 2
#define DIR_PIN_LEFT 6
#define STEP_PIN_LEFT 3
#define MOTOR_INTERFACE 1

// --- lIMIT SWITCH PINS ---
#define LIMIT_UP_PIN 10
#define LIMIT_RIGHT_PIN 9

// --- SERVO PIN ---
#define SERVO_PIN A0

// BUTTONS PINS
#define BUTTON_PIN A1
#define BUTTON2_PIN A2
#define BUTTON3_PIN A3

#define STEPS_PER_MM 80.0

// --- GLOBAL MOTOR & ACTUATOR OBJECTS ---
extern AccelStepper stepper_right;
extern AccelStepper stepper_left;
extern Servo myServo;

// --- GLOBAL STATE VARIABLES ---
extern bool wasMoving;
extern unsigned long lastReport;
extern bool errorState;

extern int lastButtonState;
extern unsigned long lastButtonPress;
extern int lastButton2State;
extern unsigned long lastButton2Press;
extern int lastButton3State;
extern unsigned long lastButton3Press;
extern unsigned long lastGlobalButtonPress;

#endif // CONFIG_H
