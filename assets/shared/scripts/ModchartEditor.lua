--[[ 
LUA Modchart Editor v1.2.2 by .bakugo / CommanderVideo
	https://gamebanana.com/members/1787065
	https://gamejolt.com/@Commander_Video
]]

-- Optional stuff you can configure ================================
local editor_debugMode = false -- Toggles luaDebugMode and luaDeprecatedWarnings
local editor_mainFont = '' -- Set this to your own font if you want, otherwise the base game pixel font is used

modchartData = { -- The starting empty modchart, you can change default values here if you'd like
    name = 'NewModchart',
    settings = {
        camZooming = true,

        scrollInvertY = true,
		--sustainEnhancements = false
    },
    objects = {}
}

-- actual code starts here =========================================

local UITabs = {'File', 'Values', 'Test', 'Settings'}
local uiSize, tabHeight = {500, 500}, 50

local mSize, editor_minimized = {30, 30}, false
local editor_version, editor_curAction, editor_onMobile = '1.2.2'

local function isTyping() -- Returns true/false if the user is focused on a textbox
	local v = getProperty('editor_volumeCache')
	if v ~= nil and type(v) == 'table' then return true
	else return false end
end

local function mouseOverlaps(obj, _, widthOffs, heightOffs)
	if not getProperty(obj..'.exists') then return end
    local x, y = getProperty(obj .. '.x') + (widthOffs or 0), getProperty(obj .. '.y') - (heightOffs or 0)
    local width, height = getProperty(obj .. '.width'), getProperty(obj .. '.height')
    return (lastmX > x) and (lastmX < x + width) and (lastmY > y) and (lastmY < y + height)
end

local function getScreenPosition(camera) -- peak just dropped thx ghostglowdev for the idea of recreating the function so it doesnt require rhc
    if not camera then camera = 'camGame' end;
    local cX, cY, cW, cH, cZ, cIZ = getProperty(camera..'.x') or 0, getProperty(camera..'.y') or 0, getProperty(camera..'.width') or screenWidth, getProperty(camera..'.height') or screenHeight, getProperty(camera..'.zoom') or 1, getProperty(camera..'.initialZoom') or 1;
    return {(getPropertyFromClass('flixel.FlxG', 'mouse._globalScreenX') - cX + 0.5 * cW * (cZ - cIZ)) / cZ, (getPropertyFromClass('flixel.FlxG', 'mouse._globalScreenY') - cY + 0.5 * cH * (cZ - cIZ)) / cZ};
end

local function boundTo(value, min, max)
    if value < min then return min
    elseif value > max then return max
    else return value end
end

local function lerp(a, b, t) return a + (b - a) * t end

local function updateClipRect(clippedSpr, spr)
	if not getProperty(clippedSpr..'.clipRect') then
        runHaxeCode([[
		    var sprite1 = game.getLuaObject("]]..clippedSpr..[[");
		    var sprite2 = game.getLuaObject("]]..spr..[[");
		    sprite1.clipRect = new FlxRect(sprite2.x - sprite1.x, sprite2.y - sprite1.y, sprite2.width, sprite2.height);
	    ]])
	else
        setProperty(clippedSpr..'.clipRect.x', getProperty(spr..'.x') - getProperty(clippedSpr..'.x'))
	    setProperty(clippedSpr..'.clipRect.y', getProperty(spr..'.y') - getProperty(clippedSpr..'.y'))
        setProperty(clippedSpr..'.clipRect.width', getProperty(spr..'.width'))
        setProperty(clippedSpr..'.clipRect.height', getProperty(spr..'.height'))
	end
end

local function print_table(node, multiline) -- CREDIT: https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console THANK YOU
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    table.insert(output,output_str)
    output_str = table.concat(output)
    return not multiline and output_str:gsub('\n', ''):gsub('\t', '') or output_str
end

local function getTableLength(tbl) -- because using #tbl ignores non numerical keys
	local n = 0
	for k, v in pairs(tbl) do n = n+1 end
	return n
end

local function tableFind(table, query)
	for _, v in pairs(table) do if v == query then return true end end
	return false
end

local function deepcopy(orig) -- Don't know what a metatable is but I need this to copy tables
    local copy
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

local function string_to_table(str)
    local f = loadstring("return "..str)
    return f and f()
end

local rgbOffsets = {'redOffset', 'greenOffset', 'blueOffset'}
local function updateColorOffsets(spr, amt)
	for _, v in ipairs(rgbOffsets) do
		setProperty(spr..'.colorTransform.'..v, amt or 0)
	end
end

local function deleteDropdown()
	local dropKey = stringSplit(currentDropdown, '_')[2]
	currentDropdown = nil 
	tabSaves[curTab][dropKey].update()
end

local function addTextToDebug(text, color)
	if version > '0.7.1' then
		debugPrint(text, color)
	else
		runHaxeCode("game.addTextToDebug('"..text.."', 0xFF"..color..");")
	end
end

