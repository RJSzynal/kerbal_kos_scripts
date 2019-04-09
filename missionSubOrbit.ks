// Launch
RUNONCEPATH("0:/library.ks").
initMission("Launch to sub-orbit").

// Part 1
initParachutes().
doLaunchToTargetHeight(75_000).

//Part 2
doSuicideBurn().
