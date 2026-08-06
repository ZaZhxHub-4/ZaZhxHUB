-- // Secure PS + Heartbeat via File (Workspace Delta)
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local USERNAME = LP.Name
local HEARTBEAT_DIR = "/storage/emulated/0/Delta/Workspace/zhx_heartbeat/"
local DEBUG_FILE = "zhx_hb_debug.txt"

-- Fungsi debug ke file terpisah
local function debugLog(msg)
    pcall(function()
        writefile(DEBUG_FILE, os.date("%H:%M:%S") .. " | " .. msg .. "\n")
    end)
end

-- Whitelist
local WHITELIST = {
    "z4a4a4", "esmeralda888509", "zazhx4", "zazhx14",
    "ucupps01", "ucupps03", "lohlohloh404", "lohlohloh505",
    "pegawaixruby", "rubyxesmeraldo", "zzzhxxx2", "zzzhxxx10",
    "zzzhxxx13", "zzzhxxx8", "zzzhxxx15", "zaazhx14",
    "warungevo_tb", "tagxgudang", "lahlahlah55555",
    "lohlohloh3030", "cashew_404", "queendstr", "baygonz89"
}

local function isWhitelisted(username)
    local lower = username:lower()
    for _, w in ipairs(WHITELIST) do
        if w == lower then return true end
    end
    return false
end

-- Menulis sinyal ke file
local function writeSignal(filename, content)
    local path = HEARTBEAT_DIR .. filename
    pcall(function()
        writefile(path, content)
    end)
end

local function sendHeartbeat()
    writeSignal(USERNAME .. "_hb.txt", tostring(tick()))
end

local function sendKickSignal()
    writeSignal(USERNAME .. "_kick.txt", "kick")
    debugLog("Sinyal KICK ditulis")
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

-- UI kecil
local statusText = nil
local function updateUI(text, color)
    if statusText then
        statusText.Text = text
        statusText.TextColor3 = color or Color3.fromRGB(255,255,255)
    end
end

local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SecurePS_UI"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 30)
    frame.Position = UDim2.new(1, -230, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30,40,30)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)

    statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1,-8,1,0)
    statusText.Position = UDim2.new(0,4,0,0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "🟢 Online"
    statusText.TextColor3 = Color3.fromRGB(72,210,130)
    statusText.Font = Enum.Font.GothamBold
    statusText.TextSize = 12
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = frame
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
