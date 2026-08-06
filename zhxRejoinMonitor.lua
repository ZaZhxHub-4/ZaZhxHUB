-- // Secure PS + Heartbeat via File (Counter Based) - Minimal UI Draggable
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local USERNAME = LP.Name
local heartbeatCounter = 0

-- Whitelist
local WHITELIST = {
    "z4a4a4", "esmeralda888509", "zazhx4", "zazhx14",
    "ucupps01", "ucupps03", "lohlohloh404", "lohlohloh505",
    "pegawaixruby", "rubyxesmeraldo", "zzzhxxx2", "zzzhxxx10",
    "zzzhxxx13", "zzzhxxx8", "zzzhxxx15", "zaazhx14",
    "warungevo_tb", "tagxgudang", "lahlahlah55555",
    "lohlohloh3030", "cashew_404", "queendstr", "baygonz89", "tagxall"
}

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
    writeSignal(USERNAME .. "_hb.txt", tostring(heartbeatCounter))
end

local function sendKickSignal()
    writeSignal(USERNAME .. "_kick.txt", "kick")
end

local function checkPlayers()
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

    -- Drag functionality
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
