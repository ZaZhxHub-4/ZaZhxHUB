-- // ZHX Smart Fishing v6.0 — Blapet (Blatant Pet) Automated Method
-- // Remote hash finder, compact UI, fully automated Blapet cycle
-- // Pet Bug trigger tanpa mengganggu Fast Reel, dengan metode Stuck Charge

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ========== REMOTE HASH FINDER ==========
local function findRemoteByLabel(label)
    local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
    local children = net:GetChildren()
    for i, child in ipairs(children) do
        if child.Name == label then
            local inside = child:FindFirstChildOfClass("RemoteFunction") or child:FindFirstChildOfClass("RemoteEvent")
            if inside then
                local h = inside.Name:match("^R[FE]/([a-fA-F0-9]+)$")
                if h and #h == 64 then return inside end
            end
            local nxt = children[i+1]
            if nxt and (nxt:IsA("RemoteFunction") or nxt:IsA("RemoteEvent")) then
                local h = nxt.Name:match("^R[FE]/([a-fA-F0-9]+)$")
                if h and #h == 64 then return nxt end
            end
            break
        end
    end
    return nil
end

local chargeRF    = findRemoteByLabel("RF/ChargeFishingRod")
local minigameRF  = findRemoteByLabel("RF/RequestFishingMinigameStarted")
local catchRE     = findRemoteByLabel("RE/CatchFishCompleted") or findRemoteByLabel("RE/FishCaught")
local equipRE     = findRemoteByLabel("RE/EquipToolFromHotbar")
local autoStateRF = findRemoteByLabel("RF/UpdateAutoFishingState")
local markAutoRF  = findRemoteByLabel("RF/MarkAutoFishingUsed")

if not chargeRF or not minigameRF or not catchRE then
    error("Remote inti tidak ditemukan.")
end

-- ========== KONFIGURASI ==========
local config = {
    fastReelActive = false,
    reelDelay      = 2.6,
    loopInterval   = 0.15,

    petBugActive   = false,
    petBugInterval = 70,        -- detik antar trigger normal (tidak dipakai di Blapet)
    timingTrigger  = 2.6,
    toggleCount    = 700,       -- jumlah siklus ON-OFF per trigger

    -- Blapet
    blapetActive   = false,
    blapetCycles   = 4,         -- berapa kali stuck-charge per sesi
    blapetIntervalHours = 5,    -- ulang metode setiap berapa jam
    blapetNextRun  = 0,         -- timestamp berikutnya

    -- Internal
    lastPetBugTime = 0,
    chargeStartTime = 0,
    fastReelPaused = false,
}

local fastReelThread = nil
local blapetThread = nil

-- ========== EQUIP ROD ==========
local function equipRod()
    if equipRE then
        pcall(function() equipRE:FireServer(1) end)
    else
        local hotbar = LP.PlayerGui:FindFirstChild("Backpack")
        if hotbar then
            local slot1 = hotbar:FindFirstChild("1") or hotbar:FindFirstChild("Slot1")
            if slot1 and slot1:IsA("ImageButton") then
                pcall(function()
                    local pos = slot1.AbsolutePosition + slot1.AbsoluteSize/2
                    firesignal(UIS.InputBegan, {UserInputType = Enum.UserInputType.MouseButton1, Position = pos})
                    firesignal(UIS.InputEnded, {UserInputType = Enum.UserInputType.MouseButton1, Position = pos})
                end)
            end
        end
    end
end

-- ========== PET BUG TRIGGER (dengan toggleCount) ==========
local function triggerPetBug()
    if not autoStateRF then return end
    pcall(function() autoStateRF:InvokeServer(false) end)
    for _ = 1, config.toggleCount do
        pcall(function() autoStateRF:InvokeServer(true) end)
        task.wait(0.02)
        pcall(function() autoStateRF:InvokeServer(false) end)
        task.wait(0.02)
    end
    if markAutoRF then pcall(function() markAutoRF:InvokeServer() end) end
end

-- ========== FAST REEL CYCLE (dengan pause) ==========
local function fastReelCycle()
    if config.fastReelPaused then return end  -- jangan lakukan apa pun jika pause

    pcall(function() chargeRF:InvokeServer(1755848498.4834) end)
    config.chargeStartTime = tick()
    pcall(function() minigameRF:InvokeServer(1.2854545116425, 1) end)

    -- Pet Bug normal (hanya jika tidak dalam mode Blapet)
    if config.petBugActive and not config.blapetActive then
        local now = tick()
        if now - config.lastPetBugTime >= config.petBugInterval then
            task.spawn(function()
                local elapsed = tick() - config.chargeStartTime
                local waitTime = math.max(0, config.timingTrigger - elapsed)
                if waitTime > 0 then task.wait(waitTime) end
                if config.fastReelActive and config.petBugActive and not config.blapetActive then
                    triggerPetBug()
                    config.lastPetBugTime = tick()
                end
            end)
        end
    end

    local elapsed = tick() - config.chargeStartTime
    local remaining = math.max(0, config.reelDelay - elapsed)
    if remaining > 0 then task.wait(remaining) end

    if not config.fastReelPaused then
        pcall(function() catchRE:FireServer() end)
    end
