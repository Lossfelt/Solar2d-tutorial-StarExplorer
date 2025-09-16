---@diagnostic disable: undefined-global

local composer = require( "composer" )

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

local physics = require("physics")
physics.start()
physics.setGravity( 0, 0 )

-- Configure image sheet
local sheetOptions = {
    frames = {
        {   -- 1) asteroid 1
            x = 0,
            y = 0,
            width = 102,
            height = 85
        },
        {   -- 2) asteroid 2
            x = 0,
            y = 85,
            width = 90,
            height = 83
        },
        {   -- 3) asteroid 3
            x = 0,
            y = 168,
            width = 100,
            height = 97
        },
        {   -- 4) ship
            x = 0,
            y = 265,
            width = 98,
            height = 79
        },
        {   -- 5) laser
            x = 98,
            y = 265,
            width = 14,
            height = 40
        },
    }
}

local objectSheet = graphics.newImageSheet( "gameObjects.png",  sheetOptions )

-- Initialize variables
local lives = 3
local score = 0
local died = false
 
local asteroidsTable = {}
 
local ship
local gameLoopTimer
local livesText
local scoreText

local backGroup
local mainGroup
local uiGroup

local explosionSound
local fireSound
local musicTrack

local moveLeftHeld, moveRightHeld = false, false
local moveSpeed = 420 -- px/sek
local btnLeft, btnRight, btnFire
local onMoveLeftTouch, onMoveRightTouch, onFireTouch
local lastTime = 0

-- Sikker sjekk for display-objekter
local function isValid(obj)
    return obj ~= nil and obj.removeSelf ~= nil
end

local asteroidShape = {-21, 38, -49, 6, -33, -44, 22, -43, 49, -2, 33, 30}
local shipNose = {0, -40, 14, -12, -14, -12}
local shipBody = {-48, 25, 48, 25, 18, -12, -18, -12}


local function createAsteroid()
    local newAsteroid = display.newImageRect( mainGroup, objectSheet, 1, 102, 85 )
    table.insert( asteroidsTable, newAsteroid )
    physics.addBody( newAsteroid, "dynamic", {shape=asteroidShape, bounce=0.8} )
    newAsteroid.myName = "asteroid"

    local whereFrom = math.random(3)
    if (whereFrom == 1) then
        -- From the left
        newAsteroid.x = -60
        newAsteroid.y = math.random(500)
        newAsteroid:setLinearVelocity(math.random(40, 120), math.random(20, 60))
     elseif ( whereFrom == 2 ) then
        -- From the top
        newAsteroid.x = math.random( display.contentWidth )
        newAsteroid.y = -60
        newAsteroid:setLinearVelocity( math.random( -40,40 ), math.random( 40,120 ) )
    elseif ( whereFrom == 3 ) then
        -- From the right
        newAsteroid.x = display.contentWidth + 60
        newAsteroid.y = math.random( 500 )
        newAsteroid:setLinearVelocity( math.random( -120,-40 ), math.random( 20,60 ) )
    end

    newAsteroid:applyTorque(math.random(-6,6))
end

local function fireLaser()
    if not isValid(ship) then return end  -- <— guard
    -- Play fire sound!
    audio.play( fireSound )
    local newLaser = display.newImageRect( mainGroup, objectSheet, 5, 14, 40 )
    physics.addBody( newLaser, "dynamic", {isSensor = true} )
    newLaser.isBullet = true
    newLaser.myName = "laser"
    newLaser.x = ship.x
    newLaser.y = ship.y
    newLaser:toBack()
    transition.to( newLaser, {y=-40, time=500, onComplete = function() display.remove(newLaser) end} )
end

local function gameLoop()
    -- Create new asteroid
    createAsteroid()
    -- Remove asteroids that have drifted off screen
    for i = #asteroidsTable, 1, -1 do
        local thisAsteroid = asteroidsTable[i]
        if (thisAsteroid.x < -100 or thisAsteroid.x > display.contentWidth + 100 or 
        thisAsteroid.y < -100 or thisAsteroid.y > display.contentHeight + 100) then
            display.remove(thisAsteroid)
            table.remove( asteroidsTable, i )
        end
    end
end

local function restoreShip()
    ship.isBodyActive = false
    ship.x = display.contentCenterX
    ship.y = display.contentHeight - 220
    -- Fade in ship
    transition.to(ship, {alpha=1, time=4000,
        onComplete = function()
            ship.isBodyActive = true
            died = false
        end
    })
end

local function endGame()
    composer.setVariable( "finalScore", score )
    composer.gotoScene( "highscores", { time=800, effect="crossFade" } )
end

