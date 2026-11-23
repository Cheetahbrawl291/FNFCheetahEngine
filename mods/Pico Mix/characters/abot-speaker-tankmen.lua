local characterType = ''
local characterName = ''
local looksAtPlayer = nil
local offsetData = {0, 0}
local propertyTracker = {
    {'x', nil},
    {'y', nil},
    {'color', nil},
    {'scrollFactor.x', nil},
    {'scrollFactor.y', nil},
    {'angle', nil},
    {'alpha', nil},
    {'antialiasing', nil},
    {'visible', nil}
}

local visualizerActive = nil
function onCreate()
    --[[
        This is how the script recognizes which option you chose to use.
        However, if you decide to take Abot inside another mod,
        the 'visualizerActive' variable will default to 'true' to avoid any bugs or issues.
    ]]
    if getModSetting('visualizerActive', currentModDirectory) == nil then
        visualizerActive = true
    else
        visualizerActive = getModSetting('visualizerActive', currentModDirectory)
    end

    --[[
        WARNING!!!
        Only set this variable to false if you want to set up specific shaders 
        to each individual part of Abot. Else, refer to line 385 to know how to set shaders globally.
    ]]
    if getVar('trackShader') == nil then
        setVar('trackShader', true)
    end
end

--[[ 
    Self explanatory, creates the speaker based on if it's attached to a character or not,
    and the inputted offsets. Wait, why did I explain it still?
    Because it also sets up everything needed for the script to work, duh.
]]
function createSpeaker(attachedCharacter, offsetX, offsetY)
    characterName = attachedCharacter
    offsetData = {offsetX, offsetY}
    if getCharacterType(attachedCharacter) ~= nil then
        characterType = getCharacterType(attachedCharacter)
    end

    makeAnimatedLuaSprite('tankmanBodyLeft', 'characters/addons/tankman-body')
    addAnimationByPrefix('tankmanBodyLeft', 'idle', 'tankmanBody', 24, false)
    if characterType ~= '' then
        setObjectOrder('tankmanBodyLeft', getObjectOrder(characterType..'Group'))
    end
    addLuaSprite('tankmanBodyLeft')

    makeAnimatedLuaSprite('tankmanHeadLeft', 'characters/addons/tankman-head1')
    addAnimationByPrefix('tankmanHeadLeft', 'idle', 'tankmanTop1', 24, false)
    if characterType ~= '' then
        setObjectOrder('tankmanHeadLeft', getObjectOrder(characterType..'Group') + 1)
    end
    addLuaSprite('tankmanHeadLeft')

    makeAnimatedLuaSprite('tankmanBodyRight', 'characters/addons/tankman-body')
    addAnimationByPrefix('tankmanBodyRight', 'idle', 'tankmanBody', 24, false)
    if characterType ~= '' then
        setObjectOrder('tankmanBodyRight', getObjectOrder(characterType..'Group'))
    end
    addLuaSprite('tankmanBodyRight')
    setProperty('tankmanBodyRight.flipX', true)

    makeAnimatedLuaSprite('tankmanHeadRight', 'characters/addons/tankman-head2')
    addAnimationByPrefix('tankmanHeadRight', 'idle', 'tankmanTop2', 24, false)
    if characterType ~= '' then
        setObjectOrder('tankmanHeadRight', getObjectOrder(characterType..'Group') + 1)
    end
    addLuaSprite('tankmanHeadRight')
    setProperty('tankmanHeadRight.flipX', true)

    makeLuaSprite('AbotSpeakerBGTank', 'characters/abot/stereoBG')
    if characterType ~= '' then
        setObjectOrder('AbotSpeakerBGTank', getObjectOrder(characterType..'Group'))
    end
    addLuaSprite('AbotSpeakerBGTank')

    for bar = 1, 7 do
        makeAnimatedLuaSprite('AbotSpeakerVisualizerTank'..bar, 'characters/abot/aBotViz')
        addAnimationByPrefix('AbotSpeakerVisualizerTank'..bar, 'idle', 'viz'..bar, 24, false)
        addAnimationByPrefix('AbotSpeakerVisualizerTank'..bar, 'visualizer', 'viz'..bar, 0, false)
        if characterType ~= '' then
            setObjectOrder('AbotSpeakerVisualizerTank'..bar, getObjectOrder(characterType..'Group'))
        end
        addLuaSprite('AbotSpeakerVisualizerTank'..bar)
        callMethod('AbotSpeakerVisualizerTank'..bar..'.animation.curAnim.finish')
    end

    makeLuaSprite('AbotEyesTank')
    makeGraphic('AbotEyesTank', 140, 60)
    if characterType ~= '' then
        setObjectOrder('AbotEyesTank', getObjectOrder(characterType..'Group'))
    end
    addLuaSprite('AbotEyesTank')

    makeFlxAnimateSprite('AbotPupilsTank')
    loadAnimateAtlas('AbotPupilsTank', 'characters/abot/systemEyes')
    if characterType ~= '' then
        setObjectOrder('AbotPupilsTank', getObjectOrder(characterType..'Group'))
    end
    addLuaSprite('AbotPupilsTank')

    looksAtPlayer = getPropertyFromClass('states.PlayState', 'SONG.notes['..curSection..'].mustHitSection')
    if looksAtPlayer == false then
        setProperty('AbotPupilsTank.anim.curFrame', 17)
        callMethod('AbotPupilsTank.anim.pause')
    else
        setProperty('AbotPupilsTank.anim.curFrame', 0)
        callMethod('AbotPupilsTank.anim.pause')
    end
    
    makeFlxAnimateSprite('AbotSpeakerTank')
    loadAnimateAtlas('AbotSpeakerTank', 'characters/abot/abotSystem')
    if characterType ~= '' then
        setObjectOrder('AbotSpeakerTank', getObjectOrder(characterType..'Group'))
    else
        setProperty('AbotSpeakerTank.x', offsetData[1])
        setProperty('AbotSpeakerTank.y', offsetData[2])
    end
    addLuaSprite('AbotSpeakerTank')
    setProperty('AbotSpeakerTank.anim.curFrame', getProperty('AbotSpeakerTank.anim.length') - 1)

    runHaxeCode([[
        // Visualizer Code
        import funkin.vis.dsp.SpectralAnalyzer;

        var visualizer:SpectralAnalyzer;
        function startVisualizer() {
            visualizer = new SpectralAnalyzer(FlxG.sound.music._channel.__audioSource, 7, 0.1, 40);
            visualizer.fftN = 256;
        }

        function stopVisualizer() {
            visualizer = null;
            for (i in 0...7) getLuaObject('AbotSpeakerVisualizerTank' + (i + 1)).animation.curAnim.finish();
        }

        var levels:Array<Bar>;
	    var levelMax:Int = 0;
        function updateVisualizer() {
            if (visualizer == null) {
                for (i in 0...7) getLuaObject('AbotSpeakerVisualizerTank' + (i + 1)).visible = false;
                return;
            }

            levels = visualizer.getLevels(levels);
		    var oldLevelMax = levelMax;
		    levelMax = 0;
		    for (i in 0...Std.int(Math.min(7, levels.length)))
		    {
                var visualizerBar = getLuaObject('AbotSpeakerVisualizerTank' + (i + 1));
                var animLength:Int = visualizerBar.animation.curAnim.numFrames - 1;

                var animFrame:Int = Math.round(levels[i].value * (animLength + 1));
                visualizerBar.visible = animFrame > 0;
			    animFrame = Std.int(Math.abs(FlxMath.bound((animFrame - 1), 0, animLength) - animLength));
		
                visualizerBar.animation.curAnim.curFrame = animFrame;
			    levelMax = Std.int(Math.max(levelMax, animLength - animFrame));
		    }

            if(levelMax >= 4) {
			    if(oldLevelMax <= levelMax && (levelMax >= 5 || getLuaObject('AbotSpeakerTank').anim.curFrame >= 3))
				    getLuaObject('AbotSpeakerTank').anim.play('', true);
		    }
        }

        // Shader Tracking Code
        function shaderCheck(object:String, character:String) return getLuaObject(object).shader == getAttachedCharacter(character).shader;
        function applyShader(object:String, character:String) getLuaObject(object).shader = getAttachedCharacter(character).shader;
        function shaderAtlasCheck(object:String, character:String) return game.variables.get(object).shader == getAttachedCharacter(character).shader;
        function applyAtlasShader(object:String, character:String) game.variables.get(object).shader = getAttachedCharacter(character).shader;

        function getAttachedCharacter(character:String) {
            switch(character) {
                case 'boyfriend':
                    return game.boyfriend;
                case 'dad':
                    return game.dad;
                case 'gf':
                    return game.gf;
                default:
                    return getLuaObject('AbotSpeakerTank');
            }
        }
    ]])

    if characterName ~= '' then
        if _G[characterType..'Name'] ~= characterName then
            showSpeaker(false)
        end
    end