local function getStrumInfoFromID(a)
	local id = a
	if not tonumber(id) and a ~= nil then id = tonumber(id:sub(#id-1, #id-1)) else return {'unknown', 'unknown'} end
	if not id or id < 0 or id > 7 then return {'unknown', 'unknown'} end
	return {(id < 4 and 'opponent' or 'player')..'-'..(getProperty('singAnimations['..(id%4)..']'):gsub('sing', ''):lower()), {(id < 4 and 'Opponent' or 'Player'), id%4}}
end

local function resetStrumProperties(s, save)
	setProperty(s..'.x', _G['default'..getStrumInfoFromID(s)[2][1]..'StrumX'..getStrumInfoFromID(s)[2][2]])
	setProperty(s..'.y', _G['default'..getStrumInfoFromID(s)[2][1]..'StrumY'..getStrumInfoFromID(s)[2][2]])
	setProperty(s..'.alpha', _G['default'..getStrumInfoFromID(s)[2][1]..'StrumAlpha'..getStrumInfoFromID(s)[2][2]])
	setProperty(s..'.angle', _G['default'..getStrumInfoFromID(s)[2][1]..'StrumAngle'..getStrumInfoFromID(s)[2][2]])
	setProperty(s..'.direction', _G['default'..getStrumInfoFromID(s)[2][1]..'StrumDirection'..getStrumInfoFromID(s)[2][2]])
	if not save then return end
	modchartData.objects[s].actions[editor_curAction].x = getProperty(s..'.x')
	modchartData.objects[s].actions[editor_curAction].y = getProperty(s..'.y')
	modchartData.objects[s].actions[editor_curAction].alpha = getProperty(s..'.alpha')
	modchartData.objects[s].actions[editor_curAction].angle = getProperty(s..'.angle')
	modchartData.objects[s].actions[editor_curAction].direction = getProperty(s..'.direction')
end

local function manageModchartTweens(obj, mode)
	local tweens, timers = {}, {}
	if modchartData.objects[obj] ~= nil and modchartData.objects[obj].numActions > 0 then
		for aNum, arr in ipairs(modchartData.objects[obj].actions) do
			if arr.delay > 0 then table.insert(timers, aNum) end
			if arr.duration > 0 then table.insert(tweens, aNum) end
		end
	elseif mode ~= 'cancel' then return end

	if mode == 'cancel' then
		local hi
		if not modchartData.objects[obj] or modchartData.objects[obj].numActions < 1 then
			hi = true
			doTweenAlpha('editor_testTweenDone_'..obj, obj, _G['default'..getStrumInfoFromID(obj)[2][1]..'StrumAlpha'..getStrumInfoFromID(obj)[2][2]], 0.3, 'cubeInOut') 
			return 
		end
		for _, aNum in ipairs(timers) do
			cancelTimer(modchartData.name..'_'..obj..'_Delay_'..aNum)
		end
		for _, aNum in ipairs(tweens) do
			for _, prop in ipairs({'X', 'Y', 'Alpha', 'Angle', 'Direction'}) do
				cancelTween(modchartData.name..'_'..obj..'_'..prop..'_'..aNum)
			end
		end
		resetStrumProperties(obj)
		if not hi then runTimer('editor_testTweenDone', 0.3) end
	elseif mode == 'pause' or mode == 'resume' then
		editor_memory.temp_tweens = tweens
		editor_memory.temp_timers = timers
		flushMemory()

		if version > '0.7.3' then obj = obj:gsub('%.', ''):gsub(' ', '_') end -- LuaUtils.formatVariable does this i guess
		runHaxeCode([[
			if (PlayState.SONG.modchartEditorMemory.temp_timers.length > 0)
				for (aNum in PlayState.SONG.modchartEditorMemory.temp_timers){
					var sT = ']]..modchartData.name..'_'..obj..'_Delay_'..[[' + aNum;
					var tT = ]]..tostring(version > '0.7.3')..[[ ? getVar('timer_' + sT) : game.modchartTimers.get(sT);
					if (tT != null) tT.active = ]]..(mode == 'pause' and 'false' or 'true')..[[;
				}
			if (PlayState.SONG.modchartEditorMemory.temp_tweens.length > 0)
				for (aNum in PlayState.SONG.modchartEditorMemory.temp_tweens){
					for (prop in ['X', 'Y', 'Alpha', 'Angle', 'Direction']){
						var sP = ']]..modchartData.name..'_'..obj..'_'..[[' + prop + '_' + aNum;
						var tP = ]]..tostring(version > '0.7.3')..[[ ? getVar('tween_' + sP) : game.modchartTweens.get(sP);
						if (tP != null) tP.active = ]]..(mode == 'pause' and 'false' or 'true')..[[;
					}
				}

			PlayState.SONG.modchartEditorMemory.temp_timers = null;
			PlayState.SONG.modchartEditorMemory.temp_tweens = null;
		]])
		editor_memory.temp_tweens, editor_memory.temp_timers = nil
	end
end

local function deselectCurrentStrum()
    if currentStrumEditing == nil then return false end
	resetStrumProperties(currentStrumEditing)
    updateColorOffsets(currentStrumEditing)
    currentStrumEditing = nil
    return true
end

--[[ Guide for the tabOptions array:
 text size: default 15 (usually)
 *All x/y values are relative to the UIBox position
  Tab = ['Option Name'] = {description, option type, {x, y}, text size, checkbox alignment (default: right), {box offset x, box offset y}, default box state} (Type: Check -> Bool)
  Tab = ['Option Name'] = {description, option type, {x, y, width, height}, {idle color, select color, outline color, outline size}, text size} (Type: Button -> Function)
  Tab = ['Option Name'] = {description, option type, {box x, box y, box width, box height}, {desctext x, desctext y, desctext size}, text size (default 15), NUMBERSONLY?, 'default content'} (Type: Textbox -> String)
  Tab = ['Option Name'] = {description, option type, {box x, box y, box width, box height}, {desctext x, desctext y, desctext size}, box text size (default 15), {'dropdown items'}, 'default choice in box'} (Type: Dropdown -> String)
  Tab = ['Option Name'] = {option type, sprite, {x, y}, {scaleX, scaleY}, animToPlay, CLICKABLE?} Type: Clone (None)
]]
local optionType_NONE = {'', ''}

local function refreshTabOptions(t)
	if t == 'File' then
		tabOptions = { 
			['File'] = {
				['Name'] = {'Modchart Name:', 'textbox', {20, 60, 240, 25}, {20, 30, 15}, 15, false, modchartData.name or 'NewModchart'},
				['Save'] = {'Save Modchart.lua', 'button', {300, 120, 170, 60}, {'000000', '808080', '39e75f', 5}, 14},
				['SaveData'] = {'Save ModchartData.txt', 'button', {300, 210, 170, 60}, {'000000', '808080', '39e75f', 5}, 13},
				['Load'] = {'Reload Modchart', 'button', {300, 30, 170, 60}, {'000000', '808080', '39e75f', 5}, 15},
				['Reset'] = {'Reset modchart', 'button', {25, 120, 170, 60}, {'000000', '808080', 'FF0000', 5}, 13},
				['versiontext'] = {'V'..editor_version..'  |  '..(editor_debugMode and 'debug' or 'release')..'  |  Modchart editor', 'info', {60, 460}, 15},
				['watermarklol'] = {'made by .bakugo on discord', 'info', {10, 420}, 12},

				-- mobile buttons for ALT/ESC/Enter
				['SaveAndExit'] = editor_onMobile and {'Save & Exit', 'button', {20, 350, 120, 45}, {'000000', '808080', 'ff8f00', 5}, 12} or optionType_NONE,
				['Exit'] = editor_onMobile and {'Exit w/o Saving', 'button', {185, 350, 120, 45}, {'000000', '808080', 'ff8f00', 5}, 12} or optionType_NONE,
				['Test'] = editor_onMobile and {'Restart & Test Modchart', 'button', {350, 350, 120, 45}, {'000000', '808080', 'ff8f00', 5}, 12} or optionType_NONE,
			}
		}
	elseif t == 'Values' then
		tabOptions = (currentStrumEditing ~= nil and modchartData.objects[currentStrumEditing] ~= nil) and {
			['Values'] = {
				['CustomCords'] = {'Use mouse position', 'button', {10, 260, 150, 50}, {'000000', '808080', 'be2ed6', 5}, 15},
				['ResetValues'] = {'Default values', 'button', {380, 385, 115, 40}, {'000000', '808080', 'e86100', 5}, 15},
			
				['ActionInfo'] = {'Action '..(editor_curAction or 0)..'/'..(modchartData.objects[currentStrumEditing] ~= nil and modchartData.objects[currentStrumEditing].numActions or 0), 'info', {10, 410}, 15},
				['CurSelection'] = {(currentStrumEditing or 'none')..'\n'..getStrumInfoFromID(currentStrumEditing)[1], 'info', {10, 450}, 15},
			
				['X'] = {'X:', 'textbox', {130, 10, 100, 25}, {10, 10, 15}, 15, true, currentStrumEditing ~= nil and (editor_curAction and tonumber(modchartData.objects[currentStrumEditing].actions[editor_curAction].x) or getProperty(currentStrumEditing..'.x')) or ''},
				['Y'] = {'Y:', 'textbox', {130, 45, 100, 25}, {10, 45, 15}, 15, true, currentStrumEditing ~= nil and (editor_curAction and tonumber(modchartData.objects[currentStrumEditing].actions[editor_curAction].y) or getProperty(currentStrumEditing..'.y')) or ''},
				['Alpha'] = {'Alpha:', 'textbox', {130, 80, 100, 25}, {10, 80, 15}, 15, true, currentStrumEditing ~= nil and (editor_curAction and tonumber(modchartData.objects[currentStrumEditing].actions[editor_curAction].alpha) or getProperty(currentStrumEditing..'.alpha')) or ''},
				['Angle'] = {'Angle:', 'textbox', {130, 115, 100, 25}, {10, 115, 15}, 15, true, currentStrumEditing ~= nil and (editor_curAction and tonumber(modchartData.objects[currentStrumEditing].actions[editor_curAction].angle) or getProperty(currentStrumEditing..'.angle')) or ''},
				['Direction'] = {'Direction:', 'textbox', {130, 150, 100, 25}, {10, 150, 15}, 15, true, currentStrumEditing ~= nil and (editor_curAction and tonumber(modchartData.objects[currentStrumEditing].actions[editor_curAction].direction) or getProperty(currentStrumEditing..'.direction')) or ''},

				['Duration'] = {'Duration:', 'textbox', {385, 10, 100, 25}, {245, 10, 14}, 15, true, currentStrumEditing ~= nil and (editor_curAction and tonumber(modchartData.objects[currentStrumEditing].actions[editor_curAction].duration) or 0)},
				['Delay'] = {'Start delay:', 'textbox', {385, 45, 100, 25}, {245, 45, 14}, 15, true, currentStrumEditing ~= nil and (editor_curAction and tonumber(modchartData.objects[currentStrumEditing].actions[editor_curAction].delay) or 0)},
				['DurationUnit'] = {'Time units:', 'dropdown', {360, 82.5, 105, 20}, {245, 80, 14}, 10, {'seconds', 'beats', 'steps'}, currentStrumEditing ~= nil and (editor_curAction and modchartData.objects[currentStrumEditing].actions[editor_curAction].durationUnit or 'seconds')},
				['Transition'] = {'Transition:', 'dropdown', {360, 117.5, 105, 20}, {245, 115, 14}, 10, {'linear', 'back', 'bounce', 'circ', 'cube', 'elastic', 'expo', 'quad', 'quart', 'quint', 'sine', 'smoothStep', 'smootherStep'}, currentStrumEditing ~= nil and (editor_curAction and tostring(modchartData.objects[currentStrumEditing].actions[editor_curAction].transition) or 'sine')},
				['TransitionType'] = {'Type:', 'dropdown', {360, 152.5, 105, 20}, {245, 150, 14}, 10, {'In', 'Out', 'InOut'}, currentStrumEditing ~= nil and (editor_curAction and modchartData.objects[currentStrumEditing].actions[editor_curAction].type or 'InOut')},
			
				['Deselect'] = {'Deselect', 'button', {380, 460, 115, 35}, {'000000', '808080', '39e75f', 5}, 15},
				['NextAction'] = {'Next action', 'button', {140, 360, 115, 40}, {'000000', '808080', '39e75f', 5}, 15},
				['PrevAction'] = {'Previous action', 'button', {10, 360, 115, 40}, {'000000', '808080', '39e75f', 5}, 15},
				['DeleteAction'] = {'Delete action', 'button', {380, 310, 115, 35}, {'000000', '808080', 'FF0000', 5}, 15},
				['CreateAction'] = {'New action', 'button', {380, 230, 115, 35}, {'000000', '808080', '39e75f', 5}, 15},

				--['Presets'] = {'Presets', 'button', {10, 180, 115, 35}, {'000000', '808080', 'ADD8E6', 5}, 15}
			}
		} or {
			['Values'] = {
				['ActionInfo'] = {'Action 0/0', 'info', {10, 410}, 15},
				['CurSelection'] = {(currentStrumEditing or 'none')..'\n'..getStrumInfoFromID(currentStrumEditing)[1], 'info', {10, 450}, 15},
				
				['PressInfo'] = {'This strum has no actions!\nCreate a new action to add it to this modchart.', 'info', {10, 30}, 14},
				['ClickDaButton'] = {'(^^^^^ click this)', 'info', {180, 300}, 11},
				['CreateFirstAction'] = {'New action', 'button', {175, 210, 170, 60}, {'000000', '808080', '39e75f', 5}, 17},
				['Copy'] = getTableLength(modchartData.objects) > 0 and {'Copy from strum', 'button', {310, 400, 185, 40}, {'000000', '808080', '005b96', 5}, 14} or optionType_NONE
			},
		}
	elseif t == 'Test' then
		tabOptions = {
			['Test'] = {
				['IconDad'] = {'clone', 'iconP2', {0, 0}, {0.8, 0.8}},
				['Dad0'] = {'clone', 'strumLineNotes.members[0]', {120, 20}, {0.5, 0.5}, 'static', true},
				['Dad1'] = {'clone', 'strumLineNotes.members[1]', {200, 20}, {0.5, 0.5}, 'static', true},
				['Dad2'] = {'clone', 'strumLineNotes.members[2]', {280, 20}, {0.5, 0.5}, 'static', true},
				['Dad3'] = {'clone', 'strumLineNotes.members[3]', {360, 20}, {0.5, 0.5}, 'static', true},
				['IconBF'] = {'clone', 'iconP1', {-5, 100}, {0.8, 0.8}},
				['BF4'] = {'clone', 'strumLineNotes.members[4]', {120, 110}, {0.5, 0.5}, 'static', true},
				['BF5'] = {'clone', 'strumLineNotes.members[5]', {200, 110}, {0.5, 0.5}, 'static', true},
				['BF6'] = {'clone', 'strumLineNotes.members[6]', {280, 110}, {0.5, 0.5}, 'static', true},
				['BF7'] = {'clone', 'strumLineNotes.members[7]', {360, 110}, {0.5, 0.5}, 'static', true},
				['HelpText'] = {'Click strums to test their actions here\n(Strums with no actions are greyed out)', 'info', {35, 210}, 15},
				['SelectAll'] = {'Select all', 'button', {260, 270, 110, 30}, {'000000', '808080', '39e75f', 5}, 10},
				['DeselectAll'] = {'Deselect all', 'button', {380, 270, 110, 30}, {'000000', '808080', '39e75f', 5}, 10},
				['Test'] = {'Test selected strums', 'button', {50, 340, 180, 50}, {'000000', '808080', '0000FF', 5}, 15},
				['Stop'] = {'Stop test', 'button', {270, 340, 180, 50}, {'000000', '808080', 'FF0000', 5}, 15},
				['Pause'] = {(not editor_onMobile and '(Q) ' or '')..'Pause test', 'button', {50, 410, 180, 50}, {'000000', '808080', 'ffbf00', 5}, 15},
				['Resume'] = {(not editor_onMobile and '(E) ' or '')..'Resume test', 'button', {270, 410, 180, 50}, {'000000', '808080', '4cbb17', 5}, 15}
			}
		}
	elseif t == 'Settings' then
		tabOptions = {
			['Settings'] = {
				['HelpText'] = {'editor settings -------------', 'info', {5, 0}, 13},
				['EditorZooms'] = {'Beat zoom in editor?', 'check', {190, 40}, 16, 'right', {10, 10}, modchartData.settings.camZooming},
				['HelpText2'] = {'modchart settings -------------', 'info', {5, 200}, 13},
				['ScrollInvert'] = {'Invert Y positions on opposite scroll?', 'check', {65, 240}, 16, 'left', {10, 10}, modchartData.settings.scrollInvertY},
				--['SustainEnhancements'] = {'Add enhanced sustain math?\n(for changing direction)', 'check', {65, 290}, 16, 'left', {10, -5}, modchartData.settings.sustainEnhancements}
			}
		}
	end
end

local function rgbToHex(array)
    return string.format('%.2x%.2x%.2x', math.min(array[1]+50,255), math.min(array[2]+50,255), math.min(array[3]+50,255))
end

local function getIconColor(chr)
    return getColorFromHex(rgbToHex(getProperty(chr .. ".healthColorArray")))
end

local function clearCurrentTab()
	local specialObjects = {}
	for i = 0, getProperty('curOptions.length')-1 do
		local name = getProperty('curOptions['..i..']')
		if name ~= nil then
			if stringEndsWith(name, 'Text') then removeLuaText(name, true)
			elseif stringEndsWith(name, 'Clone') or stringEndsWith(name, 'Textbox') then table.insert(specialObjects, name)
			else removeLuaSprite(name, true) end
		end
	end
	for _, name in ipairs(specialObjects) do
		if version > '0.7.2' then
			callMethod(name..'.destroy', {''})
			callMethod('variables.remove', {name})
		else runHaxeCode([[
				var obj = game.getLuaObject(']]..name..[[');
				obj.kill();
				game.remove(obj);
				obj.destroy();
				game.variables.remove(']]..name..[[');
			]])
		end
	end
	if version > '0.6.3' then
		if isTyping() then
			callMethod('editor_focusCallbackLost', {''})
		end
		callMethod('curOptions.resize', {0})
	else runHaxeCode([[
		if (getVar('editor_volumeCache') != null)
			getVar('editor_focusCallbackLost')();
		getVar('curOptions').resize(0);
		Paths.clearUnusedMemory();
	]]) end
end

--[[local function clearCurrentTab()
	runHaxeCode('for (d in getVar("curOptions")) game.getLuaObject(d).destroy(); setVar("curOptions", []);')
end]]

local editor_madeMarkerGroup
local function displayTestMarkers(strums)
	if not editor_testingModchart then return end
	setProperty('strumLineNotes.visible', false)
	if not editor_madeMarkerGroup then
		for i = 0, 7 do
			local tag, s = 'editor_testMarker'..i, 'strumLineNotes.members['..i..']'
			makeLuaText(tag, i, 0)
			setTextSize(tag, 23)
			setTextFont(tag, editor_mainFont)
			setProperty(tag..'.x', getProperty(s..'.x') + getProperty(s..'.width')/2 - getProperty(tag..'.textField.textWidth')/2)
			setProperty(tag..'.y', getProperty(s..'.y') + getProperty(s..'.height')/2 - getProperty(tag..'.textField.textHeight')/2)
			
			tag = tag..'_actionLabel'
			makeLuaText(tag, '', 0)
			setTextSize(tag, 11)
			setTextFont(tag, editor_mainFont)
			setProperty(tag..'.x', getProperty(s..'.x'))
			setProperty(tag..'.y', getProperty(s..'.y') + getProperty(s..'.height') - getProperty(tag..'.textField.textHeight'))
		end
		runHaxeCode([[
			var group = new flixel.group.FlxTypedGroup();
			group.camera = game.camHUD;
			setVar('editor_markerGroup', group);
			for (i in 0...8){
				group.add(game.strumLineNotes.members[i]);
				group.add(game.getLuaObject('editor_testMarker' + i));
				group.add(game.getLuaObject('editor_testMarker' + i + '_actionLabel'));
			}
			game.insert(game.members.indexOf(game.]]..(version > '0.7.1h' and 'noteGroup' or 'strumLineNotes')..[[)+1, group);
		]])
		editor_madeMarkerGroup = true
	else
		setProperty('editor_markerGroup.visible', true)
	end
	for i = 0, 7 do
		if not tableFind(strums, i) then
			doTweenAlpha('editor_testMarkerHide'..i, 'editor_testMarker'..i, 0.15, 0.4, 'cubeInOut')
			doTweenAlpha('editor_testMarkerHide'..i..'_actionLabel', 'editor_testMarker'..i..'_actionLabel', 0.15, 0.4, 'cubeInOut')
			setTextString('editor_testMarker'..i..'_actionLabel', 'Action 0/0')
		else
			setTextString('editor_testMarker'..i..'_actionLabel', 'Action 1/'..modchartData.objects['strumLineNotes.members['..i..']'].numActions)
		end
	end
end

local function updateTestMarkers()
	if not editor_testingModchart then return end
	local strumPositions = {}
	for i = 0, 7 do
		local tag, s, sPos = 'editor_testMarker'..i, 'strumLineNotes.members['..i..']', strumPositions[i]
		local sX, sY = getProperty(s..'.x'), getProperty(s..'.y')
		if sPos == nil or (sPos[1] ~= sX or sPos[2] ~= sY) then
			setProperty(tag..'.x', getProperty(s..'.x') + getProperty(s..'.width')/2 - getProperty(tag..'.textField.textWidth')/2)
			setProperty(tag..'.y', getProperty(s..'.y') + getProperty(s..'.height')/2 - getProperty(tag..'.textField.textHeight')/2)

			tag = tag..'_actionLabel'
			setProperty(tag..'.x', getProperty(s..'.x'))
			setProperty(tag..'.y', getProperty(s..'.y') + getProperty(s..'.height') - getProperty(tag..'.textField.textHeight'))

			sPos = {sX, sY}
		end
	end
end

local function hideTestMarkers()
	if not editor_testingModchart then return end
	setProperty('editor_markerGroup.visible', false)
	setProperty('strumLineNotes.visible', true)
	for i = 0, 7 do
		setProperty('editor_testMarker'..i..'.alpha', 1)
		setProperty('editor_testMarker'..i..'_actionLabel.alpha', 1)
	end
	editor_testingModchart = false
end

function editor_onActionFinished(obj, actionNum)
	if not editor_testingModchart then return end
	local i = obj:sub(#obj-1, #obj-1)
	local numActions = modchartData.objects['strumLineNotes.members['..i..']'].numActions
	setTextString('editor_testMarker'..i..'_actionLabel', 'Action '..(actionNum+1 <= numActions and actionNum+1 or 1)..'/'..numActions)
end

local function checkAndCreateDirectory(dir) -- Absolute path
	if checkFileExists(dir, true) then return true end
	if version > '0.6.3' then callMethodFromClass('sys.FileSystem', 'createDirectory', {dir})
	else runHaxeCode("FileSystem.createDirectory('"..dir.."');") end
end

local function adjustModchartScroll() -- Automatically adjust positions when importing a downscroll modchart while on upscroll/vice versa
	if modchartData.downscroll == downscroll then return false end
	for obj, actionArray in pairs(modchartData.objects) do
		for _, arr in ipairs(actionArray.actions) do
			if arr.y then arr.y = 620 - arr.y end
		end
	end
	modchartData.downscroll = downscroll
	return true
end

local function exportModchart(dataOnly, finishFunc)
	if tabSaves['File']['Name'].value ~= nil then modchartData.name = tabSaves['File']['Name'].value end
	checkAndCreateDirectory('mods/savedModcharts')
	if dataOnly then
		saveFile('mods/savedModcharts/'..modchartData.name..'_data.txt', 'modchartData = '..print_table(modchartData, true), true)
		addTextToDebug('Save: '..modchartData.name..'_data.txt successfully saved to mods/savedModcharts/', 'FFFF00')
	else
		saveFile('mods/savedModcharts/'..modchartData.name..'.lua', generateModchart(), true)
		addTextToDebug('Save: '..modchartData.name..'.lua successfully saved to mods/savedModcharts/', 'FFFF00')
	end
	if finishFunc then finishFunc() end
end

local function importModchart(name, isLua)
	local dir = not wasTest and 'savedModcharts' or 'scripts'
	checkAndCreateDirectory('mods/'..dir)
	local rName = name..(isLua and '.lua' or '_data.txt')
	local file = (version > '0.6.3' and callMethodFromClass('sys.io.File', 'getContent', {'mods/'..dir..'/'..rName}) or runHaxeCode("return File.getContent('mods/"..dir.."/"..rName.."');")):gsub('\n', ''):gsub('\r', '')
	local cutFile = isLua and stringSplit(stringSplit(file, 'modchartData = ')[2], 'local')[1] or file:gsub('modchartData = ', '')
	if wasTest then return string_to_table(cutFile) end
	modchartData = string_to_table(cutFile)
	updateOptionState('File_Name_Textbox', modchartData.name)
	if curTab == 'File' then tabSaves['File']['Name'].update() end
	adjustModchartScroll()
	addTextToDebug('Load: '..rName..' successfully loaded!', 'FFFF00')
end

local function resetModchart() modchartData.objects = {} addTextToDebug('Reset: Strum data in this modchart has been cleared', 'FFFF00') end

local warningItems = {'editor_warningBG', 'editor_warningOutline', 'editor_warningBox', 'editor_warningText', 'editor_warningNoOutline', 'editor_warningNoBox', 'editor_warningNoText', 'editor_warningYesOutline', 'editor_warningYesBox', 'editor_warningYesText'}
local warningOptions = {'editor_warningNo', 'editor_warningYes'}
local function showWarning(message, options, confirmF, confirmA)
	if editor_inputsLocked or editor_inWarning then return end
	local size, boxW = 700, 150
	editor_inputsLocked = true
	makeLuaSprite('editor_warningBG')
	makeGraphic('editor_warningBG', 1, 1, '000000')
	setProperty('editor_warningBG.alpha', 0)
	scaleObject('editor_warningBG', screenWidth, screenHeight)
		
	makeLuaSprite('editor_warningBox')
	makeGraphic('editor_warningBox', 1, 1, '000000')
	setProperty('editor_warningBox.alpha', 0)
	scaleObject('editor_warningBox', size, size/2)
	screenCenter('editor_warningBox')
	
	makeLuaSprite('editor_warningOutline')
	makeGraphic('editor_warningOutline', 1, 1, '39e75f')
	setProperty('editor_warningOutline.alpha', 0)
	scaleObject('editor_warningOutline', getProperty('editor_warningBox.scale.x')+10, getProperty('editor_warningBox.scale.y')+10)
	setProperty('editor_warningOutline.x', getMidpointX('editor_warningBox') - getProperty('editor_warningOutline.width')/2)
	setProperty('editor_warningOutline.y', getMidpointY('editor_warningBox') - getProperty('editor_warningOutline.height')/2)
	
	makeLuaText('editor_warningText', message, size-20, getProperty('editor_warningBox.x'), getProperty('editor_warningBox.y')+50)
	setProperty('editor_warningText.alpha', 0)
	setTextFont('editor_warningText', editor_mainFont)
    setTextSize('editor_warningText', 20)
	setTextBorder('editor_warningText', 1, '000000', 'outline_fast')
	--[[if version > '0.7.3' then -- even on 1.0+ this doesnt work and im not really sure why lmao
		if not editor_warning_markupCreated then
			createInstance('editor_yellowFormat2', 'flixel.text.FlxTextFormat', {getColorFromHex('FFFF00'), false, false, getColorFromHex('000000')})
			createInstance('editor_yellowFormat', 'flixel.text.FlxTextFormatMarkerPair', {instanceArg('editor_yellowFormat2'), '$'})
			editor_warning_markupCreated = true
		end
		callMethod('editor_warningText.applyMarkup', {message, instanceArg('editor_yellowFormat')})
	else]]
		runHaxeCode([[
			var yellowFormat = new FlxTextFormatMarkerPair(new FlxTextFormat(0xFFFFFF00, false, false, 0xFF000000), '$');
			game.getLuaObject('editor_warningText').applyMarkup(']]..message..[[', [yellowFormat]);
		]])
	--end
	
	for i, v in ipairs(options) do
		local name = 'editor_warning'..(i == 1 and 'No' or 'Yes')
		makeLuaSprite(name..'Box', nil, nil, getMidpointY('editor_warningBox') + 50)
		makeGraphic(name..'Box', 1, 1, '000000')
		setProperty(name..'Box'..'.alpha', 0)
		scaleObject(name..'Box', boxW, 40)
		setProperty(name..'Box.x', getMidpointX('editor_warningBox') + (i == 1 and -boxW*2 or boxW))

		makeLuaSprite(name..'Outline')
		makeGraphic(name..'Outline', 1, 1, 'FFFFFF')
		setProperty(name..'Outline.alpha', 0)
		scaleObject(name..'Outline', getProperty(name..'Box.scale.x')+10, getProperty(name..'Box.scale.y')+10)
		setProperty(name..'Outline.x', getMidpointX(name..'Box') - getProperty(name..'Outline.width')/2)
		setProperty(name..'Outline.y', getMidpointY(name..'Box') - getProperty(name..'Outline.height')/2)
		
		makeLuaText(name..'Text', v, boxW)
		setProperty(name..'Text.alpha', 0)
		setTextFont(name..'Text', editor_mainFont)
		setTextSize(name..'Text', 16)
		setTextBorder(name..'Text', 1, '000000', 'outline_fast')
		setProperty(name..'Text.x', getMidpointX(name..'Box') - getProperty(name..'Text.width')/2)
		setProperty(name..'Text.y', getMidpointY(name..'Box') - getProperty(name..'Text.height')/2)
	end
	local q
	if version > '0.7.3' then q = true
	else runHaxeCode("for (spr in ['editor_warningBG', 'editor_warningOutline', 'editor_warningBox', 'editor_warningText', 'editor_warningNoOutline', 'editor_warningNoBox', 'editor_warningNoText', 'editor_warningYesOutline', 'editor_warningYesBox', 'editor_warningYesText']) game.getLuaObject(spr).camera = getVar('camMenu');") end
	for _, spr in ipairs(warningItems) do
		if q then callMethod(spr..'.set_camera', {instanceArg('camMenu')}) end
		if stringEndsWith(spr, 'Text') then addLuaText(spr) else addLuaSprite(spr, true) end
		doTweenAlpha('editor_warningTweenOpen_'..spr, spr, _ == 1 and 0.7 or 1, 0.9, 'cubeInOut')
	end
	setProperty('editor_music.volume', getProperty('editor_music.volume')-0.18)
	editor_warning_confirmFunc, editor_warning_confirmArgs = confirmF, confirmA
	runTimer('editor_startWarning', 0.4)
end

local function closeWarning()
	for _, spr in ipairs(warningItems) do doTweenAlpha('editor_warningTweenClose_'..spr, spr, 0, 0.6, 'cubeInOut') end
	setProperty('editor_music.volume', getProperty('editor_music.volume')+0.18)
end

editor_memory = {}
local class, editor_initMemory

function initMemory()
	local existingMemory = getPropertyFromClass(class, 'SONG.modchartEditorMemory')
	if existingMemory ~= nil and type(existingMemory) == 'table' then
		editor_memory = existingMemory
	end
	editor_initMemory = true
end

function flushMemory()
	if not editor_initMemory then return end
	setPropertyFromClass(class, 'SONG.modchartEditorMemory', editor_memory)
end

function clearMemory()
	setPropertyFromClass(class, 'SONG.modchartEditorMemory')
end

--[[
Here's all the data that the editor currently remembers:
	editor_memory = {
		active = false
		showedTooltip = false
		testingModchart = 1
		cachedModchart = {}
		
		curTab = ''
		currentStrumEditing = ''
		editor_curAction = 0
	}
]]

function onCreate()
	luaDebugMode, luaDeprecatedWarnings = editor_debugMode, editor_debugMode
	class = (version > '0.6.3' and 'states.' or '')..'PlayState'

	if buildTarget == 'android' or getPropertyFromClass('flixel.FlxG', 'onMobile') then -- Android support (real!)
		editor_onMobile = true
	else editor_onMobile = false end

	initMemory()

	local function mouseOverlaps(obj, camera)
    	if version > '0.7.3' then return callMethodFromClass('flixel.FlxG', 'mouse.overlaps', {instanceArg(obj), instanceArg(obj..'.camera')})
    	elseif version < '0.7' then
      		return runHaxeCode([[
        		var obj = game.getLuaObject(']]..obj..[[');
        		return FlxG.mouse.overlaps(obj, obj.camera);
      		]])
    	end
    	if not camera then camera = 'camHUD' end
    	local mX, mY = getMouseX(camera) + getProperty(camera .. '.scroll.x') * getProperty(obj .. '.scrollFactor.x'), getMouseY(camera) + getProperty(camera .. '.scroll.y') * getProperty(obj .. '.scrollFactor.y')
    	local x, y = getProperty(obj .. '.x'), getProperty(obj .. '.y')
    	local width, height = getProperty(obj .. '.width'), getProperty(obj .. '.height')
    	return (mX > x) and (mX < x + width) and (mY > y) and (mY < y + height)
	end

	if not editor_memory.active and (editor_memory.testingModchart or -1) < 1 then -- Show the tooltip to open the editor
		onSongStart, onUpdatePost = nil

		if editor_onMobile then
			makeLuaSprite('editor_return', nil, nil, 60)
			setObjectCamera('editor_return', 'other')
			makeGraphic('editor_return', 1, 1, '0000FF')
			scaleObject('editor_return', 75, 75)
			screenCenter('editor_return', 'x')
			setProperty('editor_return.alpha', not editor_memory.showedTooltip and 0.9 or 0.09)
			addLuaSprite('editor_return', true)
			if not editor_memory.showedTooltip then runTimer('editor_returnTween', 1.22) end
		end

		if not editor_memory.showedTooltip then 
			addTextToDebug('Modchart Editor: Press '..(editor_onMobile and 'BLUE SQUARE' or '5')..' to open', 'FFFF00')
			editor_memory.showedTooltip = true
			flushMemory()
		end

		function onTimerCompleted(t)
			if t ~= 'editor_returnTween' then return end
			doTweenAlpha('editor_hideSquare', 'editor_return', 0.09, 1, 'cubeInOut')
		end

		function onUpdate()
			if editor_memory.active then return end
			if not editor_onMobile and not keyboardJustPressed('FIVE') or editor_onMobile and (not mouseOverlaps('editor_return', 'camOther') or not mouseClicked() or getProperty('endingSong')) then return end
			editor_memory.active = true
			flushMemory()
			restartSong()
		end	
		return 
	end

	if (editor_memory.testingModchart or -1) > 0 then -- 0: Not testing modchart, 1: testing, 2: returning from test
		if editor_memory.testingModchart == 1 then -- User had restarted to test the modchart
			--deleteFile('mods/scripts/modchartEditor_test_temp.lua', false, true)
			--deleteFile('scripts/modchartEditor_test_temp.lua', false, true) -- Somehow the above line didnt work on 0.7.3 so i guess this fixes it??
			-- ^ Moving these to the temp file in case the editor is in the scripts folder, which would delete the temp before it loads
			setPropertyFromClass(class, 'chartingMode', true)
			if getTableLength(editor_memory.cachedModchart.objects) <= 0 then addTextToDebug('Modchart Editor: Your modchart is empty, so nothing has changed', 'FFFF00') end
			addTextToDebug('Modchart Editor: Press '..(editor_onMobile and 'BLUE SQUARE' or 'BACKSPACE')..' to return to the editor', 'FFFF00')
			editor_memory.testingModchart = 2
			flushMemory()
			
			if not editor_onMobile then
				close()
			else
				onSongStart, onUpdatePost = nil

				makeLuaSprite('editor_return', nil, nil, 60)
				setObjectCamera('editor_return', 'other')
				makeGraphic('editor_return', 1, 1, '0000FF')
				scaleObject('editor_return', 75, 75)
				screenCenter('editor_return', 'x')
				setProperty('editor_return.alpha', 0.56)
				addLuaSprite('editor_return', true)

				function onUpdate()
					if ended or not mouseOverlaps('editor_return', 'camOther') or not mouseClicked() or getProperty('endingSong') then return end
					ended = true
					restartSong()
				end
			end
			return
		elseif editor_memory.testingModchart == 2 then -- Restore the saved data from before the test
			modchartData = editor_memory.cachedModchart
			adjustModchartScroll()
			editor_memory.testingModchart = 0
			editor_memory.cachedModchart = nil

			flushMemory()
		end
	else
		editor_memory.active = false
		flushMemory()
	end

	function onPause() return Function_Stop end -- Somehow setting canPause doesnt do anything here on 1.0.4, idk about 0.7.x
	function onCountdownStarted() setProperty('vocals.volume', 0) if getProperty('opponentVocals._sound') then setProperty('opponentVocals.volume', 0) end end

	if not editor_mainFont or editor_mainFont == '' then
		editor_mainFont = version > '0.7.3' and 'pixel-latin.ttf' or 'pixel.otf'
	end
	
	setProperty('skipCountdown', true)
	
	ogMouseVisibility = getPropertyFromClass('flixel.FlxG', 'mouse.visible')
	setPropertyFromClass('flixel.FlxG', 'mouse.visible', true)
	ogGameMuted = getPropertyFromClass('flixel.FlxG', 'sound.muted')
	setPropertyFromClass('flixel.FlxG', 'sound.muted', true) -- This is needed to prevent you from can hearing the vocals for a split second while the script loads
	
	function getSongPosition()
		if not editor_started then return 0 end
		return getProperty('editor_music.time')
	end
    modchartData.downscroll = downscroll
end

function onSongStart()
    if version > '0.7.3' and version < '1.0.2' then runHaxeCode("") end -- Weird hscript iris thing compatibility thing, we need this to actually start up our first hscript instance
	if version < '0.7' then addHaxeLibrary('StringTools') end
	addHaxeLibrary('FlxRect', 'flixel.math')
	--addHaxeLibrary('FlxSound', 'flixel.'..(version > '0.6.3' and 'sound' or 'system')) -- Breaks on most compiled 0.6.3 builds
	addHaxeLibrary('FileSystem', 'sys')
	addHaxeLibrary('FlxTextFormat', 'flixel.text')
	addHaxeLibrary('FlxTextFormatMarkerPair', 'flixel.text')
    if version > '0.7.3' then addHaxeLibrary('PsychUIInputText', 'backend.ui')
	else addHaxeLibrary('FlxUIInputText', 'flixel.addons.ui') end
	addHaxeLibrary('File', 'sys.io')
	addHaxeLibrary('PlayState', version > '0.6.3' and 'states' or '')
	addHaxeLibrary('Type', '')
	addHaxeLibrary('EReg', '')
    runHaxeCode([[
        setVar('editor_legacyFlxSound', Type.resolveClass('flixel.sound.FlxSound') == null);
        new FlxTimer().start(0.0001, function(tmr:FlxTimer){
			game.variables.remove('editor_legacyFlxSound');
        });

		if (getVar('editor_focusCallbackGain') == null){
			function copyA(arr){
				var ret;
				ret = [];
				for (v in arr) ret.push(v);
				return ret;
			}
			function gain(){
				FlxG.stage.window.textInputEnabled = true;
				setVar('editor_volumeCache', [copyA(FlxG.sound.volumeUpKeys), copyA(FlxG.sound.volumeDownKeys), copyA(FlxG.sound.muteKeys)]);
				for (soundA in [FlxG.sound.volumeUpKeys, FlxG.sound.volumeDownKeys, FlxG.sound.muteKeys]) soundA.resize(0);
			}
			function lost(){
				FlxG.stage.window.textInputEnabled = false;
				var soundC;
				soundC = getVar('editor_volumeCache');
				FlxG.sound.volumeUpKeys = soundC[0];
				FlxG.sound.volumeDownKeys = soundC[1];
				FlxG.sound.muteKeys = soundC[2];
				game.variables.remove('editor_volumeCache');
			}
			setVar('editor_focusCallbackGain', gain);
			setVar('editor_focusCallbackLost', lost);
		}
    ]]) 
	if getProperty('editor_legacyFlxSound') then addHaxeLibrary('FlxSound', 'flixel.system')
	else addHaxeLibrary('FlxSound', 'flixel.sound') end -- Im a genius
	
	setProperty('camZooming', false)
	setProperty('canPause', false)
	setProperty('canReset', false)

	-- Stop the vocals/music...not too elegant but it works
	setPropertyFromClass((version > '0.6.3' and 'backend.' or '') ..'Conductor', 'songPosition', -10000000000000000000000) --this is needed on 1.0.4 to stop the first few notes of the song from appearing
	if version < '0.7' then runHaxeCode('FlxG.sound.music.stop();') else callMethodFromClass('flixel.FlxG', 'sound.music.stop', {''}) end
	
	if version > '0.6.3' then
		function onResume()
			callMethodFromClass('flixel.FlxG', 'sound.music.pause', {''})
			callMethod('vocals.pause', {''})
			if getProperty('opponentVocals._sound') then callMethod('opponentVocals.pause', {''}) end
		end
		onResume()
		setProperty('allowDebugKeys', false)
	else
		--setProperty('playbackRate', 0)
		setProperty('debugKeysChart', {})
		setProperty('debugKeysCharacter', {})
	end
	setPropertyFromClass('flixel.FlxG', 'sound.muted', ogGameMuted)
	--[[
	-- Position the camera on gf if she isn't hidden
	if not getPropertyFromClass((version > '0.6.3' and 'backend.' or '')..'StageData', 'hide_girlfriend') then
		setProperty('camFollow.x', getMidpointX('gf') + getProperty('girlfriendCameraOffset[0]') + getProperty('gf.cameraPosition[0]'))
		setProperty('camFollow.y', getMidpointY('gf') + getProperty('girlfriendCameraOffset[1]') + getProperty('gf.cameraPosition[1]'))
		if version > '0.6.3' then callMethod('camGame.snapToTarget', {''}) else runHaxeCode("game.camGame.snapToTarget();") end
	end
	]]
	setProperty('isCameraOnForcedPos', true)

	for i = 0, 7 do
		local s = 'strumLineNotes.members['..i..']'
		_G['default'..getStrumInfoFromID(s)[2][1]..'StrumAlpha'..getStrumInfoFromID(s)[2][2]] = getProperty(s..'.alpha')
		_G['default'..getStrumInfoFromID(s)[2][1]..'StrumAngle'..getStrumInfoFromID(s)[2][2]] = getProperty(s..'.angle')
		_G['default'..getStrumInfoFromID(s)[2][1]..'StrumDirection'..getStrumInfoFromID(s)[2][2]] = getProperty(s..'.direction')
	end
	
	editor_curAction = editor_memory.editor_curAction
	currentStrumEditing = editor_memory.currentStrumEditing or nil

	drawUI()
	openTab(editor_memory.curTab or 'File')
end

local function onStepHit()
	if editor_inputsLocked or not modchartData.settings.camZooming then return end
	if curStep % 4 == 0 then
		scaleObject('iconP1', 1.2, 1.2)
		scaleObject('iconP2', 1.2, 1.2)
	end
	if curStep % 16 == 0 then
		setProperty('camGame.zoom', getProperty('camGame.zoom')+0.015)
		setProperty('camHUD.zoom', getProperty('camHUD.zoom')+0.03)
	end
end

function onUpdate()
	if not editor_started then return end
    local prevStep = curStep
    curStep = math.floor(getSongPosition() / stepCrochet)
    if curStep ~= prevStep then onStepHit() end

	if evenFrame then
		refmX, refmY = lastmX, lastmY -- Had to use this to check for mouse movement, the camera lerp somehow messed with the built in variable
		if version > '0.7.3' then
			refCurText = getPropertyFromClass('backend.ui.PsychUIInputText', 'focusOn')
		end
	end
end

function onUpdatePost(e)
	if not evenFrame then
		lastmX, lastmY = unpack(getScreenPosition('camMenu'))
		mouseJustMoved = not ((refmX == lastmX) and (refmY == lastmY))

		if version > '0.7.3' then
			local curText = getPropertyFromClass('backend.ui.PsychUIInputText', 'focusOn')
			if refCurText ~= curText then
				if not curText and isTyping() then callMethod('editor_focusCallbackLost', {''})
				elseif curText ~= nil then callMethod('editor_focusCallbackGain', {''}) end
				refCurText = curText
			end
		end
	end

	if editor_started and not editor_inputsLocked then
		if not editor_testingModchart and not editor_trackingMouse and not isTyping() then  -- If you aren't busy or typing
			if keyboardJustPressed('ALT') then
				showWarning('Your modchart will be saved to $mods/savedModcharts/'..(tabSaves['File']['Name'].value or modchartData.name)..'$.\nSave and exit?', {'no', 'yes'}, exportModchart, {nil, function() editor_inputsLocked = true destroyUI(true) end})
				return
			elseif keyboardJustPressed('ESCAPE') then
				showWarning('Any unsaved progress will be lost.\nQuit to the menu?', {'no', 'yes'}, destroyUI, {true})
				return
			elseif keyboardJustPressed('ENTER') then
				local code = generateModchart()
				code = code .. [[
-- Extra features since the user is testing this modchart
local ended]]..(editor_debugMode and ', set' or '')..[[

local deletedSelf
function onUpdate()]]..(editor_debugMode and '\nif not set then set = true luaDebugMode = true luaDeprecatedWarnings = true end' or '')..[[

	if not deletedSelf then deletedSelf = true
		deleteFile('mods/scripts/modchartEditor_test_temp.lua', false, true)
		deleteFile('scripts/modchartEditor_test_temp.lua', false, true)
	end
	if ended or getProperty('endingSong') then return end
	if keyboardJustPressed('BACKSPACE') then ended = true restartSong() end
end

function onEndSong()
	restartSong() 
	return Function_Stop
end

function onGameOver()
	debugPrint('you kinda suck lol')
	restartSong()
	return Function_Stop
end

function onDestroy()
	setPropertyFromClass((version > '0.6.3' and 'states.' or '')..'PlayState', 'chartingMode', ]]..tostring(getPropertyFromClass(class, 'chartingMode'))..[[)
end]]
				checkAndCreateDirectory('mods/scripts')
				saveFile('mods/scripts/modchartEditor_test_temp.lua', code, true)
				editor_memory.testingModchart = 1
				editor_memory.cachedModchart = modchartData

				editor_memory.curTab = curTab
				editor_memory.currentStrumEditing = currentStrumEditing
				editor_memory.editor_curAction = editor_curAction

				flushMemory()
				restartSong()
			end
		end
		
		if editor_testingModchart then
			updateTestMarkers()

			if keyboardJustPressed('Q') then tabSaves['Test']['Pause'].customUpdate() end
			if keyboardJustPressed('E') then tabSaves['Test']['Resume'].customUpdate() end
		end

		-- Mouse stuff
		if draggingUI and mousePressed() then updateUIPositions()
		elseif draggingUI and not mousePressed() then draggingUI = false; initialmX, initialmY, initialuiX, initialuiY = nil, nil, nil, nil end
	
		if not draggingUI and mouseOverlaps('UIBox', nil, nil, tabHeight) and mousePressed() and mouseJustMoved then -- the bop somehow counted as moving the mouse
			draggingUI = true
			initialmX, initialmY = unpack(getScreenPosition('camMenu'))
			initialuiX, initialuiY = getProperty('UIBox.x'), getProperty('UIBox.y')
		end
		
		if mouseJustMoved or mousePressed() then
			if editor_trackingMouse and not editor_copyingStrum then
				local cancelledCustomCords, doneTracking
				if currentStrumEditing == nil then return end
				if not editor_trackingOriginalPosX then editor_trackingOriginalPosX, editor_trackingOriginalPosY = getProperty(currentStrumEditing..'.x'), getProperty(currentStrumEditing..'.y') end
				if mouseClicked() then 
					editor_trackingMouse = false; 
					local curTab, key = 'Values', 'CustomCords'
					if (mouseOverlaps(curTab..'_'..key..'_Body') or mouseOverlaps(curTab..'_'..key..'_Text')) and tabSaves[curTab][key].customUpdate ~= nil then cancelledCustomCords = true end
					setProperty(currentStrumEditing..'.x', editor_trackingOriginalPosX) setProperty(currentStrumEditing..'.y', editor_trackingOriginalPosY) 
					doneTracking = true
				end
				if not cancelledCustomCords then 
					setProperty(currentStrumEditing..'.x', lastmX) 
					setProperty(currentStrumEditing..'.y', lastmY) 
					tabSaves['Values']['X'].value = lastmX
					tabSaves['Values']['Y'].value = lastmY
				else
					tabSaves['Values']['X'].value = editor_trackingOriginalPosX
					tabSaves['Values']['Y'].value = editor_trackingOriginalPosY
				end
				if mouseClicked() or cancelledCustomCords then editor_trackingOriginalPosX, editor_trackingOriginalPosY = nil, nil end
				tabSaves['Values']['X'].update()
				tabSaves['Values']['Y'].update()
				tabSaves['Values']['X'].customUpdate('Values', 'X')
				tabSaves['Values']['Y'].customUpdate('Values', 'Y')
				if cancelledCustomCords or doneTracking then return end
			end

			if mouseOverlaps('UIBox_minimizeBG') or mouseOverlaps('UIBox_minimizeIcon') then
				if mouseClicked() then
					setProperty('UIBox_minimizeBG.color', 0)
					editor_minimized = not editor_minimized

					setProperty('UIBox.visible', not editor_minimized)
					for i = 0, getProperty('curOptions.length')-1 do
						setProperty(getProperty('curOptions['..i..']')..'.visible', not editor_minimized)
					end
				else
					setProperty('UIBox_minimizeBG.color', 0xFFFFFF)
				end
			else
				setProperty('UIBox_minimizeBG.color', 0)
			end
				
			if not editor_testingModchart and not editor_trackingMouse and not editor_minimized then
				for _, a in ipairs(UITabs) do
					local onTab, onTabName = mouseOverlaps('UITab_'..a), mouseOverlaps('UITabName_'..a)
					if not onTab and not onTabName and curTab ~= a then
						setProperty('UITab_'..a..'.color', 0x000000)
					elseif (onTab or onTabName) and mouseClicked() and curTab ~= a then
						setProperty('UITab_'..a..'.color', 0x000000)
						openTab(a)
					else setProperty('UITab_'..a..'.color', 0xFFFFFF) end
				end
			end
			
			if tabOptions[curTab] and curTab ~= 'Values' and not editor_minimized or tabOptions[curTab] and currentStrumEditing ~= nil and not editor_minimized then
				local dropdownOverlapping = false
				for key, option in pairs(tabOptions[curTab]) do
					if stringTrim(option[2]:lower()) == 'dropdown' then
						if (mouseOverlaps(curTab..'_'..key..'_Body') or mouseOverlaps(curTab..'_'..key..'_BodyButton')) then dropdownOverlapping = true end
						setProperty(curTab..'_'..key..'_BodyButton'..'.color', (mouseOverlaps(curTab..'_'..key..'_Body') or mouseOverlaps(curTab..'_'..key..'_BodyButton')) and not mouseClicked() and 0x808080 or (mouseOverlaps(curTab..'_'..key..'_Body') or mouseOverlaps(curTab..'_'..key..'_BodyButton')) and mouseClicked() and 0x000000 or 0xD3D3D3)				
						local selectedSomethin = false
						if currentDropdown == curTab..'_'..key..'_SelectedText' then
							for i = 1, tabSaves[curTab][key].extraData[2] do
								if (mouseOverlaps(currentDropdown:gsub('SelectedText', 'DSelectionBG_'..i)) or mouseOverlaps(currentDropdown:gsub('SelectedText', 'DSelectionText_'..i))) then
									setTextColor(currentDropdown:gsub('SelectedText', 'DSelectionText_'..i), 'FFFFFF')
									setProperty(currentDropdown:gsub('SelectedText', 'DSelectionBG_'..i)..'.color', 0x3399ff)
									if mouseClicked() then 
										selectedSomethin = true 
										updateOptionState(currentDropdown, tabSaves[curTab][key].extraData[1][i]) 
										setTextString(currentDropdown, tabSaves[curTab][key].value) 
										if tabSaves[curTab][key].customUpdate ~= nil then tabSaves[curTab][key].customUpdate(curTab, key) end
									end
								else
									setTextColor(currentDropdown:gsub('SelectedText', 'DSelectionText_'..i), '000000')
									setProperty(currentDropdown:gsub('SelectedText', 'DSelectionBG_'..i)..'.color', 0xFFFFFF)
								end
							end
						end
						if (mouseOverlaps(curTab..'_'..key..'_Body') or mouseOverlaps(curTab..'_'..key..'_BodyButton')) and mouseClicked() then 
							if currentDropdown ~= nil then
								deleteDropdown()
							end 
							currentDropdown = curTab..'_'..key..'_SelectedText' tabSaves[curTab][key].update()
						elseif mouseClicked() and currentDropdown ~= nil and not dropdownOverlapping and (selectedSomethin or not selectedSomethin and currentDropdown == curTab..'_'..key..'_SelectedText' ) then 
							deleteDropdown()
							return
						end
						if selectedSomethin then 
							if currentDropdown ~= nil then deleteDropdown() end 
							return 
						end -- Stops selection overlapping on dropdowns, why its able to stop this idfk lmao
					elseif stringTrim(option[2]:lower()) == 'check' and not editor_testingModchart then
						setProperty(curTab..'_'..key..'_CheckBox'..'.color', (mouseOverlaps(curTab..'_'..key..'_CheckBox') and not mouseClicked() and 0xD3D3D3 or mouseOverlaps(curTab..'_'..key..'_CheckBox') and 0x808080 or 0xFFFFFF))
						if mouseOverlaps(curTab..'_'..key..'_CheckBox') and mouseClicked() then tabSaves[curTab][key].update() if tabSaves[curTab][key].customUpdate ~= nil then tabSaves[curTab][key].customUpdate(curTab, key) end end
					elseif stringTrim(option[2]:lower()) == 'button' and not dropdownOverlapping and (not editor_testingModchart or curTab == 'Test' and (key == 'Stop' or key == 'Pause' or key == 'Resume')) then
						local onBody, onText = mouseOverlaps(curTab..'_'..key..'_Body'), mouseOverlaps(curTab..'_'..key..'_Text')
						if not editor_trackingMouse or curTab == 'Values' and (key == 'CustomCords' or (editor_copyingStrum and key == 'Copy')) then
							setProperty(curTab..'_'..key..'_Body'..'.color', (onBody or onText) and not mouseClicked() and not currentDropdown and getColorFromHex(option[4][2] or '808080') or getColorFromHex(option[4][1] or '000000'))
							if not currentDropdown and (onBody or onText) and mouseClicked() and tabSaves[curTab][key].customUpdate ~= nil then tabSaves[curTab][key].customUpdate(curTab, key) end
						end
					elseif stringTrim(option[1]:lower()) == 'clone' and mouseOverlaps(curTab..'_'..key..'_Clone') and not editor_testingModchart then
						if mouseClicked() and tabSaves[curTab][key].customUpdate ~= nil then tabSaves[curTab][key].customUpdate(curTab, key) end
					end
				end
			end
		end
		setProperty('camGame.zoom', lerp(getProperty('defaultCamZoom'), getProperty('camGame.zoom'), boundTo(1 - (e * 3.125 * getProperty('camZoomingDecay')), 0, 1)));
		setProperty('camHUD.zoom', lerp(1, getProperty('camHUD.zoom'), boundTo(1 - (e * 3.125 * getProperty('camZoomingDecay')), 0, 1)));
		local mult, mult2 = lerp(1, getProperty('iconP1.scale.x'), math.exp(-e * 9)), lerp(1, getProperty('iconP2.scale.x'), math.exp(-e * 9));
		scaleObject('iconP1', mult, mult)
		scaleObject('iconP2', mult2, mult2)
		
		if not editor_testingModchart then
			local canSelectStrum = not mouseOverlaps('UIBox', nil, nil, tabHeight)
			for i = 0, 7 do
				local s = 'strumLineNotes.members['..i..']'
				local overlaps, clicked = mouseOverlaps(s), mouseClicked()
				if canSelectStrum and currentStrumEditing ~= s then 
					if not editor_copyingStrum and overlaps and clicked then
						local prevStrumEditing
						if currentStrumEditing ~= nil then prevStrumEditing = currentStrumEditing deselectCurrentStrum() end 
						currentStrumEditing = s
						if curTab == 'Values' then
							editor_curAction = 1 
							-- third arg of openTab needs to be false to recycle the current menu objects to save on performance
							openTab(curTab, true, ((modchartData.objects[currentStrumEditing] == nil) ~= (modchartData.objects[prevStrumEditing] == nil)))
						end
					elseif editor_copyingStrum and modchartData.objects[s] then
						updateColorOffsets(s, overlaps and 100)

						if overlaps and clicked then
							modchartData.objects[currentStrumEditing] = deepcopy(modchartData.objects[s])
							for i = 0, 7 do updateColorOffsets('strumLineNotes.members['..i..']') end
							editor_copyingStrum, editor_trackingMouse = false, false
							addTextToDebug('Copy: Successfully copied '..getStrumInfoFromID(s)[1]..'!', 'FFFF00')
							openTab(curTab, true, true)
						end
					end
				end
			end
			if currentStrumEditing ~= nil and not editor_copyingStrum then
				updateColorOffsets(currentStrumEditing, -1 * math.abs(math.sin(getSongPosition() * 0.003) *31 + 60))
			end
		end
	end
	
	if editor_inWarning then
		for _, v in ipairs(warningOptions) do
			local selecting = (mouseOverlaps(v..'Box') or mouseOverlaps(v..'Text'))
			setProperty(v..'Outline.color', selecting and getColorFromHex('FFFF00') or getColorFromHex('FFFFFF'))
			if (selecting and mouseClicked()) or (keyboardJustPressed('ENTER') or keyboardJustPressed('ESCAPE')) then
				if editor_inWarning and not keyboardJustPressed('ESCAPE') and (selecting and stringEndsWith(v, 'Yes')) or not keyboardJustPressed('ESCAPE') and keyboardJustPressed('ENTER') and editor_inWarning then editor_inWarning = false editor_warning_confirmFunc(unpack(editor_warning_confirmArgs or {})) end
				if (_ == 1 and keyboardJustPressed('ESCAPE')) or (_ == 2 and keyboardJustPressed('ENTER')) then setProperty(v..'Outline.color', getColorFromHex('FFFF00')) end
				editor_inWarning = false
				closeWarning()
			end
		end

		-- If you click outside the warning box, it closes
		if editor_inWarning and mouseClicked() then
			local isOverlappingWarning
			for k, v in ipairs(warningItems) do
				if k > 1 and mouseOverlaps(v) then isOverlappingWarning = true end -- the k check is to exclude the bg
			end
			if not isOverlappingWarning then
				editor_inWarning = false
				closeWarning()
			end
		end
	end

	evenFrame = not evenFrame
end

local maxOffscreen = 50
function updateUIPositions()
	if initialmX - lastmX == 0 and initialmY - lastmY == 0 then return end
	if currentDropdown ~= nil then
		deleteDropdown()
	end
	if lastmX > 0 - maxOffscreen*9 and lastmX < screenWidth - maxOffscreen and lastmY > 0 - maxOffscreen*9 and lastmY < screenHeight - maxOffscreen then
		setProperty('UIBox.x', initialuiX - initialmX + lastmX)
		setProperty('UIBox.y', initialuiY - initialmY + lastmY)
	end
	local uiX, uiY = getProperty('UIBox.x'), getProperty('UIBox.y')
	setProperty('UIBox_minimizeBG.x', uiX + uiSize[1])
	setProperty('UIBox_minimizeBG.y', uiY-tabHeight)
	setProperty('UIBox_minimizeIcon.x', uiX+uiSize[1]+mSize[1]/2-getProperty('UIBox_minimizeIcon.width')/2)
	setProperty('UIBox_minimizeIcon.y', uiY+mSize[2]/2-getProperty('UIBox_minimizeIcon.height')/2-tabHeight)

	for i, tab in ipairs(UITabs) do
		setProperty('UITab_'..tab..'.x', uiX + getProperty('UITab_'..tab..'.width') * i - getProperty('UITab_'..tab..'.width'))
		setProperty('UITab_'..tab..'.y', uiY - getProperty('UITab_'..tab..'.height'))
		setProperty('UITabName_'..tab..'.x', getMidpointX('UITab_'..tab) - getProperty('UITabName_'..tab..'.width')/2)
		setProperty('UITabName_'..tab..'.y', getMidpointY('UITab_'..tab) - getProperty('UITabName_'..tab..'.height')/2)
	end
	if curTab == 'Values' and currentStrumEditing == nil then
		setProperty(curTab..'_sys_NoStrumSelected_Text.x', uiX)
		setProperty(curTab..'_sys_NoStrumSelected_Text.y', -40 + uiY + getProperty('UIBox.height')/2)
	end
	if not tabOptions[curTab] or curTab == 'Values' and currentStrumEditing == nil then return end
	for key, option in pairs(tabOptions[curTab]) do
		local uiX, uiY = getProperty('UIBox.x'), getProperty('UIBox.y')
		if stringTrim(option[1]:lower()) == 'clone' then
			setProperty(curTab..'_'..key..'_Clone'..'.x', uiX + option[3][1])
			setProperty(curTab..'_'..key..'_Clone'..'.y', uiY + option[3][2])
		elseif stringTrim(option[2]:lower()) == 'info' then
			setProperty(curTab..'_'..key..'_Text'..'.x', uiX + option[3][1])
			setProperty(curTab..'_'..key..'_Text'..'.y', uiY + option[3][2])
		elseif stringTrim(option[2]:lower()) == 'check' then
			setProperty(curTab..'_'..key..'_DescText'..'.x', uiX + option[3][1])
			setProperty(curTab..'_'..key..'_DescText'..'.y', uiY + option[3][2])
			setProperty(curTab..'_'..key..'_CheckBox'..'.y', uiY + option[3][2] - (option[6][2] or 0))
			if stringTrim(option[5]:lower()) == 'right' then setProperty(curTab..'_'..key..'_CheckBox'..'.x', getProperty(curTab..'_'..key..'_DescText'..'.x') + getProperty(curTab..'_'..key..'_DescText'..'.textField.textWidth') + (option[6][1] or 0))
			else setProperty(curTab..'_'..key..'_CheckBox'..'.x', getProperty(curTab..'_'..key..'_DescText'..'.x') - getProperty(curTab..'_'..key..'_CheckBox'..'.width') - (option[6][1] or 0)) end
		elseif stringTrim(option[2]:lower()) == 'button' then
			setProperty(curTab..'_'..key..'_Body'..'.x', uiX + option[3][1])
			setProperty(curTab..'_'..key..'_Body'..'.y', uiY + option[3][2])
			setProperty(curTab..'_'..key..'_Outline'..'.x', getMidpointX(curTab..'_'..key..'_Body') - ((option[3][3] + option[4][4])/2))
			setProperty(curTab..'_'..key..'_Outline'..'.y', getMidpointY(curTab..'_'..key..'_Body') - ((option[3][4] + option[4][4])/2))
			setProperty(curTab..'_'..key..'_Text'..'.x', getMidpointX(curTab..'_'..key..'_Body') - getProperty(curTab..'_'..key..'_Text'..'.width')/2)
			setProperty(curTab..'_'..key..'_Text'..'.y', getMidpointY(curTab..'_'..key..'_Body') - getProperty(curTab..'_'..key..'_Text'..'.height')/2)
		elseif stringTrim(option[2]:lower()) == 'textbox' then
			setProperty(curTab..'_'..key..'_Textbox'..'.x', uiX + option[3][1])
			setProperty(curTab..'_'..key..'_Textbox'..'.y', uiY + option[3][2])
			setProperty(curTab..'_'..key..'_DescText'..'.x', uiX + (option[4][1] or option[3][1] or 0))
			setProperty(curTab..'_'..key..'_DescText'..'.y', uiY + (option[4][2] or option[3][2] - getProperty(curTab..'_'..key..'_DescText'..'.textField.textHeight') or 0))
		elseif stringTrim(option[2]:lower()) == 'dropdown' then
			setProperty(curTab..'_'..key..'_Body'..'.x', uiX + option[3][1])
			setProperty(curTab..'_'..key..'_Body'..'.y', uiY + option[3][2])
			setProperty(curTab..'_'..key..'_SelectedText'..'.x', uiX + option[3][1])
			setProperty(curTab..'_'..key..'_SelectedText'..'.y', uiY + option[3][2])
			setProperty(curTab..'_'..key..'_DescText'..'.x', uiX + option[4][1])
			setProperty(curTab..'_'..key..'_DescText'..'.y', uiY + option[4][2])
			setProperty(curTab..'_'..key..'_BodyButton'..'.x', getProperty(curTab..'_'..key..'_Body'..'.x') + getProperty(curTab..'_'..key..'_Body'..'.width'))
			setProperty(curTab..'_'..key..'_BodyButton'..'.y', getProperty(curTab..'_'..key..'_Body'..'.y'))
		end
	end
end

drawUI = function()
	runHaxeCode([[
		var camMenu:FlxCamera = new FlxCamera();
		camMenu.bgColor = 0x0;
		setVar('camMenu', camMenu);
		FlxG.cameras.add(camMenu, false);
		
		var UINames:Array<String> = ['UIBox', 'UIBox_minimizeBG', 'UIBox_minimizeIcon']]..(not editor_onMobile and ", 'tooltips'" or '')..[[];
		setVar('UINames', UINames);
		
		var curOptions:Array<String> = [];
		setVar('curOptions', curOptions);
	]])
	-- Editor tooltips
	if not editor_onMobile then
		makeLuaText('tooltips', 'Escape - Exit without saving\nAlt - Save & Exit to menu\nEnter - Restart & Test modchart', screenWidth, screenWidth - 350, screenHeight - (downscroll and 690 or 120))
		setProperty('tooltips._defaultFormat.leading', 20)
		setTextSize('tooltips', 15)
		setTextFont('tooltips', editor_mainFont)
		setTextBorder('tooltips', 3, '000000', 'outline_fast')
		setTextAlignment('tooltips', 'left')
		setObjectOrder('tooltips', 0)
		if version > '0.7.3' then callMethod('tooltips.set_camera', {instanceArg('camMenu')}) else runHaxeCode("game.getLuaObject('tooltips').camera = getVar('camMenu');") end
	end

	local uiPos, uiAlpha = {50, 150}, 0.6
	makeLuaSprite('UIBox', nil, uiPos[1], uiPos[2])
	makeGraphic('UIBox', 1, 1, '000000')
	scaleObject('UIBox', uiSize[1], uiSize[2])
	setProperty('UIBox.alpha', uiAlpha)
	addLuaSprite('UIBox')

	local n = 'UIBox_minimizeBG'
	makeLuaSprite(n, nil, uiPos[1] + uiSize[1], uiPos[2]-tabHeight)
	makeGraphic(n, 1, 1, 'FFFFFF')
	scaleObject(n, mSize[1], mSize[2])
	setProperty(n..'.alpha', uiAlpha)
	addLuaSprite(n)
	
	local o = 'UIBox_minimizeIcon'
	makeLuaSprite(o)
	makeGraphic(o, 1, 1, 'FFFFFF')
	scaleObject(o, mSize[1]/1.5, mSize[1]/3)
	setProperty(o..'.alpha', uiAlpha)

	setProperty(o..'.x', getProperty(n..'.x')+getProperty(n..'.width')/2-getProperty(o..'.width')/2)
	setProperty(o..'.y', uiPos[2] - tabHeight + mSize[2]/2 - getProperty(o..'.height')/2)
	addLuaSprite(o)

	for i, tab in ipairs(UITabs) do
		makeLuaSprite('UITab_'..tab)
		makeGraphic('UITab_'..tab, 1, 1, 'FFFFFF')
		scaleObject('UITab_'..tab, getProperty('UIBox.width') / #UITabs, tabHeight)
		--setProperty('UITab_'..tab..'.alpha', 0.8)
		setProperty('UITab_'..tab..'.x', getProperty('UIBox.x') + getProperty('UITab_'..tab..'.width') * i - getProperty('UITab_'..tab..'.width'))
		setProperty('UITab_'..tab..'.y', getProperty('UIBox.y') - getProperty('UITab_'..tab..'.height'))
		addLuaSprite('UITab_'..tab)
		
		makeLuaText('UITabName_'..tab, tab, getProperty('UIBox.width') / #UITabs)
		setTextSize('UITabName_'..tab, math.floor(tabHeight/3.3))
		setTextFont('UITabName_'..tab, editor_mainFont)
		setTextBorder('UITabName_'..tab, 1, '000000', 'outline_fast')
		setProperty('UITabName_'..tab..'.x', getMidpointX('UITab_'..tab) - getProperty('UITabName_'..tab..'.width')/2)
		setProperty('UITabName_'..tab..'.y', getMidpointY('UITab_'..tab) - getProperty('UITabName_'..tab..'.height')/2)
		addLuaText('UITabName_'..tab)
		
		setProperty('UINames['..getProperty('UINames.length')..']', 'UITab_'..tab)
		setProperty('UINames['..getProperty('UINames.length')..']', 'UITabName_'..tab)
	end
	runHaxeCode("for (s in getVar('UINames')) game.getLuaObject(s).camera = getVar('camMenu');")

	if editor_started then return end
	runTimer('beginMusic', 0.2)
end

function openTab(tab, forceRefresh, creatingFirstAction)
	local recycleOptions
	currentDropdown = nil
	if curTab == tab and not forceRefresh then return end
	if (not forceRefresh) or (luaTextExists('Values_sys_NoStrumSelected_Text') or creatingFirstAction) then clearCurrentTab() else recycleOptions = true end
	for _, daTab in ipairs(UITabs) do setProperty('UITab_'..daTab..'.alpha', daTab == tab and 0.8 or 0.6) end
	if not editor_memory.editor_curAction then
    	if tab == 'Values' then editor_curAction = forceRefresh and (editor_curAction or 1) or 1 else editor_curAction = nil end
	end
	curTab = tab
	initTabOptions()
	if tabOptions[curTab] then 
		if recycleOptions then 
			--debugPrint('recycled')
			for k, option in pairs(tabOptions[curTab]) do
				-- Update the internal values before displaying them
				local optionType = stringTrim(option[2]:lower())
				if optionType == 'textbox' or optionType == 'dropdown' then
					tabSaves[curTab][k].value = option[7]
				end
				if optionType ~= 'dropdown' then if tabSaves[curTab][k] ~= nil and tabSaves[curTab][k].update ~= nil then tabSaves[curTab][k].update() end
				else setTextString(curTab..'_'..k..'_'..'SelectedText', tabSaves[curTab][k].value) end
			end
			return
		end

        if tab ~= 'Values' or tab == 'Values' and currentStrumEditing ~= nil then
            makeOptions()
        else
            local key = 'sys_NoStrumSelected'
            makeLuaText(curTab..'_'..key..'_Text', 'No strum is selected!\nClick a strum to begin editing', getProperty('UIBox.width'), getProperty('UIBox.x'))
			setTextSize(curTab..'_'..key..'_Text', 20)
			setProperty(curTab..'_'..key..'_Text.y', -40 + getProperty('UIBox.y') + getProperty('UIBox.height')/2)
			setTextFont(curTab..'_'..key..'_Text', editor_mainFont)
			setTextBorder(curTab..'_'..key..'_Text', 1, '000000', 'outline_fast')
			addLuaText(curTab..'_'..key..'_Text')
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_Text')
			if version > '0.7.3' then callMethod(curTab..'_'..key..'_Text'..'.set_camera', {instanceArg('camMenu')}) else runHaxeCode("game.getLuaObject('"..curTab..'_'..key..'_Text'.."').camera = getVar('camMenu');") end
        end
		if editor_minimized then for i = 0, getProperty('curOptions.length')-1 do setProperty(getProperty('curOptions['..i..']')..'.visible', false) end end
    end
end

function makeOptions() --Types: Info (String), Check (Bool), Button (Function), Textbox (String), Dropdown (String), Info (None), Clone (None, clickable)
	local uiX, uiY = getProperty('UIBox.x'), getProperty('UIBox.y')
	for key, option in pairs(tabOptions[curTab]) do
		if stringTrim(option[2]:lower()) == 'info' then
			updateOptionState(curTab..'_'..key..'_Text')
			
			makeLuaText(curTab..'_'..key..'_Text', option[1], screenWidth, uiX + option[3][1], uiY + option[3][2])
			setTextSize(curTab..'_'..key..'_Text', option[4] or 15)
			setTextFont(curTab..'_'..key..'_Text', editor_mainFont)
			setTextAlignment(curTab..'_'..key..'_Text', 'left')
			setTextBorder(curTab..'_'..key..'_Text', 1, '000000', 'outline_fast')
			addLuaText(curTab..'_'..key..'_Text')
			
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_Text')
			
		elseif stringTrim(option[2]:lower()) == 'check' then
			updateOptionState(curTab..'_'..key..'_CheckBox')
			if tabSaves[curTab][key].value == nil then tabSaves[curTab][key].value = option[7] end
			
			makeLuaText(curTab..'_'..key..'_DescText', option[1], screenWidth, uiX + option[3][1], uiY + option[3][2])
			setTextSize(curTab..'_'..key..'_DescText', option[4] or 15)
			setTextFont(curTab..'_'..key..'_DescText', editor_mainFont)
			setTextAlignment(curTab..'_'..key..'_DescText', 'left')
			setTextBorder(curTab..'_'..key..'_DescText', 1, '000000', 'outline_fast')
			addLuaText(curTab..'_'..key..'_DescText')
			
			makeAnimatedLuaSprite(curTab..'_'..key..'_CheckBox', 'checkboxanim', nil, uiY + option[3][2] - (option[6][2] or 0))
			setGraphicSize(curTab..'_'..key..'_CheckBox', 40, 40)
			addAnimationByPrefix(curTab..'_'..key..'_CheckBox', 'on', 'checkbox anim0009', 0)
			addAnimationByPrefix(curTab..'_'..key..'_CheckBox', 'off', 'checkbox0000', 0)
			addOffset(curTab..'_'..key..'_CheckBox', 'on', 47, 41.5)
			addOffset(curTab..'_'..key..'_CheckBox', 'off', 33, 33)
			playAnim(curTab..'_'..key..'_CheckBox', (tabSaves[curTab][key].value == true and 'on' or tabSaves[curTab][key].value == false and 'off'), true)
			addLuaSprite(curTab..'_'..key..'_CheckBox')
			
			if stringTrim(option[5]:lower()) == 'right' then setProperty(curTab..'_'..key..'_CheckBox'..'.x', getProperty(curTab..'_'..key..'_DescText'..'.x') + getProperty(curTab..'_'..key..'_DescText'..'.textField.textWidth') + (option[6][1] or 0))
			else setProperty(curTab..'_'..key..'_CheckBox'..'.x', getProperty(curTab..'_'..key..'_DescText'..'.x') - getProperty(curTab..'_'..key..'_CheckBox'..'.width') - (option[6][1] or 0)) end
	
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_DescText')
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_CheckBox')
			
		elseif stringTrim(option[2]:lower()) == 'button' then
			makeLuaSprite(curTab..'_'..key..'_Body', nil, uiX + option[3][1], uiY + option[3][2])
			makeGraphic(curTab..'_'..key..'_Body', 1, 1, 'FFFFFF')
			scaleObject(curTab..'_'..key..'_Body', option[3][3], option[3][4])
			setProperty(curTab..'_'..key..'_Body.color', getColorFromHex(option[4][1] or '000000'))
			
			makeLuaSprite(curTab..'_'..key..'_Outline', nil, getMidpointX(curTab..'_'..key..'_Body') - ((option[3][3] + option[4][4])/2), getMidpointY(curTab..'_'..key..'_Body') - ((option[3][4] + option[4][4])/2))
			makeGraphic(curTab..'_'..key..'_Outline', 1, 1, option[4][3] or 'FFFFFF')
			scaleObject(curTab..'_'..key..'_Outline', option[3][3] + option[4][4], option[3][4] + option[4][4])
			
			makeLuaText(curTab..'_'..key..'_Text', option[1], option[3][3])
			setTextSize(curTab..'_'..key..'_Text', option[5] or 15)
			setTextFont(curTab..'_'..key..'_Text', editor_mainFont)
			setTextBorder(curTab..'_'..key..'_Text', 1, '000000', 'outline_fast')
			setProperty(curTab..'_'..key..'_Text'..'.x', getMidpointX(curTab..'_'..key..'_Body') - getProperty(curTab..'_'..key..'_Text'..'.width')/2)
			setProperty(curTab..'_'..key..'_Text'..'.y', getMidpointY(curTab..'_'..key..'_Body') - getProperty(curTab..'_'..key..'_Text'..'.height')/2)

			--updateClipRect(curTab..'_'..key..'_Body', curTab..'_'..key..'_Outline') -- not really needed + wastes memory

			addLuaSprite(curTab..'_'..key..'_Outline')
			addLuaSprite(curTab..'_'..key..'_Body')
			addLuaText(curTab..'_'..key..'_Text')
			
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_Outline')
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_Body')
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_Text')
		
		elseif stringTrim(option[2]:lower()) == 'textbox' then
            local textTag = curTab..'_'..key..'_Textbox'
			updateOptionState(textTag, curTab ~= 'Values' and tabSaves[curTab][key].value or option[7] or '')

			makeLuaText(curTab..'_'..key..'_DescText', option[1], screenWidth, uiX + (option[4][1] or option[3][1]), uiY + (option[4][2] or option[3][2] - 30))
			setTextSize(curTab..'_'..key..'_DescText', option[5] or 15)
			setTextAlignment(curTab..'_'..key..'_DescText', 'left')
			setTextFont(curTab..'_'..key..'_DescText', editor_mainFont)
			setTextBorder(curTab..'_'..key..'_DescText', 0)
			addLuaText(curTab..'_'..key..'_DescText')

            if version > '0.7.3' then
                createInstance(textTag, 'backend.ui.PsychUIInputText', {uiX + option[3][1], uiY + option[3][2], option[3][3], tabSaves[curTab][key].value, option[5] or 15})
                setProperty(textTag..'.textObj.color', getColorFromHex('000000'))
                setTextFont(textTag..'.textObj', editor_mainFont)
                addInstance(textTag)
				runHaxeCode([[
					var text = game.getLuaObject("]]..textTag..[[");
					if (]]..tostring(option[6])..[[)
						text.filterMode = 2;
					else {
						if (getVar('editor_filenameFilter') == null) setVar('editor_filenameFilter', new EReg('([<>:"\\/\\\\|?*_])', "g"));
						text.customFilterPattern = getVar('editor_filenameFilter');
					}

					function i(o, n){
						getVar('editor_lua').call('updateOptionState', [']]..textTag..[[', n]);
					}
					text.onChange = i;
				]])
			else
				runHaxeCode([[
					var text = new FlxUIInputText(]]..(uiX + option[3][1])..[[, ]]..(uiY + option[3][2])..[[, ]]..option[3][3]..[[, ']]..tabSaves[curTab][key].value..[[');
					text.setFormat(Paths.font("]]..editor_mainFont..[["), ]]..(option[5] or 15)..[[, 0x0);
					game.add(text);
					setVar(']]..textTag..[[', text);
					if (]]..tostring(option[6])..[[)
						text.filterMode = 2;
					else {
						if (getVar('editor_filenameFilter') == null) setVar('editor_filenameFilter', new EReg('([<>:"\\/\\\\|?*_])', "g"));
						text.customFilterPattern = getVar('editor_filenameFilter');
					}

					text.focusGained = getVar('editor_focusCallbackGain');
					text.focusLost = getVar('editor_focusCallbackLost');

					function i(a, n){
						getVar('editor_lua').call('updateOptionState', [']]..textTag..[[', text.text]);
					}
					text.callback = i;
				]])
			end

			setProperty('curOptions['..getProperty('curOptions.length')..']', textTag)
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_DescText')
			
			tabSaves[curTab][key].update()
		elseif stringTrim(option[2]:lower()) == 'dropdown' then
			updateOptionState(curTab..'_'..key..'_SelectedText')
			if tabSaves[curTab][key].value == nil then tabSaves[curTab][key].value = (option[7] or '') end
			if tabSaves[curTab][key].extraData[1] == nil then tabSaves[curTab][key].extraData[1] = (option[6] or {''}) end
			
			makeLuaSprite(curTab..'_'..key..'_Body', nil, uiX + option[3][1], uiY + option[3][2])
			makeGraphic(curTab..'_'..key..'_Body', 1, 1, 'FFFFFF')
			scaleObject(curTab..'_'..key..'_Body', option[3][3], option[3][4])
			
			makeLuaSprite(curTab..'_'..key..'_BodyButton', nil, getProperty(curTab..'_'..key..'_Body'..'.x') + getProperty(curTab..'_'..key..'_Body'..'.width'), getProperty(curTab..'_'..key..'_Body'..'.y'))
			makeGraphic(curTab..'_'..key..'_BodyButton', 1, 1, 'FFFFFF')
			scaleObject(curTab..'_'..key..'_BodyButton', option[3][4], option [3][4])
			
			makeLuaText(curTab..'_'..key..'_DescText', option[1], screenWidth, uiX + option[4][1], uiY + option[4][2])
			setTextSize(curTab..'_'..key..'_DescText', option[4][3] or 15)
			setTextFont(curTab..'_'..key..'_DescText', editor_mainFont)
			setTextAlignment(curTab..'_'..key..'_DescText', 'left')
			setTextBorder(curTab..'_'..key..'_DescText', 1, '000000', 'outline_fast')
			
			makeLuaText(curTab..'_'..key..'_SelectedText', option[7] or '', screenWidth, getProperty(curTab..'_'..key..'_Body'..'.x'), getProperty(curTab..'_'..key..'_Body'..'.y'))
			setTextSize(curTab..'_'..key..'_SelectedText', option[5] or 15)
			setTextFont(curTab..'_'..key..'_SelectedText', editor_mainFont)
			setTextAlignment(curTab..'_'..key..'_SelectedText', 'left')
			setTextColor(curTab..'_'..key..'_SelectedText', '000000')
			setTextBorder(curTab..'_'..key..'_SelectedText', 0)
			
			addLuaSprite(curTab..'_'..key..'_Body')
			addLuaSprite(curTab..'_'..key..'_BodyButton')
			addLuaText(curTab..'_'..key..'_DescText')
			addLuaText(curTab..'_'..key..'_SelectedText')
			
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_Body')
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_BodyButton')
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_DescText')
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_SelectedText')
		elseif stringTrim(option[1]:lower()) == 'clone' then
			updateOptionState(curTab..'_'..key..'_Clone')
			runHaxeCode([[
				var spr = game.]]..option[2]..[[.clone();
				game.add(spr);
				spr.setPosition(]]..(uiX + option[3][1])..[[, ]]..(uiY + option[3][2])..[[);
				setVar(']]..curTab..[[_]]..key..[[_Clone', spr);
			]])
			scaleObject(curTab..'_'..key..'_Clone', option[4][1] or 1, option[4][2] or 1)
			
			if stringStartsWith(key, 'Dad') or stringStartsWith(key, 'BF') then
				local id = key:gsub('Dad', ''):gsub('BF', '')
				if not modchartData.objects['strumLineNotes.members['..id..']'] or modchartData.objects['strumLineNotes.members['..id..']'].numActions < 1 then
					option[6] = false
					updateColorOffsets(curTab..'_'..key..'_Clone', -100)
				else
					updateColorOffsets(curTab..'_'..key..'_Clone', tabSaves[curTab][key].extraData[1] and 100)
				end
			end
			if option[5] then playAnim(curTab..'_'..key..'_Clone', option[5], true) end
			setProperty('curOptions['..getProperty('curOptions.length')..']', curTab..'_'..key..'_Clone')
		end
	end
	if version > '0.7.3' then
		for i = 0, getProperty('curOptions.length')-1 do
			local o = getProperty('curOptions['..i..']')
			if o then callMethod(o..'.set_camera', {instanceArg('camMenu')}) end
		end
	else
		runHaxeCode('for (a in getVar("curOptions")) if (a != null) game.getLuaObject(a).camera = getVar("camMenu");')
	end
end

function initTabOptions()
	if currentStrumEditing ~= nil and curTab == 'Values' and modchartData['objects'][currentStrumEditing] ~= nil then
		if modchartData['objects'][currentStrumEditing]['actions'][editor_curAction] ~= nil then -- I dont know why but trying to combine this check with ^^ BREAKS IT???
			if not modchartData['objects'][currentStrumEditing].actions[editor_curAction] then modchartData['objects'][currentStrumEditing].actions[editor_curAction] = {} end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].x then modchartData.objects[currentStrumEditing].actions[editor_curAction].x = getProperty(currentStrumEditing..'.x') end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].y then modchartData.objects[currentStrumEditing].actions[editor_curAction].y = getProperty(currentStrumEditing..'.y') end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].alpha then modchartData.objects[currentStrumEditing].actions[editor_curAction].alpha = getProperty(currentStrumEditing..'.alpha') end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].angle then modchartData.objects[currentStrumEditing].actions[editor_curAction].angle = getProperty(currentStrumEditing..'.angle') end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].direction then modchartData.objects[currentStrumEditing].actions[editor_curAction].direction = getProperty(currentStrumEditing..'.direction') end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].duration then modchartData.objects[currentStrumEditing].actions[editor_curAction].duration = 0 end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].durationUnit then modchartData.objects[currentStrumEditing].actions[editor_curAction].durationUnit = 'seconds' end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].transition then modchartData.objects[currentStrumEditing].actions[editor_curAction].transition = 'sine' end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].type then modchartData.objects[currentStrumEditing].actions[editor_curAction].type = 'InOut' end
			if not modchartData.objects[currentStrumEditing].actions[editor_curAction].delay then modchartData.objects[currentStrumEditing].actions[editor_curAction].delay = 0 end
			setProperty(currentStrumEditing..'.x', modchartData['objects'][currentStrumEditing].actions[editor_curAction].x)
			setProperty(currentStrumEditing..'.y', modchartData['objects'][currentStrumEditing].actions[editor_curAction].y)
			setProperty(currentStrumEditing..'.alpha', modchartData['objects'][currentStrumEditing].actions[editor_curAction].alpha)
			setProperty(currentStrumEditing..'.angle', modchartData['objects'][currentStrumEditing].actions[editor_curAction].angle)
			setProperty(currentStrumEditing..'.direction', modchartData['objects'][currentStrumEditing].actions[editor_curAction].direction)
		end
	elseif currentStrumEditing ~= nil then
		resetStrumProperties(currentStrumEditing)
	end
	refreshTabOptions(curTab)
	for dir, _ in pairs(tabOptions) do
		if not tabSaves[dir] then tabSaves[dir] = {} end
	end
