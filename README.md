# EquipSetSwapper
An equip set slot extender addon for Windower 4.

This addon allows you to save your equip sets to files and load them again via in-game commands. You can create multiple files, for example one for each job, and swap them around to use more than the 200 slots the game normally has.

# Setup
- If you have more than one character, you will first need to set the user ID of your currently logged in character using the 'setUserId' command. Each of your characters has its own ID that corresponds to the directory names found in the PlayOnline/SquareEnix/Final Fantasy XI/USER directory. If you only have one character, this step can be skipped.
- The addon will automatically create a backup of your current sets, just in case you want to restore them later using '//ess load backup'.
- Save your sets into a new file using '//ess save [name]'.
- (Optional) To test if you selected the correct user ID, rename one of your sets and reload the file you just saved using '//ess load [name]'. If the renamed set name is not reverted, you picked the wrong user ID and have to choose a different one.

# Usage
You must close all in-game menus before saving or loading equip set files.
After loading a file, the game will not see the changed equip sets (macros will still point to your previous sets) until you **zone** or **open the in-game equip sets menu**!

When you save a file, all 200 equip set slots will be stored at the same time. Any edits you make in-game will not affect these stored files until you save them again. It is recommended to switch to other files using the 'swap' command, as it will first save any changes you might have made to your current file, before loading the other one.

The addon's data directory contains all equip set files including your backup, do not delete it!

## Commands

| Command                 | Action                                                                                         |
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| //ess save [name]       | Saves your current equip sets as a new file or overwrites an existing one.                     |
| //ess load [name]       | Loads an existing file, replacing all current equip sets.                                      |
| //ess swap [name]       | Swaps to a different file, by first saving the current and then loading the other.             |
| //ess list              | Lists all existing equip set files.                                                            |
| //ess setUserId [ID]    | Selects the character directory on which the above commands are performed.                     |
