-- MIT License

-- Copyright (c) 2021 David Fletcher

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

function init(plugin)
    print("Aseprite is initializing Gif Sequencing")

    -----------------------------------
    -- PLUGIN COMMANDS
    -----------------------------------
    -- A plugin command is simply a menu element that, when clicked, runs the function passed to onclick.
    -- In this file, we specify menu element definitions, but abstract away their implementations to different Lua scripts.
    -- This is done for organizational purposes, and to ease the iterative development of scripts. With this structure,
    -- we can develop the script file independently of the plugin definition, using Aseprite's scripting engine
    -- to run scripts as we build out our functionality, then wrap the finalized scripts in a plugin.
    -----------------------------------
    -- We use the parameter to init, plugin, to access the preferences table. This table will be saved on exit and restored
    -- upon re-entry, so that you can easily save any user-defined preferences you need to. You will notice that we use
    -- loadfile() to create a Lua chunk based on our script, and then pass the preferences table to the script as an argument.
    -- The script can modify that table, which will then be saved automagically by Aseprite's API.
    -----------------------------------
    plugin:newCommand {
        id="gif-sequencing",
        title="Export Gif Sequence",
        group="file_export",
        onclick=function()
            local executable = app.fs.joinPath(app.fs.userConfigPath, "extensions", "gif-sequencing", "gif-sequencing.lua")
            -- load the lua script into a Lua chunk, then execute it with the parameter plugin.preferences
            loadfile(executable)(plugin.preferences)
        end
    }
end
  
function exit(plugin)
    print("Aseprite is closing Gif Sequencing")
end