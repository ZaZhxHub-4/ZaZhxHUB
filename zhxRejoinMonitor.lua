-- // Secure PS + Heartbeat via HTTP (request/syn.request) + Debug
local Players = game:GetService("Players")
local HS = game:GetService("HttpService") -- untuk JSONEncode saja
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local USERNAME = LP.Name
local APK_IP = "127.0.0.1"

-- Baca IP APK dari file (ditulis APK di workspace Delta)
pcall(function()
    local ipFile = "/storage/emulated/0/Delta/Workspace/zhx_apk_ip.txt"
    if isfile and isfile(ipFile) then
        local ip = readfile(ipFile):gsub("%s+", "")
        if ip ~= "" then APK_IP = ip end
    end
end)

local APK_URL = "http://" .. APK_IP .. ":8080/report"

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

-- Kirim sinyal ke APK (gunakan request / syn.request)
local function sendToAPK(action)
    local body = HS:JSONEncode({ username = USERNAME, action = action })
    local ok = false
    local errMsg = ""

    -- Coba gunakan syn.request (Delta)
    if syn and syn.request then
        local success, result = pcall(function()
            syn.request({
                Url = APK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)
        if success then
            ok = true
        else
            errMsg = "syn.request error: " .. tostring(result)
        end
    end

    -- Fallback: request global (beberapa executor menyediakan ini)
    if not ok and request then
        local success, result = pcall(function()
            request({
                Url = APK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)
        if success then
            ok = true
        else
            errMsg = "request error: " .. tostring(result)
        end
    end

    -- Fallback terakhir: HttpService (biasanya gagal)
    if not ok then
        local success, result = pcall(function()
            HS:PostAsync(APK_URL, body)
        end)
        if success then
            ok = true
        else
            errMsg = "HttpService error: " .. tostring(result)
        end
    end

    -- Tulis debug ke file
    local debugMsg = ok and (action .. " OK") or (action .. " GAGAL: " .. errMsg)
    pcall(function()
        writefile("zhx_http_status.txt", os.date("%H:%M:%S") .. " | " .. debugMsg)
    end)
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

-- Heartbeat loop (30 detik)
task.spawn(function()
    while true do
        sendToAPK("heartbeat")
        updateUI("🟢 Online", Color3.fromRGB(72,210,130))
        task.wait(30)
    end
end)

-- Cek intruder loop (5 detik)
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
