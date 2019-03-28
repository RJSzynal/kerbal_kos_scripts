// Sources:  http://forum.kerbalspaceprogram.com/threads/40053-Estimate-the-duration-of-a-burn

FUNCTION awaitNode {
    PARAMETER node IS NEXTNODE.
    waitPeriod(node:ETA - (calcBurnTime(node:DELTAV) / 2) + 5).
}

FUNCTION waitPeriod {
    PARAMETER secondsToWait.
    LOCAL startTime IS TIME:SECONDS.
    LOCAL elapsedTime IS TIME:SECONDS - startTime.
    UNTIL elapsedTime > secondsToWait {
        SET elapsedTime TO TIME:SECONDS - startTime.
        SET remainingTime TO secondsToWait - elapsedTime.
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
        PRINT "Remaining time:  " + ROUND(remainingTime,2) at (TERMINAL:WIDTH - 25,5).
        PRINT "   Warp factor:  " + KUNIVERSE:TIMEWARP:WARP at (TERMINAL:WIDTH - 25,6).
        IF KUNIVERSE:TIMEWARP:WARP > maxwarp {
            SET KUNIVERSE:TIMEWARP:WARP TO maxwarp.
        }
    }
    PRINT "                         " at (TERMINAL:WIDTH - 25,5).
    PRINT "                         " at (TERMINAL:WIDTH - 25,6).
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
}

