local neneComboAnim = nil
function onCreate()
    --[[
        This is how the script recognizes which option you chose to use.
        However, if you decide to take Nene inside another mod,
        the 'neneComboAnim' variable will default to 'none' to avoid any bugs or issues.
    ]]
    if getModSetting('neneComboAnim', currentModDirectory) == nil then
        neneComboAnim = 'Disabled'
    else
        neneComboAnim = getModSetting('neneComboAnim', currentModDirectory)
    end
end

function onCreatePost()
    --[[
        If you ever want to use Abot Speaker on another character,
        just copy and paste this below, and change what's between '{}'.
    
        WARNING: The speaker can only get attached to BF, Dad, or GF type characters.
        Else, the offsets act as simple x and y positions.
        Go check the 'abot-speaker' script for more information at line 385.
    ]]
    addLuaScript('characters/abot-speaker-tankmen')
    callScript('characters/abot-speaker-tankmen', 'createSpeaker', {'nene-tankmen', 0, 0}) -- {characterName, offsetX, offsetY}

    -- Some extra code to set up the speaker's shader in the 'tankErect' stage.
    if curStage == 'tankErect' then
        setVar('trackShader', false) -- Check line 30 of 'abot-speaker' to know its use.
        if shadersEnabled == true then
            initLuaShader('adjustColor')
            for _, object in ipairs({'AbotSpeakerTank', 'AbotSpeakerBGTank', 'AbotPupilsTank', 'AbotEyesTank'}) do
                setSpriteShader(object, 'adjustColor')
                setShaderFloat(object, 'hue', -38)
                setShaderFloat(object, 'saturation', -20)
                setShaderFloat(object, 'contrast', -25)
                setShaderFloat(object, 'brightness', -46)
            end

            for bar = 1, 7 do
                setSpriteShader('AbotSpeakerVisualizerTank'..bar, 'adjustColor')
                setShaderFloat('AbotSpeakerVisualizerTank'..bar, 'hue', -30)
                setShaderFloat('AbotSpeakerVisualizerTank'..bar, 'saturation', -10)
                setShaderFloat('AbotSpeakerVisualizerTank'..bar, 'contrast', 0)
                setShaderFloat('AbotSpeakerVisualizerTank'..bar, 'brightness', -12)
            end

            for _, bodyPart in ipairs({'Body', 'Head'}) do
                for _, side in ipairs({'Left', 'Right'}) do
                    local tankTag = 'tankman'..bodyPart..side
                    setSpriteShader(tankTag, 'dropShadow')
                    setShaderFloat(tankTag, 'hue', -38)
                    setShaderFloat(tankTag, 'saturation', -20)
                    setShaderFloat(tankTag, 'contrast', -25)
                    setShaderFloat(tankTag, 'brightness', -46)

                    setShaderFloat(tankTag, 'ang', math.rad(90))
    		        setShaderFloat(tankTag, 'str', 1)
    		        setShaderFloat(tankTag, 'dist', 15)
    		        setShaderFloat(tankTag, 'thr', 1)

                    setShaderFloat(tankTag, 'AA_STAGES', 2)
			        setShaderFloatArray(tankTag, 'dropColor', {223 / 255, 239 / 255, 60 / 255})
                    
                    if bodyPart == 'Head' then
                        setShaderSampler2D(tankTag, 'altMask', 'characters/addons/masks/tankman-head_mask')
                        setShaderFloat(tankTag, 'thr2', 0.4)
                        setShaderBool(tankTag, 'useMask', true)
                    else
                        setShaderBool(tankTag, 'useMask', false)
                    end
			        
                    runHaxeCode([[
                        import flixel.math.FlxAngle;
                        var object = game.getLuaObject(objectTag);

                        object.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
                        {
                            if (object.shader != null) {
                                object.shader.setFloatArray('uFrameBounds', [object.frame.uv.x, object.frame.uv.y, object.frame.uv.width, object.frame.uv.height]);
                                object.shader.setFloat('angOffset', object.frame.angle * FlxAngle.TO_RAD);
                            }
                        }
                    ]], {objectTag = tankTag})
                end
            end
        end
	end
