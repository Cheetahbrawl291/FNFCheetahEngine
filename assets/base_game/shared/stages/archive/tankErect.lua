shootNotes = {}
runTankmen = {}
function onCreate()
	makeLuaSprite('bar', 'tankmanBattlefield/erect/bg', -985, -805)
	scaleObject('bar', 1.15, 1.15)
	addLuaSprite('bar')

	makeAnimatedLuaSprite('sniper', 'tankmanBattlefield/erect/sniper', -127, 349)
	addAnimationByPrefix('sniper', 'idle', 'Tankmanidlebaked instance 1', 24, false)
	addAnimationByPrefix('sniper', 'sip', 'tanksippingBaked instance 1', 24, false)
	scaleObject('sniper', 1.15, 1.15)
	addLuaSprite('sniper')
	playAnim('sniper', 'idle')

	makeAnimatedLuaSprite('tankguy', 'tankmanBattlefield/erect/guy', 1398, 407)
	addAnimationByPrefix('tankguy', 'idle', 'BLTank2 instance 1', 24, false)
	scaleObject('tankguy', 1.15, 1.15)
	addLuaSprite('tankguy')

	if stringEndsWith(gfName, '-speaker') == true then
		local hasBopAnim = nil
		if getProperty('gf.danceIdle') == true then
			hasBopAnim = (callMethod('gf.hasAnimation', {'danceLeft'}) and callMethod('gf.hasAnimation', {'danceRight'}))
		else
			hasBopAnim = callMethod('gf.hasAnimation', {'idle'})
		end
		setProperty('gf.skipDance', not hasBopAnim)

		if gfName == 'pico-speaker' then
			for i = 0, getProperty('gf.animationNotes.length') - 1 do
				callMethod('gf.animationNotes.shift')
			end
		end
		
		if checkFileExists('data/'..songPath..'/picospeaker.json') then
			local songFormat = callMethodFromClass('backend.Paths', 'formatToSongPath', {songPath})
			local shootChart = callMethodFromClass('backend.Song', 'getChart', {'picospeaker', songFormat})
			for _, section in pairs(shootChart.notes) do
				for _, note in pairs(section.sectionNotes) do
					table.insert(shootNotes, note)
				end
			end
		end
	end
end

