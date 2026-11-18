local _, ns = ...

-- The hunter pets near the player on the minimap, in the same colours and with the same
-- choices as on the world map. The minimap has no pins of its own, so each dot is placed
-- from the player's position, the minimap's zoom and, when it turns, the player's facing.

-- How many yards the minimap shows from edge to edge, for each zoom level.
local MINIMAP_YARDS = {
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
    outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}
-- How often the dots follow the player while moving, in seconds.
local UPDATE_INTERVAL = 0.05

local driver = CreateFrame("Frame")
local dots = {}
-- The beasts in the player's zone: { beast, x, y } for each dot, and the zone's size in yards.
local zone = { mapID = nil, entries = {}, width = 0, height = 0 }
local indoors = false
local lastX, lastY, lastFacing, lastZoom
local elapsedSinceUpdate = 0

local function HideDots(fromIndex)
    for i = fromIndex, #dots do
        dots[i]:Hide()
    end
end

local function GetDot(index)
    local dot = dots[index]
    if not dot then
        dot = CreateFrame("Frame", nil, Minimap)
        dot:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        ns.SetupDot(dot)
        dot:EnableMouse(true)
        dot:SetScript("OnEnter", function(self)
            ns.ShowBeastTooltip(self, self.beast)
        end)
        dot:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        dots[index] = dot
    end
    return dot
end

-- The player's zone map with hunter pets on it. A cave or a small area inside a zone has a
-- map of its own, so this goes up to the zone around it.
local function GetPlayerZoneMap()
    local mapID = C_Map.GetBestMapForUnit("player")
    while mapID do
        local mapInfo = C_Map.GetMapInfo(mapID)
        if not mapInfo then
            return nil
        end
        if ns.HUNTER_PETS[mapInfo.name] then
            return mapID, mapInfo.name
        end
        if mapInfo.mapType and mapInfo.mapType <= Enum.UIMapType.Zone then
            return nil
        end
        mapID = mapInfo.parentMapID
    end
end

-- The size of the zone map in yards, from the world positions of two of its corners.
local function GetZoneYards(mapID)
    if not C_Map.GetWorldPosFromMapPos then
        return 0, 0
    end
    local _, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
    local _, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
    if not topLeft or not bottomRight then
        return 0, 0
    end
    -- In world positions x runs north and y runs west.
    return math.abs(topLeft.y - bottomRight.y), math.abs(topLeft.x - bottomRight.x)
end

-- The dots for the player's zone, after the choices in the menu.
local function BuildZone()
    zone.entries = {}
    zone.mapID = nil
    if not PetMapDB.minimap then
        return
    end
    local mapID, zoneName = GetPlayerZoneMap()
    if not mapID then
        return
    end
    zone.mapID = mapID
    zone.width, zone.height = GetZoneYards(mapID)
    -- With the world map's dots off, the minimap shows one dot per beast.
    local mode = PetMapDB.show == "all" and "all" or "approximate"
    zone.size = ns.DOT_SIZE[mode]
    for _, beast in ipairs(ns.HUNTER_PETS[zoneName]) do
        if not ns.IsShown(beast) then
            -- Left out by the choices in the menu.
        elseif mode == "all" then
            local points = beast.points
            for i = 1, #points, 2 do
                table.insert(zone.entries, { beast = beast, x = points[i], y = points[i + 1] })
            end
        else
            table.insert(zone.entries, { beast = beast, x = beast.x, y = beast.y })
        end
    end
end

local function IsSquare()
    return GetMinimapShape and GetMinimapShape() == "SQUARE"
end

-- Places the dots around the player. force places them even when nothing has moved.
local function PlaceDots(force)
    if not zone.mapID or zone.width == 0 or #zone.entries == 0 then
        HideDots(1)
        return
    end
    local position = C_Map.GetPlayerMapPosition(zone.mapID, "player")
    if not position then
        HideDots(1)
        return
    end
    local playerX, playerY = position:GetXY()
    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing() or 0
    local zoom = Minimap:GetZoom()
    if not force and playerX == lastX and playerY == lastY and facing == lastFacing and zoom == lastZoom then
        return
    end
    lastX, lastY, lastFacing, lastZoom = playerX, playerY, facing, zoom

    local yards = MINIMAP_YARDS[indoors and "indoor" or "outdoor"][zoom] or MINIMAP_YARDS.outdoor[0]
    local radius = Minimap:GetWidth() / 2
    local pixelsPerYard = radius * 2 / yards
    local size = zone.size
    -- Keeps the whole dot inside the minimap's edge.
    local limit = radius - size / 2
    local square = IsSquare()
    local cosFacing, sinFacing = math.cos(facing), math.sin(facing)

    local count = 0
    for _, entry in ipairs(zone.entries) do
        -- Yards east and north of the player; the map's y runs south.
        local east = (entry.x - playerX) * zone.width
        local north = (playerY - entry.y) * zone.height
        -- A turning minimap keeps the player's facing at the top.
        local dx = (east * cosFacing + north * sinFacing) * pixelsPerYard
        local dy = (north * cosFacing - east * sinFacing) * pixelsPerYard
        local inside
        if square then
            inside = math.abs(dx) <= limit and math.abs(dy) <= limit
        else
            inside = dx * dx + dy * dy <= limit * limit
        end
        if inside then
            count = count + 1
            local dot = GetDot(count)
            dot.beast = entry.beast
            dot:SetSize(size, size)
            ns.SetDotColor(dot, entry.beast)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
            dot:Show()
        end
    end
    HideDots(count + 1)
end

-- The game tells nothing about indoors and outdoors, but it keeps a zoom for each. When the
-- two are the same, the zoom is changed for a moment to tell them apart.
local checkingIndoors = false
local function CheckIndoors()
    if checkingIndoors then
        return
    end
    checkingIndoors = true
    local zoom = Minimap:GetZoom()
    if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
        Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
    end
    indoors = tonumber(GetCVar("minimapZoom")) ~= Minimap:GetZoom()
    Minimap:SetZoom(zoom)
    checkingIndoors = false
end

-- Called when a choice changes, from pet_map.lua.
function ns.UpdateMinimap()
    BuildZone()
    if zone.mapID then
        driver:Show()
        PlaceDots(true)
    else
        driver:Hide()
        HideDots(1)
    end
end

driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate >= UPDATE_INTERVAL then
        elapsedSinceUpdate = 0
        PlaceDots(false)
    end
end)

driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:RegisterEvent("ZONE_CHANGED")
driver:RegisterEvent("ZONE_CHANGED_INDOORS")
driver:RegisterEvent("MINIMAP_UPDATE_ZOOM")
driver:SetScript("OnEvent", function(_, event)
    if not PetMapDB then
        return
    end
    if event == "MINIMAP_UPDATE_ZOOM" then
        CheckIndoors()
        PlaceDots(true)
        return
    end
    CheckIndoors()
    ns.UpdateMinimap()
end)
