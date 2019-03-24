// Sources:  http://forum.kerbalspaceprogram.com/threads/40053-Estimate-the-duration-of-a-burn

RUNONCEPATH("0:/library.ks").

// Check that the current stage has liquidfuel, to avoid an error occurring at the last min.  If the stage doesn't even have the resources in the structure (which for mysterious reasons seems to sometimes happen), the script crashes here, rather than later, making it easier to correct.
IF STAGE:LiquidFuel = 0 {
    PRINT "LiquidFuel empty.".
}

LOCAL maxThrustLimited IS calcMaxThrustLimited().

SAS OFF.
LOCK steering TO NEXTNODE.

awaitNode(NEXTNODE).

LOCAL tvar IS 0.
LOCK THROTTLE TO tvar.
PRINT "Fast burn".
LOCAL oldDeltaV IS NEXTNODE:DELTAV:MAG + 1.
UNTIL (NEXTNODE:DELTAV:MAG < 1 AND STAGE:LIQUIDFUEL > 0) or (NEXTNODE:DELTAV:MAG > oldDeltaV) {
    LOCAL da IS maxThrustLimited * THROTTLE / SHIP:MASS.
    LOCAL tset IS NEXTNODE:DELTAV:MAG * SHIP:MASS / maxThrustLimited.
    IF NEXTNODE:DELTAV:MAG < 2*da AND tset > 0.1 {
        SET tvar TO tset.
    }
    IF NEXTNODE:DELTAV:MAG > 2*da {
        SET tvar TO 1.
    }
    SET oldDeltaV TO NEXTNODE:DELTAV:MAG.
}
// caveman debugging
IF (NEXTNODE:DELTAV:MAG > oldDeltaV) {
    PRINT "Warning:  Delta-V target exceeded during fast-burn!".
}
// compensate 1m/s due to "until" stopping short; nd:deltav:mag never gets to 0!
PRINT "Slow burn".
IF STAGE:LIQUIDFUEL > 0 AND da <> 0 {
    WAIT 1/da.
}
LOCK THROTTLE TO 0.

UNLOCK ALL.
SAS ON.
