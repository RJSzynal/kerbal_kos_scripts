// Sources:  http://forum.kerbalspaceprogram.com/threads/40053-Estimate-the-duration-of-a-burn

FUNCTION initMission {
    PARAMETER missionName.
    initGlobals().
    CLEARSCREEN.
    PRINT missionName + ": " + TIME:CALENDAR + ", " + TIME:CLOCK.
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.01.
}

FUNCTION initGlobals {
    GLOBAL lowOrbitAltitudeLexicon IS LEXICON(
        "Kerbin", 80_000,
        "Mun", 14_000,
        "Minmus", 10_000,
        "Kerbol", 610_000,
        "Eeloo", 10_000,
        "Moho", 20_000,
        "Eve", 100_000,
        "Gilly", 10_000,
        "Duna", 60_000,
        "Ike", 10_000,
        "Dres", 12_000,
        "Jool", 210_000,
        "Laythe", 60_000,
        "Vall", 15_000,
        "Tylo", 10_000,
        "Bop", 30_000,
        "Pol", 10_000
    ).
    GLOBAL startMissionTime IS MISSIONTIME.
    GLOBAL radarAltOffset IS ALT:RADAR.                                       // alt:radar value when landed (KSP measures from part way up the ship)
    // SET radarAltOffset TO 7.06443023681641.
    LOCK lowOrbitAltitude TO lowOrbitAltitudeLexicon[SHIP:BODY:NAME].
    LOCK shipApoapsisRadius TO calcRadiusFromAltitude(SHIP:APOAPSIS).
    LOCK shipPeriapsisRadius TO calcRadiusFromAltitude(SHIP:PERIAPSIS).
    LOCK shipBaseAltitude TO ALT:RADAR - radarAltOffset.                          // Get the actual ship altitude
    LOCK bodyGravityAccel TO SHIP:BODY:MU / SHIP:BODY:RADIUS^2.                   // Gravity effect on ship
    LOCK shipMaxDecel TO (SHIP:AVAILABLETHRUST / SHIP:MASS) - bodyGravityAccel.   // Maximum deceleration
    LOCK suicideStopDistance TO SHIP:VERTICALSPEED^2 / (2 * shipMaxDecel).        // Distance required to stop
    LOCK suicideTimeRemaining TO shipBaseAltitude / ABS(SHIP:VERTICALSPEED).      // Time left for suicide burn
}

FUNCTION initBodyProps {
    IF SHIP:BODY:NAME = "Kerbin" {
        // trajectory parameters
        SET gravityTurn0 TO 1000.
        SET gravityTurn1 TO 50000.
        SET pitch0 TO 0.
        SET pitch1 TO 90.
        // velocity parameters
        SET maxDynamicPressure TO 70. // was 7000.
    }
    ELSE {
        printMissionMessage("WARNING: no body properties for " + SHIP:BODY:NAME + "!").
    }
}

FUNCTION initAutoStaging {
    WHEN SHIP:MAXTHRUST = 0 THEN {
        STAGE.
        IF SHIP:MAXTHRUST > 0 {
            RETURN true.
        } ELSE {
            RETURN false.
        }
    }
}

FUNCTION initParachutes {
    IF SHIP:BODY:ATM:EXISTS {
        WHEN SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT THEN {
            STAGE.
            RETURN false.
        }
    }
}