end

-- Self explanatory. Nothing to add this time.
local speakerActive = true
function showSpeaker(value)
    for _, object in ipairs({'AbotSpeakerTank', 'AbotSpeakerBGTank', 'AbotPupilsTank', 'AbotEyesTank'}) do
        setProperty(object..'.visible', value)
    end  
    for bar = 1, 7 do
        setProperty('AbotSpeakerVisualizerTank'..bar..'.visible', value)
    end
    for _, side in ipairs({'Left', 'Right'}) do
        setProperty('tankmanBody'..side..'.visible', value)
        setProperty('tankmanHead'..side..'.visible', value)
    end

    speakerActive = value
    if visualizerActive == true then
        if value == true then 
            runHaxeFunction('startVisualizer')
        else
            runHaxeFunction('stopVisualizer')
        end
    end

    if characterType == '' and value == true then
        characterType = getCharacterType(characterName)
        setProperty('AbotSpeakerTank.x', getProperty(characterType..'.x') + offsetData[1])
        setProperty('AbotSpeakerTank.y', getProperty(characterType..'.y') + offsetData[2])
        updateTankmenProperty('x')
        updateTankmenProperty('y')
    end
end

function onEvent(eventName, value1, value2, strumTime)
    -- This is to prevent the speaker from still appearing when the attached character's gone.
    if eventName == 'Change Character' then
        if getCharacterType(value2) == characterType and value2 ~= characterName then
            showSpeaker(false)
        elseif characterName ~= '' then
            showSpeaker(true)
        end
    end
    -- This is to make Abot look at either the player or oppnent while using this camera event.
    if eventName == 'Set Camera Target' then
        for _, startStringBF in ipairs({'0', 'bf', 'boyfriend'}) do
            if stringStartsWith(string.lower(value1), startStringBF) then
                if looksAtPlayer == false then
                    playAnim('AbotPupilsTank', '', true, false, 17)
                end
            end
        end
        for _, startStringDad in ipairs({'1', 'dad', 'opponent'}) do
            if stringStartsWith(string.lower(value1), startStringDad) then
                if looksAtPlayer == true then
                    playAnim('AbotPupilsTank', '', true, false, 0)
                end
            end
        end
    end
