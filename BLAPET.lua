-- // ZHX Smart Fishing v6.3 — Two-Column UI + Save/Load Config
-- // Blapet Method (Final Fix) dengan konfigurasi persisten

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

-- ========== KONFIGURASI DEFAULT ==========
local config = {
    reelDelay      = 4,
    loopInterval   = 0.15,
    timingTrigger  = 4,
    petBugInterval = 70,
    toggleCount    = 700,
    blapetCycles     = 4,
    blapetStuckTime  = 15,
    blapetFinalStuck = 60,
    blapetIntervalHours = 5,
}

-- State
local fastReelActive = false
local petBugActive   = false
local blapetActive   = false
local fastReelPaused = false
local lastPetBugTime = 0
local chargeStartTime = 0
local fastReelThread = nil
local blapetThread   = nil

-- ========== SAVE / LOAD CONFIG ==========
local CONFIG_FOLDER = "ZHX_Configs"
local CONFIG_FILE   = CONFIG_FOLDER .. "/FastReelConfig.json"
local inputBoxes = {}  -- [key] = TextBox

local function ensureFolder()
    if not isfolder or not makefolder then return false end
    if not isfolder(CONFIG_FOLDER) then
        pcall(function() makefolder(CONFIG_FOLDER) end)
    end
    return isfolder(CONFIG_FOLDER)
end

local function saveConfig()
    if not writefile or not ensureFolder() then
        print("Save gagal: executor tidak support writefile.")
        return
    end
    pcall(function()
        writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(config))
        print("✅ Config disimpan.")
    end)
end

local function loadConfig()
    if not readfile or not isfile or not isfile(CONFIG_FILE) then
        return
    end
    pcall(function()
        local data = game:GetService("HttpService"):JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(data) do
            if config[k] ~= nil then
                config[k] = v
            end
        end
        -- Update UI input boxes
        for k, box in pairs(inputBoxes) do
            if config[k] ~= nil then
                box.Text = tostring(config[k])
            end
        end
        print("✅ Config dimuat otomatis.")
    end)
end

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

-- ========== PET BUG TRIGGER ==========
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

-- ========== FAST REEL CYCLE ==========
local function fastReelCycle()
    if fastReelPaused then return end
    pcall(function() chargeRF:InvokeServer(1755848498.4834) end)
    chargeStartTime = tick()
    pcall(function() minigameRF:InvokeServer(1.2854545116425, 1) end)

    if petBugActive and not blapetActive then
        local now = tick()
        if now - lastPetBugTime >= config.petBugInterval then
            task.spawn(function()
                local elapsed = tick() - chargeStartTime
                local waitTime = math.max(0, config.timingTrigger - elapsed)
                if waitTime > 0 then task.wait(waitTime) end
                if fastReelActive and petBugActive then
                    triggerPetBug()
                    lastPetBugTime = tick()
                end
            end)
        end
    end

    local elapsed = tick() - chargeStartTime
    local remaining = math.max(0, config.reelDelay - elapsed)
    if remaining > 0 then task.wait(remaining) end
    if not fastReelPaused then
        pcall(function() catchRE:FireServer() end)
    end
end

local function mainLoop()
    while fastReelActive do
        if not fastReelPaused then fastReelCycle() end
        task.wait(0.01)
    end
end

local function startFastReel()
    if fastReelActive then return end
    equipRod()
    task.wait(0.1)
    fastReelActive = true
    fastReelPaused = false
    fastReelThread = task.spawn(mainLoop)
end

local function stopFastReel()
    fastReelActive = false
    fastReelPaused = false
    if fastReelThread then task.cancel(fastReelThread); fastReelThread = nil end
end

-- ========== BLAPET METHOD ==========
local function runBlapetCycle(isLastCycle)
    fastReelPaused = true
    task.wait(0.3)

    petBugActive = false
    task.wait(0.1)
    petBugActive = true
    task.spawn(function() triggerPetBug() end)

    local stuckDuration = isLastCycle and config.blapetFinalStuck or config.blapetStuckTime
    task.wait(stuckDuration)

    petBugActive = false
    fastReelPaused = false
end

local function blapetSession()
    for i = 1, config.blapetCycles do
        if not blapetActive then break end
        local isLast = (i == config.blapetCycles)
        runBlapetCycle(isLast)
        if not isLast then
            local lastCharge = chargeStartTime
            local waited = 0
            while blapetActive and waited < 10 do
                if chargeStartTime > lastCharge then break end
                task.wait(0.1)
                waited = waited + 0.1
            end
        end
    end
end

local function startBlapet()
    if blapetActive then return end
    blapetActive = true
    blapetThread = task.spawn(function()
        while blapetActive do
            blapetSession()
            local waitTime = config.blapetIntervalHours * 3600
            local nextRun = tick() + waitTime
            while blapetActive and tick() < nextRun do
                task.wait(10)
            end
        end
    end)
end

local function stopBlapet()
    blapetActive = false
    fastReelPaused = false
    petBugActive = false
    if blapetThread then task.cancel(blapetThread); blapetThread = nil end
end

-- ========== UI ==========
local pg = LP:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name = "ZHX_SmartFishing_v6.3"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = pg
pcall(function() sg.DisplayOrder = 99999 end)

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
Instance.new("UIStroke", floatBtn).Color = Color3.fromRGB(72, 210, 130)

