-- CustomCompassPins by Shinni
local ADDON_NAME = "CustomCompassPins"
local version = 1.33

-- Get global environment
local _G = getfenv(0)

-- Lua built-ins
local pairs = _G.pairs
local select = _G.select
local string = _G.string
local string_format = string.format
local type = _G.type

-- ESO math functions
local zo_abs = _G.zo_abs
local zo_atan2 = _G.zo_atan2
local zo_sqrt = _G.zo_sqrt

-- ESO API functions
local GetCurrentMapIndex = _G.GetCurrentMapIndex
local GetFrameTimeMilliseconds = _G.GetFrameTimeMilliseconds
local GetMapContentType = _G.GetMapContentType
local GetMapPlayerPosition = _G.GetMapPlayerPosition
local GetMapTileTexture = _G.GetMapTileTexture
local GetMapType = _G.GetMapType
local GetPlayerCameraHeading = _G.GetPlayerCameraHeading
local SetMapToPlayerLocation = _G.SetMapToPlayerLocation
local ZO_ControlPool = _G.ZO_ControlPool
local ZO_WorldMap_GetPinManager = _G.ZO_WorldMap_GetPinManager

-- ESO constants
local MAPTYPE_SUBZONE = _G.MAPTYPE_SUBZONE
local MAP_CONTENT_DUNGEON = _G.MAP_CONTENT_DUNGEON
local SET_MAP_RESULT_MAP_CHANGED = _G.SET_MAP_RESULT_MAP_CHANGED
local ZO_PI = _G.ZO_PI
local ZO_TWO_PI = _G.ZO_TWO_PI

-- ESO UI globals
local CALLBACK_MANAGER = _G.CALLBACK_MANAGER
local CHAT_ROUTER = _G.CHAT_ROUTER
local GuiRoot = _G.GuiRoot
local WINDOW_MANAGER = _G.GetWindowManager()
local WORLD_MAP_SCENE = _G.WORLD_MAP_SCENE


-- Constants
local CENTER = _G.CENTER

---@class CompassPinLayout
---@field maxDistance number Maximum visibility distance in normalized map units
---@field texture string Path to the pin texture
---@field FOV? number Field of view in radians (default: ZO_PI * 0.6)
---@field maxAngle? number Maximum visible angle (default: 1.0)
---@field sizeCallback? fun(pin: CompassPin, angle: number, normalizedAngle: number, normalizedDistance: number) Custom size calculation function
---@field additionalLayout? {[1]: fun(pin: CompassPin, angle: number, normalizedAngle: number, normalizedDistance: number), [2]: fun(pin: CompassPin)} Custom visual effects

---@class CompassPin
---@field xLoc number X coordinate in normalized map units
---@field yLoc number Y coordinate in normalized map units
---@field pinType string Type identifier for the pin
---@field pinTag any Unique identifier for the pin
---@field pinName? string Optional name for the pin
---@field data table Additional custom data
---@field SetAnchor fun(self: CompassPin, anchor: string, parent: Control, relativePoint: string, offsetX: number, offsetY: number) Set pin anchor
---@field ClearAnchors fun(self: CompassPin) Clear all anchors
---@field SetAlpha fun(self: CompassPin, value: number) Set pin transparency (0-1)
---@field SetHidden fun(self: CompassPin, hidden: boolean) Show/hide the pin
---@field SetDimensions fun(self: CompassPin, width: number, height: number) Set pin size
---@field SetColor fun(self: CompassPin, r: number, g: number, b: number, a: number) Set pin color
---@field GetNamedChild fun(self: CompassPin, name: string): Control Get child control by name