end

function onCountdownTick(swagCounter)
    --[[
        Makes the speaker bop at the same time as the character.
        Ex: If the character only bops their head when the beat is even,
        then the speaker will also do the same.
        This will only work during the countdown.
    ]]
    if visualizerActive == false then
        if characterType == 'gf' then
            characterSpeed = getProperty('gfSpeed')
        else
            characterSpeed = 1
        end
        if characterType ~= '' then
            danceEveryNumBeats = getProperty(characterType..'.danceEveryNumBeats')
        else
            danceEveryNumBeats = 1
        end
        if swagCounter % (danceEveryNumBeats * characterSpeed) == 0 then
            playAnim('AbotSpeakerTank', '', true, false, 1)
            for bar = 1, 7 do
                playAnim('AbotSpeakerVisualizerTank'..bar, 'idle', true)
            end
        end
    end
    for i, side in ipairs({'Left', 'Right'}) do
        playAnim('tankmanBody'..side, 'idle', true)
        playAnim('tankmanHead'..side, 'idle', true)
    end
end

function onBeatHit()
    --[[
        Ditto, but it works for the entirety of the song.
    ]]
    if visualizerActive == false then
        if characterType == 'gf' then
            characterSpeed = getProperty('gfSpeed')
        else
            characterSpeed = 1
        end
        if characterType ~= '' then
            danceEveryNumBeats = getProperty(characterType..'.danceEveryNumBeats')
        else
            danceEveryNumBeats = 1
        end
        if curBeat % (danceEveryNumBeats * characterSpeed) == 0 then
            playAnim('AbotSpeakerTank', '', true, false, 1)
            for bar = 1, 7 do
                playAnim('AbotSpeakerVisualizerTank'..bar, 'idle', true)
            end
            for i, side in ipairs({'Left', 'Right'}) do
                playAnim('tankmanBody'..side, 'idle', true)
                playAnim('tankmanHead'..side, 'idle', true)
            end
        end
    end
    for i, side in ipairs({'Left', 'Right'}) do
        playAnim('tankmanBody'..side, 'idle', true)
        playAnim('tankmanHead'..side, 'idle', true)
    end
