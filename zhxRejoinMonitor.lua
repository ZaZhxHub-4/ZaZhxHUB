-- // ZHX Rejoiner Monitor - PUBLIC (Whitelist dari APK)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local USERNAME = LP.Name
local heartbeatCounter = 0

-- Folder workspace global (sama dengan APK)
local WORKSPACE = "/storage/emulated/0/Delta/Workspace/"
local VERIFICATION_FILE = WORKSPACE .. "zhx_verified"
local WHITELIST_FILE = WORKSPACE .. "whitelist_config.txt"

-- Pastikan folder workspace ada
pcall(function() makefolder(WORKSPACE) end)

-- Load whitelist dari file (hanya baca)
local function loadWhitelist()
    local list = {}
    pcall(function()
        if isfile(WHITELIST_FILE) then
            local content = readfile(WHITELIST_FILE)
            for name in content:gmatch("[^\r\n]+") do
                name = name:gsub("%s+", "")
                if name ~= "" then
                    table.insert(list, name:lower())
                end
            end
        end
    end)
    return list
end

local WHITELIST = loadWhitelist()

local function isWhitelisted(username)
    local lower = username:lower()
    for _, w in ipairs(WHITELIST) do
        if w == lower then return true end
    end
    return false
end

local function writeSignal(filename, content)
    pcall(function() writefile(filename, content) end)
end

local function sendHeartbeat()
    heartbeatCounter = heartbeatCounter + 1
    writeSignal(WORKSPACE .. USERNAME .. "_hb.txt", tostring(heartbeatCounter))
end

local function sendKickSignal()
    writeSignal(WORKSPACE .. USERNAME .. "_kick.txt", "kick")
end

local function checkPlayers()
    if #WHITELIST == 0 then return true, nil end
    local players = Players:GetPlayers()
    for _, player in ipairs(players) do
        if player ~= LP and not isWhitelisted(player.Name) then
            return false, player.Name
        end
    end
    return true, nil
end

-- UI kecil & draggable
local uiButton = nil
local function updateUI(text, color)
    if uiButton then
        uiButton.Text = text
        uiButton.TextColor3 = color or Color3.fromRGB(255,255,255)
    end
end

local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SecurePS_UI"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    uiButton = Instance.new("TextButton")
    uiButton.Size = UDim2.new(0, 120, 0, 22)
    uiButton.Position = UDim2.new(1, -130, 0, 10)
    uiButton.BackgroundColor3 = Color3.fromRGB(30,40,30)
    uiButton.BorderSizePixel = 0
    uiButton.Text = "🟢 Online"
    uiButton.TextColor3 = Color3.fromRGB(72,210,130)
    uiButton.Font = Enum.Font.GothamBold
    uiButton.TextSize = 11
    uiButton.AutoButtonColor = false
    uiButton.Parent = gui
    Instance.new("UICorner", uiButton).CornerRadius = UDim.new(0,6)

    local dragging, dragStart, startPos = false, nil, nil
    uiButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = uiButton.Position
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            uiButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

buildUI()

-- Heartbeat loop (10 detik)
task.spawn(function()
    while true do
        sendHeartbeat()
        updateUI("🟢 Online", Color3.fromRGB(72,210,130))
        task.wait(10)
    end
end)

-- Cek intruder loop (5 detik)
task.spawn(function()
    while true do
        local safe, intruder = checkPlayers()
        if not safe then
            updateUI("🔴 " .. intruder .. "!", Color3.fromRGB(255,100,100))
            sendKickSignal()
            task.wait(2)
            pcall(function()
                LP:Kick("Proses pengamanan aktif! (" .. intruder .. ")")
            end)
        end
        task.wait(5)
    end
end)

-- ============ VERIFICATION FILE ============
pcall(function()
    if not isfile(VERIFICATION_FILE) then
        writefile(VERIFICATION_FILE, "verified")
    end
end)
