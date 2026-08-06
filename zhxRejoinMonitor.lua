-- // Secure PS + Heartbeat via HTTP + Debug Log
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local USERNAME = LP.Name
local APK_IP = "127.0.0.1"
local DEBUG_FILE = "/storage/emulated/0/zhx_heartbeat_debug.txt"

-- Fungsi menulis debug ke file
local function debugLog(msg)
    pcall(function()
        local f = io.open(DEBUG_FILE, "a")
        if f then
            f:write(os.date("%H:%M:%S") .. " | " .. LP.Name .. " | " .. msg .. "\n")
            f:close()
        end
    end)
end

-- Baca IP APK dari file
pcall(function()
    local ipFile = "/storage/emulated/0/zhx_apk_ip.txt"
    if isfile and isfile(ipFile) then
        local ip = readfile(ipFile):gsub("%s+", "")
        if ip ~= "" then APK_IP = ip end
    end
end)

local APK_URL = "http://" .. APK_IP .. ":8080/report"
debugLog("IP APK: " .. APK_IP)
debugLog("URL: " .. APK_URL)

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

local function sendToAPK(action)
    local success, err = pcall(function()
        HttpService:PostAsync(APK_URL, HttpService:JSONEncode({
            username = USERNAME,
            action = action
        }))
    end)
    if success then
        debugLog("✅ " .. action .. " terkirim")
    else
        debugLog("❌ Gagal kirim " .. action .. ": " .. tostring(err))
    end
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

-- Heartbeat loop
task.spawn(function()
    while true do
        sendToAPK("heartbeat")
        updateUI("🟢 Online", Color3.fromRGB(72,210,130))
        task.wait(30)
    end
end)

-- Cek intruder loop
task.spawn(function()
    while true do
        local safe, intruder = checkPlayers()
        if not safe then
            updateUI("🔴 " .. intruder .. "!", Color3.fromRGB(255,100,100))
            sendToAPK("kick")
            task.wait(2)
            pcall(function()
                LP:Kick("Proses pengamanan aktif! (" .. intruder .. ")")
            end)
        end
        task.wait(5)
    end
end)
