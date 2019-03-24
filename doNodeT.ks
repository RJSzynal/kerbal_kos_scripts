// Sources:  http://forum.kerbalspaceprogram.com/threads/40053-Estimate-the-duration-of-a-burn

RUNONCEPATH("0:/library.ks").

SAS OFF.
LOCK STEERING TO NEXTNODE.

awaitNode().

LOCAL burnTime IS calcBurnTime().
LOCAL burnTimeStart IS TIME:SECONDS.
UNTIL TIME:SECONDS >= burnTimeStart + burnTime {
    LOCK THROTTLE TO 1.
}
LOCK THROTTLE TO 0.

UNLOCK ALL.
SAS ON.
