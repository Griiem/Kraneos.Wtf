print("aaaa")

return function (Window, WindUI)

local Tab = Window:Tab({
    Title = "Tab Title",
    Icon = "bird",
})

local YourHStack = Tab:HStack()
 
local LeftVStack = YourHStack:VStack()
local RightVStack = YourHStack:VStack()
 
LeftVStack:Button({
    Title = "Click Me",
    Callback = function()
        print("Button clicked")
    end
})

end
