// Sources:  http://forum.kerbalspaceprogram.com/threads/40053-Estimate-the-duration-of-a-burn

FUNCTION awaitNode {
    PARAMETER node IS NEXTNODE.
    waitPeriod(node:ETA - (calcBurnTime(node:DELTAV) / 2)).
}

FUNCTION waitPeriod {
    PARAMETER secondsToWait.
    SET startTime TO TIME:SECONDS.
    UNTIL TIME:SECONDS - startTime > secondsToWait {
        SET remainingTime TO secondsToWait - TIME:SECONDS.
        IF KUNIVERSE:TIMEWARP:MODE = "RAILS" {
            SET maxwarp TO 8.
            IF remainingTime < 100000 { SET maxwarp TO 7. }
            IF remainingTime < 10000  { SET maxwarp TO 6. }
            IF remainingTime < 1000   { SET maxwarp TO 5. }
            IF remainingTime < 100    { SET maxwarp TO 4. }
            IF remainingTime < 60     { SET maxwarp TO 3. }
            IF remainingTime < 50     { SET maxwarp TO 2. }
            IF remainingTime < 25     { SET maxwarp TO 1. }
            IF remainingTime < 8      { SET maxwarp TO 0. }
        } ELSE {
            SET maxwarp TO 4.
            IF remainingTime < 8      { SET maxwarp TO 0. }
        }
        PRINT "    Remaining time:  " + remainingTime at (0,5).
        PRINT "       Warp factor:  " + KUNIVERSE:TIMEWARP:WARP at (0,6).
        IF KUNIVERSE:TIMEWARP:WARP > maxwarp {
            SET KUNIVERSE:TIMEWARP:WARP TO maxwarp.
        }
    }
    PRINT " " at (0,5).
    PRINT " " at (0,6).
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
}

FUNCTION launchToTargetHeight {
    PARAMETER targetHeight is 80000.
    Parameter maxStage IS 3.
    LOCK STEERING TO HEADING(90,90).
    LOCK THROTTLE TO 1.

    WHEN SHIP:MAXTHRUST = 0 THEN {
        STAGE.
        IF STAGE:NUMBER >= maxStage {
            RETURN true.
        } ELSE {
            RETURN false.
        }
    }

    WAIT UNTIL SHIP:APOAPSIS >= targetHeight.

    LOCK THROTTLE TO 0.
    UNLOCK ALL.
}

FUNCTION circulariseOrbit {
    IF SHIP:VERTICALSPEED < 0 AND SHIP:PERIAPSIS < SHIP:BODY:ATMOSPHERE:HEIGHT { PRINT "Ship has passed apoapsis and will enter the atmosphere". }
    LOCAL deltaV IS calcChangePeriapsisDeltaV(SHIP:APOAPSIS).
    IF deltaV < 0 {
        LOCK shipDirection TO SHIP:RETROGRADE.
    } ELSE {
        LOCK shipDirection TO SHIP:PROGRADE.
    }
    LOCAL burnTime IS calcBurnTime(deltaV).
    waitAngle(shipDirection).
    waitPeriod(ETA:APOAPSIS - (burnTime / 2)).
    LOCAL previousApsisDiff IS ABS(SHIP:PERIAPSIS - SHIP:APOAPSIS) + 10.
    LOCAL apsisDiff IS ABS(SHIP:PERIAPSIS - SHIP:APOAPSIS).
    UNTIL apsisDiff > previousApsisDiff OR apsisDiff < 10 { // Quit within 10 meters or if we overshoot
        LOCK THROTTLE TO 1.
        SET previousApsisDiff TO ABS(SHIP:PERIAPSIS - SHIP:APOAPSIS).
        WAIT 0.001.
    }
    LOCK THROTTLE TO 0.
    UNLOCK ALL.
}