end

local function mainLoop()
    while config.fastReelActive do
        if not config.fastReelPaused then
            fastReelCycle()
        end
        if config.loopInterval > 0 then task.wait(config.loopInterval) end
        task.wait(0.01) -- beri napas jika pause
    end
end

local function startFastReel()
    if config.fastReelActive then return end
    equipRod()
    task.wait(0.1)
    config.fastReelActive = true
    config.fastReelPaused = false
    fastReelThread = task.spawn(mainLoop)
end

local function stopFastReel()
    config.fastReelActive = false
    config.fastReelPaused = false
    if fastReelThread then task.cancel(fastReelThread); fastReelThread = nil end
end

-- ========== BLAPET METHOD ==========
local function runBlapetCycle()
    -- Satu siklus Blapet: pause Fast Reel, restart Pet Bug, resume
    config.fastReelPaused = true
    task.wait(0.2) -- pastikan berhenti di posisi stuck

    -- Matikan Pet Bug dulu
    local wasPetBugActive = config.petBugActive
    config.petBugActive = false
    task.wait(0.1)

    -- Nyalakan Pet Bug lagi (memulai ulang toggle count yang besar)
    config.petBugActive = true
    -- Trigger langsung, jangan tunggu interval
    task.spawn(function()
        triggerPetBug()
    end)
    -- Tunggu sebentar agar toggle selesai dijalankan (bisa lama karena count besar)
    -- Tapi kita tidak bisa menunggu seluruh 700x selesai, itu akan lama.
    -- Dari pengamatan, yang penting adalah proses ON-OFF sedang berlangsung saat user stuck.
    -- Jadi kita tunggu sedikit (misal 2 detik) lalu resume Fast Reel.
    task.wait(2)  -- memberi waktu beberapa toggle berjalan

    -- Resume Fast Reel
    config.fastReelPaused = false
    -- Setelah resume, user akan menyelesaikan reel, catch, lalu charge lagi.
end

local function blapetSession()
    -- Jalankan beberapa siklus seperti manual: pause, restart pet bug, resume, biarkan sampai charge berikutnya, lalu ulangi
    for i = 1, config.blapetCycles do
        if not config.blapetActive then break end
        runBlapetCycle()
        -- Tunggu sampai user menyelesaikan reel, catch, dan charge lagi (posisi stuck berikutnya)
        -- Kita tidak bisa deteksi presisi, tapi kita bisa perkirakan: reelDelay + loopInterval + sedikit
        -- Setelah resume, fastReelCycle akan charge. Kita ingin pause lagi setelah charge sebelum reel.
        -- Jadi kita tunggu sampai chargeStartTime baru, lalu kita pause sebelum reel.
        -- Caranya: kita tunggu sebentar, lalu pause lagi setelah charge.
        task.wait(0.5) -- tunggu hingga resume dan mulai charge
        -- Sekarang kita loop kecil untuk menunggu charge selesai dan kemudian pause di timing yang tepat
        local waited = 0
        while config.blapetActive and waited < 10 do
            if tick() - config.chargeStartTime > config.timingTrigger * 0.8 then
                -- sudah mendekati waktu reel, pause!
                config.fastReelPaused = true
                break
            end
            task.wait(0.05)
            waited = waited + 0.05
        end
        -- Jika kita keluar karena pause, maka kita sudah di posisi stuck untuk siklus berikutnya.
    end
    -- Setelah selesai semua siklus, matikan Pet Bug dan biarkan Fast Reel normal
    config.petBugActive = false
    config.fastReelPaused = false
end

local function startBlapet()
    if config.blapetActive then return end
    config.blapetActive = true
    blapetThread = task.spawn(function()
        while config.blapetActive do
            blapetSession()
            -- Jadwalkan ulang setelah interval jam
            local waitTime = config.blapetIntervalHours * 3600
            config.blapetNextRun = tick() + waitTime
            -- Kita bisa membiarkan Fast Reel tetap berjalan normal, Pet Bug mati.
            -- Tapi lebih baik kita pause Fast Reel? Tidak, user tetap mancing normal.
            -- Tunggu sampai waktunya
            while config.blapetActive and tick() < config.blapetNextRun do
                task.wait(10)
            end
        end
    end)
end

local function stopBlapet()
    config.blapetActive = false
    config.fastReelPaused = false
    config.petBugActive = false
    if blapetThread then task.cancel(blapetThread); blapetThread = nil end
end

-- ========== UI ==========
local pg = LP:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name = "ZHX_SmartFishing_v6.0"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = pg
pcall(function() sg.DisplayOrder = 99999 end)