FUNCTION launchToTargetHeight {
    PARAMETER targetHeight is 80000.
    Parameter maxStage IS 3.
    LOCK STEERING TO HEADING(90,90).
    LOCK THROTTLE TO 1.

    autoStaging(maxStage).

    WAIT UNTIL SHIP:APOAPSIS >= targetHeight.

    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION launchToOrbit {
    bodyProps().
    PARAMETER targetHeight is lorb.
    Parameter maxStage IS 2.
    IF BODY:NAME = "Kerbin" {
        // trajectory parameters
        SET gravityTurn0 TO 1000.
        SET gravityTurn1 TO 50000.
        SET pitch0 TO 0.
        SET pitch1 TO 90.
        // velocity parameters
        SET maxq TO 7000.
    }
    SET throttleSet TO 1.
    LOCK THROTTLE TO throttleSet.
    LOCK STEERING TO heading(90,90) + R(0, 0, 0).
    PRINT "T-1  All systems GO. Ignition!".
    SET altRadarRamp TO ALT:RADAR + 25.               // ramp altitude
    when ALT:RADAR > altRadarRamp THEN {
        PRINT "T+" + ROUND(elapsedMissionTime) + " Liftoff".
        RETURN false.
    }
    when ALT:RADAR > gravityTurn0 THEN {
        PRINT "T+" + ROUND(elapsedMissionTime) + " Beginning gravity turn".
        RETURN false.
    }
    WAIT 1.
    SET startMissionTime TO TIME:SECONDS.
    PRINT "T+" + ROUND(elapsedMissionTime) + " Ignition".

    autoStaging(2).

    // control speed and attitude
    SET pitch TO 0.
    UNTIL ALTITUDE > BODY:ATM:HEIGHT or APOAPSIS > targetHeight {
        SET altRadar TO ALT:RADAR.
        // control attitude
        IF altRadar > gravityTurn0 and altRadar < gravityTurn1 {
            SET arr TO (altRadar - gravityTurn0) / (gravityTurn1 - gravityTurn0).
            SET pda TO (cos(arr * 180) + 1) / 2.
            SET pitch TO pitch1 * ( pda - 1 ).
            LOCK STEERING TO heading(90,90) + R(0, pitch, 0).
        }
        IF altRadar > gravityTurn1 {
            LOCK STEERING TO heading(90,90) + R(0, pitch, 0).
        }
        // dynamic pressure q
        SET exp TO -ALTITUDE/sh.
        SET atmosphericDensity TO BODY:ATM:SEALEVELPRESSURE * CONSTANT:E^exp.    // atmospheric density
        // SET q TO 0.5 * atmosphericDensity * VELOCITY:SURFACE:MAG^2.
        SET q TO 0.5 * BODY:ATM:ALTITUDEPRESSURE(ALTITUDE) * VELOCITY:SURFACE:MAG^2.
        // calculate target velocity
        SET velocityLow TO maxq*0.9.
        SET velocityHigh TO maxq*1.1.
        IF q < velocityLow { SET throttleSet TO 1. }
        IF q > velocityLow and q < velocityHigh { SET throttleSet TO (velocityHigh-q)/(velocityHigh-velocityLow). }
        IF q > velocityHigh { SET throttleSet TO 0. }
        WAIT 0.1.
    }
    SET throttleSet TO 0.
    IF ALTITUDE < BODY:ATM:HEIGHT {
        PRINT "T+" + ROUND(elapsedMissionTime) + " Waiting to leave atmosphere".
        LOCK STEERING TO heading(90,90) + R(0, pitch, 0).       // roll for orbital orientation
        // thrust to compensate atmospheric drag losses
        UNTIL ALTITUDE > BODY:ATM:HEIGHT {
            // calculate target velocity
            IF APOAPSIS >= targetHeight { SET throttleSet TO 0. }
            IF APOAPSIS < targetHeight { SET throttleSet TO (targetHeight-apoapsis)/(targetHeight*0.01). }
            WAIT 0.1.
        }
    }
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION circulariseOrbit {
    IF SHIP:VERTICALSPEED < 0 AND SHIP:PERIAPSIS < SHIP:BODY:ATM:HEIGHT { PRINT "T+" + round(missiontime) + " Ship has passed apoapsis and will enter the atmosphere". }
    LOCAL deltaV IS calcChangePeriapsisDeltaV(SHIP:APOAPSIS).
    // ====== THIS NEEDS REDOING, THE DIRECTION IS WRONG. IT NEEDS TO BE PRO/RETROGRADE AT APOAPSIS NOT AT EACH POINT IN TIME =========
    IF deltaV < 0 {
        LOCK shipDirection TO SHIP:RETROGRADE.
        PRINT "T+" + round(missiontime) + " Ship direction set to Retrograde".
    } ELSE {
        LOCK shipDirection TO SHIP:PROGRADE.
        PRINT "T+" + round(missiontime) + " Ship direction set to Prograde".
    }
    // ================================================================================================================================
    LOCAL burnTime IS calcBurnTime(deltaV).
    waitAngle(shipDirection).
    LOCAL waitTime IS ETA:APOAPSIS - (burnTime / 2).
    PRINT "T+" + round(missiontime) + " Entering wait period of " + waitTime + "s".
    waitPeriod(waitTime).
    LOCK apsisDiff TO ABS(SHIP:PERIAPSIS - SHIP:APOAPSIS).
    LOCAL previousApsisDiff IS apsisDiff + 10.
    PRINT "T+" + round(missiontime) + " Beginning burn".
    UNTIL apsisDiff < 10 or apsisDiff > previousApsisDiff { // Quit within 10 meters
        PRINT "Apsis diff:  " + ROUND(apsisDiff,2) at (TERMINAL:WIDTH - 30,5).
        LOCK THROTTLE TO 1.
        SET previousApsisDiff TO apsisDiff.
        WAIT 0.1.
    }
    PRINT "                              " at (TERMINAL:WIDTH - 30,5).
    PRINT "T+" + round(missiontime) + " Ending burn".
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    UNLOCK shipDirection.
    UNLOCK apsisDiff.
}

FUNCTION autoStaging {
    PARAMETER maxStage is 3.
    WHEN SHIP:MAXTHRUST = 0 THEN {
        STAGE.
        IF STAGE:NUMBER >= maxStage {
            RETURN true.
        } ELSE {
            RETURN false.
        }
    }
}

FUNCTION waitAngle {
    PARAMETER targetDirection.
    PARAMETER tolerance IS 0.03.

    LOCK STEERING TO targetDirection.
    WAIT UNTIL ABS(SIN(targetDirection:PITCH) - SIN(SHIP:FACING:PITCH)) < tolerance and ABS(SIN(targetDirection:YAW) - SIN(SHIP:FACING:YAW)) < tolerance and ABS(SIN(targetDirection:ROLL) - SIN(SHIP:FACING:ROLL)) < tolerance.
}

FUNCTION createCircularisationNode {
    PARAMETER targetAltitude IS SHIP:APOAPSIS.
    LOCAL node IS NODE(TIME:SECONDS + ETA:APOAPSIS, 0, 0, calcChangePeriapsisDeltaV(targetAltitude)).
    ADD node.
    RETURN node.
}

FUNCTION doNodeDeltaV {
    PARAMETER node IS NEXTNODE.
    LOCAL maxThrustLimited IS calcMaxThrustLimited().
    LOCAL initialSASState IS SAS.

    SAS OFF.
    LOCK steering TO node.

    awaitNode(node).

    LOCAL throttlePosition IS 0.
    LOCK THROTTLE TO throttlePosition.
    LOCAL oldDeltaV IS node:DELTAV:MAG + 1.
    UNTIL node:DELTAV:MAG < 1 or node:DELTAV:MAG > oldDeltaV {
        LOCAL availableDeltaV IS maxThrustLimited * THROTTLE / SHIP:MASS.
        LOCAL throttleTarget IS node:DELTAV:MAG * SHIP:MASS / maxThrustLimited.
        IF node:DELTAV:MAG < 2*availableDeltaV and throttleTarget > 0.1 {
            SET throttlePosition TO throttleTarget.
        }
        IF node:DELTAV:MAG > 2*availableDeltaV {
            SET throttlePosition TO 1.
        }
        SET oldDeltaV TO node:DELTAV:MAG.
    }
    // compensate 1m/s due to "until" stopping short; nd:deltav:mag never gets to 0!
    IF availableDeltaV <> 0 {
        WAIT 1/availableDeltaV.
    }
    LOCK THROTTLE TO 0.

    UNLOCK STEERING.
    UNLOCK THROTTLE.
    SAS initialSASState.
}

FUNCTION suicideBurn {
    PARAMETER radarAltOffset.                                          // alt:radar value when landed (KSP measures from part way up the ship)
    LOCK actualAlt TO alt:radar - radarAltOffset.                      // Get the actual ship altitude
    LOCK shipGravity TO CONSTANT:G * BODY:MASS / BODY:RADIUS^2.        // Gravity effect on ship
    LOCK maxDecel TO (SHIP:AVAILABLETHRUST / SHIP:MASS) - shipGravity. // Maximum deceleration
    LOCK stopDistance TO SHIP:VERTICALSPEED^2 / (2 * maxDecel).        // Distance required to stop
    LOCK targetThrottle TO stopDistance / actualAlt.                   // Throttle position required for suicide burn
    LOCK timeRemaining TO actualAlt / ABS(SHIP:VERTICALSPEED).         // Time left for suicide burn

    UNTIL SHIP:VERTICALSPEED < -10 {
        RCS ON.
        SAS OFF.
        BRAKES ON.
        LOCK STEERING TO SRFRETROGRADE.
        WHEN timeRemaining < 5 THEN { GEAR ON. }
        WAIT 0.001.
    }
    UNTIL actualAlt <= stopDistance {
        IF targetThrottle > 0.4 { // Minimum throttle on Falcon 9 is 40%
            LOCK THROTTLE TO targetThrottle.
        } ELSE {
            LOCK THROTTLE TO 0.
        }
        WAIT 0.001.
    }
    UNTIL SHIP:VERTICALSPEED > -0.1 {
        SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
        RCS OFF.
        WAIT 0.001.
    }
    UNLOCK actualAlt.
    UNLOCK shipGravity.
    UNLOCK maxDecel.
    UNLOCK stopDistance.
    UNLOCK targetThrottle.
    UNLOCK timeRemaining.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION turnToSun {
    PRINT "T+" + ROUND(missiontime) + " Turning ship to expose solar panels.".
    waitAngle(R(-90,0,0),0.01).
}

FUNCTION bodyProps {
    if SHIP:BODY:NAME = "Kerbin" {
        set sh to 5000.          // scale height (atmosphere) [m]
        set lorb to 80_000.      // low orbit altitude [m]
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Mun" {
        set lorb to 14_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Minmus" {
        set lorb to 10_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Kerbol" {
        set sh to 5000.
        set lorb to 610_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Eeloo" {
        set lorb to 10_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Moho" {
        set lorb to 20_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Eve" {
        set sh to 5000.
        set lorb to 100_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Gilly" {
        set lorb to 10_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Duna" {
        set sh to 5000.
        set lorb to 60_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Ike" {
        set lorb to 10_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Dres" {
        set lorb to 12_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Jool" {
        set sh to 5000.
        set lorb to 210_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Laythe" {
        set sh to 5000.
        set lorb to 60_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Vall" {
        set lorb to 15_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Tylo" {
        set lorb to 10_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Bop" {
        set lorb to 30_000.
        set bodyPropSet to True.
    }
    else if SHIP:BODY:NAME = "Pol" {
        set lorb to 10_000.
        set bodyPropSet to True.
    }
    else {
        set lorb to 620_000.
        print "T+" + round(missiontime) + " WARNING: no body properties for " + SHIP:BODY:NAME + "! Low orbit set to 610,000km".
    }
    set mu to SHIP:BODY:MU.  // gravitational parameter, mu = G mass
    set rb to SHIP:BODY:RADIUS.           // Radius of body [m]
    set soi to SHIP:BODY:SOIRADIUS.        // sphere of influence [m]
    set ad0 to SHIP:BODY:ATM:SEALEVELPRESSURE. // atmospheric density at msl [kg/m^3]
    set ha to SHIP:BODY:ATM:HEIGHT.            // atmospheric height [m]
    set euler to CONSTANT:E.
    set pi to CONSTANT:PI.
    // fix NaN and Infinity push on stack errors, https://github.com/KSP-KOS/KOS/issues/152
    set CONFIG:SAFE to FALSE.
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

    RETURN targetVelocity - apoapsisVelocity.
}

FUNCTION experiment {
    LOCK currentRadius to ALTITUDE + SHIP:BODY:RADIUS.
    LOCK periapsisRadius to PERIAPSIS + SHIP:BODY:RADIUS.
    LOCK apoapsisRadius to APOAPSIS + SHIP:BODY:RADIUS.

    LOCK circularSpeed to SQRT(SHIP:BODY:MU/currentRadius).
    LOCK perpendicularSpeed to SQRT(((1+SHIP:OBT:ECCENTRICITY)*SHIP:BODY:MU)/((1-SHIP:OBT:ECCENTRICITY)*SHIP:OBT:SEMIMAJORAXIS)).
    LOCK angularMomentum to perpendicularSpeed*periapsisRadius.

    LOCK Vperpendicular to angularMomentum/currentRadius.
    LOCK Pitch to 90-VECTORANGLE(UP:VECTOR,PROGRADE:VECTOR).

    LOCK DeltaVX to circularSpeed-Vperpendicular.
    LOCK DeltaVY to -VERTICALSPEED.

    LOCK PitchAxis to VCRS(UP:VECTOR,PROGRADE:VECTOR).
    LOCK XDirection to ANGLEAXIS(Pitch,PitchAxis).
    LOCK DeltaV to DeltaVX*XDirection:VECTOR + DeltaVY*UP:VECTOR.

    LOCK DeltaVDirection to DeltaV:DIRECTION.
}