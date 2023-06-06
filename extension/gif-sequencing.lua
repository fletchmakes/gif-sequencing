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

-----------------------------------
-- USER DEFINED PREFERENCES
-----------------------------------
-- In this file, we receive a reference to the table plugin.preferences (from ./plugin.lua).
-- In Lua, when a parameter is a table, it is passed by reference.
-- This allows us to mutate the parameter, and the original object will be mutated as well;
-- Thus, we do not need to have a "return value" from this script
-----------------------------------
-- If you need to stage edits to the preferences table, but don't want them saved in certain situations,
-- consider creating a deep copy of the preferences table at the start of your script,
-- editing the copy, and if you'd like to save your changes, deep copy the edited copy you made, and
-- save it back to the original preferences table; an implementation of a deep copy function
-- can be found in ./helpers.lua
-----------------------------------
local prefs = ...
if (prefs == nil) then
    prefs = {
        presets = {}
    }
end

-----------------------------------
-- CREATE CONFIRM DIALOG
-----------------------------------
-- param: str - a string value that will be displayed to the user (usually a question if they'd like to confirm an action)
-- returns: true, if the user clicked "Confirm"; nil, if the user clicked "Cancel" or closed the dialog
-----------------------------------
-- This function creates a simple dialog window that will display a message, along with two buttons: "Cancel" and "Confirm".
-- You can observe whether or not the user closed the dialog in this way:
-- local confirmed = create_confirm("Would you like to continue?")
-- if (not confirmed) then
-- end
-----------------------------------
local function create_confirm(str)
    local confirm = Dialog("Confirm?")

    confirm:label {
        id="text",
        text=str
    }

    confirm:button {
        id="cancel",
        text="Cancel",
        onclick=function()
            confirm:close()
        end
    }

    confirm:button {
        id="confirm",
        text="Confirm",
        onclick=function()
            confirm:close()
        end
    }

    -- show to grab centered coordinates
    confirm:show{ wait=true }

    return confirm.data.confirm
end

-----------------------------------
-- CREATE ERROR DIALOG
-----------------------------------
-- param: table - a table of string values that will be displayed to the user (usually an error message)
-- param: dialog - the Dialog object (if any) that spawned this error message
-- param: exit - a boolean value; 0 to keep dialog open, and 1 to close dialog
-----------------------------------
-- This function creates a simple dialog window that will alert the user of an error that occured.
-- If you call this from a Dialog function, you can optionally close the dialog to end user interaction
-- and prevent further errors (making the user try again).
-----------------------------------
local function create_error(table, dialog, exit)
    app.alert{title="There was an error.", text=table}
    if (exit == 1) then dialog:close() end
end

-----------------------------------
-- DEEPCOPY FUNCTION (from http://lua-users.org/wiki/CopyTable)
-----------------------------------
-- param: orig - any Lua value (table or otherwise) that should be copied and returned
-- returns: an exact copy of the original value
-----------------------------------
-- This function is extremely useful if you need to stage edits to a table, but
-- roll them back if there was an error or if the user cancelled the action.
-- Create a copy of the table you want to edit, edit the copy, and then do nothing
-- if the changes should be ignored; but if the changes should be saved, deep copy the
-- edited copy again, and set that equal to the original value you were trying to edit.
-----------------------------------
local function deepcopy(orig)
    -- http://lua-users.org/wiki/CopyTable
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end

        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end

    return copy
end

-----------------------------------
-- HELPER FUNCTIONS
-----------------------------------
local function getListOfTags()
    local result = {}

    local sprite = app.activeSprite
    for _,t in ipairs(sprite.tags) do
        table.insert(result, t.name)
    end

    return result
end

local function getNumberList(max)
    local result = {}

    for i=1,max do
        table.insert(result, tostring(i))
    end

    return result
end

local function getPresetNameList(presets)
    local pNames = {
        "None"
    }

    local map = {}

    for i,p in pairs(presets) do
        table.insert(pNames, p.preset)
        map[p.preset] = i
    end

    return pNames, map
end

local function validatePresetHasNecessaryTags(sequence)
    -- if the sequence is nil, just pass back true (probably a "None" preset)
    if (sequence == nil) then return true end

    local tagNamesMissing = {}

    local foundAll = true
    local foundOne = false
    for _,seq_t in pairs(sequence.tags) do
        foundOne = false
        for _,spr_t in ipairs(app.activeSprite.tags) do
            if (seq_t.name == spr_t.name) then
                foundOne = true
                break
            end
        end

        if (not foundOne) then
            table.insert(tagNamesMissing, seq_t.name)
            foundAll = false
        end
    end

    return foundAll, tagNamesMissing
end

-----------------------------------
-- WINDOW FACTORIES
-----------------------------------
local function reorderTagsWindow(sequence, exit)
    local dialog = Dialog("Reorder Tags")

    local function refresh(dlg)
        dlg:close()
        reorderTagsWindow(sequence, exit):show{ wait=true }
    end

    -- build the list of tags that can be re-ordered
    local numberList = getNumberList(#sequence)

    for idx,tag in ipairs(sequence) do
        dialog:combobox {
            id="tag"..idx,
            label=idx..": "..tag.name.." x"..tag.repetitions,
            option=tostring(idx),
            options=numberList,
            onchange=function()
                table.remove(sequence, idx)
                table.insert(sequence, tonumber(dialog.data["tag"..idx]), tag)
                refresh(dialog)
            end
        }
    end

    dialog:separator {
        id="actions",
        text="Actions"
    }

    dialog:button {
        id="cancel",
        text="Cancel",
        onclick=function()
            dialog:close()
        end
    }

    dialog:button {
        id="save",
        text="Save",
        onclick=function()
            exit.action = "save"
            dialog:close()
        end
    }

    return dialog
end

local function editTagWindow(tag)
    local dialog = Dialog("Edit Tag")

    dialog:separator {
        id="details",
        text="Tag Details"
    }

    dialog:combobox {
        id="tag",
        label="Tag",
        option="",
        options=getListOfTags()
    }

    dialog:number {
        id="repetitions",
        label="Repetitions",
        number=0,
        decimals=0
    }

    dialog:separator {
        id="actions",
        text="Actions"
    }

    dialog:button {
        id="cancel",
        text="Cancel",
        onclick=function()
            dialog:close()
        end
    }

    dialog:button {
        id="save",
        text="Save",
        onclick=function()
            dialog:close()
        end
    }

    -- force the dialog to render the incoming data
    dialog:modify {
        id="tag",
        option=tag.name
    }

    dialog:modify {
        id="repetitions",
        text=tag.repetitions
    }

    return dialog
end

local function mainWindow(sequence, presets, exit)
    local dialog = Dialog("Export Gif Sequence")

    local function refresh(dlg)
        dlg:close()
        mainWindow(sequence, presets, exit):show{ wait=true }
    end

    local presetNames, presetMap = getPresetNameList(presets)

    dialog:separator {
        id="preset_sep",
        text="Presets"
    }

    dialog:combobox {
        id="presets",
        options=presetNames,
        option=sequence.preset,
        onchange=function()
            local isValid, tagNamesMissing = validatePresetHasNecessaryTags(presets[presetMap[dialog.data.presets]])

            if (not isValid) then
                local message = {"You cannot use this preset since the current document does not have all of the tags needed for this preset.", "Missing tags:"}
                for _,name in ipairs(tagNamesMissing) do
                    table.insert(message, name)
                end
                create_error(message, nil, 0)
                refresh(dialog)
                return
            end

            if (dialog.data.presets == "None") then
                sequence = {
                    preset="None",
                    tags={}
                }
            else
                sequence = deepcopy(presets[presetMap[dialog.data.presets]])
            end
            refresh(dialog)
        end
    }

    dialog:button {
        id="delete_preset",
        text="Delete Selected Preset",
        enabled=(sequence.preset ~= "None"),
        onclick=function()
            table.remove(presets, presetMap[dialog.data.presets])
            sequence = {
                preset="None",
                tags={}
            }
            refresh(dialog)
        end
    }

    dialog:separator {
        id="sequence",
        text="Sequence"
    }

    if (#sequence.tags == 0) then
        dialog:label {
            id="noitems",
            text="There are currently no tags in the sequence."
        }
    else
        for idx,tag in pairs(sequence.tags) do
            dialog:button {
                id="tag_"..idx,
                text=tag.name.." x"..tag.repetitions,
                onclick=function()
                    local original = tag
                    local edit = editTagWindow({ name=original.name, repetitions=original.repetitions }):show{ wait=true }

                    if (edit.data.save) then
                        local edited_tag = { name=edit.data.tag, repetitions=edit.data.repetitions }
                        table.remove(sequence.tags, idx)
                        table.insert(sequence.tags, idx, edited_tag)

                        refresh(dialog)
                    end
                end
            }

            dialog:button {
                id="tag_delete_"..idx,
                text="Remove Tag",
                onclick=function()
                    local confirm = create_confirm("Are you sure you'd like to delete this tag?")
                    if (confirm) then
                        table.remove(sequence.tags, idx)
                        refresh(dialog)
                    end
                end
            }

            dialog:newrow()
        end
    end

    dialog:separator {
        id="actions",
        text="Actions"
    }

    dialog:button {
        id="add_tag",
        text="Add Another Tag",
        onclick=function()
            local tag_list = getListOfTags()
            local edit = editTagWindow({ name=tag_list[1], repetitions=1 })
            edit:show{ wait=true }

            if (edit.data.save) then
                local new_tag = { name=edit.data.tag, repetitions=edit.data.repetitions }
                table.insert(sequence.tags, new_tag)

                refresh(dialog)
            end
        end
    }

    dialog:button {
        id="reorder_tags",
        text="Reorder Tags",
        onclick=function()
            local copy = deepcopy(sequence.tags)
            local exit_reorder = { action=nil }

            reorderTagsWindow(copy, exit_reorder):show{ wait=true }
            if (exit_reorder.action == "save") then
                sequence.tags = deepcopy(copy)
                refresh(dialog)
            end
        end
    }

    dialog:button {
        id="clear_all",
        text="Clear All Tags",
        onclick=function()
            sequence.tags = {}
            refresh(dialog)
        end
    }

    dialog:check {
        id="save_as",
        selected=false,
        text="Save Sequence As Preset",
        onclick=function()
            if (dialog.data.save_as) then
                exit.preset = true
                dialog:modify {
                    id="preset_name",
                    visible=true,
                    focus=true
                }
                dialog:modify {
                    id="save_preset",
                    visible=true
                }
            else
                exit.preset = nil
                dialog:modify {
                    id="preset_name",
                    visible=false
                }
                dialog:modify {
                    id="save_preset",
                    visible=false
                }
            end
        end
    }

    dialog:entry {
        id="preset_name",
        text="New Preset",
        visible=false
    }

    dialog:button {
        id="save_preset",
        text="Save Preset",
        visible=false,
        onclick=function()
            local copy = deepcopy(sequence)
            copy.preset = dialog.data.preset_name

            if (presetMap[copy.preset] ~= nil) then
                -- just overwrite the changes, don't create a new entry
                presets[presetMap[copy.preset]] = copy
            else
                -- save a new entry
                table.insert(presets, copy)
            end

            sequence = deepcopy(copy)
            refresh(dialog)
        end
    }

    dialog:button {
        id="export",
        text="Export Sequence",
        onclick=function()
            exit.action = "export"
            exit.sequence = deepcopy(sequence)
            dialog:close()
        end
    }

    return dialog
end

-----------------------------------
-- EXECUTE MAIN LOGIC
-----------------------------------

-- first check to see if any tags exist in the sprite
local numTags = #getListOfTags()
if (numTags == 0) then
    create_error({"You cannot use this option if there are no tags defined."}, nil, 0)
else
    local sequence = {
        preset="None",
        tags={}
    }

    if (prefs.presets == nil) then
        prefs.presets = {}
    end

    if (prefs.last_open ~= nil) then
        -- validate that the sequence we are loading is valid. if it's not, continue loading a blank sequence instead
        local isValid, tagNamesMissing = validatePresetHasNecessaryTags(prefs.last_open)
        if (isValid) then
            sequence = deepcopy(prefs.last_open)
        end
    end

    local exit = { action=nil, sequence=nil }
    mainWindow(sequence, prefs.presets, exit):show{ wait=true }

    if (exit.action == "export") then
        -- DEVELOPMENT VERSION
        -- local exportChunk = app.fs.joinPath(app.fs.userConfigPath, "scripts", "export.lua")
        -- PRODUCTION VERSION
        local exportChunk = app.fs.joinPath(app.fs.userConfigPath, "extensions", "gif-sequencing", "export.lua")
        -- load the lua script into a Lua chunk, then execute it with the parameter plugin.preferences
        loadfile(exportChunk)(exit.sequence)
    end

    prefs.last_open = deepcopy(exit.sequence)
end
