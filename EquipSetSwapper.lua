--[[
	Copyright © 2023, Tylas
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
_addon.version = '1.1.0'
_addon.commands = {'ess'}

require('tables')
require('logger')
local file = require('files')
local config = require('config')

local defaults = {}
defaults.current = ''
defaults.userId = ''

-- directory names
local dataDir = 'data\\'
local backupDir = 'backup\\'
local ffxiUserDir = 'FINAL FANTASY XI\\USER\\'

-- full directory paths
-- NOTE: "windower" functions require a full path, however the addon "files" library requires paths relative to the addon directory only
local userPath = windower.pol_path .. '\\..\\' .. ffxiUserDir
local dataPath = windower.addon_path .. dataDir

local isLoaded = false
local confirmFile = nil

windower.register_event('load', function()
	if windower.ffxi.get_info().logged_in then
		Settings = config.load(defaults)
		isLoaded = true

		if CheckUserId() then
			CheckCurrentSet()
		end
	end
end)

windower.register_event('login', function()
	if not isLoaded then
		Settings = config.load(defaults)
		isLoaded = true
		confirmFile = nil

		if CheckUserId() then
			CheckCurrentSet()
		end
	end
end)

windower.register_event('logout', function()
	Settings = nil
	isLoaded = false
	confirmFile = nil
end)

windower.register_event('addon command', function(...)
	local args = T{...}
	local command
	if args[1] then
		command = string.lower(args[1])
	end

	if command == 'setuserid' then
		if args[2] then
			SetUserId(args[2])
		else
			log('User ID missing.')
		end
		return
	end

	-- commands that require the user ID

	if not CheckUserId() then
		return
	end

	if command == 'list' then
		log('Listing equip set files:')
		local subDirs = windower.get_dir(dataPath .. Settings.userId)
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
			ShowHelp()
			return
		end

		if command == 'save' then
			if fileName == 'backup' then
				log('File name \'backup\' is reserved. Choose a different name.')
				return
			end

			if SetExists(fileName) and fileName ~= Settings.current and confirmFile ~= fileName then
				log('File \'' .. fileName .. '\' exists but is not the current file. Repeat command to confirm overwrite.')
				confirmFile = fileName
				return
			end

			CheckBackup()
			SaveSet(fileName)
			CheckCurrentSet();

			confirmFile = nil
		elseif command == 'load' then
			CheckBackup()
			LoadSet(fileName)
			CheckCurrentSet();
		elseif command == 'swap' then
			CheckBackup()
			if Settings.current == fileName then
				log('File \'' .. fileName .. '\' is already active.')
			elseif Settings.current ~= '' then
				SaveSet(Settings.current)
				LoadSet(fileName)
				CheckCurrentSet();
			else
				log('No current file found. Save a new file before trying to swap.')
			end
		end
	else
		ShowHelp()
	end
end)

function ShowHelp()
	log('Commands: //ess')
	log('save <name> - Saves your current equip sets')
	log('load <name> - Loads an existing file, replacing all current equip sets')
	log('swap <name> - Swaps to a different file by first saving the current, then loading the other')
	log('list - Lists all existing equip set files')
	log('setUserId <ID> - Selects the character on which the above commands are performed')
end

function CheckCurrentSet()
	if Settings.current ~= '' then
		log('Current = ' .. Settings.current)
	else
		log('Save to a new file before starting to edit your equip sets.')
		log('Type \'//ess help\' to see all available commands.')
	end
end

function CheckUserId()
	if Settings.userId == '' then
		local subDirs = windower.get_dir(userPath)
		local autoSelect = false

		if (table.length(subDirs) == 2) then
			autoSelect = true
		else
			log('The user ID must be set before using this addon.')
			log('Each of your characters has its own ID that corresponds to the directory names found in ' .. ffxiUserDir)
			log('Select one of the following IDs using the command \'//ess setUserId <id>\'.')
		end

		for k,v in pairs(subDirs) do
			if v ~= 'tig.dat' then
				if autoSelect then
					SetUserId(v)
				else
					log(v)
				end
			end
		end

		return false
	end

	return true
end

function SetUserId(id)
	if not windower.dir_exists(userPath .. id) then
		log('The directory ' .. ffxiUserDir .. id .. ' does not exist.')
	else
		Settings.userId = string.lower(id)
		Settings:save()
		log('User ID set to \'' .. Settings.userId .. '\'.')
		CheckBackup()
		CheckCurrentSet()
	end
end

-- save / load logic

function SetExists(fileName)
	return windower.dir_exists(dataPath .. Settings.userId .. '\\' .. fileName)
end

function SaveSet(fileName)
	local srcDir = userPath .. Settings.userId .. '\\'
	local dstDir = file.create_path(dataDir .. Settings.userId .. '\\' .. fileName)

	log('Saving file \'' .. fileName .. '\'...')
	CopyEquipSets(srcDir, dstDir)

	Settings.current = fileName
	Settings:save()
end

function LoadSet(fileName)
	local srcDir = dataPath .. Settings.userId .. '\\' .. fileName .. '\\'
	local dstDir = userPath .. Settings.userId .. '\\'

	if windower.dir_exists(srcDir) then
		log('Loading file \'' .. fileName .. '\'...')
		CopyEquipSets(srcDir, dstDir)

		Settings.current = fileName
		Settings:save()
	else
		log('File \'' .. fileName .. '\' does not exist.')
	end
end

function CheckBackup()
	local addonBackupPath = dataDir .. Settings.userId .. '\\' .. backupDir

	if not windower.dir_exists(windower.addon_path .. addonBackupPath) then
		local srcDir = userPath .. Settings.userId .. '\\'
		local dstDir = file.create_path(addonBackupPath)

		log('Backing up current equip sets to ' .. dstDir)
		log('You can restore them using //ess load backup')
		CopyEquipSets(srcDir, dstDir)
	end
end

-- both dir parameters must be full paths of directories that already exist
-- NOTE: the game will always re-create missing equipset files once you access the respective page in the menu
function CopyEquipSets(srcDir, dstDir)
	for i = 0, 9 do
		local esFile = 'es' .. tostring(i) .. '.dat'
		local srcFile = srcDir .. esFile
		local dstFile = dstDir .. esFile
		if windower.file_exists(srcFile) then
			CopyFile(srcFile, dstFile)
		end
	end

	log('Done.')
end

-- overwrites dst if it already exists
function CopyFile(src, dst)
	local fh, err = io.open(src, 'rb')
	if not fh then error(err) return end

	local content = fh:read('*all')
	fh:close()

	fh, err = io.open(dst, 'wb')
	if not fh then error(err) return end

	fh:write(content)
	fh:close()
end