---@class CompassPinManager
---@field pinData table<string, CompassPinData> Storage for pin data
---@field defaultAngle number Default maximum visible angle
---@field CreatePin fun(self: CompassPinManager, pinType: string, pinTag: any, xLoc: number, yLoc: number, pinName?: string, ...: any) Create a new pin
---@field RemovePin fun(self: CompassPinManager, pinTag: any) Remove a specific pin
---@field RemovePins fun(self: CompassPinManager, pinType?: string) Remove all pins of a type
---@field Update fun(self: CompassPinManager, x: number, y: number, heading: number) Update all pins

---@class CompassPinData
---@field xLoc number X coordinate
---@field yLoc number Y coordinate
---@field pinType string Type identifier
---@field pinTag any Unique identifier
---@field pinName? string Optional name
---@field pinKey? any Internal key for pin management

---@class COMPASS_PINS
---@field version number Current version number
---@field defaultFOV number Default field of view
---@field distanceCoefficient number Current distance coefficient
---@field pinCallbacks table<string, fun(pinManager: CompassPinManager)> Pin creation callbacks
---@field pinLayouts table<string, CompassPinLayout> Pin layout configurations
---@field AddCustomPin fun(self: COMPASS_PINS, pinType: string, pinCallback: fun(pinManager: CompassPinManager), layout: CompassPinLayout) Add a new pin type
---@field RefreshPins fun(self: COMPASS_PINS, pinType?: string) Refresh pins of a type
---@field GetDistanceCoefficient fun(self: COMPASS_PINS): number Get current distance coefficient
---@field RefreshDistanceCoefficient fun(self: COMPASS_PINS) Update distance coefficient
---@field Update fun(self: COMPASS_PINS) Update all pins

local onlyUpdate = false
if COMPASS_PINS and COMPASS_PINS.version then
    if COMPASS_PINS.version >= version then
        return
    end
    onlyUpdate = true
else
    COMPASS_PINS = {}
end

local PARENT = COMPASS.container
local FOV = ZO_PI * 0.6
local coefficients = { 0.16, 1.08, 1.32, 1.14, 1.14, 1.23, 1.16, 1.24, 1.33, 1.00, 1.12, 1.00, 1.00, 0.89, 1.00, 1.37, 1.20, 4.27, 2.67, 3.20, 5.00, 8.45, 0.89, 0.10, 1.14 }
local Compass_Pins = COMPASS_PINS -- local reference for update performance

-- Base class, can be accessed via COMPASS_PINS
local CompassPinManager = ZO_ControlPool:Subclass()

---Initialize or update the COMPASS_PINS object
---@param ... any Additional initialization parameters
---@return COMPASS_PINS
function COMPASS_PINS:New(...)
    if onlyUpdate then
        self:UpdateVersion()
    else
        self:Initialize(...)
    end

    self.control:SetHidden(false)

    self.version = version
    self.name = ADDON_NAME
    self.defaultFOV = FOV
    self:RefreshDistanceCoefficient()

    local lastUpdate = 0
    self.control:SetHandler("OnUpdate",
                            function ()
                                local now = GetFrameTimeMilliseconds()
                                if (now - lastUpdate) >= 20 then
                                    self:Update()
                                    lastUpdate = now
                                end
                            end)

    self:SetupCallbacks()

    return self
end

---Update the version while preserving pin data
function COMPASS_PINS:UpdateVersion()
    local data = self.pinManager.pinData
    self.pinManager = CompassPinManager:New()
    if data then
        self.pinManager.pinData = {}
        for pinTag, entry in pairs(data) do
            self.pinManager.pinData[pinTag] = entry
        end
    end
end

---Initialize the COMPASS_PINS object
---@param ... any Additional initialization parameters
function COMPASS_PINS:Initialize(...)
    self.control = WINDOW_MANAGER:CreateControlFromVirtual(nil, GuiRoot, "ZO_MapPin")
    self.pinCallbacks = {}
    self.pinLayouts = {}
    self.pinManager = CompassPinManager:New()
end

