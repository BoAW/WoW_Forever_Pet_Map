local _, ns = ...

-- Tameable beasts on the zone maps, from the list in data/hunter_pets.lua: one dot per
-- beast in the middle of where it is found, or one dot per spawn. A button on the map
-- opens a menu with the choices, and the same choices are on the settings page.
local DOT_SIZE = { approximate = 12, all = 8 }
ns.DOT_SIZE = DOT_SIZE
local DOT_BORDER = 1.5
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ICON = "Interface\\Icons\\Ability_Hunter_BeastTaming"
-- The most a submenu of families or beasts grows before it scrolls.
local MENU_HEIGHT = 400

local MODES = {
    { value = "off", label = "Off" },
    { value = "approximate", label = "One per beast" },
    { value = "all", label = "All spawns" },
}
local RARITIES = {
    { value = "all", label = "All" },
    { value = "rare", label = "Rares only" },
    { value = "notRare", label = "Not rares" },
}

local provider
local mapButton

local function FormatLevels(minLevel, maxLevel)
    return ("%d-%d"):format(minLevel, maxLevel)
end

local function ColorText(text, color)
    return CreateColor(color[1], color[2], color[3]):WrapTextInColorCode(text)
end

local function FindChoice(choices, value)
    for _, choice in ipairs(choices) do
        if choice.value == value then
            return choice
        end
    end
    return choices[1]
end

-- Families and beasts unticked in the map button's menu, kept by family key and beast name.
local function GetHidden(kind)
    local key = kind == "family" and "hiddenFamilies" or "hiddenBeasts"
    PetMapDB[key] = PetMapDB[key] or {}
    return PetMapDB[key]
end

function ns.IsShown(beast)
    if GetHidden("family")[beast.family] or GetHidden("beast")[beast.name] then
        return false
    end
    local rarity = PetMapDB.rarity
    if rarity == "rare" then
        return beast.rare
    elseif rarity == "notRare" then
        return not beast.rare
    end
    return true
end

-- The dots on the map.

function ns.CreateRoundTexture(frame, sublevel, inset)
    local texture = frame:CreateTexture(nil, "ARTWORK", nil, sublevel)
    texture:SetPoint("TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", -inset, inset)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture
end

PetMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function PetMapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
    ns.SetupDot(self)
end

-- The black ring and the coloured dot inside it, used by the dots on both maps.
function ns.SetupDot(frame)
    frame.Border = ns.CreateRoundTexture(frame, 0, 0)
    frame.Border:SetColorTexture(0, 0, 0, 0.9)
    frame.Dot = ns.CreateRoundTexture(frame, 1, DOT_BORDER)
end

function ns.SetDotColor(frame, beast)
    local family = ns.HUNTER_PET_FAMILIES[beast.family]
    local color = family and family.color or { 1, 1, 1 }
    frame.Dot:SetColorTexture(color[1], color[2], color[3])
end

function PetMapPinMixin:OnAcquired(beast, x, y, size)
    self.beast = beast
    self:SetSize(size, size)
    ns.SetDotColor(self, beast)
    self:SetPosition(x, y)
end

-- The beast's name, levels, family and whether it is rare or elite.
function ns.ShowBeastTooltip(owner, beast)
    local family = ns.HUNTER_PET_FAMILIES[beast.family]
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(beast.name)
    if beast.levels then
        GameTooltip:AddLine(LEVEL .. " " .. FormatLevels(beast.levels[1], beast.levels[2]), 1, 1, 1)
    end
    if family then
        GameTooltip:AddLine(family.name, family.color[1], family.color[2], family.color[3])
    end
    if beast.rare and beast.elite then
        GameTooltip:AddLine("Rare elite", 1, 0.82, 0)
    elseif beast.rare then
        GameTooltip:AddLine("Rare", 1, 0.82, 0)
    elseif beast.elite then
        GameTooltip:AddLine("Elite", 1, 0.82, 0)
    end
    GameTooltip:Show()
end

function PetMapPinMixin:OnMouseEnter()
    ns.ShowBeastTooltip(self, self.beast)
end

function PetMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

