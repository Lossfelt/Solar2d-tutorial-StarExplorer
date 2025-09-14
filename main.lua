local composer = require( "composer" )
 
-- Hide status bar
display.setStatusBar( display.HiddenStatusBar )
 
-- Seed the random number generator
math.randomseed( os.time() )

-- Reserve channel 1 for background music
audio.reserveChannels( 1 )
-- Reduce the overall volume of the channel
audio.setVolume( 0.5, { channel=1 } )

-- Funksjon som slår på «immersive sticky» på Android
local function applyImmersive()
    if system.getInfo("platform") == "android" then
        native.setProperty("androidSystemUiVisibility", "immersiveSticky")
    end
end

-- Kjør ved oppstart (etter første frame for sikker timing)
timer.performWithDelay(0, applyImmersive)

-- Re-aktiver når appen gjenopptas eller skjermen endrer størrelse
local function onSystemEvent(e)
    if e.type == "applicationStart" or e.type == "applicationResume" then
        applyImmersive()
    end
end
Runtime:addEventListener("system", onSystemEvent)
Runtime:addEventListener("resize", applyImmersive)  -- nyttig ved tastatur/rotasjon
 
-- Go to the menu screen
composer.gotoScene( "menu" )