---Set up map change detection and callbacks
function COMPASS_PINS:SetupCallbacks()
    if _G["CustomCompassPins_MapChangeDetector"] == nil then
        ZO_WorldMap_GetPinManager():AddCustomPin("CustomCompassPins_MapChangeDetector",
                                                 function ()
                                                     local tileIndex = 1
                                                     local currentMap = select(3, (GetMapTileTexture(tileIndex)):lower():find("maps/([%w%-]+/[%w%-]+_%w+)"))
                                                     CALLBACK_MANAGER:FireCallbacks("CustomCompassPins_MapChanged", currentMap)
                                                 end)
        ZO_WorldMap_GetPinManager():SetCustomPinEnabled(_G["CustomCompassPins_MapChangeDetector"], true)

        CALLBACK_MANAGER:RegisterCallback("CustomCompassPins_MapChanged",
                                          function (currentMap)
                                              if self.map ~= currentMap then
                                                  self:RefreshDistanceCoefficient()
                                                  self:RefreshPins()
                                                  self.map = currentMap
                                              end
                                          end)
    end

    local callback
    callback = function (oldState, newState)
        if self.version ~= version then
            WORLD_MAP_SCENE:UnregisterCallback("StateChange", callback)
            return
        end
        if newState == SCENE_HIDING then
            if (SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED) then
                CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
            end
        end
    end
    WORLD_MAP_SCENE:RegisterCallback("StateChange", callback)
end

---Add a new custom pin type
---@param pinType string Unique identifier for the pin type
---@param pinCallback fun(pinManager: CompassPinManager) Function to create pins
---@param layout CompassPinLayout Pin appearance and behavior settings
function COMPASS_PINS:AddCustomPin(pinType, pinCallback, layout)
    if type(pinType) ~= "string"
    or self.pinLayouts[pinType] ~= nil
    or type(pinCallback) ~= "function"
    or type(layout) ~= "table" then
        return
    end
    layout.maxDistance = layout.maxDistance or 0.02
    layout.texture = layout.texture or "EsoUI/Art/MapPins/hostile_pin.dds"

    self.pinCallbacks[pinType] = pinCallback
    self.pinLayouts[pinType] = layout
end

---Refresh pins of a specific type or all pins
---@param pinType? string Type of pins to refresh
function COMPASS_PINS:RefreshPins(pinType)
    self.pinManager:RemovePins(pinType)
    if pinType then
        if not self.pinCallbacks[pinType] then
            return
        end
        self.pinCallbacks[pinType](self.pinManager)
    else
        for tag, callback in pairs(self.pinCallbacks) do
            callback(self.pinManager)
        end
    end
end

---Get the current distance coefficient based on map type
---@return number coefficient The distance coefficient
function COMPASS_PINS:GetDistanceCoefficient()
    local coefficient = 1
    local mapId = GetCurrentMapIndex()
    if mapId then
        coefficient = coefficients[mapId] or 1 -- zones and starting isles
    else
        if GetMapContentType() == MAP_CONTENT_DUNGEON then
            coefficient = 16 -- all dungeons, value between 8 - 47, usually 16
        elseif GetMapType() == MAPTYPE_SUBZONE then
            coefficient = 6  -- all subzones, value between 5 - 8, usually 6
        end
    end

    return zo_sqrt(coefficient)
end

---Update the distance coefficient
function COMPASS_PINS:RefreshDistanceCoefficient()
    self.distanceCoefficient = self:GetDistanceCoefficient()
end

---Update all pins' positions
function COMPASS_PINS:Update()
    local heading = GetPlayerCameraHeading()
    if not heading then
        return
    end
    if heading > ZO_PI then -- normalize heading to [-pi,pi]
        heading = heading - ZO_TWO_PI
    end

    local x, y = GetMapPlayerPosition("player")
    self.pinManager:Update(x, y, heading)
end

---Create a new CompassPinManager instance
---@param ... any Additional initialization parameters
---@return CompassPinManager
function CompassPinManager:New(...)
    local result = ZO_ControlPool.New(self, "ZO_MapPin", PARENT, "Pin")
    result:Initialize2(...)
    return result