end

function onMoveCamera(character)
    -- Abot will look to the right (towards the player).
    if character == 'boyfriend' then
        if looksAtPlayer == false then
            playAnim('AbotPupilsTank', '', true, false, 17)
        end
    end
    -- Abot will look to the left (towards the opponent).
    if character == 'dad' then
        if looksAtPlayer == true then
            playAnim('AbotPupilsTank', '', true, false, 0)
        end
    end
end

function onSongStart()
    -- Starts Abot's Visualizer, if the option has been selected.
    if visualizerActive == true and speakerActive == true then
        runHaxeFunction('startVisualizer')
    end
end

function onEndSong()
    --[[
        Stops Abot's Visualizer, if the option has been selected.
        This is to prevent the speaker from tracking the menu music.
    ]]
    if visualizerActive == true then
        runHaxeFunction('stopVisualizer')
    end
end

function onUpdatePost(elapsed)
    --[[ 
        Updates Abot's Visualizer, if the option has been selected.
        Otherwise, the Visualizer's bars will disappear when the animation is finished.
    ]]
    if visualizerActive == true then
        runHaxeFunction('updateVisualizer')
    elseif speakerActive == true then
        for bar = 1, 7 do
            setProperty('AbotSpeakerVisualizerTank'..bar..'.visible', not getProperty('AbotSpeakerVisualizerTank'..bar..'.animation.finished'))
        end
    end

    --[[ 
        This is what makes Abot track properties and apply them to the entire speaker.
        It also works when the speaker isn't attached to any character, 
        as it'd be annoying to change every part of the speaker manually.
    ]]
    for property = 1, #propertyTracker do
        if characterType ~= '' then
            if propertyTracker[property][2] ~= getProperty(characterType..'.'..propertyTracker[property][1]) then
                propertyTracker[property][2] = getProperty(characterType..'.'..propertyTracker[property][1])
                setAbotSpeakerProperty(propertyTracker[property][1], propertyTracker[property][2])
            end
        else
            if propertyTracker[property][2] ~= getProperty('AbotSpeakerTank.'..propertyTracker[property][1]) then
                propertyTracker[property][2] = getProperty('AbotSpeakerTank.'..propertyTracker[property][1])
                setAbotSpeakerProperty(propertyTracker[property][1], propertyTracker[property][2])
            end
        end
        updateTankmenProperty(propertyTracker[property][1])
    end

    -- Ditto, but for shaders.
    if getVar('trackShader') == true then
        for _, object in ipairs({'AbotSpeakerTank', 'AbotPupilsTank'}) do
            if runHaxeFunction('shaderAtlasCheck', {object, characterType}) == false then
                runHaxeFunction('applyAtlasShader', {object, characterType})
            end
        end
        for bar = 1, 7 do
            if runHaxeFunction('shaderCheck', {'AbotSpeakerVisualizerTank'..bar, characterType}) == false then
                runHaxeFunction('applyShader', {'AbotSpeakerVisualizerTank'..bar, characterType})
            end
        end
        for _, object in ipairs({'AbotSpeakerBGTank', 'AbotEyesTank'}) do
            if runHaxeFunction('shaderCheck', {object, characterType}) == false then
                runHaxeFunction('applyShader', {object, characterType})
            end
        end
        for _, bodyPart in ipairs({'BodyLeft', 'BodyRight', 'HeadLeft', 'HeadRight'}) do
            if runHaxeFunction('shaderCheck', {'tankman'..bodyPart, characterType}) == false then
                runHaxeFunction('applyShader', {'tankman'..bodyPart, characterType})
            end
        end
    end

    -- These make it so the animations stop when they're supposed to, instead of looping endlessly.
    if getProperty('AbotSpeakerTank.anim.curFrame') >= 15 then
        callMethod('AbotSpeakerTank.anim.pause')
    end
    if looksAtPlayer == true then
        if getProperty('AbotPupilsTank.anim.curFrame') >= 17 then
            looksAtPlayer = false
            callMethod('AbotPupilsTank.anim.pause')
        end
    end
    if looksAtPlayer == false then
        if getProperty('AbotPupilsTank.anim.curFrame') >= 31 then
            looksAtPlayer = true
            callMethod('AbotPupilsTank.anim.pause')
        end
    end

    -- This is how we control the animations' speed depending on the 'playbackRate' for Atlas Sprites.
    setProperty('AbotSpeakerTank.anim.framerate', 24 * playbackRate)
    setProperty('AbotPupilsTank.anim.framerate', 24 * playbackRate)
