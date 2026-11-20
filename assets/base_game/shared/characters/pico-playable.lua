function onCreate()
    if boyfriendName == 'pico-playable' then
        pauseMusic = getPropertyFromClass('backend.ClientPrefs', 'data.pauseMusic')
        setPropertyFromGameOver('characterName', 'pico-playable-dead')
        setPropertyFromGameOver('deathSoundName', 'fnf_loss_sfx-pico')
        setPropertyFromGameOver('loopSoundName', 'gameOver-pico')
        setPropertyFromGameOver('endSoundName', 'gameOverEnd-pico')

        runHaxeCode([[
            function getScreenPosition(character:String) {
                var characterPos:Array<Dynamic>;
                switch(character) {
                    case 'boyfriend':
                        characterPos = game.boyfriend.getScreenPosition();
                    case 'dad':
                        characterPos = game.dad.getScreenPosition();
                    case 'gf':
                        characterPos = game.gf.getScreenPosition();
                    default:
                        return;
                }
                return [characterPos.x, characterPos.y];
            }
        ]])
    end
end

function onPause()
    --[[
        Checks and replaces the Pause Menu music to the '-(pico)' version, if there's one.
        If not, it'll keep the original one.
        Ex: 'Tea Time' will stay the same since there isn't a 'tea-time-(pico)' present in the files.
    ]]
    if boyfriendName == 'pico-playable' then
        fileName = pauseMusic:gsub(' ', '-'):lower()
        if checkFileExists('music/'..fileName..'-(pico).ogg') then
            setPropertyFromClass('backend.ClientPrefs', 'data.pauseMusic', pauseMusic..' (Pico)')
        end
    end
end

function onDestroy()
    --[[ 
        Since we don't want the Pause Menu to stay stuck to the '-pico' version all the time,
        we revert it back to normal to avoid any issues and keep it exclusive to our character.
    ]]
    if boyfriendName == 'pico-playable' and stringEndsWith(getPropertyFromClass('backend.ClientPrefs', 'data.pauseMusic'), ' (Pico)') then
        setPropertyFromClass('backend.ClientPrefs', 'data.pauseMusic', pauseMusic)
    end
end

local gfPos = {}
function onGameOver()
    if boyfriendName == 'pico-playable' then
        gfPos = runHaxeFunction('getScreenPosition', {'gf'})
    end
end

function onGameOverStart()
    if boyfriendName == 'pico-playable' then
        makeAnimatedLuaSprite('gameOverRetry', 'characters/Pico_Death_Retry', getPropertyFromGameOver('boyfriend.x') + 205, getPropertyFromGameOver('boyfriend.y') - 80)
        addAnimationByPrefix('gameOverRetry', 'idle', 'Retry Text Loop0')
        addAnimationByPrefix('gameOverRetry', 'confirm', 'Retry Text Confirm0', 24, false)
        addOffset('gameOverRetry', 'confirm', 250, 200)
        addLuaSprite('gameOverRetry', true)
        setProperty('gameOverRetry.visible', false)
        
        makeAnimatedLuaSprite('neneDeathSprite', 'characters/NeneKnifeToss', gfPos[1] + 150, gfPos[2])
        addAnimationByPrefix('neneDeathSprite', 'throw', 'knife toss0', 24, false)
        addLuaSprite('neneDeathSprite', true)
    end
end

function onUpdate(elapsed)
    if boyfriendName == 'pico-playable' and inGameOver == true then
        if getProperty('neneDeathSprite.animation.finished') then
            setProperty('neneDeathSprite.visible', false)
        end
        if getPropertyFromGameOver('boyfriend.animation.curAnim.name') == 'firstDeath' then
            if getPropertyFromGameOver('boyfriend.animation.curAnim.curFrame') == 35 then
                playAnim('gameOverRetry', 'idle')
                setProperty('gameOverRetry.visible', true)
            end
        end
    end
end

function onGameOverConfirm(isNotGoingToMenu)
    if isNotGoingToMenu == true and boyfriendName == 'pico-playable' then
        playAnim('gameOverRetry', 'confirm')
        setProperty('gameOverRetry.visible', true)
    end
end

function getPropertyFromGameOver(property)
    if getPropertyFromClass('substates.GameOverSubstate', property) ~= nil then
        return getPropertyFromClass('substates.GameOverSubstate', property)
    else
        return getPropertyFromClass('substates.GameOverSubstate', 'instance.'..property)
    end
end

function setPropertyFromGameOver(property, value)
    if getPropertyFromClass('substates.GameOverSubstate', property) ~= nil then
        setPropertyFromClass('substates.GameOverSubstate', property, value)
    else
        setPropertyFromClass('substates.GameOverSubstate', 'instance.'..property, value)
    end
end