FUNCTION doSuicideBurn {
    WAIT UNTIL SHIP:VERTICALSPEED < -100.

    printMissionMessage("Beginning controlled descent").
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SAS OFF.
    RCS ON.
    IF SHIP:BODY:ATM:EXISTS {
        BRAKES ON.
    }
    LOCK STEERING TO SRFRETROGRADE.
    WHEN suicideTimeRemaining < 5 THEN { GEAR ON. }

    WAIT UNTIL shipBaseAltitude <= suicideStopDistance.

    printMissionMessage("Beginning suicide burn").
    LOCK THROTTLE TO suicideStopDistance / shipBaseAltitude.
    WAIT UNTIL SHIP:VERTICALSPEED > -0.1.

    printMissionMessage("Landed").
    RCS OFF.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION doSuicideBurnAlt {
    UNTIL SHIP:VERTICALSPEED < -50 { WAIT 0.01. }

    printMissionMessage("Beginning controlled descent").
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SAS OFF.
    LOCK STEERING TO SRFRETROGRADE.
    WHEN suicideTimeRemaining < 5 THEN { GEAR ON. }
    LOCK THROTTLE TO 0.
    UNTIL shipBaseAltitude <= suicideStopDistance {
        // LOCAL suicideThrottle IS suicideStopDistance / shipBaseAltitude.

        // PRINT "suicideTargetThrottle:  " + ROUND(suicideTargetThrottle, 4) at (TERMINAL:WIDTH - 40,6).
        // LOCAL throttlePressureControl IS calcThrottleForDynamicPressureControl(true).
        // PRINT "throttlePressureControl:  " + ROUND(throttlePressureControl, 4) at (TERMINAL:WIDTH - 40,7).
        // LOCAL suicideThrottle IS MAX(suicideTargetThrottle, throttlePressureControl).
        // PRINT "suicideThrottle:  " + ROUND(suicideThrottle, 4) at (TERMINAL:WIDTH - 40,8).

        // IF suicideThrottle > 0.4 { // Minimum throttle on Falcon 9 is 40%
        //     LOCK THROTTLE TO suicideThrottle.
        // } ELSE {
        //     LOCK THROTTLE TO 0.
        // }
        WAIT 0.001.
    }

    printMissionMessage("Beginning suicide burn").
    RCS ON.
    LOCK THROTTLE TO 1.
    UNTIL SHIP:VERTICALSPEED > -0.1 { WAIT 0.001. }

    printMissionMessage("Landed").
    RCS OFF.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION doLaunchToTargetHeight {
    initBodyProps().
    PARAMETER targetHeight is lowOrbitAltitude.
    LOCAL missionStartDelay IS 1.
    SET throttleSet TO 1.
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    RCS ON.
    SAS OFF.
    LOCK THROTTLE TO throttleSet.
    LOCK STEERING TO HEADING(90,90).

    printMissionMessage("All systems GO", -missionStartDelay).
    LOCAL altRadarLaunchPad IS ALT:RADAR + 25. // Launch Pad altitude
    WHEN ALT:RADAR > altRadarLaunchPad THEN {
        IF GEAR {
            GEAR OFF.
        }
        printMissionMessage("Liftoff").
        RETURN false.
    }
    WAIT missionStartDelay.
    SET startMissionTime TO MISSIONTIME.

    printMissionMessage("Ignition").
    initAutoStaging().

    UNTIL SHIP:APOAPSIS >= targetHeight {
        SET throttleSet TO calcThrottleForDynamicPressureControl().
    }
    IF SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT {
        printMissionMessage("Waiting to leave atmosphere").
        // thrust to compensate atmospheric drag losses
        UNTIL SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT {
            // calculate target velocity
            IF SHIP:APOAPSIS >= targetHeight { SET throttleSet TO 0. }
            IF SHIP:APOAPSIS < targetHeight { SET throttleSet TO (targetHeight-SHIP:APOAPSIS)/(targetHeight/100). }
            WAIT 0.1.
        }
    }
    printMissionMessage("Exited atmosphere").
    LOCK THROTTLE TO 0.
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
    RCS OFF.
    SAS ON.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION doLaunchToOrbit {
    initBodyProps().
    PARAMETER targetHeight is lowOrbitAltitude.
    LOCAL missionStartDelay IS 1.
    SET throttleSet TO 1.
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    LOCK THROTTLE TO throttleSet.
    LOCK STEERING TO heading(90,90).

    printMissionMessage("All systems GO", -missionStartDelay).
    LOCAL altRadarLaunchPad IS ALT:RADAR + 25. // Launch Pad altitude
    WHEN ALT:RADAR > altRadarLaunchPad THEN {
        IF GEAR {
            GEAR OFF.
        }
        printMissionMessage("Liftoff").
        RETURN false.
    }
    WHEN ALT:RADAR > gravityTurn0 THEN {
        printMissionMessage("Beginning gravity turn").
        RETURN false.
    }
    WAIT missionStartDelay.
    SET startMissionTime TO MISSIONTIME.
    printMissionMessage("Ignition").

    initAutoStaging().

    // control speed and attitude
    SET targetPitch TO 0.
    UNTIL SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT or SHIP:APOAPSIS > targetHeight {
        SET altRadar TO ALT:RADAR.
        // control attitude
        IF altRadar > gravityTurn0 and altRadar < gravityTurn1 {
            SET arr TO (altRadar - gravityTurn0) / (gravityTurn1 - gravityTurn0).
            SET pda TO (cos(arr * 180) + 1) / 2.
            SET targetPitch TO pitch1 * ( pda - 1 ).
            LOCK STEERING TO heading(90,90) + R(0, targetPitch, 0).
        }
        IF altRadar > gravityTurn1 {
            LOCK STEERING TO heading(90,90) + R(0, targetPitch, 0).
        }
        SET throttleSet TO calcThrottleForDynamicPressureControl().
        WAIT 0.1.
    }
    SET throttleSet TO 0.
    IF SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT {
        printMissionMessage("Waiting to leave atmosphere").
        LOCK STEERING TO heading(90,90) + R(0, targetPitch, 0). // roll for orbital orientation
        // thrust to compensate atmospheric drag losses
        UNTIL SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT {
            // calculate target velocity
            IF SHIP:APOAPSIS >= targetHeight { SET throttleSet TO 0. }
            IF SHIP:APOAPSIS < targetHeight { SET throttleSet TO (targetHeight-SHIP:APOAPSIS)/(targetHeight*0.01). }
            WAIT 0.1.
        }
    }
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION doCirculariseOrbit {
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    IF SHIP:VERTICALSPEED < 0 AND SHIP:PERIAPSIS < SHIP:BODY:ATM:HEIGHT { printMissionMessage("Ship has passed apoapsis and will enter the atmosphere"). }
    LOCAL deltaV IS calcChangePeriapsisDeltaV(SHIP:APOAPSIS).
    // ====== THIS NEEDS REDOING, THE DIRECTION IS WRONG. IT NEEDS TO BE PRO/RETROGRADE AT APOAPSIS NOT AT EACH POINT IN TIME =========
    IF deltaV < 0 {
        LOCK shipDirection TO SHIP:RETROGRADE.
        printMissionMessage("Ship direction set to Retrograde").
    } ELSE {
        LOCK shipDirection TO SHIP:PROGRADE.
        printMissionMessage("Ship direction set to Prograde").
    }
    // ================================================================================================================================
    LOCAL burnTime IS calcBurnTime(deltaV).
    doAwaitAngle(shipDirection).
    LOCAL waitTime IS ETA:APOAPSIS - (burnTime / 2).
    printMissionMessage("Entering wait period of " + waitTime + "s").
    doWaitPeriod(waitTime).
    LOCK apsisDiff TO ABS(SHIP:PERIAPSIS - SHIP:APOAPSIS).
    LOCAL previousApsisDiff IS apsisDiff + 10.
    printMissionMessage("Beginning burn").
    UNTIL apsisDiff < 10 or apsisDiff > previousApsisDiff { // Quit within 10 meters
        PRINT "Apsis diff:  " + ROUND(apsisDiff,2) at (TERMINAL:WIDTH - 30,5).
        LOCK THROTTLE TO 1.
        SET previousApsisDiff TO apsisDiff.
        WAIT 0.1.
    }
    PRINT "                              " at (TERMINAL:WIDTH - 30,5).
    printMissionMessage("Ending burn").
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    UNLOCK shipDirection.
    UNLOCK apsisDiff.
}

FUNCTION doCircularisation {
    printMissionMessage("Beginning circularisation").
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    IF CAREER():CANMAKENODES {
        SET circNode TO createChangePeriapsisAltitudeNode().
        doNodeDeltaV(circNode).
    } ELSE {
        doCirculariseOrbit().
    }
}

FUNCTION doNodeDeltaV {
    PARAMETER thisNode IS NEXTNODE.

    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SAS OFF.
    LOCK THROTTLE TO 0.
    LOCK STEERING TO thisNode:DELTAV:DIRECTION.

    doAwaitNode(thisNode, 5).
    WAIT 5.

    LOCAL throttlePosition IS 0.
    LOCK THROTTLE TO throttlePosition.
    LOCAL oldDeltaV IS thisNode:DELTAV:MAG.
    LOCAL availableDeltaV IS SHIP:AVAILABLETHRUST * THROTTLE / SHIP:MASS.
    UNTIL thisNode:DELTAV:MAG < 1 or thisNode:DELTAV:MAG > oldDeltaV + 1 {
        SET availableDeltaV TO SHIP:AVAILABLETHRUST * THROTTLE / SHIP:MASS.
        LOCAL throttleTarget IS thisNode:DELTAV:MAG * SHIP:MASS / SHIP:AVAILABLETHRUST.
        IF thisNode:DELTAV:MAG < 2*availableDeltaV and throttleTarget > 0.1 {
            SET throttlePosition TO throttleTarget.
        }
        IF thisNode:DELTAV:MAG > 2*availableDeltaV {
            SET throttlePosition TO 1.
        }
        SET oldDeltaV TO thisNode:DELTAV:MAG.
    }
    // compensate 1m/s due to "until" stopping short; nd:deltav:mag never gets to 0!
    IF availableDeltaV <> 0 {
        WAIT 1/availableDeltaV.
    }
    LOCK THROTTLE TO 0.
    REMOVE circnode.

    UNLOCK STEERING.
    UNLOCK THROTTLE.
    SAS ON.
}

FUNCTION doNodeDeltaT {
    PARAMETER thisNode IS NEXTNODE.

    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    SAS OFF.
    LOCK STEERING TO thisNode:DELTAV:DIRECTION.

    doAwaitNode(thisNode, 5).
    WAIT 5.

    LOCAL burnTime IS calcBurnTime(thisNode:DELTAV).
    LOCAL burnTimeStart IS TIME:SECONDS.
    UNTIL TIME:SECONDS >= burnTimeStart + burnTime {
        LOCK THROTTLE TO 1.
    }
    LOCK THROTTLE TO 0.

    UNLOCK STEERING.
    UNLOCK THROTTLE.
    SAS ON.
}

FUNCTION doDeOrbit {
    SET KUNIVERSE:TIMEWARP:WARP TO 0.
    LOCAL targetAltitude IS 0.
    IF SHIP:BODY:ATM:EXISTS {
        SET targetAltitude TO SHIP:BODY:ATM:HEIGHT - 5_000.
    }

    printMissionMessage("Beginning de-orbit").
    doAwaitAngle(SHIP:RETROGRADE).
    UNTIL SHIP:PERIAPSIS < targetAltitude {
        LOCK THROTTLE TO 1.
    }
    LOCK THROTTLE TO 0.

    UNLOCK STEERING.
    UNLOCK THROTTLE.
}

FUNCTION doWaitPeriod {
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

FUNCTION doTurnToSun {
    printMissionMessage("Turning ship to expose solar panels").
    doAwaitAngle(R(-90,0,0),0.01).
}

FUNCTION doAwaitNode {
    PARAMETER thisNode IS NEXTNODE.
    PARAMETER earlyWakeUpSeconds IS 0.
    doWaitPeriod(thisNode:ETA - (calcBurnTime(thisNode:DELTAV:MAG) / 2) - earlywakeupseconds).
}

FUNCTION doAwaitAngle {
    PARAMETER targetDirection.
    PARAMETER tolerance IS 0.03.

    LOCK STEERING TO targetDirection.
    WAIT UNTIL ABS(SIN(targetDirection:PITCH) - SIN(SHIP:FACING:PITCH)) < tolerance and ABS(SIN(targetDirection:YAW) - SIN(SHIP:FACING:YAW)) < tolerance and ABS(SIN(targetDirection:ROLL) - SIN(SHIP:FACING:ROLL)) < tolerance.
}

FUNCTION printMissionMessage {
    PARAMETER message.
    PARAMETER time IS ROUND(MISSIONTIME - startMissionTime).
    LOCAL sign IS "+".
    IF time < 0 { SET sign TO "". }
    PRINT "T" + sign + time + " " + message.
}

FUNCTION createChangePeriapsisAltitudeNode {
    PARAMETER targetAltitude IS SHIP:APOAPSIS.
    LOCAL newNode IS NODE(TIME:SECONDS + ETA:APOAPSIS, 0, 0, calcChangePeriapsisDeltaV(targetAltitude)).
    ADD newNode.
    RETURN newNode.
}

// ====================
// === Calculations ===
// ====================

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

// REDUNDANT: SHIP:AVAILABLETHRUST
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
    PARAMETER thisDeltaV.

    LOCAL velocity IS ( SHIP:AVAILABLETHRUST / calcTotalISP() ) * (SHIP:BODY:MU / SHIP:BODY:RADIUS^2).
    RETURN (SHIP:MASS * velocity / SHIP:AVAILABLETHRUST) * (1 - CONSTANT:E^(-thisDeltaV/velocity)).
}

FUNCTION calcRadiusFromAltitude {
    PARAMETER altitudeIn IS SHIP:ALTITUDE.
    RETURN SHIP:BODY:RADIUS + altitudeIn.
}

FUNCTION calcChangePeriapsisDeltaV {
    PARAMETER targetAltitude IS SHIP:APOAPSIS.

    // radius at apoapsis
    LOCAL targetPeriapsisRadius IS calcRadiusFromAltitude(targetAltitude).
    LOCAL targetSemiMajorAxis IS (targetPeriapsisRadius + shipApoapsisRadius) / 2.

    //Vis-viva equation to give speed we'll have at apoapsis.
    LOCAL apoapsisVelocity IS SQRT(SHIP:BODY:MU * ((2 / shipApoapsisRadius) - (1 / SHIP:ORBIT:SEMIMAJORAXIS))).
    //Vis-viva equation to calculate speed we want at apoapsis for a circular orbit.
    //For a circular orbit, desired SMA = radius of apoapsis.
    LOCAL targetVelocity IS SQRT(SHIP:BODY:MU * ((2 / targetPeriapsisRadius) - (1 / targetSemiMajorAxis))).

    RETURN targetVelocity - apoapsisVelocity.
}

// Manage dynamic pressure by controlling speed
FUNCTION calcThrottleForDynamicPressureControl {
    PARAMETER isRetrograde IS false.
    LOCAL throttleRequired IS 0.
    LOCAL dynamicPressureLowerLimit IS maxDynamicPressure*0.9.
    LOCAL dynamicPressureUpperLimit IS maxDynamicPressure*1.1.
    LOCAL dynamicPressureCurrent IS SHIP:DYNAMICPRESSURE * Constant:AtmTokPa.
    IF dynamicPressureCurrent < dynamicPressureLowerLimit {
        SET throttleRequired TO 1.
    }
    IF dynamicPressureCurrent > dynamicPressureLowerLimit and dynamicPressureCurrent < dynamicPressureUpperLimit {
        SET throttleRequired TO (dynamicPressureUpperLimit - dynamicPressureCurrent)/(dynamicPressureUpperLimit - dynamicPressureLowerLimit).
    }
    IF dynamicPressureCurrent > dynamicPressureUpperLimit {
        SET throttleRequired TO 0.
    }

    IF isRetrograde {
        SET throttleRequired TO ABS(throttleRequired - 1).
    }
    RETURN throttleRequired.
}
