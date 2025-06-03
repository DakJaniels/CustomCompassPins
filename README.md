# CustomCompassPins

A library for adding custom pins to the ESO compass. This library provides a robust and performant way to display custom markers on the compass, with automatic handling of map changes, distance scaling, and pin management.

## Quick Start

### Installation
Add this to your addon's manifest file:
```txt
## DependsOn: CustomCompassPins>=33
```

### Basic Usage
```Lua
-- Define your pin data
local myPins = {
    {x = 0.5, y = 0.5, name = "Pin 1"},
    {x = 0.7, y = 0.3, name = "Pin 2"},
}

-- Add your custom pin type
COMPASS_PINS:AddCustomPin("myCompassPins",
    function(pinManager)
        for _, pinData in pairs(myPins) do
            pinManager:CreatePin("myCompassPins", pinData, pinData.x, pinData.y, pinData.name)
        end
    end,
    {
        maxDistance = 0.05,
        texture = "esoui/art/compass/quest_assistedareapin.dds"
    }
)
```

## Core Features

### Pin Management
- Automatic pin creation and cleanup
- Efficient pin pooling and reuse
- Automatic distance-based visibility
- Smooth fade effects
- Customizable pin sizes and colors

### Map Integration
- Automatic map change detection
- Dynamic distance scaling based on map type
- Smooth transitions between zones
- Support for zones, dungeons, and subzones

### Performance
- Uses ESO's optimized math functions
- Efficient pin pooling system
- Reduced callback overhead
- Automatic cleanup of out-of-range pins
- Optimized angle calculations

## Detailed Usage

### Adding Custom Pins
```Lua
COMPASS_PINS:AddCustomPin(pinType, pinCallback, layout)
```

Parameters:
* `pinType` (string): Unique identifier for your pin type
* `pinCallback` (function): Called to create pins
* `layout` (table): Pin appearance and behavior settings

### Pin Layout Options

Required settings:
* `maxDistance` (number): Maximum visibility distance (normalized map units)
* `texture` (string): Path to pin texture

Optional settings:
* `FOV` (number): Field of view in radians (default: ZO_PI * 0.6)
* `maxAngle` (number): Maximum visible angle (default: 1.0)
* `sizeCallback` (function): Custom size calculation
* `additionalLayout` (table): Custom visual effects

### Pin Object Properties
* `xLoc`, `yLoc`: Pin coordinates
* `pinType`: Type identifier
* `pinTag`: Unique identifier
* `pinName`: Optional name
* `data`: Additional custom data

### Available Pin Methods
* `SetAlpha(value)`: Set transparency (0-1)
* `SetHidden(bool)`: Show/hide pin
* `SetDimensions(width, height)`: Set pin size
* `SetColor(r, g, b, a)`: Set pin color
* `GetNamedChild("Background")`: Get texture control

## Advanced Features

### Custom Size Calculation
```Lua
sizeCallback = function(pin, angle, normalizedAngle, normalizedDistance)
    local size = 32 * (1 - normalizedDistance)
    pin:SetDimensions(size, size)
end
```

### Custom Visual Effects
```Lua
additionalLayout = {
    function(pin, angle, normalizedAngle, normalizedDistance)
        -- Apply effects
        pin:SetColor(1, 1, 1, 1 - normalizedDistance)
    end,
    function(pin)
        -- Reset effects
        pin:SetColor(1, 1, 1, 1)
    end
}
```

## Technical Details

### Version Compatibility
- Automatic version checking
- Preserves pin data during updates
- Handles version conflicts gracefully

### Distance Coefficient System
- Zone-specific distance scaling
- Automatic map type detection
- Pre-calculated coefficients for performance
- Smooth transitions between map types

### Error Handling
- System-level error messages
- Parameter validation
- Automatic pin cleanup
- Graceful error recovery

### Map Change Detection
- Automatic map change monitoring
- Distance coefficient updates
- Pin position recalculation
- Zone transition handling

## License

This software is licensed under CreativeCommons CC BY-NC-SA 4.0
Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

See LICENSE.txt for full details.
