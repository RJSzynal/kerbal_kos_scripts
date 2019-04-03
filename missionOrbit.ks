// Launch
RUNONCEPATH("0:/library.ks").
initMission("Launch to orbit").

// Part 1
doLaunchToOrbit().
doCircularisation().

printMissionMessage("Orbit achieved").
doWaitPeriod(60).

// Part 2
doDeOrbit().
doSuicideBurn().
