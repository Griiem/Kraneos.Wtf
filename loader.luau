local HttpService = game:GetService("HttpService")

local _version = "1.6.66"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. _version .. "/main.lua"))()

local OWNER = "Griiem"
local REPO = "Kraneos.Wtf"
local BRANCH = "main"

local RAW_URL = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(OWNER, REPO, BRANCH)
local API_URL = ("https://api.github.com/repos/%s/%s/contents/tabs/"):format(OWNER, REPO)

local games = loadstring(game:HttpGet(RAW_URL .. "games.luau"))()

local gameFolder
for name, id in pairs(games) do
    if game.PlaceId == id or game.GameId == id then
        gameFolder = name
        break
    end
end

if not gameFolder then
    WindUI:Notify({
        Title = "Kraneos",
        Content = "Esse jogo não é suportado.",
        Icon = "x",
        Duration = 5,
    })
    return
end

local Window = WindUI:CreateWindow({
    Title = "",
    Icon = "stone",
    Author = nil,
    Folder = "Kraneos",
    ToggleKey = Enum.KeyCode.L,
    Size = UDim2.fromScale(.26, .19),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(900, 900),
    Transparent = true,
    Theme = "Plant",
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    BackgroundImageTransparency = 1,
    Background = "8508980536",
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Button",
                Content = "No function yet",
                Icon = "user",
                Duration = 3,
            })
        end,
    },
})

Window:Tag({
    Title = "v0.0.1",
    Icon = "rocket",
    Color = Color3.fromHex("#89fa98"),
    Radius = 6.333,
})

Window:Tag({
    Title = "夢",
    Color = Color3.fromHex("#b5c242"),
    Radius = 13,
})

local TABS_URL = RAW_URL .. "tabs/" .. gameFolder .. "/"

local function loadTab(name)
    local url = TABS_URL .. name .. ".luau"

    local success, err = pcall(function()
        local source = game:HttpGet(url)
        assert(source and #source > 0, "Empty source")

        local chunk, compileError = loadstring(source)
        assert(chunk, compileError or "Compilation failed")

        local setup = chunk()

        assert(
            type(setup) == "function",
            "Tab must return a function"
        )

        setup(Window, WindUI)
    end)

    if not success then
        warn("[Kraneos] Failed to load tab '" .. name .. "': " .. tostring(err))
        return false
    end

    return true
end

local listed, files = pcall(function()
    return HttpService:JSONDecode(game:HttpGet(API_URL .. gameFolder .. "?ref=" .. BRANCH))
end)

if not listed or type(files) ~= "table" then
    WindUI:Notify({
        Title = "Kraneos",
        Content = "Não consegui listar as tabs de " .. gameFolder .. ".",
        Icon = "x",
        Duration = 5,
    })
    return
end

table.sort(files, function(a, b)
    return a.name < b.name
end)

for _, file in ipairs(files) do
    if file.type == "file" then
        local tabName = file.name:match("^(.+)%.luau$")
        if tabName then
            loadTab(tabName)
        end
    end
end

print("[Wtf.Warning] Loaded...")