end

--[[
    This function is used when you change any of the properties of the attached character, 
    or the speaker itself if it's not attached to any character. 
    This only works for the properties present in 'propertyTracker'.

    WARNING: Do not use this function if you want to change Abot Speaker's properties,
    as it is only meant to be used inside this script.
    Instead, use the 'setProperty' function as usual.
    Examples:
    setProperty('boyfriend.alpha', 0.5)     --> If attached to the BF character type.
    setProperty('dad.alpha', 0.5)           --> If attached to the Dad character type.
    setProperty('gf.alpha', 0.5)            --> If attached to the GF character type.
    setProperty('AbotSpeakerTank.alpha', 0.5)   --> If not attached to any character type.

    Other Lua functions also work the same way.
    Examples:
    - If attached to a character type:
        doTweenX('tweenTestX', 'boyfriend', 500, 3, 'linear')
        doTweenY('tweenTestY', 'dad', 200, 3, 'linear')
        doTweenColor('tweenTestColor', 'gf', 'FF0000', 3, 'linear')
    
    - If not attached to a character type:
        setSpriteShader('AbotSpeakerTank', 'shaderName')
        setShaderFloat('AbotSpeakerTank', 'shaderValue', value)
]]
function setAbotSpeakerProperty(property, value)
    if property == 'x' then
        if characterType ~= '' then
            value = value + offsetData[1]
            setProperty('AbotSpeakerTank.'..property, value - 100)
        end
        for bar = 1, 7 do
            setProperty('AbotSpeakerVisualizerTank'..bar..'.'..property, getProperty('AbotSpeakerTank.'..property) + 200 + visualizerOffsetX(bar))
        end
        setProperty('AbotSpeakerBGTank.'..property, getProperty('AbotSpeakerTank.'..property) + 165)
        setProperty('AbotEyesTank.'..property, getProperty('AbotSpeakerTank.'..property) + 30)
        setProperty('AbotPupilsTank.'..property, getProperty('AbotSpeakerTank.'..property) - 507)
    elseif property == 'y' then
        if characterType ~= '' then
            value = value + offsetData[2]
            setProperty('AbotSpeakerTank.'..property, value + 316)
        end
        for bar = 1, 7 do
            setProperty('AbotSpeakerVisualizerTank'..bar..'.'..property, getProperty('AbotSpeakerTank.'..property) + 84 + visualizerOffsetY(bar))
        end
        setProperty('AbotSpeakerBGTank.'..property, getProperty('AbotSpeakerTank.'..property) + 30)
        setProperty('AbotEyesTank.'..property, getProperty('AbotSpeakerTank.'..property) + 230)
        setProperty('AbotPupilsTank.'..property, getProperty('AbotSpeakerTank.'..property) - 492)
    else
        if characterType ~= '' then
            setProperty('AbotSpeakerTank.'..property, value)
        end
        for bar = 1, 7 do
            setProperty('AbotSpeakerVisualizerTank'..bar..'.'..property, value)
        end
        setProperty('AbotSpeakerBGTank.'..property, value)
        setProperty('AbotEyesTank.'..property, value)
        setProperty('AbotPupilsTank.'..property, value)
    end
end

