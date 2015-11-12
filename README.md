#### Lama Usage:

```lua
if not lama then --check if the api is loaded.  Bad things happen if it is.
  os.loadAPI( "lama" ) --load the api
  lama.overwrite() --overwrite _G.turtle, will overwrite a table instead if given one
end

--use turtle commands normally, _G.turtle has been overwritten

--Get the position of the turtle
local x, y, z, facing = lama.getPosition() 

--Set the position of the turtle (facing is optional)
lama.setPosition( x, y, z[, facing] )
```
#### For more information:
https://github.com/lupus590/CC-Hive/wiki/Lama