end

---Initialize the CompassPinManager
---@param ... any Additional initialization parameters
function CompassPinManager:Initialize2(...)
    self.pinData = {}
    self.defaultAngle = 1
end

---Create a new pin object
---@param data CompassPinData Pin data
---@return CompassPin pin The created pin
---@return any pinKey Internal key for pin management
function CompassPinManager:GetNewPin(data)
    local pin, pinKey = self:AcquireObject()
    self:ResetPin(pin)
    pin:SetHandler("OnMouseDown", nil)
    pin:SetHandler("OnMouseUp", nil)
    pin:SetHandler("OnMouseEnter", nil)
    pin:SetHandler("OnMouseExit", nil)
    pin:GetNamedChild("Highlight"):SetHidden(true)

    pin.xLoc = data.xLoc
    pin.yLoc = data.yLoc
    pin.pinType = data.pinType
    pin.pinTag = data.pinTag
    pin.pinName = data.pinName
    pin.data = data

    local layout = COMPASS_PINS.pinLayouts[data.pinType]
    local texture = pin:GetNamedChild("Background")
    texture:SetTexture(layout.texture)

    return pin, pinKey
end

-- creates a pin of the given pinType at the given location
-- (radius is not implemented yet)
---@param pinType string Type identifier
---@param pinTag any Unique identifier
---@param xLoc number X coordinate
---@param yLoc number Y coordinate
---@param pinName? string Optional name
---@param ... CompassPinData Additional data
function CompassPinManager:CreatePin(pinType, pinTag, xLoc, yLoc, pinName, ...)
    local data = { ... } -- in case the user wants to add more information

    data.xLoc = xLoc or 0
    data.yLoc = yLoc or 0
    data.pinType = pinType or "NoType"
    data.pinTag = pinTag or {}
    data.pinName = pinName

    self:RemovePin(data.pinTag) -- added in 1.29
    -- some addons add new compass pins outside of this libraries callback
    -- function. in such a case the old pins haven't been removed yet and get stuck
    -- see destinations comment section 03/19/16 (uladz) and newer

    self.pinData[pinTag] = data
end

---Remove a specific pin
---@param pinTag any Unique identifier of the pin to remove
function CompassPinManager:RemovePin(pinTag)
    local entry = self.pinData[pinTag]
    if entry and entry.pinKey then
        self:ReleaseObject(entry.pinKey)
    end
    self.pinData[pinTag] = nil
end

---Remove all pins of a type or all pins
---@param pinType? string Type of pins to remove
function CompassPinManager:RemovePins(pinType)
    if not pinType then
        self:ReleaseAllObjects()
        self.pinData = {}
    else
        for key, data in pairs(self.pinData) do
            if data.pinType == pinType then
                if data.pinKey then
                    self:ReleaseObject(data.pinKey)
                end
                self.pinData[key] = nil
            end
        end
    end
end

---Reset a pin to its default state
---@param pin CompassPin The pin to reset
function CompassPinManager:ResetPin(pin)
    for _, layout in pairs(COMPASS_PINS.pinLayouts) do
        if layout.additionalLayout then
            layout.additionalLayout[2](pin)
        end
    end
end

---Update all pins' positions
---@param x number Player X coordinate
---@param y number Player Y coordinate
---@param heading number Player heading
function CompassPinManager:Update(x, y, heading)
    for _, pinData in pairs(self.pinData) do
        self:UpdateSinglePin(pinData, x, y, heading)
    end
end

