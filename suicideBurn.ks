// Suicide burn
PARAMETER radarAltOffset.                                          // alt:radar value when landed (KSP measures from part way up the ship)
LOCK actualAlt TO alt:radar - radarAltOffset.                      // Get the actual ship altitude
LOCK shipGravity TO CONSTANT:G * BODY:MASS / BODY:RADIUS^2.        // Gravity effect on ship
LOCK maxDecel TO (SHIP:AVAILABLETHRUST / SHIP:MASS) - shipGravity. // Maximum deceleration
LOCK stopDistance TO SHIP:VERTICALSPEED^2 / (2 * maxDecel).        // Distance required to stop
LOCK targetThrottle TO stopDistance / actualAlt.                   // Throttle position required for suicide burn
LOCK timeRemaining TO actualAlt / ABS(SHIP:VERTICALSPEED).         // Time left for suicide burn

WAIT UNTIL SHIP:VERTICALSPEED < -10 {
    RCS ON.
    SAS OFF.
    BRAKES ON.
    LOCK STEERING TO SRFRETROGRADE.
    WHEN timeRemaining < 5 THEN { GEAR ON. }
}.

WAIT UNTIL actualAlt <= stopDistance {
    LOCK THROTTLE TO targetThrottle.
}.

WAIT UNTIL SHIP:VERTICALSPEED > -0.1 {
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
    RCS OFF.
}.
