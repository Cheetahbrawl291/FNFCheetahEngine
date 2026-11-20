function onCreate()
	addHaxeLibrary('FlxAngle', 'flixel.math')
	addHaxeLibrary('FlxTrail', 'flixel.addons.effects')
	makeLuaSprite('schoolBuildingEvil', 'weeb/erect/evilSchoolBG', -275, -20)
	setScrollFactor('schoolBuildingEvil', 0.8, 0.9)
	scaleObject('schoolBuildingEvil', 6, 6)
	addLuaSprite('schoolBuildingEvil')
	setProperty('schoolBuildingEvil.antialiasing', false)

	-- Default Game Over.
	setPropertyFromClass('substates.GameOverSubstate', 'characterName', 'bf-pixel-dead')
	setPropertyFromClass('substates.GameOverSubstate', 'deathSoundName', 'fnf_loss_sfx-pixel')
	setPropertyFromClass('substates.GameOverSubstate', 'loopSoundName', 'gameOver-pixel')
	setPropertyFromClass('substates.GameOverSubstate', 'endSoundName', 'gameOverEnd-pixel')
end

function onCreatePost()
	runHaxeCode([[
		import flixel.math.FlxAngle;
		import flixel.addons.effects.FlxTrail;

		// Adds the trail behind the opponent.
		var dadTrail:FlxTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
		game.addBehindDad(dadTrail);
		
		function setShaderFrameInfo(objectName:String) {
			var object:FlxSprite;
			switch(objectName) {
				case 'boyfriend':
                	object = game.boyfriend;
            	case 'dad':
                	object = game.dad;
            	case 'gf':
                	object = game.gf;
            	default:
                	object = game.getLuaObject(objectName);
			}

			object.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
        	{
				if (object.shader != null) {
					object.shader.setFloatArray('uFrameBounds', [object.frame.uv.x, object.frame.uv.y, object.frame.uv.width, object.frame.uv.height]);
            		object.shader.setFloat('angOffset', object.frame.angle * FlxAngle.TO_RAD);
				}
        	}
		}
	]])

	if shadersEnabled == true then
		initLuaShader('dropShadow')
        for i, object in ipairs({'boyfriend', 'dad', 'gf'}) do
			setSpriteShader(object, 'dropShadow')
			setShaderFloat(object, 'hue', -28)
    		setShaderFloat(object, 'saturation', -20)
    		setShaderFloat(object, 'contrast', 31)
    		setShaderFloat(object, 'brightness', -66)
			
			setShaderFloat(object, 'ang', math.rad(120))
			setShaderFloat(object, 'str', 1)
			setShaderFloat(object, 'dist', 4)
    		setShaderFloat(object, 'thr', 0.1)

			setShaderFloat(object, 'AA_STAGES', 0)
			setShaderFloatArray(object, 'dropColor', {82 / 255, 29 / 255, 75 / 255})
			runHaxeFunction('setShaderFrameInfo', {object})

			local imageFile = stringSplit(getProperty(object..'.imageFile'), '/')
			if checkFileExists('images/characters/masks/'..imageFile[#imageFile]..'_mask.png') then
				setShaderSampler2D(object, 'altMask', 'characters/masks/'..imageFile[#imageFile]..'_mask')
				setShaderFloat(object, 'thr2', 1)
				setShaderBool(object, 'useMask', true)
			else
				setShaderBool(object, 'useMask', false)
			end

			if _G[object..'Name'] == 'gf-pixel' then
				setShaderFloat(object, 'hue', -28)
    			setShaderFloat(object, 'saturation', -20)
    			setShaderFloat(object, 'contrast', 11)
    			setShaderFloat(object, 'brightness', -42)

				setShaderFloat(object, 'dist', 3)
				setShaderFloat(object, 'thr', 0.3)
			end

			if object == 'dad' then
				setShaderFloat(object, 'ang', math.rad(105))
				setShaderFloat(object, 'str', 0.34)
				setShaderFloat(object, 'dist', 3)
			elseif object == 'gf' then
				setShaderFloat(object, 'ang', math.rad(90))
			end
        end

		if lowQuality == false then
			initLuaShader('wiggle')
			setSpriteShader('schoolBuildingEvil', 'wiggle')
			setShaderFloat('schoolBuildingEvil', 'uSpeed', 2)
			setShaderFloat('schoolBuildingEvil', 'uFrequency', 4)
			setShaderFloat('schoolBuildingEvil', 'uWaveAmplitude', 0.017)
			setShaderInt('schoolBuildingEvil', 'effectType', 0)
		end
	end

	-- Sets up the sprites for the 'Trigger BG Ghouls' event if it's present in the chart.
	for note = 0, getProperty('eventNotes.length') - 1 do
        if getPropertyFromGroup('eventNotes', note, 'event') == 'Trigger BG Ghouls' then
			if lowQuality == false then
				makeAnimatedLuaSprite('girlfreaksEvil', 'weeb/bgGhouls', -100, 190)
				addAnimationByPrefix('girlfreaksEvil', 'anim', 'BG freaks glitch instance', 24, false)
				setScrollFactor('girlfreaksEvil', 0.9, 0.9)
				scaleObject('girlfreaksEvil', 6, 6)
				addLuaSprite('girlfreaksEvil')
				setProperty('girlfreaksEvil.antialiasing', false)
				setProperty('girlfreaksEvil.visible', false)
			end
		end
	end
end

-- Simple thing to update the wiggle shader.
local elapsedTime = 0
function onUpdatePost(elapsed)
	if shadersEnabled == true and lowQuality == false then
		elapsedTime = elapsedTime + elapsed
		setShaderFloat('schoolBuildingEvil', 'uTime', elapsedTime)
	end
end

-- Everything from this point is for the 'Trigger BG Ghouls' event
function onEvent(eventName, value1, value2, strumTime)
	if eventName == 'Trigger BG Ghouls' then
		if lowQuality == false then
			playAnim('girlfreaksEvil', 'anim', true)
			--setProperty('girlfreaksEvil.visible', true) -- Remove the comment if you want this event to work on the stage
			runTimer('freaksAnimLength', getProperty('girlfreaksEvil.animation.curAnim.numFrames') / 24)
		end
	end
end

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'freaksAnimLength' then
		setProperty('girlfreaksEvil.visible', false)
	end
end