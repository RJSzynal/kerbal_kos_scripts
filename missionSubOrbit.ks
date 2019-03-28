// Launch
RUNONCEPATH("0:/library.ks").

CLEARSCREEN.
PRINT "Launch to sub-orbit: " + TIME:CALENDAR + ", " + TIME:CLOCK.
SET radarAltOffset TO ALT:RADAR - 6.
// SET radarAltOffset TO 7.06443023681641.
SET startMissionTime TO TIME:SECONDS.
LOCK elapsedMissionTime TO TIME:SECONDS - startMissionTime.

launchToTargetHeight(80_000, 3).

PRINT "T+" + ROUND(elapsedMissionTime) + " Beginning suicide burn".
suicideBurn(radarAltOffset).