---Update a single pin's position
---@param pinData CompassPinData Pin data
---@param playerX number Player X coordinate
---@param playerY number Player Y coordinate
---@param heading number Player heading
function CompassPinManager:UpdateSinglePin(pinData, playerX, playerY, heading)
    local layout = Compass_Pins.pinLayouts[pinData.pinType]
    local distance = layout.maxDistance * Compass_Pins.distanceCoefficient

    local xDif = playerX - pinData.xLoc
    local yDif = playerY - pinData.yLoc
    local normalizedDistance = (xDif * xDif + yDif * yDif) / (distance * distance)

    if normalizedDistance >= 1 then
        if pinData.pinKey then
            self:ReleaseObject(pinData.pinKey)
            pinData.pinKey = nil
        end
        return
    end

    local pin
    if pinData.pinKey then
        pin = self:GetExistingObject(pinData.pinKey)
    else
        pin, pinData.pinKey = self:GetNewPin(pinData)
    end

    if not pin then
        CHAT_ROUTER:AddSystemMessage(string_format("CustomCompassPin Error: no pin with key %s found!", pinData.pinKey))
        return
    end

    pin:SetHidden(true)

    local angle = self:CalculatePinAngle(xDif, yDif, heading)
    local normalizedAngle = 2 * angle / (layout.FOV or Compass_Pins.defaultFOV)
    local absNormalizedAngle = zo_abs(normalizedAngle)

    if absNormalizedAngle > (layout.maxAngle or self.defaultAngle) then
        return
    end

    self:PositionPin(pin, PARENT, normalizedAngle, normalizedDistance)
    self:ApplyPinSize(pin, layout, angle, normalizedAngle, normalizedDistance, absNormalizedAngle)

    if layout.additionalLayout then
        layout.additionalLayout[1](pin, angle, normalizedAngle, normalizedDistance)
    end
end

---Calculate the angle between player and pin
---@param xDif number X difference
---@param yDif number Y difference
---@param heading number Player heading
---@return number angle The calculated angle
function CompassPinManager:CalculatePinAngle(xDif, yDif, heading)
    local angle = -zo_atan2(xDif, yDif)
    angle = angle + heading

    if angle > ZO_PI then
        angle = angle - ZO_TWO_PI
    elseif angle < -ZO_PI then
        angle = angle + ZO_TWO_PI
    end

    return angle
end

---Position a pin on the compass
---@param pin CompassPin The pin to position
---@param parent Control The parent control
---@param normalizedAngle number Normalized angle (-1 to 1)
---@param normalizedDistance number Normalized distance (0 to 1)
function CompassPinManager:PositionPin(pin, parent, normalizedAngle, normalizedDistance)
    pin:ClearAnchors()
    pin:SetAnchor(CENTER, parent, CENTER, 0.5 * parent:GetWidth() * normalizedAngle, 0)
    pin:SetHidden(false)
    pin:SetAlpha(1 - normalizedDistance)
end

---Apply size to a pin based on angle and distance
---@param pin CompassPin The pin to size
---@param layout CompassPinLayout Pin layout settings
---@param angle number Angle between player and pin
---@param normalizedAngle number Normalized angle (-1 to 1)
---@param normalizedDistance number Normalized distance (0 to 1)
---@param absNormalizedAngle number Absolute normalized angle
function CompassPinManager:ApplyPinSize(pin, layout, angle, normalizedAngle, normalizedDistance, absNormalizedAngle)
    if layout.sizeCallback then
        layout.sizeCallback(pin, angle, normalizedAngle, normalizedDistance)
    else
        if absNormalizedAngle > 0.25 then
            pin:SetDimensions(36 - 16 * absNormalizedAngle, 36 - 16 * absNormalizedAngle)
        else
            pin:SetDimensions(32, 32)
        end
    end
end

COMPASS_PINS:New()


--[[
Example usage:

COMPASS_PINS:AddCustomPin("myCompassPins", function (pinManager)
                              for _, pinTag in pairs(myData) do
                                  pinManager:CreatePin("myCompassPins", pinTag, pinTag.x, pinTag.y)
                              end
                          end,
                          {
                              maxDistance = 0.05,
                              texture = "esoui/art/compass/quest_assistedareapin.dds"
                          })

]]
