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

local sequence = ...

-----------------------------------
-- HELPER METHODS
-----------------------------------
local function getLayerGroups(sprite)
    local result = {}

    for _,layer in ipairs(sprite.layers) do
        if (layer.isGroup) then
            table.insert(result, layer.name)
        end
    end

    return result
end

local function layerGroupWindow(sprite)
    local dialog = Dialog("Select Layer Group")

    dialog:combobox {
        id="layerGroupName",
        options=getLayerGroups(sprite)
    }

    dialog:button {
        id="cancel",
        text="Cancel"
    }
    
    dialog:button {
        id="save",
        text="Save"
    }

    return dialog
end


local function readAllTags(sprite)
    local tags = {}

    -- main loop where we compile all of the info we need to essentially copy / paste
    for _,tag in ipairs(sprite.tags) do
        -- snag the name from the tag to use as a dictionary reference when we're reading the sequence later
        tags[tag.name] = {}
        
        -- loop through all of the frames within this tag and copy the image information from each cel
        tags[tag.name].frames = {}
        -- we should be flattened at this point, so grabbing the active layer is a cheap operation to get what we want (the layer:cel() function)
        local layer = app.activeLayer
        for f=tag.fromFrame.frameNumber,tag.toFrame.frameNumber do
            local cel = layer:cel(f)
            if (cel ~= nil) then
                table.insert(tags[tag.name].frames, {
                    pixels=layer:cel(f).image,
                    position=layer:cel(f).position
                })
            else
                table.insert(tags[tag.name].frames, {
                    pixels=nil,
                    position=nil
                })
            end
        end
    end

    return tags
end

local function buildSequence(sprite, sequence, tags)
    -- we should be flattened at this point, so grabbing the active layer is a cheap operation to get what we want (the layer:cel() function)
    local layer = app.activeLayer

    -- loop through the sequence and start building up the frames
    for _,seq_tag in ipairs(sequence.tags) do
        -- loop through the repetitions on this tag
        for tag=1,seq_tag.repetitions do
            -- loop through the frames on this tag
            for _,image in ipairs(tags[seq_tag.name].frames) do
                local frame = sprite:newEmptyFrame(#sprite.frames+1)
                if (image.pixels ~= nil) then
                    sprite:newCel(layer, frame, image.pixels, image.position)
                end
            end
        end
    end
end

local function deleteAllTags(sprite)
    for tag=1,#sprite.tags do
        sprite:deleteTag(sprite.tags[1])
    end
end

local function deleteAllFramesInRange(sprite, min, max)
    for f=min,max do
        sprite:deleteFrame(sprite.frames[min])
    end
end

local function deleteAllHiddenLayers(sprite)
    for _,layer in ipairs(sprite.layers) do
        if (not layer.isVisible) then
            sprite:deleteLayer(layer)
        end
    end
end

local function exportAsGif()
    -- it says "save a copy", but really this opens the file export menu
    app.command.SaveFileCopyAs { ["useUI"]=true }
end

-----------------------------------
-- EXECUTE MAIN LOGIC
-----------------------------------

-- origSprite is the reference to the user's original file. DO NOT MODIFY
-- tempSprite is the reference to the file we will be modifying heavily before exporting, then abandoning
local origSprite = app.activeSprite
local tempSprite = Sprite(origSprite)

-- change the filename if a layergroup is selected
local layerGroupWindow = layerGroupWindow(tempSprite)
layerGroupWindow:show{ wait=true }

if (layerGroupWindow.data.save) and (layerGroupWindow.data.layerGroupName ~= "") then
    tempSprite.filename = app.fs.joinPath(app.fs.filePath(origSprite.filename),layerGroupWindow.data.layerGroupName)  
end

-- delete all of the invisible layers because they are not needed, then flatten
deleteAllHiddenLayers(tempSprite)
tempSprite:flatten()

-- read all of the tags into a large table that we can pull info from later
local tags = readAllTags(tempSprite)
local lastFrameOfOriginalSprite = #tempSprite.frames

-- start putting the sequence back together in the specified order
-- appended at the back of the sprite; original frames will be deleted after we've built the sequence
buildSequence(tempSprite, sequence, tags)

-- delete all of the tags so there isn't any confusion (this step isn't strictly necessary, but it was
-- helpful during debugging to keep me from getting confused)
deleteAllTags(tempSprite)

-- we've built the sequence appended as frames at the end of the timeline; let's now delete the original
-- frames to leave behind JUST the sequence desired
deleteAllFramesInRange(tempSprite, 1, lastFrameOfOriginalSprite)

-- finally ready to export!
exportAsGif()

-- close the temporary sprite to finalize the process
tempSprite:close()