local function SetupProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate("PetMapPinTemplate")
    end

    function provider:RefreshAllData()
        self:RemoveAllData()
        local mode = PetMapDB.show
        local size = DOT_SIZE[mode]
        if not size then
            return
        end
        local map = self:GetMap()
        local mapID = map:GetMapID()
        local mapInfo = mapID and C_Map.GetMapInfo(mapID)
        for _, beast in ipairs(mapInfo and ns.HUNTER_PETS[mapInfo.name] or {}) do
            if not ns.IsShown(beast) then
                -- Left out by the choices in the menu.
            elseif mode == "all" then
                local points = beast.points
                for i = 1, #points, 2 do
                    map:AcquirePin("PetMapPinTemplate", beast, points[i], points[i + 1], size)
                end
            else
                map:AcquirePin("PetMapPinTemplate", beast, beast.x, beast.y, size)
            end
        end
    end

    WorldMapFrame:AddDataProvider(provider)
end

-- The button on the map and its menu.

local function UpdateButton()
    if mapButton then
        mapButton.Icon:SetDesaturated(FindChoice(MODES, PetMapDB.show).value == "off")
    end
end

local function Update()
    UpdateButton()
    if provider and provider:GetMap() then
        provider:RefreshAllData()
    end
    if ns.UpdateMinimap then
        ns.UpdateMinimap()
    end
end

local function ShowButtonTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Pet Map")
    GameTooltip:AddDoubleLine("Show", FindChoice(MODES, PetMapDB.show).label, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Which", FindChoice(RARITIES, PetMapDB.rarity).label, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Minimap", PetMapDB.minimap and "On" or "Off", 1, 1, 1, 1, 1, 1)
    if next(GetHidden("family")) or next(GetHidden("beast")) then
        GameTooltip:AddLine("Some families or beasts are hidden.", 1, 0.82, 0)
    end
    GameTooltip:AddLine("Click to choose.", 1, 1, 1)
    GameTooltip:Show()
end

-- Changes the value through the setting itself, so the settings page follows.
local function SetOption(key, value)
    local setting = Settings.GetSetting and Settings.GetSetting("PetMap_" .. key)
    if setting then
        setting:SetValue(value)
    else
        PetMapDB[key] = value
        Update()
    end
end

-- One section of the menu: a title and a choice for each value, the current one marked.
local function AddMenuSection(root, title, key, choices)
    root:CreateTitle(title)
    for _, choice in ipairs(choices) do
        root:CreateRadio(choice.label, function(value)
            return FindChoice(choices, PetMapDB[key]).value == value
        end, function(value)
            SetOption(key, value)
            -- Keeps the menu open, so several choices can be made in one go.
            return MenuResponse and MenuResponse.Refresh
        end, choice.value)
    end
end

-- A submenu with a tick for each family or beast, and Show all and Hide all at the top.
-- items holds { key, label } for each line; kind says which hidden list the keys belong to.
local function AddTickSubmenu(root, title, kind, items)
    local submenu = root:CreateButton(title)
    if submenu.SetScrollMode then
        submenu:SetScrollMode(MENU_HEIGHT)
    end
    local function SetAll(hidden)
        local hiddenList = GetHidden(kind)
        for _, item in ipairs(items) do
            hiddenList[item.key] = hidden or nil
        end
        Update()
        return MenuResponse and MenuResponse.Refresh
    end
    submenu:CreateButton("Show all", function()
        return SetAll(false)
    end)
    submenu:CreateButton("Hide all", function()
        return SetAll(true)
    end)
    submenu:CreateDivider()
    for _, item in ipairs(items) do
        submenu:CreateCheckbox(item.label, function(key)
            return not GetHidden(kind)[key]
        end, function(key)
            local hiddenList = GetHidden(kind)
            hiddenList[key] = not hiddenList[key] or nil
            Update()
            return MenuResponse and MenuResponse.Refresh
        end, item.key)
    end
end

local function GetFamilyItems()
    local items = {}
    for key, family in pairs(ns.HUNTER_PET_FAMILIES) do
        table.insert(items, { key = key, label = ColorText(family.name, family.color) })
    end
    table.sort(items, function(a, b)
        return ns.HUNTER_PET_FAMILIES[a.key].name < ns.HUNTER_PET_FAMILIES[b.key].name
    end)
    return items
end

-- The beasts on the zone map, lowest level first, each name once and in its family's colour.
local function GetBeastItems(beasts)
    local sorted, seen = {}, {}
    for _, beast in ipairs(beasts) do
        if not seen[beast.name] then
            seen[beast.name] = true
            table.insert(sorted, beast)
        end
    end
    table.sort(sorted, function(a, b)
        local levelA, levelB = a.levels and a.levels[1] or 0, b.levels and b.levels[1] or 0
        if levelA ~= levelB then
            return levelA < levelB
        end
        return a.name < b.name
    end)
    local items = {}
    for _, beast in ipairs(sorted) do
        local family = ns.HUNTER_PET_FAMILIES[beast.family]
        local label = family and ColorText(beast.name, family.color) or beast.name
        if beast.levels then
            label = label .. " " .. FormatLevels(beast.levels[1], beast.levels[2])
        end
        if beast.rare then
            label = label .. " (Rare)"
        end
        table.insert(items, { key = beast.name, label = label })
    end
    return items