end

tabSaves = {
	['File'] = {
		['Name'] = {customUpdate = function(t,k) modchartData.name = tabSaves[t][k].value end},
		['Save'] = {customUpdate = function()
                        if checkFileExists('mods/savedModcharts/'..tabSaves['File']['Name'].value..'.lua', true) then
                            showWarning('There is already a file named\n$'..tabSaves['File']['Name'].value..'.lua'..'$\nDo you want to overwrite it?', {'nah', 'yea'}, exportModchart) 
                        else
                            exportModchart()
                        end
					end},
		['SaveData'] = {customUpdate = function()
                        if checkFileExists('mods/savedModcharts/'..tabSaves['File']['Name'].value..'_data.txt', true) then
                            showWarning('There is aleady a file named\n$'..tabSaves['File']['Name'].value..'_data.txt'..'$\nDo you want to overwrite it?', {'nah', 'yea'}, exportModchart, {true}) 
                        else
                            exportModchart(true)
                        end
					end},
		['Load'] = {customUpdate = function()
						local hasLua, hasData = checkFileExists('mods/savedModcharts/'..tabSaves['File']['Name'].value..'.lua', true), checkFileExists('mods/savedModcharts/'..tabSaves['File']['Name'].value..'_data.txt', true)
                        if hasLua or hasData then

                            showWarning('File found: $'..(hasLua and tabSaves['File']['Name'].value..'.lua' or tabSaves['File']['Name'].value..'_data.txt')..'$\nImporting a modchart will clear current progress.\nDo you wish to proceed?', {'no', 'yes'}, importModchart, {tabSaves['File']['Name'].value, hasLua}) 
                        else
							addTextToDebug('Load: No .lua or data .txt for '..tabSaves['File']['Name'].value..' was found in mods/savedModcharts/', 'FF0000')
                        end
					end},
		['Reset'] = {customUpdate = function()
						showWarning('This will delete all strum data in this modchart.\nDo you wish to proceed?', {'noo', 'ye'}, resetModchart)
					end},
		-- Mobile
		['SaveAndExit'] = {customUpdate = function()
						showWarning('Your modchart will be saved to $mods/savedModcharts/'..(tabSaves['File']['Name'].value or modchartData.name)..'$.\nSave and exit?', {'no', 'yes'}, exportModchart, {nil, function() editor_inputsLocked = true destroyUI(true) end})
					end},
		['Exit'] = {customUpdate = function()
						showWarning('Any unsaved progress will be lost.\nQuit to the menu?', {'no', 'yes'}, destroyUI, {true})
					end},
		['Test'] = {customUpdate = function() -- Just presses the keyboard key for you lmao
						runHaxeCode("FlxG.stage.dispatchEvent(new KeyboardEvent('keyDown', true, true, -1, 13));")
					end}
	},
	['Values'] = {
		['X'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].x = tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumX'..getStrumInfoFromID(currentStrumEditing)[2][2]] setProperty(currentStrumEditing..'.x', tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumX'..getStrumInfoFromID(currentStrumEditing)[2][2]]) end},
		['Y'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].y = tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumY'..getStrumInfoFromID(currentStrumEditing)[2][2]] setProperty(currentStrumEditing..'.y', tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumY'..getStrumInfoFromID(currentStrumEditing)[2][2]]) end},
		['Alpha'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].alpha = tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumAlpha'..getStrumInfoFromID(currentStrumEditing)[2][2]] setProperty(currentStrumEditing..'.alpha', tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumAlpha'..getStrumInfoFromID(currentStrumEditing)[2][2]]) end},
		['Angle'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].angle = tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumAngle'..getStrumInfoFromID(currentStrumEditing)[2][2]] setProperty(currentStrumEditing..'.angle', tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumAngle'..getStrumInfoFromID(currentStrumEditing)[2][2]]) end},
		['Direction'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].direction = tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumDirection'..getStrumInfoFromID(currentStrumEditing)[2][2]] setProperty(currentStrumEditing..'.direction', tonumber(tabSaves[t][k].value) or _G['default'..getStrumInfoFromID(currentStrumEditing)[2][1]..'StrumDirection'..getStrumInfoFromID(currentStrumEditing)[2][2]]) end},
		
		['Duration'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].duration = (tonumber(tabSaves[t][k].value) or -1) > 0 and tonumber(tabSaves[t][k].value) or 0 end},
		['Delay'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].delay = (tonumber(tabSaves[t][k].value) or -1) > 0 and tonumber(tabSaves[t][k].value) or 0 end},
		['DurationUnit'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].durationUnit = tostring(tabSaves[t][k].value) or 'seconds' end},
		['Transition'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].transition = tostring(tabSaves[t][k].value) or 'sine' end},
		['TransitionType'] = {customUpdate = function(t, k) modchartData.objects[currentStrumEditing].actions[editor_curAction].type = tostring(tabSaves[t][k].value) or 'InOut' end},
		
		['Deselect'] = {customUpdate = function(t) deselectCurrentStrum() openTab(t, true, true) end},
		['CustomCords'] = {customUpdate = function() if editor_trackingMouse then return end addTextToDebug('Mouse position: Click anywhere to confirm, Reclick button to cancel', 'FFFF00') editor_trackingMouse = true end},
		['ResetValues'] = {customUpdate = function(t) if not currentStrumEditing or editor_curAction < 1 then return end addTextToDebug('ResetValues: Strum values for this action have been reset', 'FFFF00') resetStrumProperties(currentStrumEditing, true) openTab(t, true) end},
        
		['NextAction'] = {customUpdate = function(t) if editor_curAction < 1 then return end editor_curAction = (editor_curAction +1 <= modchartData.objects[currentStrumEditing].numActions and editor_curAction+1 or 1) openTab(t, true) end},
        ['PrevAction'] = {customUpdate = function(t) if editor_curAction < 1 then return end editor_curAction = (editor_curAction -1 >= 1 and editor_curAction -1 or modchartData.objects[currentStrumEditing].numActions) openTab(t, true) end},
        ['CreateAction'] = {customUpdate = function(t) if not editor_curAction then return end local hi if not modchartData['objects'][currentStrumEditing] then hi = true modchartData['objects'][currentStrumEditing] = {actions = {}, numActions = 0} end modchartData.objects[currentStrumEditing].numActions = modchartData.objects[currentStrumEditing].numActions +1 table.insert(modchartData.objects[currentStrumEditing].actions, (hi and 1 or editor_curAction+1), {}) editor_curAction = (editor_curAction+1 <= modchartData.objects[currentStrumEditing].numActions and editor_curAction+1 or modchartData.objects[currentStrumEditing].numActions) openTab(t, true) end},
        ['CreateFirstAction'] = {customUpdate = function(t) if not editor_curAction then return end local hi if not modchartData['objects'][currentStrumEditing] then hi = true modchartData['objects'][currentStrumEditing] = {actions = {}, numActions = 0} end modchartData.objects[currentStrumEditing].numActions = modchartData.objects[currentStrumEditing].numActions +1 table.insert(modchartData.objects[currentStrumEditing].actions, (hi and 1 or editor_curAction+1), {}) editor_curAction = (editor_curAction+1 <= modchartData.objects[currentStrumEditing].numActions and editor_curAction+1 or modchartData.objects[currentStrumEditing].numActions) openTab(t, true, true) end},
		['DeleteAction'] = {customUpdate = function(t) if editor_curAction < 1 then return end local dontRecycle modchartData.objects[currentStrumEditing].numActions = modchartData.objects[currentStrumEditing].numActions -1 table.remove(modchartData.objects[currentStrumEditing].actions, editor_curAction) editor_curAction = (editor_curAction -1 >= 1 and editor_curAction -1 or 1) if modchartData['objects'][currentStrumEditing].numActions <= 0 then dontRecycle = true modchartData['objects'][currentStrumEditing] = nil end openTab(t, true, dontRecycle) end},
		['Presets'] = {customUpdate = function(t)
			debugPrint('hi')
		end},

		['Copy'] = {customUpdate = function()
			editor_copyingStrum, editor_trackingMouse = not editor_copyingStrum, not editor_copyingStrum
			if editor_copyingStrum then
				addTextToDebug('Copy: Click strum to be copied, Reclick button to cancel', 'FFFF00')
				for i = 0, 7 do
					local s = 'strumLineNotes.members['..i..']'
					if not modchartData.objects[s] and s ~= currentStrumEditing then updateColorOffsets(s, -100)
					elseif s ~= currentStrumEditing then updateColorOffsets(s, 0)
					else updateColorOffsets(s, -50) end
				end
			else
				for i = 0, 7 do updateColorOffsets('strumLineNotes.members['..i..']') end
				addTextToDebug('Copy: Cancelled', 'FFFF00')
			end
		end}
	},
	['Test'] = {
		['SelectAll'] = {customUpdate = function(t) for key, option in pairs(tabOptions[t]) do if stringTrim(option[1]:lower()) == 'clone' and option[6] then tabSaves[t][key].extraData[1] = true updateColorOffsets(t..'_'..key..'_Clone', 100) end end end},
		['DeselectAll'] = {customUpdate = function(t) for key, option in pairs(tabOptions[t]) do if stringTrim(option[1]:lower()) == 'clone' and option[6] then tabSaves[t][key].extraData[1] = false updateColorOffsets(t..'_'..key..'_Clone', 0) end end end},
		['Test'] = {customUpdate = function(t)
			if editor_testingModchart then return end
			deselectCurrentStrum()
			local strums = {}
			for key, option in pairs(tabOptions[t]) do if stringTrim(option[1]:lower()) == 'clone' and option[6] and tabSaves[t][key].extraData[1] then table.insert(strums, tonumber(key:sub(#key, #key))) end end
			if #strums <= 0 then addTextToDebug('Test: You must select a strum to test the modchart!', 'FF0000') return end 
			local code = generateModchart(strums, true)
			editor_testCount = (editor_testCount or 0)+1
				
			editor_testingModchart = true
			displayTestMarkers(strums)

			if version > '0.7.2' then
				if editor_debugMode then saveFile('mods/modchartEditor_test_temp.lua', code, true) end -- Preserve the tested code for viewing, deletes in onDestroy
				createInstance('editor_testModchart'..editor_testCount, 'psychlua.FunkinLua', {code})
				callMethod('luaArray.push', {instanceArg('editor_testModchart'..editor_testCount)})
			else
				saveFile('mods/modchartEditor_test_temp.lua', code, true)
				runHaxeCode([[
					setVar('editor_testModchart]]..editor_testCount..[[', new ]]..(version > '0.6.3' and 'psychlua.' or '')..[[FunkinLua('mods/modchartEditor_test_temp.lua'));
					var scriptT = getVar('editor_testModchart]]..editor_testCount..[[');
					if (]]..tostring(editor_debugMode)..[[) scriptT.set('luaDebugMode', true);
					game.luaArray.push(scriptT);
				]])
				if not editor_debugMode then deleteFile('modchartEditor_test_temp.lua', false, true) end
			end
			for i = 0, 3 do setProperty('strumLineNotes.members['..i..'].color', getIconColor('dad')) setProperty('strumLineNotes.members['..(i+4)..'].color', getIconColor('boyfriend')) end
			for i = 0, 7 do if not tableFind(strums, i) then noteTweenAlpha('editor_testHide'..i, i, 0.15, 0.4, 'cubeInOut') end end
			for _, v in ipairs({'Stop', 'Pause', 'Resume'}) do setTextColor('Test_'..v..'_Text', 'FFFF00') end
			for _, v in ipairs({'Test', 'SelectAll', 'DeselectAll'}) do setProperty('Test_'..v..'_Outline.color', getColorFromHex('4a4a4a')) end
		end},
		['Stop'] = {customUpdate = function()
						if not editor_testingModchart then return end 
						for _, v in ipairs({'Stop', 'Pause', 'Resume'}) do setTextColor('Test_'..v..'_Text', 'FFFFFF') end
						for _, v in ipairs({'Test', 'SelectAll', 'DeselectAll'}) do setProperty('Test_'..v..'_Outline.color', getColorFromHex(tabOptions['Test'][v][4][3] or 'FFFFFF')) end
						if version > '0.7.2' then
							--callMethod('editor_testModchart'..editor_testCount..'.stop', {''}) -- Crashes the game somehow
							callMethod('luaArray.remove', {instanceArg('editor_testModchart'..editor_testCount)})
							callMethod('variables.remove', {'editor_testModchart'..editor_testCount})
						else
							runHaxeCode([[
								//getVar('editor_testModchart]]..editor_testCount..[[').stop();
								game.luaArray.remove(getVar('editor_testModchart]]..editor_testCount..[['));
								game.variables.remove('editor_testModchart]]..editor_testCount..[[');
							]])
						end
						editor_testingModchart_paused = nil
						for i = 0, 7 do cancelTween('editor_testHide'..i) setProperty('strumLineNotes.members['..i..'].color', getColorFromHex('FFFFFF')) manageModchartTweens('strumLineNotes.members['..i..']', 'cancel') end
					end},
		['Pause'] = {customUpdate = function()
						if not editor_testingModchart or editor_testingModchart_paused then return end 
						editor_testingModchart_paused = true
						for i = 0, 7 do manageModchartTweens('strumLineNotes.members['..i..']', 'pause') end
					end},
		['Resume'] = {customUpdate = function()
						if not editor_testingModchart or not editor_testingModchart_paused then return end
						editor_testingModchart_paused = nil
						for i = 0, 7 do manageModchartTweens('strumLineNotes.members['..i..']', 'resume') end
					end}
	},
    ['Settings'] = {
    	['EditorZooms'] = {customUpdate = function(t,k) modchartData.settings.camZooming = tabSaves[t][k].value end},
    	['ScrollInvert'] = {customUpdate = function(t,k) modchartData.settings.scrollInvertY = tabSaves[t][k].value end},
		['SustainEnhancements'] = {customUpdate = function(t,k) modchartData.settings.sustainEnhancements = tabSaves[t][k].value end}
    }
}

function onTimerCompleted(t)
	if t == 'beginMusic' then
		runHaxeCode([[
			var editor_music:FlxSound = new FlxSound().loadEmbedded(FlxG.sound.music._sound);
			FlxG.sound.list.add(editor_music);
			editor_music.looped = true;
			editor_music.volume = 0.8;
			editor_music.play();
			setVar('editor_music', editor_music);

			var lua;
			for (script in game.luaArray) if (script.scriptName == "]]..scriptName..[["){
				lua = script;
				break;
			}
			setVar('editor_lua', lua);
			editor_music.onComplete = () -> {
				lua.set('curStep', 0);
			}
		]])
		editor_started = true
		evenFrame, mouseJustMoved = true, true
		curStep = 0 -- unfortunately cant be local since i need to set it within rhc
		if editor_onMobile then addHaxeLibrary('KeyboardEvent', 'openfl.events') end
		onUpdatePost(0) -- This is to stop the tab buttons from appearing as white before moving the mouse + start the music
	elseif t == 'editor_startWarning' then editor_inWarning = true
	elseif t == 'editor_testTweenDone' then hideTestMarkers() end
end

function onTweenCompleted(t, v)
	if stringStartsWith(t, 'editor_warningTweenClose_') then
		removeLuaSprite(v or t:gsub('editor_warningTweenClose_', ''), true)
		editor_inputsLocked, editor_inWarning, editor_warning_confirmFunc, editor_warning_confirmArgs = false, false
	elseif stringStartsWith(t, 'editor_testTweenDone_') then hideTestMarkers() end
end

function onDestroy()
	if not editor_started then return end
	destroyUI()
end

destroyUI = function(exit)
	editor_started = false
	currentDropdown = nil
	if editor_debugMode then deleteFile((version > '0.6.3' and 'mods/' or '')..'modchartEditor_test_temp.lua', false, true) end
	setPropertyFromClass('flixel.FlxG', 'mouse.visible', ogMouseVisibility)
	clearCurrentTab()
	runHaxeCode([[
		for (b in getVar("UINames")) game.getLuaObject(b).destroy(); 
		setVar("UINames", []);
		getVar('editor_music').stop();
	]])
	if exit then exitSong() end
end

function updateOptionState(obj, value)
	local objTab, objSaveTag, objComponent = unpack(stringSplit(obj, '_'))
	if not tabSaves[objTab][objSaveTag] then tabSaves[objTab][objSaveTag] = {} end
	-- value: self explanatory
	-- update: Function that handles base changes, based on option type
	-- customUpdate: Function for extra, option-specific changes. this is usually used for saving the value to the modchart
	if not tabSaves[objTab][objSaveTag].extraData then tabSaves[objTab][objSaveTag].extraData = {} end -- funny array for extra values
	
	if value ~= nil then tabSaves[objTab][objSaveTag].value = value end
	if objComponent == 'Textbox' and tabSaves[objTab][objSaveTag].customUpdate ~= nil then tabSaves[objTab][objSaveTag].customUpdate(objTab, objSaveTag) end

	if tabSaves[objTab][objSaveTag].update ~= nil then return end
	if stringTrim(tabOptions[objTab][objSaveTag][2]:lower()) == 'check' then tabSaves[objTab][objSaveTag].update = function() tabSaves[objTab][objSaveTag].value = not tabSaves[objTab][objSaveTag].value; playAnim(objTab..'_'..objSaveTag..'_CheckBox', (tabSaves[objTab][objSaveTag].value == true and 'on' or 'off'), true) end
	elseif stringTrim(tabOptions[objTab][objSaveTag][2]:lower()) == 'textbox' then tabSaves[objTab][objSaveTag].update = function()
		if version > '0.7.3' then setProperty(objTab..'_'..objSaveTag..'_'..'Textbox.textObj.text', tabSaves[objTab][objSaveTag].value)
		else setProperty(objTab..'_'..objSaveTag..'_'..'Textbox.text', tabSaves[objTab][objSaveTag].value) end
	end
	elseif stringTrim(tabOptions[objTab][objSaveTag][1]:lower()) == 'clone' and (stringStartsWith(objSaveTag, 'Dad') or stringStartsWith(objSaveTag, 'BF')) then tabSaves[objTab][objSaveTag].customUpdate = function() if not tabOptions[objTab][objSaveTag][6] then return end tabSaves[objTab][objSaveTag].extraData[1] = not tabSaves[objTab][objSaveTag].extraData[1] updateColorOffsets(objTab..'_'..objSaveTag..'_Clone', -100 * (tabSaves[objTab][objSaveTag].extraData[1] and -1 or 0)) end
	elseif stringTrim(tabOptions[objTab][objSaveTag][2]:lower()) == 'info' then tabSaves[objTab][objSaveTag].update = function() setTextString(objTab..'_'..objSaveTag..'_'..'Text', tabOptions[objTab][objSaveTag][1]) end
	elseif stringTrim(tabOptions[objTab][objSaveTag][2]:lower()) == 'dropdown' then tabSaves[objTab][objSaveTag].update = function() 
		if currentDropdown ~= nil then
			--if not luaSpriteExists(objTab..'_'..objSaveTag..'_'..'DSelectionBG_1') then
				for i, spr in ipairs(tabSaves[objTab][objSaveTag].extraData[1]) do		
					makeLuaSprite(objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..i)
					makeGraphic(objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..i, 1, 1, 'FFFFFF')
					scaleObject(objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..i, getProperty(objTab..'_'..objSaveTag..'_'..'Body.scale.x'), getProperty(objTab..'_'..objSaveTag..'_'..'Body.scale.y'))
					setProperty(objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..i..'.x', getProperty(objTab..'_'..objSaveTag..'_'..'Body.x'))
					setProperty(objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..i..'.y', getProperty(objTab..'_'..objSaveTag..'_'..'Body.y') + (getProperty(objTab..'_'..objSaveTag..'_'..'Body.scale.y') * i))
				
					makeLuaText(objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i, spr, getProperty(objTab..'_'..objSaveTag..'_'..'Body.scale.x'), getProperty(objTab..'_'..objSaveTag..'_'..'Body.x'), getProperty(objTab..'_'..objSaveTag..'_'..'Body.y') + (getProperty(objTab..'_'..objSaveTag..'_'..'Body.scale.y') * i))
					setTextSize(objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i, getProperty(currentDropdown..'.size'))
					setTextFont(objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i, editor_mainFont)
					setTextAlignment(objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i, 'left')
					setProperty(objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i..'.color', getProperty(currentDropdown..'.color'))
					setTextBorder(objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i, 0)
				
					addLuaSprite(objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..i, true)
					addLuaText(objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i)
				
					setProperty('curOptions['..getProperty('curOptions.length')..']', objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..i)
					setProperty('curOptions['..getProperty('curOptions.length')..']', objTab..'_'..objSaveTag..'_'..'DSelectionText_'..i)
					tabSaves[objTab][objSaveTag].extraData[2] = i
				end
				if version > '0.7.3' then
					for i = 0, getProperty('curOptions.length')-1 do
						local o = getProperty('curOptions['..i..']')
						if o then callMethod(o..'.set_camera', {instanceArg('camMenu')}) end
					end
				else
					runHaxeCode('for (a in getVar("curOptions")) if (a != null) game.getLuaObject(a).camera = getVar("camMenu");')
				end
			--end
		else
			runHaxeCode([[
				for (i in 1...]]..(tabSaves[objTab][objSaveTag].extraData[2] + 1)..[[){ // Gotta do this bullshit since looping thru curOptions normally would skip odd-numbered members somehow??
					var data:String = "]]..objTab..'_'..objSaveTag..'_'..'DSelectionBG_'..[[" + i;
					getVar('curOptions').remove(data, true);
					getVar('curOptions').remove(StringTools.replace(data, 'DSelectionBG_', 'DSelectionText_'), true);
					game.getLuaObject(data).destroy();
					game.getLuaObject(StringTools.replace(data, 'DSelectionBG_', 'DSelectionText_')).destroy();
				}
			]])
		end
		end
	end
end

function generateModchart(strumsToTest, testing)
    --local needsCancelTweens
    local originalMD = print_table(modchartData) -- Had to print the table early, storing the real table still somehow keeps the changes I make later
    local ogObjects = deepcopy(modchartData.objects) -- ^ fix to this issue but is apparently expensive
    local tweenActions, delayedActions = {}, {}

    -- Trim the modchart during generaton by removing redundant values
    for object, actionArray in pairs(modchartData.objects) do
        gen_lastX, gen_lastY, gen_lastAlpha, gen_lastAngle, gen_lastDirection = actionArray.actions[1].x, actionArray.actions[1].y, actionArray.actions[1].alpha, actionArray.actions[1].angle, actionArray.actions[1].direction
        for i, indivArr in ipairs(actionArray.actions) do
            if i > 1 then
                for _, prop in ipairs({'X', 'Y', 'Alpha', 'Angle', 'Direction'}) do
                    if _G['gen_last'..prop] == indivArr[prop:lower()] then _G['gen_delete'..prop] = true end
                end
                    gen_lastX, gen_lastY, gen_lastAlpha, gen_lastAngle, gen_lastDirection = actionArray.actions[i].x, actionArray.actions[i].y, actionArray.actions[i].alpha, actionArray.actions[i].angle, actionArray.actions[i].direction
                for _, prop in ipairs({'X', 'Y', 'Alpha', 'Angle', 'Direction'}) do
                    if _G['gen_delete'..prop] then 
                        actionArray.actions[i][prop:lower()] = nil
                        _G['gen_delete'..prop] = nil
                    end
                end
                if getTableLength(actionArray.actions[i]) <= 0 then table.remove(actionArray.actions, i) end
            end
            if indivArr.transition == 'linear' then actionArray.actions[i].type = '' end
        end
        gen_lastX, gen_lastY, gen_lastAlpha, gen_lastAngle, gen_lastDirection = nil
		if strumsToTest then
			if not tableFind(strumsToTest, tonumber(object:sub(#object-1, #object-1))) then modchartData.objects[object] = nil end
        end
    end
            
    local daCode = [[
function onCreate()
    ]]..(testing and '' or "if not startedCountdown and not waited then return runTimer(modchartData.name..'_beginWait', 0) end -- Stop the modchart from running before strums are created")..[[]]
	local indent = string.rep('    ', 1)
	if testing then daCode = daCode..'\n'..indent..'playbackRate = 1' end
    local objectArrayLength = getTableLength(modchartData.objects)
    for object, actionArray in pairs(modchartData.objects) do
        local id = object:sub(#object-1, #object-1)
        for _, prop in ipairs({'X', 'Y', 'Alpha', 'Angle', 'Direction'}) do
            if actionArray.actions[1]['delay'] > 0 then
                daCode = daCode..'\n'..indent.."runTimer(modchartData.name..".."'_"..object.."_Delay_1', "..actionArray.actions[1]['delay']..(actionArray.actions[1]['durationUnit'] == 'beats' and ' * crochet * 0.001' or actionArray.actions[1]['durationUnit'] == 'steps' and ' * stepCrochet * 0.001' or '').." / playbackRate)"
                if not actionArray.actions[1].addedToDelays then actionArray.actions[1].addedToDelays = true table.insert(delayedActions, {object, 1}) end
                --if not actionArray.actions[1].addedToTweens then actionArray.actions[1].addedToTweens = true table.insert(tweenActions, {object, 1}) end
                break
            elseif actionArray.actions[1]['duration'] > 0 then
                if not actionArray.actions[1].cancelTweens then 
                  actionArray.actions[1].cancelTweens = true needsCancelTweens = true
                  daCode = daCode..'\n'..indent.."cancelTweensOf('"..object.."')"
                end
                daCode = daCode..'\n'..indent..'noteTween'..prop.."(modchartData.name..".."'_"..object.."_"..prop.."_1', "..id..", "..(prop == 'Y' and modchartData.settings.scrollInvertY and ('downscroll == modchartData.downscroll and '..actionArray.actions[1]['y']..' or 620 - '..actionArray.actions[1]['y']) or actionArray.actions[1][prop:lower()])..", "..actionArray.actions[1]['duration']..(actionArray.actions[1]['durationUnit'] == 'beats' and ' * crochet * 0.001' or actionArray.actions[1]['durationUnit'] == 'steps' and ' * stepCrochet * 0.001' or '').." / playbackRate, ".."'"..actionArray.actions[1]['transition']..actionArray.actions[1]['type'].."')"
               -- if not actionArray.actions[1].addedToTweens then actionArray.actions[1].addedToTweens = true table.insert(tweenActions, {object, 1}) end
            else
                if not actionArray.actions[1].cancelTweens then
                  actionArray.actions[1].cancelTweens = true needsCancelTweens = true 
                  daCode = daCode..'\n'..indent.."cancelTweensOf('"..object.."')"
                end
                daCode = daCode..'\n'..indent.."setProperty('"..object.."."..(prop:lower()).."', "..(prop == 'Y' and modchartData.settings.scrollInvertY and ('downscroll == modchartData.downscroll and '..actionArray.actions[1]['y']..' or 620 - '..actionArray.actions[1]['y']) or actionArray.actions[1][prop:lower()])..")"
                if _ >= 5 and not actionArray.actions[1].endedEarly then modchartData.objects[object].actions[1].endedEarly = true daCode = daCode..'\n'..indent.."onTweenCompleted(modchartData.name..'_"..object.."_None_1', '"..object.."')" end
            end
                if actionArray.numActions > 1 and not actionArray.actions[1].addedToTweens then actionArray.actions[1].addedToTweens = true table.insert(tweenActions, {object, 1}) end
        end
        objectArrayLength = objectArrayLength-1
        if objectArrayLength > 0 then daCode = daCode..'\n' end
    end

    --if needsCancelTweens then
        daCode = [[
local function cancelTweensOf(obj)
    if version > '0.7.2' then
        callMethodFromClass('flixel.tweens.FlxTween', 'cancelTweensOf', {instanceArg(obj), {'x', 'y', 'alpha', 'angle', 'direction'}})
    else
        runHaxeCode("FlxTween.cancelTweensOf(game."..obj..", ['x', 'y', 'alpha', 'angle', 'direction']);")
    end
end

local function resetFinished(obj) for _, arr in ipairs(modchartData.objects[obj].actions) do arr.finished = false end end

]]..daCode
    --end
    
    daCode = daCode..[[

end

function onTweenCompleted(t)
    if not stringStartsWith(t, modchartData.name) then return end
    local modName, obj, prop, actionNum = unpack(stringSplit(t, '_'))
	actionNum = tonumber(actionNum) or 0]]..(testing and "\n    if not modchartData.objects[obj].actions[actionNum].finished then callOnLuas('editor_onActionFinished', {obj, actionNum}) end\n" or '\n')..[[
	if modchartData.objects[obj].actions[actionNum].finished then return end
]]
    local function getActionCode(object, aNum, indentLevel, finishedDelay, doneLoop, isDelay)
        if not modchartData.objects[object].actions[aNum] then return '' end
        local friend, inside_me
        local daCode = ''
        local indent = indentLevel > 0 and string.rep('    ', indentLevel) or ''
        local id = object:sub(#object-1, #object-1)
        for _, prop in ipairs({'X', 'Y', 'Alpha', 'Angle', 'Direction'}) do
            if modchartData.objects[object].actions[aNum]['delay'] > 0 and not finishedDelay then
                daCode = daCode..'\n'..indent.."runTimer(modName..'_'..obj..'_Delay_"..aNum.."', "..modchartData.objects[object].actions[aNum]['delay']..(modchartData.objects[object].actions[aNum]['durationUnit'] == 'beats' and ' * crochet * 0.001' or modchartData.objects[object].actions[aNum]['durationUnit'] == 'steps' and ' * stepCrochet * 0.001' or '').." / playbackRate)"
                inside_me = true
               -- if not modchartData.objects[object].actions[aNum].addedToDelays then modchartData.objects[object].actions[aNum].addedToDelays = true table.insert(delayedActions, {object, aNum}) end
                --if not modchartData.objects[object].actions[aNum].addedToTweens and modchartData.objects[object].actions[aNum]['duration'] > 0 then modchartData.objects[object].actions[aNum].addedToTweens = true table.insert(tweenActions, {object, aNum}) end
                break
            elseif modchartData.objects[object].actions[aNum]['duration'] > 0 and modchartData.objects[object].actions[aNum][prop:lower()] then 
                daCode = daCode..'\n'..indent..'noteTween'..prop.."(modName..'_'..obj..'_"..prop.."_"..aNum.."', "..id..", "..(prop == 'Y' and modchartData.settings.scrollInvertY and ('downscroll == modchartData.downscroll and '..modchartData.objects[object].actions[aNum]['y']..' or 620 - '..modchartData.objects[object].actions[aNum]['y']) or modchartData.objects[object].actions[aNum][prop:lower()])..", "..modchartData.objects[object].actions[aNum]['duration']..(modchartData.objects[object].actions[aNum]['durationUnit'] == 'beats' and ' * crochet * 0.001' or modchartData.objects[object].actions[aNum]['durationUnit'] == 'steps' and ' * stepCrochet * 0.001' or '').." / playbackRate, ".."'"..modchartData.objects[object].actions[aNum]['transition']..modchartData.objects[object].actions[aNum]['type'].."')"
                --if not modchartData.objects[object].actions[aNum].addedToTweens then modchartData.objects[object].actions[aNum].addedToTweens = true table.insert(tweenActions, {object, aNum}) end
            else
                if modchartData.objects[object].actions[aNum][prop:lower()] then daCode = daCode..'\n'..indent.."setProperty(obj..'."..(prop:lower()).."', "..(prop == 'Y' and modchartData.settings.scrollInvertY and ('downscroll == modchartData.downscroll and '..modchartData.objects[object].actions[aNum]['y']..' or 620 - '..modchartData.objects[object].actions[aNum]['y']) or modchartData.objects[object].actions[aNum][prop:lower()])..")" end
                modchartData.objects[object].actions[aNum].endedEarly = true
                friend = true
            end
        end
		if modchartData.objects[object].actions[aNum]['delay'] > 0 and not modchartData.objects[object].actions[aNum].addedToDelays then modchartData.objects[object].actions[aNum].addedToDelays = true table.insert(delayedActions, {object, aNum}) end
        if modchartData.objects[object].numActions > 1 and not modchartData.objects[object].actions[aNum].addedToTweens then modchartData.objects[object].actions[aNum].addedToTweens = true table.insert(tweenActions, {object, aNum}) end
        if not isDelay and not finishedDelay or not isDelay and not inside_me then daCode = daCode..'\n'..indent.."modchartData.objects[obj].actions[actionNum].finished = true" end
        if finishedDelay and doneLoop then daCode = daCode..'\n'..indent.."resetFinished(obj)" end
        if friend and (modchartData.objects[object].actions[aNum].delay <= 0 or finishedDelay) and modchartData.objects[object].actions[aNum].duration <= 0 then daCode = daCode..'\n'..indent.."onTweenCompleted(modName..'_'..obj..'_None_"..aNum.."', obj)" end
        return daCode
    end 
    
    for object, actionArray in pairs(modchartData.objects) do
		if actionArray.numActions > 1 then
			for actionNum, arr in ipairs(actionArray.actions) do
				if actionNum == actionArray.numActions then arr.addedToTweens = true table.insert(tweenActions, {object, actionNum, true}) end
				if arr.delay <= 0 and arr['duration'] > 0 then
					if not arr.addedToTweens then arr.addedToTweens = true table.insert(tweenActions, {object, actionNum}) end
				end
			end
		end
	end

    for _, arr in ipairs(tweenActions) do
        local object, actionNum, hi = unpack(arr)
        daCode = daCode..[[
    ]]..(_ > 1 and '\n'..indent..'elseif' or 'if')..[[ obj == ']]..object..[[' and actionNum == ]]..actionNum..[[ then]]..getActionCode(object, not hi and (modchartData.objects[object].actions[actionNum+1] and actionNum+1 or 1) or 1, 2, hi and true, hi and true)
    end

    daCode = daCode..[[

    ]]..(#tweenActions > 0 and 'end' or '')..[[ 
end

function onTimerCompleted(t)
    if not stringStartsWith(t, modchartData.name) then return end
    local modName, obj, prop, actionNum = unpack(stringSplit(t, '_'))
    actionNum = tonumber(actionNum) or 0
    ]]..(testing and '-- ' or '')..[[if actionNum > 0 and curStep <= 0 then cancelTweensOf(obj) end
    if stringEndsWith(t, 'beginWait') then
        waited = true onCreate()]]
        
    for _, arr in ipairs(delayedActions) do
        local object, actionNum = unpack(arr)
        daCode = daCode..[[

    elseif obj == ']]..object..[[' and actionNum == ]]..actionNum..[[ then]]..getActionCode(object, modchartData.objects[object].actions[actionNum] and actionNum or 1, 2, true, nil, true)
    end
    daCode = daCode..[[

    end
end
]]
    -- Add finishing touches
    daCode = [[
--[=[
                   .___     .__                   __   
  _____   ____   __| _/____ |  |__ _____ ________/  |_ 
 /     \ /  _ \ / __ |/ ___\|  |  \\__  \\_  __ \   __\
|  Y Y  (  <_> ) /_/ \  \___|   Y  \/ __ \|  | \/|  |  
|__|_|  /\____/\____ |\___  >___|  (____  /__|   |__|  
      \/            \/    \/     \/     \/             
                                      __               
  _____   ____   _____   ____   _____/  |_             
 /     \ /  _ \ /     \_/ __ \ /    \   __\            
|  Y Y  (  <_> )  Y Y  \  ___/|   |  \  |              
|__|_|  /\____/|__|_|  /\___  >___|  /__|              
      \/             \/     \/     \/       
//// Script generated using discord user .bakugo 's lua fnf modchart editor for fnf psych engine (for fnf)
]=]

modchartData = ]]..originalMD..[[

]]..daCode
	modchartData.objects = deepcopy(ogObjects) -- Revert the table to what the user gave
    return daCode
end