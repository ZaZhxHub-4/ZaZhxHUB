task.wait(8)

-- // ZHX Rejoiner Monitor - PUBLIC + PANDA AUTH VALIDATION + MULTI EXECUTOR
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG DETEKSI ERROR PROMPT
-- true  = aktif
-- false = nonaktif sementara (jika terjadi false positive)
-- ============================================================
local ENABLE_ERROR_DETECTION = true

local ServiceID = "zhxrejoiner"
local key = getgenv().Key

if not key or key == "" then
    LP:Kick("Key tidak ditemukan. Gunakan loader dari panel premium.")
    return
end

-- Deteksi executor (hanya untuk info)
local executorName = "delta"
pcall(function()
    local detected = identifyexecutor()
    if detected and type(detected) == "string" then
        executorName = detected:lower()
    end
end)

-- Path file cukup nama file saja.
-- Delta & Lime sama-sama membaca dari workspace default masing-masing.
local function resolvePath(filename)
    return filename
end

local function readHwidFromFile()
    local target = resolvePath("zhxhwid.txt")
    local ok, content = pcall(readfile, target)
    if ok and content then
        content = content:gsub("%s+", "")
        if content ~= "" then
            return content
        end
    end
    return nil
end

local HWID = readHwidFromFile()

if not HWID or HWID == "" then
    LP:Kick("HWID tidak ditemukan. Pastikan APK ZHX Rejoiner sudah teraktivasi.")
    return
end

local fetch = request or http_request or (syn and syn.request)
if not fetch then
    LP:Kick("Executor tidak mendukung HTTP Request.")
    return
end

-- Fungsi validasi
-- Return:
--   true  = valid
--   false = invalid / expired / hwid mismatch / key salah
--   nil   = error / timeout / gagal request / gagal decode
local function validateKey(k)
    local bodyData = {
        ServiceID = ServiceID,
        HWID = HWID,
        Key = k
    }
    local jsonBody = HttpService:JSONEncode(bodyData)

    local ok, response = pcall(fetch, {
        Url = "https://api.pandauth.com/api/v1/keys/validate",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = jsonBody
    })

    if not ok or not response or not response.Body then
        return nil
    end

    local okDecode, result = pcall(HttpService.JSONDecode, HttpService, response.Body)

    if not okDecode or type(result) ~= "table" then
        return nil
    end

    if result.Authenticated_Status == "Success" then
        return true
    end

    return false
end

-- Validasi awal, retry terus jika error
while true do
    local status = validateKey(key)

    if status == true then
        break
    elseif status == false then
        LP:Kick("ZHX HUB REJOINER INVALID HWID")
        return
    else
        task.wait(15)
    end
end

-- ============ BAGIAN MONITORING PUBLIC ============

local USERNAME = LP.Name
local heartbeatCounter = 0

local WHITELIST = {}
pcall(function()
    local target = resolvePath("whitelist_config.txt")
    if isfile(target) then
        local content = readfile(target)
        for name in content:gmatch("[^\r\n]+") do
            name = name:gsub("%s+", "")
            if name ~= "" then
                table.insert(WHITELIST, name:lower())
            end
        end
    end
end)

local function isWhitelisted(username)
    local lower = username:lower()
    for _, w in ipairs(WHITELIST) do
        if w == lower then return true end
    end
    return false
end

local function writeSignal(filename, content)
    pcall(function()
        writefile(resolvePath(filename), content)
    end)
end

local function sendHeartbeat()
    heartbeatCounter = heartbeatCounter + 1
    writeSignal(USERNAME .. "_hb.txt", tostring(heartbeatCounter))
end

local function sendKickSignal()
    writeSignal(USERNAME .. "_kick.txt", "kick")
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

-- Heartbeat loop (15 detik)
task.spawn(function()
    while true do
        sendHeartbeat()
        updateUI("🟢 Online", Color3.fromRGB(72,210,130))
        task.wait(15)
    end
end)

-- Periodic license check (10 menit + jitter acak)
task.spawn(function()
    while true do
        task.wait(600 + math.random(0, 30))

        local status = validateKey(key)
        local retryCount = 0

        while status == nil and retryCount < 3 do
            task.wait(15)
            status = validateKey(key)
            retryCount = retryCount + 1
        end

        if status == false then
            LP:Kick("ZHX HUB REJOINER INVALID HWID")
        elseif status == true then
            updateUI("🟢 Online", Color3.fromRGB(72,210,130))
        end
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
                LP:Kick("Proses pengaman aktif! -ZHX REJOINER-")
            end)
        end
        task.wait(5)
    end
end)

-- Deteksi error prompt Roblox (CoreGui), hanya 277 & 278, tiap 25 detik
task.spawn(function()
    if not ENABLE_ERROR_DETECTION then
        return
    end

    local errorKeywords = {
        "error", "kesalahan",
        "kode", "code",
        "koneksi", "connection",
        "terputus", "disconnect", "disconnected",
        "tidak aktif", "idle",
        "dikeluarkan", "dilarang", "kicked", "banned"
    }

    local function hasErrorKeyword(text)
        local lower = text:lower()
        for _, word in ipairs(errorKeywords) do
            if lower:find(word, 1, true) then
                return true
            end
        end
        return false
    end

    local function hasAllowedErrorCode(text)
        return text:find("277", 1, true) ~= nil or text:find("278", 1, true) ~= nil
    end

    local sentSignal = false

    while ENABLE_ERROR_DETECTION do
        local foundError = false

        pcall(function()
            local coreGui = game:GetService("CoreGui")
            for _, obj in ipairs(coreGui:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local txt = obj.Text or ""
                    if hasErrorKeyword(txt) and hasAllowedErrorCode(txt) then
                        foundError = true
                        break
                    end
                end
            end
        end)

        if foundError then
            if not sentSignal then
                sendKickSignal()
                updateUI("🔴 Error Code!", Color3.fromRGB(255,100,100))
                sentSignal = true
            end
        else
            sentSignal = false
        end

        task.wait(25)
    end
end)