end

-- A round button like the game's minimap buttons: icon, dark background and ring.
local function CreateRoundButton(name, parent)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(31, 31)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetTexture(ICON)
    button.Icon:SetSize(17, 17)
    button.Icon:SetPoint("TOPLEFT", 7, -6)
    button.Icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    return button
end

-- A round button in the top right corner of the map that opens a menu with the choices.
local function SetupButton()
    local scrollContainer = WorldMapFrame.ScrollContainer
    local button = CreateRoundButton("PetMapButton", WorldMapFrame)
    button:SetPoint("TOPRIGHT", scrollContainer, "TOPRIGHT", -4, -4)
    -- Above the map's pins, which are drawn on the map's canvas.
    button:SetFrameLevel(scrollContainer:GetFrameLevel() + 1000)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        MenuUtil.CreateContextMenu(self, function(_, root)
            AddMenuSection(root, "Show", "show", MODES)
            root:CreateCheckbox("Show on minimap", function()
                return PetMapDB.minimap
            end, function()
                SetOption("minimap", not PetMapDB.minimap)
                return MenuResponse and MenuResponse.Refresh
            end)
            root:CreateDivider()
            AddMenuSection(root, "Which", "rarity", RARITIES)
            root:CreateDivider()
            AddTickSubmenu(root, "Families", "family", GetFamilyItems())
            local mapID = WorldMapFrame:GetMapID()
            local mapInfo = mapID and C_Map.GetMapInfo(mapID)
            local beasts = mapInfo and ns.HUNTER_PETS[mapInfo.name]
            if beasts then
                AddTickSubmenu(root, "Beasts in " .. mapInfo.name, "beast", GetBeastItems(beasts))
            end
        end)
    end)
    button:SetScript("OnEnter", ShowButtonTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    mapButton = button
    UpdateButton()
end

local function SetupMap()
    SetupProvider()
    SetupButton()
end

-- The settings page: the choices, and a line about the button on the map.

local function AddDropdown(category, key, label, tooltip, default, choices)
    local setting = Settings.RegisterAddOnSetting(category, "PetMap_" .. key, key, PetMapDB,
        type(default), label, default)
    -- Older clients name it CreateDropDown.
    local createDropdown = Settings.CreateDropdown or Settings.CreateDropDown
    createDropdown(category, setting, function()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do
            container:Add(choice.value, choice.label)
        end
        return container:GetData()
    end, tooltip)
    setting:SetValueChangedCallback(Update)
end

local function RegisterSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Pet Map")

    AddDropdown(category, "show", "Show hunter pets",
        "Shows the beasts a hunter can tame on the zone maps. Point at one to see the beast, "
            .. "its levels and its family."
            .. "\nOne per beast: one dot in the middle of where the beast is found."
            .. "\nAll spawns: a dot for every place the beast can be found.",
        "off", MODES)
    local minimapSetting = Settings.RegisterAddOnSetting(category, "PetMap_minimap", "minimap", PetMapDB,
        "boolean", "Show on minimap", false)
    -- Older clients name it CreateCheckBox.
    local createCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
    createCheckbox(category, minimapSetting,
        "Shows the hunter pets near you on the minimap, also when they are off on the world map. "
            .. "With the world map's Show set to Off, the minimap shows one dot per beast.")
    minimapSetting:SetValueChangedCallback(Update)
    AddDropdown(category, "rarity", "Which hunter pets",
        "Shows all hunter pets, only the rare ones or only those that are not rare.",
        "all", RARITIES)

    local note = Settings.CreateElementInitializer("PetMapSettingsLineTemplate", {})
    hooksecurefunc(note, "InitFrame", function(_, frame)
        frame.Text:SetText("You can also change these with the button in the top right corner of the world map.")
    end)
    layout:AddInitializer(note)

    Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    PetMapDB = PetMapDB or {}
    -- Registering a setting also fills in its default value in PetMapDB.
    RegisterSettings()
    -- The world map is loaded on demand in some game versions.
    if WorldMapFrame then
        SetupMap()
    else
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", SetupMap)
    end
end)