local function spawnExplosion(x, y)
  local explosion = display.newEmitter({
      textureFileName = "ember.png",
      emitterType = 0,                 -- point/line/field
      duration = 0.12,                 -- kort "burst"
      maxParticles = 100,
      angle = -90, angleVariance = 360, -- i alle retninger
      speed = 240, speedVariance = 140,
      gravityy = 350,                   -- faller ned etter burst
      radialAcceleration = 0, tangentialAcceleration = 0,
      particleLifespan = 0.6, particleLifespanVariance = 0.2,
      startParticleSize = 12, startParticleSizeVariance = 6,
      finishParticleSize = 2,
      startColorRed=1, startColorGreen=0.7, startColorBlue=0.2, startColorAlpha=1,
      finishColorRed=0.9, finishColorGreen=0.3, finishColorBlue=0.05, finishColorAlpha=0,
      blendFuncSource = 770, blendFuncDestination = 1, -- additiv = «fres»
      absolutePosition = true            -- partiklene lever videre selv om emitter fjernes
  })
  explosion.x, explosion.y = x, y

  -- Rydd opp etter at partiklene har dødd (litt over maksimal lifespan)
  timer.performWithDelay(900, function() display.remove(explosion) end)
end

local function onCollision(event)
    if (event.phase == "began") then
        local obj1 = event.object1
        local obj2 = event.object2
        if ((obj1.myName=="asteroid" and obj2.myName=="laser") or
        (obj1.myName=="laser" and obj2.myName=="asteroid")) then
            -- Create visual explosion
            spawnExplosion(obj1.x, obj1.y)
            -- Remove both the laser and asteroid
            display.remove( obj1 )
            display.remove( obj2 )
            -- Play explosion sound!
            audio.play( explosionSound )
            for i=#asteroidsTable, 1, -1 do
                if (asteroidsTable[i]==obj1 or asteroidsTable[i]==obj2) then
                    table.remove( asteroidsTable, i )
                    break
                end
            end
            -- Increase score
            score = score + 100
            scoreText.text = "Score: " .. score
        elseif ((obj1.myName=="asteroid" and obj2.myName=="ship") or 
        (obj1.myName=="ship" and obj2.myName=="asteroid")) then
            if (died == false) then
                died = true
                -- Play explosion sound!
                audio.play( explosionSound )
                -- Update lives
                lives = lives - 1
                livesText.text = "Lives: " .. lives
                if lives==0 then
                    display.remove( ship )
                    ship = nil
					timer.performWithDelay( 2000, endGame )
                else
                    ship.alpha = 0
                    timer.performWithDelay( 1000, restoreShip )
                end
            end
        end
    end
end

local function onEnterFrame(event)
    -- Skip om skipet er borte (f.eks. etter at du døde)
    if not isValid(ship) then return end

    if lastTime == 0 then 
        lastTime = event.time 
        return
    end

    local dt = (event.time - lastTime) / 1000
    lastTime = event.time
    if dt > 0.1 then dt = 0.1 end  -- clamp for sikkerhets skyld

    local vx = 0
    if moveLeftHeld  then vx = vx - moveSpeed end
    if moveRightHeld then vx = vx + moveSpeed end
    if vx ~= 0 then
        ship.x = ship.x + vx * dt
        local halfW = ship.width * 0.5
        if ship.x < halfW then ship.x = halfW end
        local maxX = display.contentWidth - halfW
        if ship.x > maxX then ship.x = maxX end
    end
end

-- Hjelper: lag en “hitbox” rundt ikonene så de er lette å treffe
local function makeIconButton(parent, filename, x, y, iconW, iconH, hitScale)
    local g = display.newGroup(); parent:insert(g)
    local hitW, hitH = iconW * (hitScale or 1.4), iconH * (hitScale or 1.4)
    local hit = display.newRoundedRect(g, 0, 0, hitW, hitH, 16)
    hit.isVisible, hit.isHitTestable, hit.alpha = false, true, 0.001
    local img = display.newImageRect(g, filename, iconW, iconH)
    g.x, g.y = x, y
    return g
end

-- Touch-lyttere (hold for bevegelse, trykk for skudd)
onMoveLeftTouch = function(event)
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
        moveLeftHeld = true
    elseif event.target.isFocus and (event.phase == "ended" or event.phase == "cancelled") then
        moveLeftHeld = false
        display.getCurrentStage():setFocus(event.target, nil)
        event.target.isFocus = false
    end
    return true
end

onMoveRightTouch = function(event)
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
        moveRightHeld = true
    elseif event.target.isFocus and (event.phase == "ended" or event.phase == "cancelled") then
        moveRightHeld = false
        display.getCurrentStage():setFocus(event.target, nil)
        event.target.isFocus = false
    end
    return true