FUNCTION waitAngle {
    PARAMETER direction.
    LOCK STEERING TO R(direction:pitch,direction:yaw,direction:roll).
    WAIT UNTIL (ship:facing:pitch >= (round(direction:pitch) - 5) AND ship:facing:roll >= (round(direction:roll) - 5)) AND (ship:facing:pitch <= (round(direction:pitch) + 5) AND ship:facing:roll <= (round(direction:roll) + 5)).
}

// ====================
// === Calculations ===
// ====================

FUNCTION calcMeanISP {
    // Get average ISP of all engines.
    // http://wiki.kerbalspaceprogram.com/wiki/Tutorial:Advanced_Rocket_Design
    LOCAL sumISP IS 0.
    LIST ENGINES IN myEngines.
    FOR engine IN myEngines {
        IF engine:ISP > 0 {
            SET sumISP TO sumISP + engine:ISP.
        }
    }
    RETURN sumISP / myEngines:LENGTH.
}

FUNCTION calcTotalISP {
    // Get average ISP of all engines.
    // http://wiki.kerbalspaceprogram.com/wiki/Tutorial:Advanced_Rocket_Design
    LOCAL sumISP IS 0.
    LIST ENGINES IN myEngines.
    FOR engine IN myEngines {
        IF engine:ISP > 0 {
            SET sumISP TO sumISP + engine:ISP.
        }
    }
    RETURN sumISP.
}

FUNCTION calcMaxThrustLimited {
    LOCAL maxThrustLimited IS 0.
    LIST ENGINES IN myEngines.
    FOR engine IN myEngines {
        IF engine:ISP > 0 {
            SET maxThrustLimited TO maxThrustLimited + (engine:MAXTHRUST * (engine:THRUSTLIMIT / 100) ).
        }
    }
    RETURN maxThrustLimited.
}

FUNCTION calcBurnTime {
    PARAMETER deltaV.

    // Get average ISP of all engines.
    // http://wiki.kerbalspaceprogram.com/wiki/Tutorial:Advanced_Rocket_Design
    LOCAL sumISP IS 0.
    LOCAL maxThrustLimited IS 0.
    LIST ENGINES IN myEngines.
    FOR engine IN myEngines {
        IF engine:ISP > 0 {
            SET sumISP TO sumISP + (engine:MAXTHRUST / engine:ISP).
            SET maxThrustLimited TO maxThrustLimited + (engine:MAXTHRUST * (engine:THRUSTLIMIT / 100) ).
        }
    }
    LOCAL massFlowRate IS ( maxThrustLimited / sumISP ).
    LOCAL velocity IS massFlowRate * (SHIP:BODY:MU / SHIP:BODY:RADIUS^2).
    RETURN (SHIP:MASS * velocity / maxThrustLimited) * (1 - CONSTANT:E^(-deltaV/velocity)).
}

FUNCTION calcChangePeriapsisDeltaV {
    PARAMETER targetAltitude IS SHIP:APOAPSIS.

    // radius at apoapsis
    LOCAL apoapsisRadius IS SHIP:BODY:RADIUS + SHIP:APOAPSIS.
    LOCAL periapsisRadius IS SHIP:BODY:RADIUS + SHIP:PERIAPSIS.
    LOCAL targetPeriapsisRadius IS SHIP:BODY:RADIUS + targetAltitude.
    LOCAL targetSemiMajorAxis IS (targetPeriapsisRadius + apoapsisRadius) / 2.

    //Vis-viva equation to give speed we'll have at apoapsis.
    LOCAL apoapsisVelocity IS SQRT(SHIP:BODY:MU * ((2 / apoapsisRadius) - (1 / SHIP:ORBIT:SEMIMAJORAXIS))).
    //Vis-viva equation to calculate speed we want at apoapsis for a circular orbit.
    //For a circular orbit, desired SMA = radius of apoapsis.
    LOCAL targetVelocity IS SQRT(SHIP:BODY:MU * ((2 / targetPeriapsisRadius) - (1 / targetSemiMajorAxis))).
    LOCAL deltaV IS targetVelocity - apoapsisVelocity.

    RETURN calcBurnTime(deltaV).
}