--[[ Old version of the function above.

function updateSpeaker(property)
    if property == 'x' then
        setProperty('AbotSpeakerTank.'..property, offset.x - 100)
        for bar = 1, 7 do
            setProperty('AbotSpeakerVisualizerTank'..bar..'.'..property, offset.x + 100 + visualizerOffsetX(bar))
        end
        setProperty('AbotSpeakerBGTank.'..property, offset.x + 65)
        setProperty('AbotEyesTank.'..property, offset.x - 60)
        setProperty('AbotPupilsTank.'..property, offset.x - 607)
    elseif property == 'y' then
        setProperty('AbotSpeakerTank.'..property, offset.y + 316)
        for bar = 1, 7 do
            setProperty('AbotSpeakerVisualizerTank'..bar..'.'..property, offset.y + 400 + visualizerOffsetY(bar))
        end
        setProperty('AbotSpeakerBGTank.'..property, offset.y + 347)
        setProperty('AbotEyesTank.'..property, offset.y + 567)
        setProperty('AbotPupilsTank.'..property, offset.y - 176)
    elseif characterType ~= '' then
        setProperty('AbotSpeakerTank.'..property, getProperty(characterType..'.'..property))
        for bar = 1, 7 do
            setProperty('AbotSpeakerVisualizerTank'..bar..'.'..property, getProperty(characterType..'.'..property))
        end
        setProperty('AbotSpeakerBGTank.'..property, getProperty(characterType..'.'..property))
        setProperty('AbotEyesTank.'..property, getProperty(characterType..'.'..property))
        setProperty('AbotPupilsTank.'..property, getProperty(characterType..'.'..property))
    end
end
]]

--[[
    Exclusive function for the tankmen variant of the speaker.
    This controls the properties of the tankmen depending of the speaker,
    so they also only apply the properties present in 'propertyTracker'.
]]
function updateTankmenProperty(property)
    if property == 'x' then
        setProperty('tankmanBodyLeft.'..property, getProperty('AbotSpeakerTank.'..property) + 610)
        setProperty('tankmanHeadLeft.'..property, getProperty('tankmanBodyLeft.'..property) - 77)
        setProperty('tankmanBodyRight.'..property, getProperty('AbotSpeakerTank.'..property) - 78)
        setProperty('tankmanHeadRight.'..property, getProperty('tankmanBodyRight.'..property) - 17)
    elseif property == 'y' then
        setProperty('tankmanBodyLeft.'..property, getProperty('AbotSpeakerTank.'..property) - 125)
        setProperty('tankmanHeadLeft.'..property, getProperty('tankmanBodyLeft.'..property) - 123)
        setProperty('tankmanBodyRight.'..property, getProperty('AbotSpeakerTank.'..property) - 128)
        setProperty('tankmanHeadRight.'..property, getProperty('tankmanBodyRight.'..property) - 123)
    else
        setProperty('tankmanBodyLeft.'..property, getProperty('AbotSpeakerTank.'..property))
        setProperty('tankmanHeadLeft.'..property, getProperty('AbotSpeakerTank.'..property))
        setProperty('tankmanBodyRight.'..property, getProperty('AbotSpeakerTank.'..property))
        setProperty('tankmanHeadRight.'..property, getProperty('AbotSpeakerTank.'..property))
    end
end

--[[
    This handles the offsets for each visualizer bar.
    Again, it is to make things automatic instead of doing everything manually.
]]
local visualizerPosX = {0, 59, 56, 66, 54, 52, 51}
local visualizerPosY = {0, -8, -3.5, -0.4, 0.5, 4.7, 7}
function visualizerOffsetX(bar)
    local i = 1
    local offsetX = 0
    while i <= bar do
        offsetX = offsetX + visualizerPosX[i]
        i = i + 1
    end
    return offsetX
end

function visualizerOffsetY(bar)
    local i = 1
    local offsetY = 0
    while i <= bar do
        offsetY = offsetY + visualizerPosY[i]
        i = i + 1
    end
    return offsetY
end

function getCharacterType(characterName)
    if boyfriendName == characterName then
        return 'boyfriend'
    elseif dadName == characterName then
        return 'dad'
    elseif gfName == characterName then
        return 'gf'
    end
end