-- === FLOATING BUTTON ===
local floatingGui = Instance.new("ScreenGui")
floatingGui.Name = "ZHX_FloatingBtn"
floatingGui.ResetOnSpawn = false
floatingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
floatingGui.Parent = pg
pcall(function() floatingGui.DisplayOrder = 99998 end)

local floatBtn = Instance.new("ImageButton")
floatBtn.Size = UDim2.new(0, 46, 0, 46)
floatBtn.Position = UDim2.new(0, 12, 0, 100)
floatBtn.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
floatBtn.BorderSizePixel = 0
floatBtn.Image = "rbxassetid://78392602281326"
floatBtn.ScaleType = Enum.ScaleType.Fit
floatBtn.ZIndex = 9999
floatBtn.Parent = floatingGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", floatBtn)
stroke.Color = Color3.fromRGB(72, 210, 130)
stroke.Thickness = 1.5

-- === MAIN PANEL (compact) ===
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 350)  -- lebih tinggi untuk Blapet
frame.Position = UDim2.new(1, -230, 1, -360)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.ZIndex = 9998
frame.Visible = false
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", frame).Color = Color3.fromRGB(72, 210, 130)

floatBtn.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "⚡ Smart Fishing v6.0"
title.TextColor3 = Color3.fromRGB(72, 210, 130)
title.TextSize = 12
title.Font = Enum.Font.GothamBold
title.ZIndex = 101
title.Parent = frame

local function makeInput(y, label, default, callback)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 90, 0, 20)
    lbl.Position = UDim2.new(0, 8, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200,200,200)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.ZIndex = 101
    lbl.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 55, 0, 20)
    box.Position = UDim2.new(0, 105, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(30,30,40)
    box.BorderSizePixel = 0
    box.Text = tostring(default)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.TextSize = 10
    box.Font = Enum.Font.Gotham
    box.ZIndex = 101
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,4)

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then callback(num) end
    end)
    return box
end

local function makeToggleButton(y, text, startFn, stopFn, getActiveFn)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 28)
    btn.Position = UDim2.new(0, 8, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
    btn.BorderSizePixel = 0
    btn.Text = "▶ " .. text
    btn.TextColor3 = Color3.fromRGB(72, 210, 130)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.ZIndex = 101
    btn.AutoButtonColor = false
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)

    btn.MouseButton1Click:Connect(function()
        if getActiveFn() then
            stopFn()
            btn.Text = "▶ " .. text
            btn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
        else
            startFn()
            btn.Text = "⏹ " .. text
            btn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
        end
    end)
    return btn
end

local y = 35
-- Baris 1: Fast Reel settings
makeInput(y, "Reel Delay", config.reelDelay, function(v) config.reelDelay = v end)
y = y + 24
makeInput(y, "Loop Interval", config.loopInterval, function(v) config.loopInterval = v end)
y = y + 24
makeInput(y, "Timing Trigger", config.timingTrigger, function(v) config.timingTrigger = v end)

y = y + 30
makeToggleButton(y, "Fast Reel", startFastReel, stopFastReel, function() return config.fastReelActive end)

-- Baris 2: Pet Bug settings
y = y + 35
makeInput(y, "Pet Bug Interval", config.petBugInterval, function(v) config.petBugInterval = math.max(10, v) end)
y = y + 24
makeInput(y, "Toggle Count", config.toggleCount, function(v) config.toggleCount = math.max(1, math.floor(v)) end)

y = y + 30
makeToggleButton(y, "Pet Bug (Smart)", 
    function() config.petBugActive = true; config.lastPetBugTime = 0 end,
    function() config.petBugActive = false end,
    function() return config.petBugActive end
)

-- Baris 3: Blapet settings
y = y + 35
makeInput(y, "Blapet Cycles", config.blapetCycles, function(v) config.blapetCycles = math.max(1, math.floor(v)) end)
y = y + 24
makeInput(y, "Blapet Interval (jam)", config.blapetIntervalHours, function(v) config.blapetIntervalHours = math.max(0.5, v) end)

y = y + 30
makeToggleButton(y, "Blapet (Auto)", 
    startBlapet,
    stopBlapet,
    function() return config.blapetActive end
)

-- Drag untuk panel utama
local dragging, dragStart, startPos = false, nil, nil
frame.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inp.Position
        startPos = frame.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Drag untuk floating button
local floatDragging, floatDragStart, floatStartPos = false, nil, nil
floatBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        floatDragging = true
        floatDragStart = inp.Position
        floatStartPos = floatBtn.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if floatDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - floatDragStart
        local viewport = workspace.CurrentCamera.ViewportSize
        local newX = math.clamp(floatStartPos.X.Offset + delta.X, 0, viewport.X - 46)
        local newY = math.clamp(floatStartPos.Y.Offset + delta.Y, 0, viewport.Y - 46)
        floatBtn.Position = UDim2.new(0, newX, 0, newY)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        floatDragging = false
    end
end)

print("v6.0 Blapet: Otomatis metode stuck charge + toggle masif.")