end

onFireTouch = function(event)
    if event.phase == "began" then
        display.getCurrentStage():setFocus(event.target, event.id)
        event.target.isFocus = true
        if isValid(ship) then fireLaser() end
    elseif event.target.isFocus and (event.phase == "ended" or event.phase == "cancelled") then
        display.getCurrentStage():setFocus(event.target, nil)
        event.target.isFocus = false
    end
    return true
end

-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen

	physics.pause()  -- Temporarily pause the physics engine

	-- Set up display groups
    backGroup = display.newGroup()  -- Display group for the background image
    sceneGroup:insert( backGroup )  -- Insert into the scene's view group
 
    mainGroup = display.newGroup()  -- Display group for the ship, asteroids, lasers, etc.
    sceneGroup:insert( mainGroup )  -- Insert into the scene's view group
 
    uiGroup = display.newGroup()    -- Display group for UI objects like the score
    sceneGroup:insert( uiGroup )    -- Insert into the scene's view group

	-- Load the background
    local background = display.newImageRect( backGroup, "background.png", 800, 1400 )
    background.x = display.contentCenterX
    background.y = display.contentCenterY

	-- Display the ship
	ship = display.newImageRect( mainGroup, objectSheet, 4, 98, 79 )
    ship.x = display.contentCenterX
    ship.y = display.contentHeight - 220
    physics.addBody( ship, { shape=shipNose, isSensor=true }, {shape=shipBody, isSensor=true} )
    ship.myName = "ship"
 
    -- Display lives and score
    livesText = display.newText( uiGroup, "Lives: " .. lives, 200, 80, native.systemFont, 36 )
    scoreText = display.newText( uiGroup, "Score: " .. score, 400, 80, native.systemFont, 36 )

   -- Trygge skjermgrenser
    local safeLeft   = display.safeScreenOriginX
    local safeRight  = display.safeScreenOriginX + display.safeActualContentWidth
    local safeBottom = display.safeScreenOriginY + display.safeActualContentHeight

    -- Plassering/str.
    local pad = 30
    local iconW, iconH = 80, 80      -- størrelsen på venstre/høyre-ikon
    local fireW, fireH = 120, 120    -- større skyteknapp

    -- Venstre side (to knapper ved siden av hverandre)
    local leftX1 = safeLeft + pad + iconW*0.5
    local leftX2 = leftX1 + iconW + 30
    local yBtn   = safeBottom - pad - iconH*0.5

    btnLeft  = makeIconButton(uiGroup, "left-arrow-white.png",  leftX1, yBtn, iconW, iconH, 1.6)
    btnRight = makeIconButton(uiGroup, "right-arrow-white.png", leftX2, yBtn, iconW, iconH, 1.6)

    -- Høyre side (stor FIRE)
    local fireX = safeRight - pad - fireW*0.5
    btnFire     = makeIconButton(uiGroup, "target-white.png", fireX, yBtn, fireW, fireH, 1.3)

    -- Lyttere for touch
    btnLeft:addEventListener( "touch", onMoveLeftTouch )
    btnRight:addEventListener( "touch", onMoveRightTouch )
    btnFire:addEventListener( "touch", onFireTouch )

    explosionSound = audio.loadSound( "audio/explosion.wav" )
    fireSound = audio.loadSound( "audio/fire.wav" )
    musicTrack = audio.loadStream( "audio/80s-Space-Game_Looping.wav")
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		physics.start()
        Runtime:addEventListener( "collision", onCollision )
        gameLoopTimer = timer.performWithDelay( 500, gameLoop, 0 )
        Runtime:addEventListener("enterFrame", onEnterFrame)
        -- Start the music!
        audio.play( musicTrack, { channel=1, loops=-1 } )
    end
end

-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
		timer.cancel( gameLoopTimer )

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
		Runtime:removeEventListener( "collision", onCollision )
        physics.pause()
        Runtime:removeEventListener("enterFrame", onEnterFrame)
        lastTime = 0
        if btnLeft then   btnLeft:removeEventListener( "touch", onMoveLeftTouch )  end
        if btnRight then  btnRight:removeEventListener( "touch", onMoveRightTouch ) end
        if btnFire then   btnFire:removeEventListener( "touch", onFireTouch )       end
-- (kan også display.remove(...) på knappene her hvis du ikke resirkulerer scenen)
		composer.removeScene( "game" )
        -- Stop the music!
        audio.stop( 1 )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view
    -- Dispose audio!
    audio.dispose( explosionSound )
    audio.dispose( fireSound )
    audio.dispose( musicTrack )

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