function onCreatePost()
	if shadersEnabled == true then
		runHaxeCode([[
            import flixel.math.FlxAngle;
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

		initLuaShader('dropShadow')
        for i, object in ipairs({'boyfriend', 'dad', 'gf'}) do
            setSpriteShader(object, 'dropShadow')
    		setShaderFloat(object, 'hue', -38)
    		setShaderFloat(object, 'saturation', -20)
    		setShaderFloat(object, 'contrast', -25)
    		setShaderFloat(object, 'brightness', -46)
			
            setShaderFloat(object, 'ang', math.rad(90))
    		setShaderFloat(object, 'str', 1)
    		setShaderFloat(object, 'dist', 15)
    		setShaderFloat(object, 'thr', 0.1)

			setShaderFloat(object, 'AA_STAGES', 2)
			setShaderFloatArray(object, 'dropColor', {223 / 255, 239 / 255, 60 / 255})
			runHaxeFunction('setShaderFrameInfo', {object})

			local imageFile = stringSplit(getProperty(object..'.imageFile'), '/')
			if checkFileExists('images/characters/masks/'..imageFile[#imageFile]..'_mask.png') then
				setShaderSampler2D(object, 'altMask', 'characters/masks/'..imageFile[#imageFile]..'_mask')
				setShaderFloat(object, 'thr2', 1)
				setShaderBool(object, 'useMask', true)
			else
				setShaderBool(object, 'useMask', false)
			end

			if _G[object..'Name'] =='gf-tankmen' then
				setShaderFloat(object, 'thr2', 0.4)
			end

			if object == 'dad' then
				setShaderFloat(object, 'ang', math.rad(135))
    			setShaderFloat(object, 'thr', 0.3)
			end
		end
	end

	if lowQuality == false and #shootNotes > 0 then
		local tankNum = 0
		for i = 1, #shootNotes do
			if getRandomBool(16) then
				tankNum = tankNum + 1
				local offset = getRandomInt(25, 50)
				createTankman('tankmanRun'..tankNum, 500, 275 + offset, shootNotes[i][2] < 2)
				runTankmen[tankNum] = {
					strumTime = shootNotes[i][1],
					goingRight = shootNotes[i][2] < 2,
					endingOffset = getRandomFloat(50, 200),
					speed = getRandomFloat(0.6, 1),
					isDead = false
				}
			end
		end
	end
end

function onUpdatePost(elapsed)
	if #runTankmen > 0 then
    	updateTankman()
	end

    if #shootNotes > 0 and getSongPosition() > shootNotes[1][1] then
        noteData = shootNotes[1][2] + 1
        playAnim('gf', 'shoot'..noteData, true)
        setProperty('gf.specialAnim', true)
        table.remove(shootNotes, 1)
    end
end

sniperSpecialAnim = false
function onBeatHit()
	if getRandomBool(2) and sniperSpecialAnim == false then
		playAnim('sniper', 'sip', true)
		runTimer('sipAnimLength', getProperty('sniper.animation.curAnim.numFrames') / 24)
		sniperSpecialAnim = true
	end

	if curBeat % 2 == 0 then
		if sniperSpecialAnim == false then
			playAnim('sniper', 'idle', true)
		end
		playAnim('tankguy', 'idle', true)
	end
end

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'sipAnimLength' then
		sniperSpecialAnim = false
	end
end

function createTankman(tag, x, y, facingRight)
    local antialisConfig = getPropertyFromClass('backend.ClientPrefs', 'data.antialiasing')
    local shotAlt = getRandomInt(1, 2)
    makeAnimatedLuaSprite(tag, 'tankmanBattlefield/tankmanKilled1', x, y)
    addAnimationByPrefix(tag, 'run', 'tankman running')
    addAnimationByPrefix(tag, 'shot', 'John Shot '..shotAlt, 24, false)
    addOffset(tag, 'shot', 300, 200)
	setObjectOrder(tag, getObjectOrder('tankguy') + 1)
    scaleObject(tag, 1.05, 1.05, false)
    addLuaSprite(tag)

    local startFrame = getRandomInt(0, getProperty(tag..'.animation.curAnim.numFrames') - 1)
    playAnim(tag, 'run', true, false, startFrame)
    setProperty(tag..'.antialiasing', antialisConfig)
    setProperty(tag..'.flipX', facingRight)

	if shadersEnabled == true then
		setSpriteShader(tag, 'dropShadow')
    	setShaderFloat(tag, 'hue', -38)
    	setShaderFloat(tag, 'saturation', -20)
    	setShaderFloat(tag, 'contrast', -25)
    	setShaderFloat(tag, 'brightness', -46)
			
        setShaderFloat(tag, 'ang', math.rad(135))
    	setShaderFloat(tag, 'str', 1)
    	setShaderFloat(tag, 'dist', 15)
    	setShaderFloat(tag, 'thr', 0.4)

		setShaderFloat(tag, 'AA_STAGES', 2)
		setShaderFloatArray(tag, 'dropColor', {223 / 255, 239 / 255, 60 / 255})
		runHaxeFunction('setShaderFrameInfo', {tag})
        setShaderBool(tag, 'useMask', false)
	end
end

function updateTankman()
    for tankNum = 1, #runTankmen do
        local tag = 'tankmanRun'..tankNum
        if luaSpriteExists(tag) then
			local visible = (getProperty(tag..'.x') > -1 * screenWidth) and (getProperty(tag..'.x') < 1.5 * screenWidth)
            setProperty(tag..'.visible', visible)

            if getProperty(tag..'.animation.curAnim.name') == 'run' then
                local curSpeed = (getSongPosition() - runTankmen[tankNum].strumTime) * runTankmen[tankNum].speed
                if runTankmen[tankNum].goingRight == true then
                    setProperty(tag..'.x', (-0.05 * screenWidth - runTankmen[tankNum].endingOffset) + curSpeed)
                else
                    setProperty(tag..'.x', (0.95 * screenWidth + runTankmen[tankNum].endingOffset) - curSpeed)
                end
            elseif getProperty(tag..'.animation.finished') then
                removeLuaSprite(tag)
            end

            if getSongPosition() > runTankmen[tankNum].strumTime then
                if runTankmen[tankNum].isDead == false then
                    playAnim(tag, 'shot', true)
                    runTankmen[tankNum].isDead = true
                end
            end
        end
    end
end