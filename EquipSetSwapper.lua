--[[
	Copyright © 2021, Tylas
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

		* Redistributions of source code must retain the above copyright
		  notice, this list of conditions and the following disclaimer.
		* Redistributions in binary form must reproduce the above copyright
		  notice, this list of conditions and the following disclaimer in the
		  documentation and/or other materials provided with the distribution.
		* Neither the name of EquipSetSwapper nor the
		  names of its contributors may be used to endorse or promote products
		  derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'EquipSetSwapper'
_addon.author = 'Tylas'
_addon.version = '1.0.0'
_addon.commands = {'ess'}

require('tables')
require('logger')
file = require('files')
config = require('config')

local defaults = {}
defaults.current = ''
defaults.userId = ''

local dataDir = 'data\\'
local backupDir = 'backup\\'
local ffxiUserDir = 'FINAL FANTASY XI\\USER\\'
local userDir = windower.pol_path .. '\\..\\' .. ffxiUserDir

local isLoaded = false

windower.register_event('load', function()
	if windower.ffxi.get_info().logged_in then
		settings = config.load(defaults)
		isLoaded = true
		
		if checkUserId() then
			checkCurrentSet()
		end
	end
end)

windower.register_event('login', function()
	if not isLoaded then
		settings = config.load(defaults)
		isLoaded = true
		
		if checkUserId() then
			checkCurrentSet()
		end
	end
end)

windower.register_event('logout', function()
	settings = nil
	isLoaded = false
end)

windower.register_event('addon command', function(...)
	local args = T{...}
	local command
	if args[1] then
		command = string.lower(args[1])
	end
	
	if command == 'setuserid' then
		if args[2] then
			setUserId(args[2])
		else
			log('User ID missing.')
		end
		return
	end

	-- commands that require the user ID
	
	if not checkUserId() then
		return
	end
	
	if command == 'list' then
		log('Listing equip set files:')
		local subDirs = windower.get_dir(windower.addon_path .. dataDir .. settings.userId)
		if subDirs then
			for k,v in pairs(subDirs) do	
				if v ~= 'backup' then
					log(v)
				end
			end
		else
			log('No files found.')
		end
	elseif command == 'save' or command == 'load' or command == 'swap' then -- file commands
		coroutine.sleep(0.5) -- short delay, otherwise menu_open might report a wrong value
		
		-- check reason: the equipset are loaded by the game when the menu is open, saved when it is closed.
		-- any change to the sets while they are open would be lost upon closing the menu
		if windower.ffxi.get_info().menu_open then
			log('Close all menus before using this command.')
			return
		end
		
		local fileName
		if args[2] then
			fileName = string.lower(args[2])
		else
			showHelp()
			return
		end
		
		if command == 'save' then
			if fileName == 'backup' then
				log('File name \'backup\' is reserved. Choose a different name.')
				return
			end
		
			checkBackup()
			saveSet(fileName)
			checkCurrentSet();
		elseif command == 'load' then
			checkBackup()
			loadSet(fileName)
			checkCurrentSet();
		elseif command == 'swap' then
			checkBackup()
			if settings.current == fileName then
				log('File \'' .. fileName .. '\' is already active.')
			elseif settings.current ~= '' then	
				saveSet(settings.current)
				loadSet(fileName)
				checkCurrentSet();
			else
				log('No current file found. Save a new file before trying to swap.')
			end
		end
	else
		showHelp()
	end
end)

function showHelp()
	log('Commands: //ess')
	log('save <file> - Saves your current equip sets')
	log('load <file> - Loads an existing file, replacing all current equip sets')
	log('swap <file> - Swaps to a different file, by first saving the current, then loading the other')
	log('list - Lists all existing equip set files')
	log('setUserId <ID> - Selects the character directory on which the above commands are performed')
end

function checkCurrentSet()
	if settings.current ~= '' then
		log('Current = ' .. settings.current)
	else
		log('Save to a new file before starting to edit your equip sets.')
		log('Type \'//ess help\' to see all available commands.')
	end
end

function checkUserId()
	if settings.userId == '' then
		local subDirs = windower.get_dir(userDir)
		local autoSelect = false
		
		if (table.length(subDirs) == 2) then
			autoSelect = true
		else
			log('The user ID must be set before using this addon.')
			log('Each of your characters has its own ID that corresponds to the directory names found in ' .. ffxiUserDir)
			log('Select one of the following IDs using the command //ess setUserId <id>')
		end
		
		for k,v in pairs(subDirs) do
			if v ~= 'tig.dat' then
				if autoSelect then
					setUserId(v)
				else
					log(v)
				end
			end
		end
		
		return false
	end
	
	return true
end

function setUserId(id)
	if not windower.dir_exists(userDir .. id) then
		log('The directory ' .. ffxiUserDir .. id .. ' does not exist.')
	else
		settings.userId = string.lower(id)
		settings:save()
		log('User ID set to \'' .. settings.userId .. '\'.')
		checkBackup()
		checkCurrentSet()
	end
end

-- save / load logic

function saveSet(fileName)
	local srcDir = userDir .. settings.userId .. '\\'
	local dstDir = file.create_path(dataDir .. settings.userId .. '\\' .. fileName)
	
	log('Saving file \'' .. fileName .. '\'...')
	copyEquipSets(srcDir, dstDir)
	
	settings.current = fileName
	settings:save()
end

function loadSet(fileName)
	local srcDir = windower.addon_path .. dataDir .. settings.userId .. '\\' .. fileName .. '\\'
	local dstDir = userDir .. settings.userId .. '\\'
	
	if windower.dir_exists(srcDir) then
		log('Loading file \'' .. fileName .. '\'...')
		copyEquipSets(srcDir, dstDir)
		
		settings.current = fileName
		settings:save()
	else
		log('File \'' .. fileName .. '\' does not exist.')
	end
end

function checkBackup()
	local addonBackupPath = dataDir .. settings.userId .. '\\' .. backupDir

	if not windower.dir_exists(windower.addon_path .. addonBackupPath) then
		local srcDir = userDir .. settings.userId .. '\\'
		local dstDir = file.create_path(addonBackupPath)
		
		log('Backing up current equip sets to ' .. dstDir)
		log('You can restore them using //ess load backup')
		copyEquipSets(srcDir, dstDir)
	end
end

-- dirs must be full paths and already exist
-- NOTE: the game will always re-create missing equipset files once you access the respective page in the menu
function copyEquipSets(srcDir, dstDir)
	for i = 0, 4 do
		local esFile = 'es' .. tostring(i) .. '.dat'
		local srcFile = srcDir .. esFile
		local dstFile = dstDir .. esFile
		if windower.file_exists(srcFile) then
			copyFile(srcFile, dstFile)
		end
	end
	
	log('Done.')
end

-- overwrites dst if it already exists
function copyFile(src, dst)
	local fh = io.open(src, 'rb')
	local content = fh:read('*all')
	fh:close()

	fh = io.open(dst, 'wb')
	fh:write(content)
	fh:close()
end