end

local comboAnimActive = true
function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if neneComboAnim ~= 'none' and comboAnimActive == true then
        if neneComboAnim == 'Vanilla' then
            if combo == 50 then
                playAnim('gf', 'combo50')
                setProperty('gf.specialAnim', true)
            end
            if combo == 200 then
                playAnim('gf', 'combo200')
                setProperty('gf.specialAnim', true)
            end
        end
        lastCombo = combo
    end
end

function noteMiss(membersIndex, noteData, noteType, isSustainNote)
    if neneComboAnim ~= 'none' and comboAnimActive == true then
        if neneComboAnim == 'Vanilla' then
            if lastCombo >= 70 then
                playAnim('gf', 'drop70')
                setProperty('gf.specialAnim', true)
            end
        end
        if neneComboAnim == 'Psych' then
            if lastCombo > 5 then
                playAnim('gf', 'drop70')
                setProperty('gf.specialAnim', true)
            end
        end
        lastCombo = 0
    end
end

function noteMissPress(direction)
    if neneComboAnim ~= 'none' and comboAnimActive == true then
        if neneComboAnim == 'Vanilla' then
            if lastCombo >= 70 then
                playAnim('gf', 'drop70')
                setProperty('gf.specialAnim', true)
            end
        end
        if neneComboAnim == 'Psych' then
            if lastCombo > 5 then
                playAnim('gf', 'drop70')
                setProperty('gf.specialAnim', true)
            end
        end
        lastCombo = 0
    end
end

function onUpdatePost(elapsed)
    if songName ~= "Blazin'" then
        transitionAnim()
    end
end

--[[
    This function is what controls Nene's animations dependently of the player's health.
    When the player's health is low, Nene will smoothly go to her 'raiseKnife' anim.
    If the player gains enough health, Nene will go back to bopping her head.
    It also controls her animations when the train pasees by in 'philly' and 'phillyErect'.
]]
local animTrans = 0
local blinkDelay = 3
local trainStartedMoving = nil
function transitionAnim()
    if animTrans == 0 then -- Nene noticed the player being low on health.
        if getHealth() <= 0.5 then
            animTrans = 1
        else
            animTrans = 0
        end
    elseif animTrans == 1 then -- Nene stops bopping her head and raises her knife.
        if getHealth() > 0.5 then
            animTrans = 0
        elseif getProperty('gf.animation.name') == 'danceLeft' then
            comboAnimActive = false
            setProperty('gf.specialAnim', true)
            if getProperty('gf.animation.finished') then
                animTrans = 2
                playAnim('gf', 'raiseKnife')
                setProperty('gf.specialAnim', true)
                changedBeat = curBeat
            end
        end
    elseif animTrans == 2 then -- Nene keeps raising her knife while randomly blinking on beat, or lowers her knife.
        if getHealth() > 0.5 then
            animTrans = 3
            playAnim('gf', 'lowerKnife')
            setProperty('gf.specialAnim', true)
        elseif getProperty('gf.animation.finished') then
            if getProperty('gf.animation.name') ~= 'idleKnife' or curBeat - changedBeat == blinkDelay then
                blinkDelay = getRandomInt(3, 7)
                changedBeat = curBeat
                playAnim('gf', 'idleKnife')
                setProperty('gf.specialAnim', true)
            else
                lastFrame = getProperty('gf.animation.numFrames')
                playAnim('gf', 'idleKnife', false, false, lastFrame)
                setProperty('gf.specialAnim', true)
            end
        end
    elseif animTrans == 3 then -- Nene goes back to bopping her head.
        if getProperty('gf.animation.finished') then
            animTrans = 0
            comboAnimActive = true
            setProperty('gf.danced', false)
            characterDance('gf')
        end   
    end
end