// Launch
RUNONCEPATH("0:/library.ks").

CLEARSCREEN.
PRINT "Launch to orbit: " + TIME:CALENDAR + ", " + TIME:CLOCK.
SET radarAltOffset TO ALT:RADAR - 6.
// SET radarAltOffset TO 7.06443023681641.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET startMissionTime TO TIME:SECONDS.
LOCK elapsedMissionTime TO TIME:SECONDS - startMissionTime.

launchToOrbit().

PRINT "T+" + ROUND(elapsedMissionTime) + " Beginning circularisation".
IF CAREER:CANMAKENODES {
    createCircularisationNode().
} ELSE {
    circulariseOrbit().
}

PRINT "T+" + ROUND(elapsedMissionTime) + " Orbit achieved".
WAIT 60.

PRINT "T+" + ROUND(elapsedMissionTime) + " Beginning de-orbit".
waitAngle(SHIP:RETROGRADE).
UNTIL SHIP:PERIAPSIS < BODY:ATM:HEIGHT - 5_000 {
    LOCK THROTTLE TO 1.
}
LOCK THROTTLE TO 0.

PRINT "T+" + ROUND(elapsedMissionTime) + " Beginning suicide burn".
suicideBurn(radarAltOffset).
