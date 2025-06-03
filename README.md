CustomCompassPins
=================
This Library allows you to add custom pins to the compass.

## How to install:

If you are an addon developer, you should embed the library in your addon and load the files from your [addon manifest](https://wiki.esoui.com/Addon_manifest_%28.txt%29_format).

You will probably never have to update this library. The last update/bug-fix was in March 2016.
Putting this lib in your DependsOn and asking your users to install this library does also work, but it is not recommended. It will cause more work for everyone involved.

## How to use:

First you have to add the pinType:
Lua Code:

```Lua
    COMPASS_PINS:AddCustomPin( pinType, pinCallback, layout )
```

* `pinType` is a unique string eg "MySkyshards"
* `pinCallback` is a callback function which receives a pinManager (more further below)
* `layout` is a table which specifies texture and other settings for the pins of this pinType

### The callback function

The callback function is called everytime, the compass is refreshed.
This function creates the pins via the given pinManager (first and only parameter).
example:
Lua Code:

```Lua
    function( pinManager )
        for _, pin in pairs( pins ) do
            pinManager:CreatePin( pinType, pinTag, pin.x, pin.y )
        end
    end
```

The pinManager has only one method: CreatePin( pinType, pinTag, xLoc, yLoc )

* `pinType` the pinType the created pin belongs to
* `pinTag` an unique identifier for the pin. You can pass additional attributes to the pin via the pinTag, which can later be used (see layout for more information).
* `xLoc, yLoc` position of the pin in normalized map coordinates. (0,0 = topleft, 1,1 = bottomright)


### The layout table

The layout table must have the following keys:

* `maxDistance` the maximal distance (in normalized map units) for the pin to be visible (it will slowly fade out, when the pin gets close to the maxDistance)
* `texture` the filepath to the texture

#### optional keys:

* `FOV` the field of view in radians. eg 2pi will result in the pin being always visible, pi means the pin is visible as long it is not behind the player.
* `sizeCallback` a function which receives the pin, the angle between the player and the pin, the normalized angle (-1 = left border of the compass, 1 = right border of the compass, 0 = center of the compass), normalizedDistance (0 = same position as player, 1 = pin is at maxDistance)
This function can modify the size of the pin via pin:SetDimension(width, height)
If no function is given, the pin has a size of 32x32 and will become smaller if abs(normalizedAngle) > 0.25
* `additionalLayout` another table with 2 components, each one needs to be a function.
The first one receives the same parameters as the sizeCallback function. It can be used to implement additional visual effects. eg: you could do something like pin:SetColor(1,0,0,1) to make the pin red.
The second function receives only a pin as parameter. As the pins are pooled (saved to be used again), the additional modifications of the pin need to be cleared again. So in the previous example this function should call pin:SetColor(1,1,1,1) to make the pin white again.

## The pin object:

a pin has the following attributes:

* `pin.xLoc` x coordinate
* `pin.yLoc` y coordinate
* `pin.pinType` the pinType
* `pin.pinTag` the pinTag

As the pin is the first given parameter in the layout callback functions, you can pass any data to these functions via the pinTag (eg an alternate texture that is different from the one specified in the layout table)

## important functions

* `pin:SetAlpha(value)` 1 = pin is opaque, 0 = pin is transparent. Usefull for fadeout effects.
* `pin:SetHidden(bool)` if bool is true, the pin is invisible
* `pin:SetDimensions(width, height)` sets the width and height of the pin (usefull if you want to implement your own a zoom effect near the border or something like that)
* `pin:SetColor(r, g, b, a)` changes the pins color. you can create some kind of highlighting effect with this.
* `pin:GetNamedChild( "Background" )` returns the texture control.