-- ========== MAIN PANEL (Two-Column) ==========
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 370, 0, 230)  -- lebih lebar, lebih pendek
frame.Position = UDim2.new(1, -380, 1, -240)
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

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Text = "⚡ Smart Fishing v6.3"
title.TextColor3 = Color3.fromRGB(72, 210, 130)
title.TextSize = 12
title.Font = Enum.Font.GothamBold
title.ZIndex = 101
title.Parent = frame

-- Helper functions
local function makeInput(x, y, label, default, callback, configKey)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 80, 0, 20)
    lbl.Position = UDim2.new(0, x, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200,200,200)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.ZIndex = 101
    lbl.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 55, 0, 20)
    box.Position = UDim2.new(0, x+85, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(30,30,40)
    box.BorderSizePixel = 0
    box.Text = tostring(default)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.TextSize = 10
    box.Font = Enum.Font.Gotham
    box.ZIndex = 101
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,4)

    if configKey then
        inputBoxes[configKey] = box
    end

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then
            callback(num)
        end
    end)
    return box
end

local function makeToggleButton(x, y, w, text, startFn, stopFn, getActiveFn)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, w, 0, 26)
    btn.Position = UDim2.new(0, x, 0, y)
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

    local active = false
    btn.MouseButton1Click:Connect(function()
        if active then
            active = false
            btn.Text = "▶ " .. text
            btn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
            if stopFn then stopFn() end
        else
            active = true
            btn.Text = "⏹ " .. text
            btn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
            if startFn then startFn() end
        end
    end)
    -- sinkronisasi state dari luar
    task.spawn(function()
        while true do
            task.wait(0.5)
            local should = getActiveFn and getActiveFn()
            if should ~= active then
                active = should
                if active then
                    btn.Text = "⏹ " .. text
                    btn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
                else
                    btn.Text = "▶ " .. text
                    btn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
                end
            end
        end
    end)
    return btn
end

-- ========== LAYOUT ==========
local leftX = 10
local rightX = 195
local yStart = 32
local rowH = 24

-- Kolom Kiri: Fast Reel
makeInput(leftX, yStart, "Reel Delay", config.reelDelay, function(v) config.reelDelay = v end, "reelDelay")
makeInput(leftX, yStart+rowH, "Loop Interval", config.loopInterval, function(v) config.loopInterval = v end, "loopInterval")
makeInput(leftX, yStart+rowH*2, "Timing Trigger", config.timingTrigger, function(v) config.timingTrigger = v end, "timingTrigger")

makeToggleButton(leftX, yStart+rowH*3+2, 160, "Fast Reel",
    startFastReel, stopFastReel,
    function() return fastReelActive end
)

-- Kolom Kanan: Pet Bug + Blapet
local ry = yStart
makeInput(rightX, ry, "Pet Bug Interval", config.petBugInterval, function(v) config.petBugInterval = math.max(10, v) end, "petBugInterval")
ry = ry + rowH
makeInput(rightX, ry, "Toggle Count", config.toggleCount, function(v) config.toggleCount = math.max(1, math.floor(v)) end, "toggleCount")
ry = ry + rowH
makeToggleButton(rightX, ry+2, 160, "Pet Bug (Smart)",
    function() petBugActive = true; lastPetBugTime = 0 end,
    function() petBugActive = false end,
    function() return petBugActive end
)

ry = ry + rowH + 8
makeInput(rightX, ry, "Blapet Cycles", config.blapetCycles, function(v) config.blapetCycles = math.max(1, math.floor(v)) end, "blapetCycles")
ry = ry + rowH
makeInput(rightX, ry, "Stuck Time (s)", config.blapetStuckTime, function(v) config.blapetStuckTime = math.max(5, v) end, "blapetStuckTime")
ry = ry + rowH
makeInput(rightX, ry, "Final Stuck (s)", config.blapetFinalStuck, function(v) config.blapetFinalStuck = math.max(30, v) end, "blapetFinalStuck")
ry = ry + rowH
makeInput(rightX, ry, "Interval (jam)", config.blapetIntervalHours, function(v) config.blapetIntervalHours = math.max(0.5, v) end, "blapetIntervalHours")
ry = ry + rowH
makeToggleButton(rightX, ry+2, 160, "Blapet (Auto)",
    startBlapet, stopBlapet,
    function() return blapetActive end
)

-- Tombol Save Config (di bawah panel, full width)
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, -20, 0, 28)
saveBtn.Position = UDim2.new(0, 10, 1, -32)
saveBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 80)
saveBtn.BorderSizePixel = 0
saveBtn.Text = "💾 Save Config"
saveBtn.TextColor3 = Color3.fromRGB(130, 180, 255)
saveBtn.TextSize = 11
saveBtn.Font = Enum.Font.GothamBold
saveBtn.ZIndex = 101
saveBtn.AutoButtonColor = false
saveBtn.Parent = frame
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0,5)

saveBtn.MouseButton1Click:Connect(function()
    saveConfig()
    -- Notifikasi kecil: ubah teks sementara
    saveBtn.Text = "✅ Tersimpan!"
    task.wait(2)
    saveBtn.Text = "💾 Save Config"
end)

-- ========== LOAD CONFIG SAAT STARTUP ==========
loadConfig()

-- ========== DRAG FUNCTIONS ==========
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

print("v6.3: ZHX BEKASI PRIDE.")
