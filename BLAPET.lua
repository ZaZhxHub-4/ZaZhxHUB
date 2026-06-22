-- // ZHXHub Full Project v2.0 — Fix: triggerPetBug identik dengan Blapet Auto v6.5
-- // Perbaikan: panggilan OFF awal + ON-OFF bergantian + MarkAuto digunakan

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HS = game:GetService("HttpService")
local tcs = game:GetService("TextChatService")
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
    error("Remote inti Blapet tidak ditemukan.")
end

-- ========== STATE GLOBAL ==========
local state = {
    blapetConfig = {
        reelDelay = 4, loopInterval = 0.15, timingTrigger = 4,
        petBugInterval = 70, toggleCount = 700,
        blapetCycles = 4, blapetStuckTime = 15, blapetFinalStuck = 60, blapetIntervalHours = 5,
    },
    fastReelActive = false, petBugActive = false, blapetActive = false,
    fastReelPaused = false, lastPetBugTime = 0, chargeStartTime = 0,
    fastReelThread = nil, blapetThread = nil,
    inputBoxes = {},

    isWalking = false, stopRequested = false, noclipConn = nil,
    savedPositions = {}, selectedSavedIndex = nil,
    selectedLocation = nil, selectedLocBtn = nil,
    selectedPlayer = nil, selectedPlayerBtn = nil,
    selectedSavedBtn = nil, saveName = "",
    autoEventActive = false, selectedEvent = "Megalodon Hunt",
    eventMonitorThread = nil, savedUserPosition = nil, isAtEvent = false,

    webhookUrl = "", webhookEnabled = false,
    mutationEnabled = false, joinLeftEnabled = false,
    evolvedEnabled = false, scEnabled = false,
    localPlayerLeaving = false,
}

-- ========== DAFTAR LOKASI ==========
local locations = {
    ["Fisherman Island"] = CFrame.new(258.659760, 18.206026, 2899.733154, 0.255222, 0.000000, 0.966882, -0.000000, 1.000000, -0.000000, -0.966882, -0.000000, 0.255222),
    ["Kohana"] = CFrame.new(-748.334473, 2.744811, 759.022461, 0.015873, 0.000000, 0.999874, 0.000000, 1.000000, -0.000000, -0.999874, 0.000000, 0.015873),
    ["Ocean"] = CFrame.new(122, 5, 2550, 0.669631, -0.637290, 0.381387, 0, 0.513518, 0.858079, -0.742694, -0.574596, 0.343867),
    ["Treasure Room"] = CFrame.new(-3556.727295, -266.274231, -1600.418823, 0.685607, 0.000000, -0.727972, -0.000000, 1.000000, 0.000000, 0.727972, 0.000000, 0.685607),
    ["Coral Reefs"] = CFrame.new(-2762.703857, 4.010764, 2174.476562, -0.679231, -0.000000, -0.733925, -0.000000, 1.000000, -0.000000, 0.733925, -0.000000, -0.679231),
    ["Crater Island"] = CFrame.new(978.970764, 47.517365, 5086.510254, -0.574029, -0.000000, -0.818835, -0.000000, 1.000000, -0.000000, 0.818835, -0.000000, -0.574029),
    ["Copper Canyon"] = CFrame.new(-4179.353027, 8.227109, 500.384735, 0.990358, -0.000000, -0.138529, 0.000000, 1.000000, 0.000000, 0.138529, -0.000000, 0.990358),
    ["Canyon Mines"] = CFrame.new(-4039.090332, -538.592163, 551.931458, 0.754494, -0.000000, -0.656307, 0.000000, 1.000000, -0.000000, 0.656307, -0.000000, 0.754494),
    ["Lava Basin"] = CFrame.new(950.205383, 84.801346, -10198.104492, -0.018971, -0.000000, -0.999820, 0.000000, 1.000000, -0.000000, 0.999820, -0.000000, -0.018971),
    ["Underwater City"] = CFrame.new(-3307.890137, -640.492737, -10507.622070, 0.055548, -0.000000, -0.998456, 0.000000, 1.000000, -0.000000, 0.998456, -0.000000, 0.055548),
    ["Pirate Cove"] = CFrame.new(3409.220459, 4.192971, 3499.211670, 0.663150, -0.000000, 0.748486, 0.000000, 1.000000, 0.000000, -0.748486, -0.000000, 0.663150),
    ["Ancient Ruin"] = CFrame.new(6085.055176, -585.924255, 4635.187500, -0.711615, 0.000000, -0.702570, 0.000000, 1.000000, 0.000000, 0.702570, -0.000000, -0.711615),
    ["Crystal Depths"] = CFrame.new(5735.092285, -901.842957, 15324.312500, -0.999445, -0.000000, -0.033315, -0.000000, 1.000000, -0.000000, 0.033315, 0.000000, -0.999445),
    ["Stingray Shores"] = CFrame.new(-2133.558594, 18.656778, -771.773926, 0.998903, -0.000000, 0.046831, 0.000000, 1.000000, 0.000000, -0.046831, -0.000000, 0.998903),
}

-- ========== SAVE / LOAD ==========
local CONFIG_FOLDER = "ZHX_Configs"
local BLAPET_CONFIG_FILE = CONFIG_FOLDER .. "/FastReelConfig.json"
local SAFEWALK_CONFIG_FILE = CONFIG_FOLDER .. "/SafeWalkSavedPositions.json"

local function ensureFolder()
    if not isfolder or not makefolder then return false end
    if not isfolder(CONFIG_FOLDER) then pcall(function() makefolder(CONFIG_FOLDER) end) end
    return isfolder(CONFIG_FOLDER)
end

local function saveBlapetConfig()
    if not writefile or not ensureFolder() then return end
    pcall(function() writefile(BLAPET_CONFIG_FILE, HS:JSONEncode(state.blapetConfig)) end)
end
local function loadBlapetConfig()
    if not readfile or not isfile or not isfile(BLAPET_CONFIG_FILE) then return end
    pcall(function()
        local data = HS:JSONDecode(readfile(BLAPET_CONFIG_FILE))
        for k, v in pairs(data) do if state.blapetConfig[k] ~= nil then state.blapetConfig[k] = v end end
    end)
end
local function saveSavedPositions()
    if not writefile or not ensureFolder() then return end
    local data = {}
    for _, saved in ipairs(state.savedPositions) do
        local cf = saved.cf
        table.insert(data, {
            name = saved.name, x = cf.X, y = cf.Y, z = cf.Z,
            r00 = cf.RightVector.X, r01 = cf.RightVector.Y, r02 = cf.RightVector.Z,
            r10 = cf.UpVector.X, r11 = cf.UpVector.Y, r12 = cf.UpVector.Z,
            r20 = -cf.LookVector.X, r21 = -cf.LookVector.Y, r22 = -cf.LookVector.Z,
        })
    end
    pcall(function() writefile(SAFEWALK_CONFIG_FILE, HS:JSONEncode(data)) end)
end
local function loadSavedPositions()
    if not readfile or not isfile or not isfile(SAFEWALK_CONFIG_FILE) then return end
    pcall(function()
        local data = HS:JSONDecode(readfile(SAFEWALK_CONFIG_FILE))
        state.savedPositions = {}
        for _, item in ipairs(data) do
            table.insert(state.savedPositions, {
                name = item.name,
                cf = CFrame.new(item.x, item.y, item.z, item.r00, item.r01, item.r02, item.r10, item.r11, item.r12, item.r20, item.r21, item.r22)
            })
        end
    end)
end

-- ========== BLAPET FUNCTIONS (100% IDENTIK DENGAN V6.5) ==========
local function equipRod()
    if equipRE then pcall(function() equipRE:FireServer(1) end)
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

-- INI YANG DIPERBAIKI: triggerPetBug sekarang IDENTIK dengan v6.5
local function triggerPetBug()
    if not autoStateRF then return end
    pcall(function() autoStateRF:InvokeServer(false) end)  -- OFF dulu di awal (PENTING!)
    for _ = 1, state.blapetConfig.toggleCount do
        pcall(function() autoStateRF:InvokeServer(true) end)   -- ON
        task.wait(0.02)
        pcall(function() autoStateRF:InvokeServer(false) end)  -- OFF
        task.wait(0.02)
    end
    if markAutoRF then pcall(function() markAutoRF:InvokeServer() end) end  -- MarkAuto (PENTING!)
end

local function blapetFastReelCycle()
    if state.fastReelPaused then return end
    pcall(function() chargeRF:InvokeServer(1755848498.4834) end)
    state.chargeStartTime = tick()
    pcall(function() minigameRF:InvokeServer(1.2854545116425, 1) end)
    if state.petBugActive and not state.blapetActive then
        local now = tick()
        if now - state.lastPetBugTime >= state.blapetConfig.petBugInterval then
            task.spawn(function()
                local elapsed = tick() - state.chargeStartTime
                local waitTime = math.max(0, state.blapetConfig.timingTrigger - elapsed)
                if waitTime > 0 then task.wait(waitTime) end
                if state.fastReelActive and state.petBugActive then
                    triggerPetBug()
                    state.lastPetBugTime = tick()
                end
            end)
        end
    end
    local elapsed = tick() - state.chargeStartTime
    local remaining = math.max(0, state.blapetConfig.reelDelay - elapsed)
    if remaining > 0 then task.wait(remaining) end
    if not state.fastReelPaused then pcall(function() catchRE:FireServer() end) end
end

local function blapetMainLoop()
    while state.fastReelActive do
        if not state.fastReelPaused then blapetFastReelCycle() end
        task.wait(0.01)
    end
end

local function startFastReel()
    if state.fastReelActive then return end
    equipRod(); task.wait(0.1)
    state.fastReelActive = true; state.fastReelPaused = false
    state.fastReelThread = task.spawn(blapetMainLoop)
end

local function stopFastReel()
    state.fastReelActive = false; state.fastReelPaused = false
    if state.fastReelThread then task.cancel(state.fastReelThread); state.fastReelThread = nil end
end

local function runBlapetCycle(isLastCycle)
    state.fastReelPaused = true; task.wait(0.3)
    state.petBugActive = false; task.wait(0.1)
    state.petBugActive = true; task.spawn(function() triggerPetBug() end)
    local stuckDuration = isLastCycle and state.blapetConfig.blapetFinalStuck or state.blapetConfig.blapetStuckTime
    task.wait(stuckDuration)
    state.petBugActive = false; state.fastReelPaused = false
end

local function blapetSession()
    for i = 1, state.blapetConfig.blapetCycles do
        if not state.blapetActive then break end
        local isLast = (i == state.blapetConfig.blapetCycles)
        runBlapetCycle(isLast)
        if not isLast then
            local lastCharge = state.chargeStartTime; local waited = 0
            while state.blapetActive and waited < 10 do
                if state.chargeStartTime > lastCharge then break end
                task.wait(0.1); waited = waited + 0.1
            end
        end
    end
end

local function startBlapet()
    if state.blapetActive then return end
    state.blapetActive = true
    state.blapetThread = task.spawn(function()
        while state.blapetActive do
            blapetSession()
            local waitTime = state.blapetConfig.blapetIntervalHours * 3600
            local nextRun = tick() + waitTime
            while state.blapetActive and tick() < nextRun do task.wait(10) end
        end
    end)
end

local function stopBlapet()
    state.blapetActive = false; state.fastReelPaused = false; state.petBugActive = false
    if state.blapetThread then task.cancel(state.blapetThread); state.blapetThread = nil end
end

-- ========== SAFE WALK FUNCTIONS ==========
local function enableNoclip()
    if state.noclipConn then return end
    state.noclipConn = RunService.Stepped:Connect(function()
        local char = LP.Character; if not char then return end
        for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then pcall(function() part.CanCollide = false end) end end
    end)
end
local function disableNoclip()
    if state.noclipConn then state.noclipConn:Disconnect(); state.noclipConn = nil end
end
local function protectCharacter()
    local char = LP.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.MaxHealth=1e9; hum.Health=1e9 end); hum.PlatformStand=true end
end
local function unprotectCharacter()
    local char = LP.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.MaxHealth=100; hum.Health=100 end); hum.PlatformStand=false end
end

local function safeWalk(targetCF)
    if state.isWalking then state.stopRequested = true; task.wait(0.1) end
    state.isWalking = true; state.stopRequested = false
    local char = LP.Character; if not char then state.isWalking = false; return end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then state.isWalking = false; return end
    enableNoclip(); protectCharacter()
    local startCF = root.CFrame; local distance = (targetCF.Position - startCF.Position).Magnitude
    local stepSize = 2.5; local steps = math.max(1, math.ceil(distance / stepSize))
    for i = 1, steps do
        if state.stopRequested then break end
        local t = i / steps; local newCF = startCF:Lerp(targetCF, t)
        pcall(function() root.CFrame = newCF; root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero end)
        task.wait(0.03 * (0.9 + math.random() * 0.2))
    end
    if not state.stopRequested then
        pcall(function() root.Anchored = true; root.CFrame = targetCF; task.wait(0.3); root.Anchored = false end)
    end
    unprotectCharacter(); disableNoclip()
    state.isWalking = false; state.stopRequested = false
end

local function stopWalking()
    state.stopRequested = true; state.isWalking = false
    disableNoclip(); unprotectCharacter()
end

-- Auto Event
-- ========== RADAR AUTO EVENT (STRICT MEGALODON HUNT FINAL) ==========
local function getEventPosition(eventName)
    local propsFolder = WS:FindFirstChild("Props")
    if not propsFolder then return nil end

    local eventModel = propsFolder:FindFirstChild(eventName)
    if not eventModel then return nil end

    -- Lapis 1: Cari BasePart yang namanya sama persis dengan event
    -- (Dari scan: "Megalodon Hunt" adalah BasePart di dalam Model > TOP)
    for _, child in ipairs(eventModel:GetDescendants()) do
        if child:IsA("BasePart") and child.Name == eventName then
            return child.Position + Vector3.new(0, 5, 0)
        end
    end

    -- Lapis 2: Cari RotationPoint sebagai fallback
    for _, child in ipairs(eventModel:GetDescendants()) do
        if child:IsA("BasePart") and child.Name == "RotationPoint" then
            return child.Position + Vector3.new(0, 5, 0)
        end
    end

    -- Lapis 3: BasePart apapun yang ada di dalam model
    for _, child in ipairs(eventModel:GetDescendants()) do
        if child:IsA("BasePart") then
            return child.Position + Vector3.new(0, 5, 0)
        end
    end

    return nil
end

local function isEventActive(eventName)
    local propsFolder = WS:FindFirstChild("Props")
    if not propsFolder then return false end
    return propsFolder:FindFirstChild(eventName) ~= nil
end
-- ===============================================================

local function getCurrentUserCFrame()
    local char = LP.Character; if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    return root.CFrame
end
local function lockUserAtPosition()
    local char = LP.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    protectCharacter(); root.Anchored = true; state.isAtEvent = true
end
local function unlockUser()
    local char = LP.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    root.Anchored = false; unprotectCharacter(); state.isAtEvent = false
end
local function returnToSavedPosition()
    -- 1. Lepaskan status lock dari event
    if state.isAtEvent then 
        unlockUser() 
    end
    
    -- 2. Cek apakah ada patokan posisi awal untuk pulang
    if state.savedUserPosition then 
        local homeCF = state.savedUserPosition
        -- RESET patokan langsung di sini agar siap merekam posisi baru di event selanjutnya
        state.savedUserPosition = nil 
        
        -- 3. Jalan pulang ke posisi awal
        safeWalk(homeCF) 
    end
end

local function startAutoEvent()
    if state.autoEventActive then return end
    
    -- Inisialisasi ulang semua state Event saat tombol dinyalakan
    state.autoEventActive = true 
    state.savedUserPosition = nil
    state.isAtEvent = false

    state.eventMonitorThread = task.spawn(function()
        while state.autoEventActive do
            local isEventNow = isEventActive(state.selectedEvent)

            if state.isAtEvent then
                -- FASE 2 (SEDANG DI EVENT): Pantau apakah Megalodon sudah hilang
                if not isEventNow then
                    returnToSavedPosition() -- Jika hilang, langsung jalan pulang
                end
            else
                -- FASE 1 (STANDBY): Pantau apakah Megalodon muncul
                if isEventNow then
                    local pos = getEventPosition(state.selectedEvent)
                    if pos then
                        -- Rekam posisi Standby SAAT INI sebagai patokan pulang
                        if not state.savedUserPosition then 
                            state.savedUserPosition = getCurrentUserCFrame() 
                        end
                        
                        -- Mulai jalan menuju lokasi Megalodon
                        safeWalk(CFrame.new(pos)) 
                        task.wait(0.5)

                        -- VALIDASI PENTING: Cek lagi, pastikan Megalodon belum hilang saat kita tiba di lokasi
                        if isEventActive(state.selectedEvent) and state.autoEventActive then
                            lockUserAtPosition() -- Kunci posisi (Monitor FASE 2)
                        else
                            -- Kalau kita telat sampai dan Megalodon keburu hilang, putar balik!
                            returnToSavedPosition()
                        end
                    end
                end
            end
            
            -- Jeda 3 detik untuk loop Standby / Monitor berikutnya
            task.wait(3 + math.random() * 2)
        end
    end)
end

local function stopAutoEvent()
    state.autoEventActive = false
    returnToSavedPosition()
end

LP.CharacterAdded:Connect(function()
    state.isWalking = false; state.stopRequested = false
    disableNoclip(); unprotectCharacter()
end)

-- ========== WEBHOOK MONITOR FUNCTIONS ==========
local SECRET_URLS = {
    TONGKI1 = "https://discordapp.com/api/webhooks/1508339437010948169/YzAF1dtGM0PJ9LRCmh9zQID713iQ1r6vYwf7lBqNwPIXbDDuPe_uFIQnZZQ-3KlPoTpS",
    TONGKI2 = "https://discordapp.com/api/webhooks/1506044266684743801/PlopEC1wwOyfGQh-3oBQFl67_IPfoNmUYDMvEU_kjvZP6zR6v0BjfMeObTUsxhOUepqg",
}
local function isValidWebhookURL(url)
    if SECRET_URLS[url] then return true end
    return url:match("^https://discord%.com/api/webhooks/%d+/.+$") ~= nil
        or url:match("^https://discordapp%.com/api/webhooks/%d+/.+$") ~= nil
end
local function resolveURL()
    local secret = SECRET_URLS[state.webhookUrl]
    if secret then return secret end
    return state.webhookUrl
end
local function sendWebhookEmbed(embedData)
    local url = resolveURL()
    if url == "" then return end
    local payload = HS:JSONEncode({
        username = "тнР Server Monitor ZA.ZHX тнР",
        embeds = {{ title = embedData.title or "SETORAN KARYAWAN NIH 🐟", color = embedData.color or 1752220, fields = embedData.fields }}
    })
    pcall(function()
        if http_request then http_request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
        elseif syn and syn.request then syn.request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
        else request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload}) end
    end)
end

-- Webhook keyword lists
local mutationKeywords = {
    "FIRE Cute Dumbo","FIRE Shiny Cute Dumbo","FIRE Big Cute Dumbo","FIRE Big Shiny Cute Dumbo",
    "FIRE Sapphyra","FIRE Shiny Sapphyra","FIRE Big Sapphyra","FIRE Big Shiny Sapphyra",
    "FIRE Voidlight Deepfish","FIRE Shiny Voidlight Deepfish","FIRE Big Voidlight Deepfish","FIRE Big Shiny Voidlight Deepfish",
    "FIRE Rainy Dumbo","FIRE Shiny Rainy Dumbo","FIRE Big Rainy Dumbo","FIRE Big Shiny Rainy Dumbo",
    "FIRE Treasure Crab","FIRE Shiny Treasure Crab","FIRE Big Treasure Crab","FIRE Big Shiny Treasure Crab",
    "FIRE Solarflare Koi","FIRE Shiny Solarflare Koi","FIRE Big Solarflare Koi","FIRE Big Shiny Solarflare Koi",
    "GEMSTONE Cute Dumbo","GEMSTONE Shiny Cute Dumbo","GEMSTONE Big Cute Dumbo","GEMSTONE Big Shiny Cute Dumbo",
    "GEMSTONE Sapphyra","GEMSTONE Shiny Sapphyra","GEMSTONE Big Sapphyra","GEMSTONE Big Shiny Sapphyra",
    "GEMSTONE Voidlight Deepfish","GEMSTONE Shiny Voidlight Deepfish","GEMSTONE Big Voidlight Deepfish","GEMSTONE Big Shiny Voidlight Deepfish",
    "GEMSTONE Rainy Dumbo","GEMSTONE Shiny Rainy Dumbo","GEMSTONE Big Rainy Dumbo","GEMSTONE Big Shiny Rainy Dumbo",
    "GEMSTONE Treasure Crab","GEMSTONE Shiny Treasure Crab","GEMSTONE Big Treasure Crab","GEMSTONE Big Shiny Treasure Crab",
    "GEMSTONE Solarflare Koi","GEMSTONE Shiny Solarflare Koi","GEMSTONE Big Solarflare Koi","GEMSTONE Big Shiny Solarflare Koi",
    "FAIRY DUST Cute Dumbo","FAIRY DUST Shiny Cute Dumbo","FAIRY DUST Big Cute Dumbo","FAIRY DUST Big Shiny Cute Dumbo",
    "FAIRY DUST Sapphyra","FAIRY DUST Shiny Sapphyra","FAIRY DUST Big Sapphyra","FAIRY DUST Big Shiny Sapphyra",
    "FAIRY DUST Voidlight Deepfish","FAIRY DUST Shiny Voidlight Deepfish","FAIRY DUST Big Voidlight Deepfish","FAIRY DUST Big Shiny Voidlight Deepfish",
    "FAIRY DUST Rainy Dumbo","FAIRY DUST Shiny Rainy Dumbo","FAIRY DUST Big Rainy Dumbo","FAIRY DUST Big Shiny Rainy Dumbo",
    "FAIRY DUST Treasure Crab","FAIRY DUST Shiny Treasure Crab","FAIRY DUST Big Treasure Crab","FAIRY DUST Big Shiny Treasure Crab",
    "FAIRY DUST Solarflare Koi","FAIRY DUST Shiny Solarflare Koi","FAIRY DUST Big Solarflare Koi","FAIRY DUST Big Shiny Solarflare Koi",
    "NOOB Cute Dumbo","NOOB Shiny Cute Dumbo","NOOB Big Cute Dumbo","NOOB Big Shiny Cute Dumbo",
    "NOOB Sapphyra","NOOB Shiny Sapphyra","NOOB Big Sapphyra","NOOB Big Shiny Sapphyra",
    "NOOB Voidlight Deepfish","NOOB Shiny Voidlight Deepfish","NOOB Big Voidlight Deepfish","NOOB Big Shiny Voidlight Deepfish",
    "NOOB Rainy Dumbo","NOOB Shiny Rainy Dumbo","NOOB Big Rainy Dumbo","NOOB Big Shiny Rainy Dumbo",
    "NOOB Treasure Crab","NOOB Shiny Treasure Crab","NOOB Big Treasure Crab","NOOB Big Shiny Treasure Crab",
    "NOOB Solarflare Koi","NOOB Shiny Solarflare Koi","NOOB Big Solarflare Koi","NOOB Big Shiny Solarflare Koi",
    "RADIOACTIVE Cute Dumbo","RADIOACTIVE Shiny Cute Dumbo","RADIOACTIVE Big Cute Dumbo","RADIOACTIVE Big Shiny Cute Dumbo",
    "RADIOACTIVE Sapphyra","RADIOACTIVE Shiny Sapphyra","RADIOACTIVE Big Sapphyra","RADIOACTIVE Big Shiny Sapphyra",
    "RADIOACTIVE Voidlight Deepfish","RADIOACTIVE Shiny Voidlight Deepfish","RADIOACTIVE Big Voidlight Deepfish","RADIOACTIVE Big Shiny Voidlight Deepfish",
    "RADIOACTIVE Rainy Dumbo","RADIOACTIVE Shiny Rainy Dumbo","RADIOACTIVE Big Rainy Dumbo","RADIOACTIVE Big Shiny Rainy Dumbo",
    "RADIOACTIVE Treasure Crab","RADIOACTIVE Shiny Treasure Crab","RADIOACTIVE Big Treasure Crab","RADIOACTIVE Big Shiny Treasure Crab",
    "RADIOACTIVE Solarflare Koi","RADIOACTIVE Shiny Solarflare Koi","RADIOACTIVE Big Solarflare Koi","RADIOACTIVE Big Shiny Solarflare Koi",
    "LIGHTNING Cute Dumbo","LIGHTNING Shiny Cute Dumbo","LIGHTNING Big Cute Dumbo","LIGHTNING Big Shiny Cute Dumbo",
    "LIGHTNING Sapphyra","LIGHTNING Shiny Sapphyra","LIGHTNING Big Sapphyra","LIGHTNING Big Shiny Sapphyra",
    "LIGHTNING Voidlight Deepfish","LIGHTNING Shiny Voidlight Deepfish","LIGHTNING Big Voidlight Deepfish","LIGHTNING Big Shiny Voidlight Deepfish",
    "LIGHTNING Rainy Dumbo","LIGHTNING Shiny Rainy Dumbo","LIGHTNING Big Rainy Dumbo","LIGHTNING Big Shiny Rainy Dumbo",
    "LIGHTNING Treasure Crab","LIGHTNING Shiny Treasure Crab","LIGHTNING Big Treasure Crab","LIGHTNING Big Shiny Treasure Crab",
    "LIGHTNING Solarflare Koi","LIGHTNING Shiny Solarflare Koi","LIGHTNING Big Solarflare Koi","LIGHTNING Big Shiny Solarflare Koi",
    "MIDNIGHT Cute Dumbo","MIDNIGHT Shiny Cute Dumbo","MIDNIGHT Big Cute Dumbo","MIDNIGHT Big Shiny Cute Dumbo",
    "MIDNIGHT Sapphyra","MIDNIGHT Shiny Sapphyra","MIDNIGHT Big Sapphyra","MIDNIGHT Big Shiny Sapphyra",
    "MIDNIGHT Voidlight Deepfish","MIDNIGHT Shiny Voidlight Deepfish","MIDNIGHT Big Voidlight Deepfish","MIDNIGHT Big Shiny Voidlight Deepfish",
    "MIDNIGHT Rainy Dumbo","MIDNIGHT Shiny Rainy Dumbo","MIDNIGHT Big Rainy Dumbo","MIDNIGHT Big Shiny Rainy Dumbo",
    "MIDNIGHT Treasure Crab","MIDNIGHT Shiny Treasure Crab","MIDNIGHT Big Treasure Crab","MIDNIGHT Big Shiny Treasure Crab",
    "MIDNIGHT Solarflare Koi","MIDNIGHT Shiny Solarflare Koi","MIDNIGHT Big Solarflare Koi","MIDNIGHT Big Shiny Solarflare Koi",
    "HOLOGRAPHIC Cute Dumbo","HOLOGRAPHIC Shiny Cute Dumbo","HOLOGRAPHIC Big Cute Dumbo","HOLOGRAPHIC Big Shiny Cute Dumbo",
    "HOLOGRAPHIC Sapphyra","HOLOGRAPHIC Shiny Sapphyra","HOLOGRAPHIC Big Sapphyra","HOLOGRAPHIC Big Shiny Sapphyra",
    "HOLOGRAPHIC Voidlight Deepfish","HOLOGRAPHIC Shiny Voidlight Deepfish","HOLOGRAPHIC Big Voidlight Deepfish","HOLOGRAPHIC Big Shiny Voidlight Deepfish",
    "HOLOGRAPHIC Rainy Dumbo","HOLOGRAPHIC Shiny Rainy Dumbo","HOLOGRAPHIC Big Rainy Dumbo","HOLOGRAPHIC Big Shiny Rainy Dumbo",
    "HOLOGRAPHIC Treasure Crab","HOLOGRAPHIC Shiny Treasure Crab","HOLOGRAPHIC Big Treasure Crab","HOLOGRAPHIC Big Shiny Treasure Crab",
    "HOLOGRAPHIC Solarflare Koi","HOLOGRAPHIC Shiny Solarflare Koi","HOLOGRAPHIC Big Solarflare Koi","HOLOGRAPHIC Big Shiny Solarflare Koi",
    "BINARY Cute Dumbo","BINARY Shiny Cute Dumbo","BINARY Big Cute Dumbo","BINARY Big Shiny Cute Dumbo",
    "BINARY Sapphyra","BINARY Shiny Sapphyra","BINARY Big Sapphyra","BINARY Big Shiny Sapphyra",
    "BINARY Voidlight Deepfish","BINARY Shiny Voidlight Deepfish","BINARY Big Voidlight Deepfish","BINARY Big Shiny Voidlight Deepfish",
    "BINARY Rainy Dumbo","BINARY Shiny Rainy Dumbo","BINARY Big Rainy Dumbo","BINARY Big Shiny Rainy Dumbo",
    "BINARY Treasure Crab","BINARY Shiny Treasure Crab","BINARY Big Treasure Crab","BINARY Big Shiny Treasure Crab",
    "BINARY Solarflare Koi","BINARY Shiny Solarflare Koi","BINARY Big Solarflare Koi","BINARY Big Shiny Solarflare Koi",
    "CRYSTALIZED Cute Dumbo","CRYSTALIZED Shiny Cute Dumbo","CRYSTALIZED Big Cute Dumbo","CRYSTALIZED Big Shiny Cute Dumbo",
    "CRYSTALIZED Sapphyra","CRYSTALIZED Shiny Sapphyra","CRYSTALIZED Big Sapphyra","CRYSTALIZED Big Shiny Sapphyra",
    "CRYSTALIZED Voidlight Deepfish","CRYSTALIZED Shiny Voidlight Deepfish","CRYSTALIZED Big Voidlight Deepfish","CRYSTALIZED Big Shiny Voidlight Deepfish",
    "CRYSTALIZED Rainy Dumbo","CRYSTALIZED Shiny Rainy Dumbo","CRYSTALIZED Big Rainy Dumbo","CRYSTALIZED Big Shiny Rainy Dumbo",
    "CRYSTALIZED Treasure Crab","CRYSTALIZED Shiny Treasure Crab","CRYSTALIZED Big Treasure Crab","CRYSTALIZED Big Shiny Treasure Crab",
    "CRYSTALIZED Solarflare Koi","CRYSTALIZED Shiny Solarflare Koi","CRYSTALIZED Big Solarflare Koi","CRYSTALIZED Big Shiny Solarflare Koi",
    "GEMSTONE Ruby","GEMSTONE Shiny Ruby","GEMSTONE Big Ruby","GEMSTONE Big Shiny Ruby",
}
local evolvedKeyword = "Evolved Enchant Stone"
local rarityOk = {
    ["15M"]=1,["950K"]=1,["12M"]=1,["250K"]=1,["300K"]=1,["450K"]=1,["500K"]=1,
    ["600K"]=1,["750K"]=1,["800K"]=1,["900K"]=1,["1M"]=1,["1.20M"]=1,["1.50M"]=1,
    ["2M"]=1,["2.50M"]=1,["2.75M"]=1,["3M"]=1,["3.50M"]=1,["4M"]=1,["5M"]=1,
    ["6M"]=1,["25M"]=1,["30M"]=1,
}
local function getUsername(nameFromChat)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == nameFromChat or p.Name == nameFromChat then return p.Name end
    end
    return nameFromChat
end
local function parseMessage(c)
    local playerName = c:match("%]:%s*(.-)%s+obtained") or c:match("^(.-)%s+obtained") or "Unknown"
    local itemName = c:match("obtained an? (.+) %([%d%.A-Za-z%s]+kg%)")
    if not itemName then itemName = c:match("obtained an? (.-)%s*%(1 in") end
    local weight = c:match("%(([%d%.A-Za-z%s]+)kg%)")
    if weight then
        weight = weight:match("^%s*(.-)%s*$")
        if not weight:match("^[%d%.]+$") then weight = nil end
    end
    local rarity = c:match("1 in ([%d%.]+[KkMm][Mm]?) chance")
    if rarity then rarity = rarity:upper() end
    return { playerDisplay = playerName, username = getUsername(playerName), itemName = itemName or "Unknown", weight = weight, rarity = rarity }
end

task.spawn(function()
    for _, ch in ipairs(tcs:GetDescendants()) do
        if ch:IsA("TextChannel") then
            ch.MessageReceived:Connect(function(msg)
                if not msg or not msg.Text or msg.Text == "" then return end
                if not state.webhookEnabled then return end
                local raw = msg.Text:gsub("<[^>]+>", "")
                local parsed = parseMessage(raw)
                local pCount = tostring(#Players:GetPlayers())
                local pLabel = parsed.playerDisplay.." ("..parsed.username..")"
                if state.evolvedEnabled and raw:find(evolvedKeyword, 1, true) then
                    sendWebhookEmbed({ title = "EVOLVED ENCHANT NIH ⭐", color = 16763904, fields = {
                        {name="👤 Player",value=pLabel,inline=false},{name="✨ Item",value=evolvedKeyword,inline=true},
                        {name="👥 Players",value=pCount,inline=true},{name="🕐 Time",value=os.date("%Y-%m-%d %H:%M:%S"),inline=true}}})
                    return
                end
                if state.mutationEnabled then
                    for _, kw in ipairs(mutationKeywords) do
                        if raw:find(kw, 1, true) then
                            local wtVal = parsed.weight and (parsed.weight.." kg") or "?"
                            sendWebhookEmbed({ title = "🧬 MUTATION DETECTED!", color = 16711935, fields = {
                                {name="👤 Player",value=pLabel,inline=false},{name="✅ Mutation Catch",value=kw,inline=true},
                                {name="⚖️ Weight",value=wtVal,inline=true},{name="👥 Players",value=pCount,inline=true},
                                {name="🕐 Time",value=os.date("%Y-%m-%d %H:%M:%S"),inline=true}}})
                            break
                        end
                    end
                end
                if not state.scEnabled then return end
                if not parsed.rarity then return end
                if not rarityOk[parsed.rarity] then return end
                if parsed.itemName == "Runic Enchant Stone" then
                    sendWebhookEmbed({ title = "RUNIC ENCHANT NIH 🪄", color = 11730954, fields = {
                        {name="👤 Player",value=pLabel,inline=false},{name="✨ Item",value="Runic Enchant Stone",inline=true},
                        {name="🏆 Rarity",value="1 in "..parsed.rarity,inline=true},{name="👥 Players",value=pCount,inline=true},
                        {name="🕐 Time",value=os.date("%Y-%m-%d %H:%M:%S"),inline=true}}})
                    return
                end
                local wtVal = parsed.weight and (parsed.weight.." kg") or "—"
                sendWebhookEmbed({ title = "SETORAN KARYAWAN NIH 🐟", color = 1752220, fields = {
                    {name="👤 Player",value=pLabel,inline=false},{name="🎣 Item",value=parsed.itemName,inline=true},
                    {name="🏆 Rarity",value="1 in "..parsed.rarity,inline=true},{name="⚖️ Weight",value=wtVal,inline=true},
                    {name="👥 Players",value=pCount,inline=true},{name="🕐 Time",value=os.date("%Y-%m-%d %H:%M:%S"),inline=true}}})
            end)
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    if not state.joinLeftEnabled or not state.webhookEnabled then return end
    if p == LP then return end
    if state.localPlayerLeaving then return end
    sendWebhookEmbed({ title = "🟢 PLAYER JOIN", color = 65280, fields = {
        {name="👤 Player",value=p.DisplayName.." ("..p.Name..")",inline=false},
        {name="👥 Players Now",value=tostring(#Players:GetPlayers()),inline=true},
        {name="🕐 Time",value=os.date("%Y-%m-%d %H:%M:%S"),inline=true}}})
end)
Players.PlayerRemoving:Connect(function(p)
    if p == LP then state.localPlayerLeaving = true end
    if not state.joinLeftEnabled or not state.webhookEnabled then return end
    if state.localPlayerLeaving and p ~= LP then return end
    if p == LP then return end
    sendWebhookEmbed({ title = "🔴 PLAYER LEFT", color = 16711680, fields = {
        {name="👤 Player",value=p.DisplayName.." ("..p.Name..")",inline=false},
        {name="🕐 Time",value=os.date("%Y-%m-%d %H:%M:%S"),inline=true}}})
end)

-- ========== LOAD CONFIGS ==========
loadBlapetConfig()
loadSavedPositions()

-- ========== UI ==========
local pg = LP:WaitForChild("PlayerGui")
local floatingGui = Instance.new("ScreenGui")
floatingGui.Name = "ZHX_FloatBtn"; floatingGui.ResetOnSpawn = false; floatingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
floatingGui.Parent = pg; pcall(function() floatingGui.DisplayOrder = 99999 end)
local floatBtn = Instance.new("ImageButton")
floatBtn.Size = UDim2.new(0,46,0,46); floatBtn.Position = UDim2.new(0,12,0,100)
floatBtn.BackgroundColor3 = Color3.fromRGB(15,18,26); floatBtn.BorderSizePixel = 0
floatBtn.Image = "rbxassetid://78392602281326"; floatBtn.ScaleType = Enum.ScaleType.Fit
floatBtn.ZIndex = 9999; floatBtn.Parent = floatingGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", floatBtn).Color = Color3.fromRGB(72,210,130)

local mainGui = Instance.new("ScreenGui")
mainGui.Name = "ZHXHub_FullProject_v1.4"; mainGui.ResetOnSpawn = false; mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.Parent = pg; pcall(function() mainGui.DisplayOrder = 99999 end)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,420,0,340); frame.Position = UDim2.new(0.5,-210,0.5,-170)
frame.BackgroundColor3 = Color3.fromRGB(15,15,20); frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0; frame.ZIndex = 9998; frame.Visible = false; frame.Parent = mainGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", frame).Color = Color3.fromRGB(72,210,130)

floatBtn.MouseButton1Click:Connect(function() frame.Visible = not frame.Visible end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,24); title.Position = UDim2.new(0,10,0,6)
title.BackgroundTransparency = 1; title.Text = "⚡ ZHX HUB PROJECT [BETA] v2.0  ⚡"
title.TextColor3 = Color3.fromRGB(72,210,130); title.TextSize = 13
title.Font = Enum.Font.GothamBold; title.ZIndex = 101; title.Parent = frame

-- Tab Frame
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(0,100,1,-40); tabFrame.Position = UDim2.new(0,8,0,34)
tabFrame.BackgroundColor3 = Color3.fromRGB(20,20,25); tabFrame.BorderSizePixel = 0
tabFrame.ZIndex = 100; tabFrame.Parent = frame
Instance.new("UICorner", tabFrame).CornerRadius = UDim.new(0,6)
local tabLayout = Instance.new("UIListLayout")
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder; tabLayout.Padding = UDim.new(0,4); tabLayout.Parent = tabFrame

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1,-116,1,-40); contentFrame.Position = UDim2.new(0,112,0,34)
contentFrame.BackgroundColor3 = Color3.fromRGB(20,20,25); contentFrame.BorderSizePixel = 0
contentFrame.ZIndex = 100; contentFrame.Parent = frame
Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0,6)

local function createTabButton(name, buildContent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-8,0,30); btn.Position = UDim2.new(0,4,0,4)
    btn.BackgroundColor3 = Color3.fromRGB(40,40,50); btn.BorderSizePixel = 0
    btn.Text = name; btn.TextColor3 = Color3.fromRGB(200,200,200); btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold; btn.ZIndex = 101; btn.AutoButtonColor = false; btn.Parent = tabFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
    btn.MouseButton1Click:Connect(function()
        for _, child in ipairs(tabFrame:GetChildren()) do if child:IsA("TextButton") then child.BackgroundColor3 = Color3.fromRGB(40,40,50) end end
        btn.BackgroundColor3 = Color3.fromRGB(60,60,20)
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end
        buildContent().Parent = contentFrame
    end)
    return btn
end

-- Helper UI (with state sync)
local function makeInput(parent, y, label, default, callback, configKey)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0,82,0,20); lbl.Position = UDim2.new(0,8,0,y); lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextColor3 = Color3.fromRGB(200,200,200); lbl.TextSize = 10; lbl.Font = Enum.Font.Gotham; lbl.ZIndex = 101; lbl.Parent = parent
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0,55,0,20); box.Position = UDim2.new(0,100,0,y); box.BackgroundColor3 = Color3.fromRGB(30,30,40); box.BorderSizePixel = 0
    box.Text = tostring(default); box.TextColor3 = Color3.fromRGB(255,255,255); box.TextSize = 10; box.Font = Enum.Font.Gotham; box.ZIndex = 101; box.Parent = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,4)
    if configKey then state.inputBoxes[configKey] = box end
    box.FocusLost:Connect(function() local n=tonumber(box.Text) if n then callback(n) end end)
    return box
end

local function makeToggle(parent, y, text, startFn, stopFn, getActiveFn)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-16,0,26); btn.Position = UDim2.new(0,8,0,y)
    btn.BackgroundColor3 = Color3.fromRGB(20,60,30); btn.BorderSizePixel = 0
    btn.Text = getActiveFn() and ("⏹ " .. text) or ("▶ " .. text)
    btn.TextColor3 = Color3.fromRGB(72,210,130); btn.TextSize = 11; btn.Font = Enum.Font.GothamBold; btn.ZIndex = 101
    btn.AutoButtonColor = false; btn.Parent = parent; Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)
    if getActiveFn() then btn.BackgroundColor3 = Color3.fromRGB(60,20,20) end
    btn.MouseButton1Click:Connect(function()
        if getActiveFn() then
            stopFn(); btn.Text = "▶ " .. text; btn.BackgroundColor3 = Color3.fromRGB(20,60,30)
        else
            startFn(); btn.Text = "⏹ " .. text; btn.BackgroundColor3 = Color3.fromRGB(60,20,20)
        end
    end)
    return btn
end

-- ========== TAB BLAPET AUTO (IDENTIK DENGAN V6.5) ==========
local function buildBlapetTab()
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,1,0); content.BackgroundTransparency = 1; content.ZIndex = 101

    local y = 4
    local inputGap = 20
    local toggleGap = 26
    local sectionGap = 28

    makeInput(content, y, "Reel Delay", state.blapetConfig.reelDelay, function(v) state.blapetConfig.reelDelay = v end, "reelDelay")
    y = y + inputGap
    makeInput(content, y, "Loop Interval", state.blapetConfig.loopInterval, function(v) state.blapetConfig.loopInterval = v end, "loopInterval")
    y = y + inputGap
    makeInput(content, y, "Timing Trigger", state.blapetConfig.timingTrigger, function(v) state.blapetConfig.timingTrigger = v end, "timingTrigger")
    y = y + toggleGap
    makeToggle(content, y, "Fast Reel", startFastReel, stopFastReel, function() return state.fastReelActive end)
    y = y + sectionGap
    makeInput(content, y, "Pet Bug Interval", state.blapetConfig.petBugInterval, function(v) state.blapetConfig.petBugInterval = math.max(10,v) end, "petBugInterval")
    y = y + inputGap
    makeInput(content, y, "Toggle Count", state.blapetConfig.toggleCount, function(v) state.blapetConfig.toggleCount = math.max(1,math.floor(v)) end, "toggleCount")
    y = y + toggleGap
    makeToggle(content, y, "Pet Bug (Smart)", function() state.petBugActive=true; state.lastPetBugTime=0 end, function() state.petBugActive=false end, function() return state.petBugActive end)
    y = y + sectionGap
    makeInput(content, y, "Blapet Cycles", state.blapetConfig.blapetCycles, function(v) state.blapetConfig.blapetCycles = math.max(1,math.floor(v)) end, "blapetCycles")
    y = y + inputGap
    makeInput(content, y, "Stuck Time (s)", state.blapetConfig.blapetStuckTime, function(v) state.blapetConfig.blapetStuckTime = math.max(5,v) end, "blapetStuckTime")
    y = y + inputGap
    makeInput(content, y, "Final Stuck (s)", state.blapetConfig.blapetFinalStuck, function(v) state.blapetConfig.blapetFinalStuck = math.max(30,v) end, "blapetFinalStuck")
    y = y + inputGap
    makeInput(content, y, "Interval (jam)", state.blapetConfig.blapetIntervalHours, function(v) state.blapetConfig.blapetIntervalHours = math.max(0.5,v) end, "blapetIntervalHours")

    y = y + toggleGap

    local rowFrame = Instance.new("Frame")
    rowFrame.Size = UDim2.new(1,-16,0,26)
    rowFrame.Position = UDim2.new(0,8,0,y)
    rowFrame.BackgroundTransparency = 1
    rowFrame.ZIndex = 101
    rowFrame.Parent = content

    local blapetToggleBtn = Instance.new("TextButton")
    blapetToggleBtn.Size = UDim2.new(0,130,0,26); blapetToggleBtn.Position = UDim2.new(0,0,0,0)
    blapetToggleBtn.BackgroundColor3 = state.blapetActive and Color3.fromRGB(60,20,20) or Color3.fromRGB(20,60,30)
    blapetToggleBtn.Text = state.blapetActive and "⏹ Blapet (Auto)" or "▶ Blapet (Auto)"
    blapetToggleBtn.TextColor3 = Color3.fromRGB(72,210,130); blapetToggleBtn.TextSize = 11; blapetToggleBtn.Font = Enum.Font.GothamBold
    blapetToggleBtn.ZIndex = 101; blapetToggleBtn.AutoButtonColor = false; blapetToggleBtn.Parent = rowFrame
    Instance.new("UICorner", blapetToggleBtn).CornerRadius = UDim.new(0,5)

    blapetToggleBtn.MouseButton1Click:Connect(function()
        if state.blapetActive then
            stopBlapet()
            blapetToggleBtn.Text = "▶ Blapet (Auto)"; blapetToggleBtn.BackgroundColor3 = Color3.fromRGB(20,60,30)
        else
            startBlapet()
            blapetToggleBtn.Text = "⏹ Blapet (Auto)"; blapetToggleBtn.BackgroundColor3 = Color3.fromRGB(60,20,20)
        end
    end)

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0,70,0,26); saveBtn.Position = UDim2.new(0,138,0,0)
    saveBtn.BackgroundColor3 = Color3.fromRGB(30,40,80); saveBtn.BorderSizePixel = 0
    saveBtn.Text = "💾 Save"; saveBtn.TextColor3 = Color3.fromRGB(130,180,255); saveBtn.TextSize = 10; saveBtn.Font = Enum.Font.GothamBold
    saveBtn.ZIndex = 101; saveBtn.AutoButtonColor = false; saveBtn.Parent = rowFrame
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0,5)
    saveBtn.MouseButton1Click:Connect(function()
        saveBlapetConfig()
        saveBtn.Text = "✅ Saved!"; task.wait(2); saveBtn.Text = "💾 Save"
    end)

    return content
end

-- ========== TAB WALK TO LOCATION ==========
local function buildWalkToLocationTab()
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,1,0); content.BackgroundTransparency = 1; content.ZIndex = 101
    local locScroll = Instance.new("ScrollingFrame")
    locScroll.Size = UDim2.new(1,-10,1,-40); locScroll.Position = UDim2.new(0,5,0,4)
    locScroll.BackgroundColor3 = Color3.fromRGB(25,25,30); locScroll.BorderSizePixel = 0; locScroll.ScrollBarThickness = 4
    locScroll.ScrollBarImageColor3 = Color3.fromRGB(72,210,130); locScroll.CanvasSize = UDim2.new(0,0,0,0); locScroll.ZIndex = 102; locScroll.Parent = content
    local locLayout = Instance.new("UIListLayout"); locLayout.SortOrder = Enum.SortOrder.LayoutOrder; locLayout.Padding = UDim.new(0,2); locLayout.Parent = locScroll
    local btnFrame = Instance.new("Frame"); btnFrame.Size = UDim2.new(1,-10,0,30); btnFrame.Position = UDim2.new(0,5,1,-35); btnFrame.BackgroundTransparency = 1; btnFrame.ZIndex = 101; btnFrame.Parent = content
    local locGoBtn = Instance.new("TextButton"); locGoBtn.Size = UDim2.new(0,70,0,28); locGoBtn.Position = UDim2.new(0,0,0,0)
    locGoBtn.BackgroundColor3 = Color3.fromRGB(40,40,20); locGoBtn.BorderSizePixel = 0; locGoBtn.Text = "▶ Go"; locGoBtn.TextColor3 = Color3.fromRGB(255,255,255)
    locGoBtn.TextSize = 11; locGoBtn.Font = Enum.Font.GothamBold; locGoBtn.ZIndex = 101; locGoBtn.AutoButtonColor = false; locGoBtn.Parent = btnFrame
    Instance.new("UICorner", locGoBtn).CornerRadius = UDim.new(0,5)
    local locStopBtn = Instance.new("TextButton"); locStopBtn.Size = UDim2.new(0,40,0,28); locStopBtn.Position = UDim2.new(0,75,0,0)
    locStopBtn.BackgroundColor3 = Color3.fromRGB(60,20,20); locStopBtn.BorderSizePixel = 0; locStopBtn.Text = "⏹"; locStopBtn.TextColor3 = Color3.fromRGB(255,100,100)
    locStopBtn.TextSize = 14; locStopBtn.Font = Enum.Font.GothamBold; locStopBtn.ZIndex = 101; locStopBtn.AutoButtonColor = false; locStopBtn.Parent = btnFrame
    Instance.new("UICorner", locStopBtn).CornerRadius = UDim.new(0,5)
    locStopBtn.MouseButton1Click:Connect(stopWalking)
    local selectedLocBtn = nil; local selectedLocation = nil; local totalLocH = 0
    for name, cf in pairs(locations) do
        totalLocH = totalLocH + 30
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,-4,0,28); btn.BackgroundColor3 = Color3.fromRGB(30,30,35); btn.BorderSizePixel = 0
        btn.Text = name; btn.TextColor3 = Color3.fromRGB(200,220,200); btn.TextSize = 11; btn.Font = Enum.Font.Gotham; btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 103; btn.AutoButtonColor = false; btn.Parent = locScroll; Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
        btn.MouseEnter:Connect(function() if btn ~= selectedLocBtn then btn.BackgroundColor3 = Color3.fromRGB(50,50,60) end end)
        btn.MouseLeave:Connect(function() if btn ~= selectedLocBtn then btn.BackgroundColor3 = Color3.fromRGB(30,30,35) end end)
        btn.MouseButton1Click:Connect(function()
            if selectedLocBtn then selectedLocBtn.BackgroundColor3 = Color3.fromRGB(30,30,35) end
            selectedLocBtn = btn; btn.BackgroundColor3 = Color3.fromRGB(20,80,20); selectedLocation = cf
        end)
    end
    locScroll.CanvasSize = UDim2.new(0,0,0, totalLocH + 8)
    locGoBtn.MouseButton1Click:Connect(function()
        if state.autoEventActive then return end
        if selectedLocation then safeWalk(selectedLocation) end
    end)
    return content
end

-- ========== TAB WALK TO PLAYER ==========
local function buildWalkToPlayerTab()
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,1,0); content.BackgroundTransparency = 1; content.ZIndex = 101
    local playerScroll = Instance.new("ScrollingFrame")
    playerScroll.Size = UDim2.new(1,-10,1,-40); playerScroll.Position = UDim2.new(0,5,0,4)
    playerScroll.BackgroundColor3 = Color3.fromRGB(25,25,30); playerScroll.BorderSizePixel = 0; playerScroll.ScrollBarThickness = 4
    playerScroll.ScrollBarImageColor3 = Color3.fromRGB(72,210,130); playerScroll.CanvasSize = UDim2.new(0,0,0,0); playerScroll.ZIndex = 102; playerScroll.Parent = content
    local playerLayout = Instance.new("UIListLayout"); playerLayout.SortOrder = Enum.SortOrder.LayoutOrder; playerLayout.Padding = UDim.new(0,2); playerLayout.Parent = playerScroll
    local btnFrame = Instance.new("Frame"); btnFrame.Size = UDim2.new(1,-10,0,30); btnFrame.Position = UDim2.new(0,5,1,-35); btnFrame.BackgroundTransparency = 1; btnFrame.ZIndex = 101; btnFrame.Parent = content
    local refreshBtn = Instance.new("TextButton"); refreshBtn.Size = UDim2.new(0,70,0,28); refreshBtn.Position = UDim2.new(0,0,0,0)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(40,40,60); refreshBtn.BorderSizePixel = 0; refreshBtn.Text = "🔄 Refresh"; refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
    refreshBtn.TextSize = 10; refreshBtn.Font = Enum.Font.GothamBold; refreshBtn.ZIndex = 101; refreshBtn.AutoButtonColor = false; refreshBtn.Parent = btnFrame
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0,5)
    local playerGoBtn = Instance.new("TextButton"); playerGoBtn.Size = UDim2.new(0,70,0,28); playerGoBtn.Position = UDim2.new(0,75,0,0)
    playerGoBtn.BackgroundColor3 = Color3.fromRGB(40,40,20); playerGoBtn.BorderSizePixel = 0; playerGoBtn.Text = "▶ Go"; playerGoBtn.TextColor3 = Color3.fromRGB(255,255,255)
    playerGoBtn.TextSize = 11; playerGoBtn.Font = Enum.Font.GothamBold; playerGoBtn.ZIndex = 101; playerGoBtn.AutoButtonColor = false; playerGoBtn.Parent = btnFrame
    Instance.new("UICorner", playerGoBtn).CornerRadius = UDim.new(0,5)
    local playerStopBtn = Instance.new("TextButton"); playerStopBtn.Size = UDim2.new(0,40,0,28); playerStopBtn.Position = UDim2.new(0,150,0,0)
    playerStopBtn.BackgroundColor3 = Color3.fromRGB(60,20,20); playerStopBtn.BorderSizePixel = 0; playerStopBtn.Text = "⏹"; playerStopBtn.TextColor3 = Color3.fromRGB(255,100,100)
    playerStopBtn.TextSize = 14; playerStopBtn.Font = Enum.Font.GothamBold; playerStopBtn.ZIndex = 101; playerStopBtn.AutoButtonColor = false; playerStopBtn.Parent = btnFrame
    Instance.new("UICorner", playerStopBtn).CornerRadius = UDim.new(0,5)
    playerStopBtn.MouseButton1Click:Connect(stopWalking)
    local selectedPlayerBtn = nil; local selectedPlayer = nil
    local function refreshPlayerList()
        for _, child in ipairs(playerScroll:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
        selectedPlayerBtn = nil; selectedPlayer = nil; local totalH = 0
        local players = Players:GetPlayers(); table.sort(players, function(a,b) return a.Name < b.Name end)
        for _, player in ipairs(players) do
            if player ~= LP then
                totalH = totalH + 30
                local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,-4,0,28); btn.BackgroundColor3 = Color3.fromRGB(30,30,35); btn.BorderSizePixel = 0
                btn.Text = player.Name; btn.TextColor3 = Color3.fromRGB(200,220,200); btn.TextSize = 11; btn.Font = Enum.Font.Gotham; btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.ZIndex = 103; btn.AutoButtonColor = false; btn.Parent = playerScroll; Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
                btn.MouseEnter:Connect(function() if btn ~= selectedPlayerBtn then btn.BackgroundColor3 = Color3.fromRGB(50,50,60) end end)
                btn.MouseLeave:Connect(function() if btn ~= selectedPlayerBtn then btn.BackgroundColor3 = Color3.fromRGB(30,30,35) end end)
                btn.MouseButton1Click:Connect(function()
                    if selectedPlayerBtn then selectedPlayerBtn.BackgroundColor3 = Color3.fromRGB(30,30,35) end
                    selectedPlayerBtn = btn; btn.BackgroundColor3 = Color3.fromRGB(20,80,20); selectedPlayer = player
                end)
            end
        end
        playerScroll.CanvasSize = UDim2.new(0,0,0, totalH + 8)
    end
    refreshBtn.MouseButton1Click:Connect(refreshPlayerList); refreshPlayerList()
    playerGoBtn.MouseButton1Click:Connect(function()
        if state.autoEventActive then return end
        if not selectedPlayer then return end
        local char = selectedPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        safeWalk(root.CFrame)
    end)
    return content
end

-- ========== TAB SAVED POSITIONS ==========
local function buildSavedPositionsTab()
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,1,0); content.BackgroundTransparency = 1; content.ZIndex = 101
    local nameInput = Instance.new("TextBox"); nameInput.Size = UDim2.new(1,-10,0,26); nameInput.Position = UDim2.new(0,5,0,4)
    nameInput.BackgroundColor3 = Color3.fromRGB(30,30,40); nameInput.BorderSizePixel = 0; nameInput.Text = ""; nameInput.PlaceholderText = "Nama posisi..."
    nameInput.TextColor3 = Color3.fromRGB(255,255,255); nameInput.TextSize = 11; nameInput.Font = Enum.Font.Gotham; nameInput.ZIndex = 103; nameInput.Parent = content
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0,4)
    nameInput.FocusLost:Connect(function() state.saveName = nameInput.Text:gsub("%s+"," ") end)
    local savedScroll = Instance.new("ScrollingFrame")
    savedScroll.Size = UDim2.new(1,-10,1,-120); savedScroll.Position = UDim2.new(0,5,0,34)
    savedScroll.BackgroundColor3 = Color3.fromRGB(25,25,30); savedScroll.BorderSizePixel = 0; savedScroll.ScrollBarThickness = 4
    savedScroll.ScrollBarImageColor3 = Color3.fromRGB(72,210,130); savedScroll.CanvasSize = UDim2.new(0,0,0,0); savedScroll.ZIndex = 102; savedScroll.Parent = content
    local savedLayout = Instance.new("UIListLayout"); savedLayout.SortOrder = Enum.SortOrder.LayoutOrder; savedLayout.Padding = UDim.new(0,2); savedLayout.Parent = savedScroll
    local btnFrame = Instance.new("Frame"); btnFrame.Size = UDim2.new(1,-10,0,85); btnFrame.Position = UDim2.new(0,5,1,-92); btnFrame.BackgroundTransparency = 1; btnFrame.ZIndex = 101; btnFrame.Parent = content
    local savePosBtn = Instance.new("TextButton"); savePosBtn.Size = UDim2.new(1,0,0,28); savePosBtn.Position = UDim2.new(0,0,0,0)
    savePosBtn.BackgroundColor3 = Color3.fromRGB(20,40,80); savePosBtn.BorderSizePixel = 0; savePosBtn.Text = "💾 Save Current Position"; savePosBtn.TextColor3 = Color3.fromRGB(255,255,255)
    savePosBtn.TextSize = 11; savePosBtn.Font = Enum.Font.GothamBold; savePosBtn.ZIndex = 101; savePosBtn.AutoButtonColor = false; savePosBtn.Parent = btnFrame
    Instance.new("UICorner", savePosBtn).CornerRadius = UDim.new(0,5)
    local actionRow = Instance.new("Frame"); actionRow.Size = UDim2.new(1,0,0,28); actionRow.Position = UDim2.new(0,0,0,34); actionRow.BackgroundTransparency = 1; actionRow.ZIndex = 101; actionRow.Parent = btnFrame
    local savedGoBtn = Instance.new("TextButton"); savedGoBtn.Size = UDim2.new(0,70,0,28); savedGoBtn.Position = UDim2.new(0,0,0,0)
    savedGoBtn.BackgroundColor3 = Color3.fromRGB(40,40,20); savedGoBtn.BorderSizePixel = 0; savedGoBtn.Text = "▶ Go"; savedGoBtn.TextColor3 = Color3.fromRGB(255,255,255)
    savedGoBtn.TextSize = 11; savedGoBtn.Font = Enum.Font.GothamBold; savedGoBtn.ZIndex = 101; savedGoBtn.AutoButtonColor = false; savedGoBtn.Parent = actionRow
    Instance.new("UICorner", savedGoBtn).CornerRadius = UDim.new(0,5)
    local savedRemoveBtn = Instance.new("TextButton"); savedRemoveBtn.Size = UDim2.new(0,70,0,28); savedRemoveBtn.Position = UDim2.new(0,75,0,0)
    savedRemoveBtn.BackgroundColor3 = Color3.fromRGB(80,30,30); savedRemoveBtn.BorderSizePixel = 0; savedRemoveBtn.Text = "🗑 Remove"; savedRemoveBtn.TextColor3 = Color3.fromRGB(255,150,150)
    savedRemoveBtn.TextSize = 10; savedRemoveBtn.Font = Enum.Font.GothamBold; savedRemoveBtn.ZIndex = 101; savedRemoveBtn.AutoButtonColor = false; savedRemoveBtn.Parent = actionRow
    Instance.new("UICorner", savedRemoveBtn).CornerRadius = UDim.new(0,5)
    local savedStopBtn = Instance.new("TextButton"); savedStopBtn.Size = UDim2.new(0,40,0,28); savedStopBtn.Position = UDim2.new(0,150,0,0)
    savedStopBtn.BackgroundColor3 = Color3.fromRGB(60,20,20); savedStopBtn.BorderSizePixel = 0; savedStopBtn.Text = "⏹"; savedStopBtn.TextColor3 = Color3.fromRGB(255,100,100)
    savedStopBtn.TextSize = 14; savedStopBtn.Font = Enum.Font.GothamBold; savedStopBtn.ZIndex = 101; savedStopBtn.AutoButtonColor = false; savedStopBtn.Parent = actionRow
    Instance.new("UICorner", savedStopBtn).CornerRadius = UDim.new(0,5)
    savedStopBtn.MouseButton1Click:Connect(stopWalking)
    local selectedSavedBtn = nil
    local function refreshSavedList()
        for _, child in ipairs(savedScroll:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
        selectedSavedBtn = nil; state.selectedSavedIndex = nil; local totalH = 0
        for i, saved in ipairs(state.savedPositions) do
            totalH = totalH + 30
            local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,-4,0,28); btn.BackgroundColor3 = Color3.fromRGB(30,30,35); btn.BorderSizePixel = 0
            btn.Text = saved.name .. " (#" .. i .. ")"; btn.TextColor3 = Color3.fromRGB(200,220,200); btn.TextSize = 11; btn.Font = Enum.Font.Gotham; btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.ZIndex = 103; btn.AutoButtonColor = false; btn.Parent = savedScroll; Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
            btn.MouseEnter:Connect(function() if btn ~= selectedSavedBtn then btn.BackgroundColor3 = Color3.fromRGB(50,50,60) end end)
            btn.MouseLeave:Connect(function() if btn ~= selectedSavedBtn then btn.BackgroundColor3 = Color3.fromRGB(30,30,35) end end)
            btn.MouseButton1Click:Connect(function()
                if selectedSavedBtn then selectedSavedBtn.BackgroundColor3 = Color3.fromRGB(30,30,35) end
                selectedSavedBtn = btn; btn.BackgroundColor3 = Color3.fromRGB(20,80,20); state.selectedSavedIndex = i
            end)
        end
        savedScroll.CanvasSize = UDim2.new(0,0,0, totalH + 8)
    end
    savePosBtn.MouseButton1Click:Connect(function()
        local char = LP.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        local cf = root.CFrame; local pos = cf.Position; local name = state.saveName
        if name == "" then name = "Pos " .. string.format("%.0f,%.0f,%.0f", pos.X, pos.Y, pos.Z) end
        table.insert(state.savedPositions, {name = name, cf = cf}); state.saveName = ""; nameInput.Text = ""
        saveSavedPositions(); refreshSavedList()
    end)
    savedGoBtn.MouseButton1Click:Connect(function()
        if state.autoEventActive then return end
        if state.selectedSavedIndex and state.savedPositions[state.selectedSavedIndex] then safeWalk(state.savedPositions[state.selectedSavedIndex].cf) end
    end)
    savedRemoveBtn.MouseButton1Click:Connect(function()
        if state.selectedSavedIndex then table.remove(state.savedPositions, state.selectedSavedIndex); saveSavedPositions(); refreshSavedList() end
    end)
    refreshSavedList()
    return content
end

-- ========== TAB AUTO EVENT (STATE SYNC) ==========
local function buildAutoEventTab()
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,1,0); content.BackgroundTransparency = 1; content.ZIndex = 101
    local statusLabel = Instance.new("TextLabel"); statusLabel.Size = UDim2.new(1,-10,0,20); statusLabel.Position = UDim2.new(0,5,0,8)
    statusLabel.BackgroundTransparency = 1; statusLabel.Text = "Status: Standby"; statusLabel.TextColor3 = Color3.fromRGB(200,200,200); statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham; statusLabel.ZIndex = 103; statusLabel.Parent = content
    local eventLabel = Instance.new("TextLabel"); eventLabel.Size = UDim2.new(1,-10,0,20); eventLabel.Position = UDim2.new(0,5,0,34)
    eventLabel.BackgroundTransparency = 1; eventLabel.Text = "Event: Megalodon Hunt"; eventLabel.TextColor3 = Color3.fromRGB(200,200,200); eventLabel.TextSize = 11
    eventLabel.Font = Enum.Font.Gotham; eventLabel.ZIndex = 103; eventLabel.Parent = content
    local toggleBtn = Instance.new("TextButton"); toggleBtn.Size = UDim2.new(1,-10,0,34); toggleBtn.Position = UDim2.new(0,5,1,-40)
    toggleBtn.BackgroundColor3 = state.autoEventActive and Color3.fromRGB(60,20,20) or Color3.fromRGB(20,60,30)
    toggleBtn.Text = state.autoEventActive and "⏹ Matikan Auto Event" or "▶ Aktifkan Auto Event"
    toggleBtn.TextColor3 = Color3.fromRGB(255,255,255); toggleBtn.TextSize = 12; toggleBtn.Font = Enum.Font.GothamBold; toggleBtn.ZIndex = 103
    toggleBtn.AutoButtonColor = false; toggleBtn.Parent = content; Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,5)
    toggleBtn.MouseButton1Click:Connect(function()
        if state.autoEventActive then
            stopAutoEvent()
            toggleBtn.Text = "▶ Aktifkan Auto Event"; toggleBtn.BackgroundColor3 = Color3.fromRGB(20,60,30)
            statusLabel.Text = "Status: Standby"
        else
            startAutoEvent()
            toggleBtn.Text = "⏹ Matikan Auto Event"; toggleBtn.BackgroundColor3 = Color3.fromRGB(60,20,20)
            statusLabel.Text = "Status: Monitoring..."
        end
    end)
    task.spawn(function() while true do
        if state.autoEventActive then if state.isAtEvent then statusLabel.Text = "Status: Di lokasi event" else statusLabel.Text = "Status: Monitoring..." end end
        task.wait(1)
    end end)
    return content
end

-- ========== TAB WEBHOOK (STATE SYNC) ==========
local function buildWebhookTab()
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,1,0); content.BackgroundTransparency = 1; content.ZIndex = 101
    local y = 4
    local urlLabel = Instance.new("TextLabel"); urlLabel.Size = UDim2.new(0,50,0,20); urlLabel.Position = UDim2.new(0,8,0,y); urlLabel.BackgroundTransparency = 1
    urlLabel.Text = "URL:"; urlLabel.TextColor3 = Color3.fromRGB(200,200,200); urlLabel.TextSize = 10; urlLabel.Font = Enum.Font.Gotham; urlLabel.ZIndex = 103; urlLabel.Parent = content
    local urlInput = Instance.new("TextBox"); urlInput.Size = UDim2.new(1,-70,0,20); urlInput.Position = UDim2.new(0,58,0,y)
    urlInput.BackgroundColor3 = Color3.fromRGB(30,30,40); urlInput.BorderSizePixel = 0; urlInput.Text = state.webhookUrl; urlInput.PlaceholderText = "Tempel URL Webhook..."
    urlInput.TextColor3 = Color3.fromRGB(255,255,255); urlInput.TextSize = 9; urlInput.Font = Enum.Font.Code; urlInput.ZIndex = 103; urlInput.Parent = content
    Instance.new("UICorner", urlInput).CornerRadius = UDim.new(0,4)
    urlInput.FocusLost:Connect(function() state.webhookUrl = urlInput.Text:gsub("%s+",""); urlInput.Text = state.webhookUrl end)
    y = y + 24
    local whToggleBtn = Instance.new("TextButton"); whToggleBtn.Size = UDim2.new(1,-16,0,26); whToggleBtn.Position = UDim2.new(0,8,0,y)
    whToggleBtn.BackgroundColor3 = state.webhookEnabled and Color3.fromRGB(20,60,30) or Color3.fromRGB(60,20,20)
    whToggleBtn.Text = state.webhookEnabled and "⏹ Nonaktifkan Webhook" or "▶ Aktifkan Webhook"
    whToggleBtn.TextColor3 = Color3.fromRGB(255,255,255); whToggleBtn.TextSize = 11; whToggleBtn.Font = Enum.Font.GothamBold; whToggleBtn.ZIndex = 103
    whToggleBtn.AutoButtonColor = false; whToggleBtn.Parent = content; Instance.new("UICorner", whToggleBtn).CornerRadius = UDim.new(0,5)
    whToggleBtn.MouseButton1Click:Connect(function()
        if state.webhookUrl == "" then return end
        if not isValidWebhookURL(state.webhookUrl) then return end
        state.webhookEnabled = not state.webhookEnabled
        if state.webhookEnabled then whToggleBtn.Text = "⏹ Nonaktifkan Webhook"; whToggleBtn.BackgroundColor3 = Color3.fromRGB(20,60,30)
        else whToggleBtn.Text = "▶ Aktifkan Webhook"; whToggleBtn.BackgroundColor3 = Color3.fromRGB(60,20,20) end
    end)
    y = y + 30
    local function makeWebhookToggle(yy, label, stateKey)
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,-16,0,26); btn.Position = UDim2.new(0,8,0,yy)
        btn.BackgroundColor3 = state[stateKey] and Color3.fromRGB(20,60,30) or Color3.fromRGB(60,20,20)
        btn.Text = state[stateKey] and ("⏹ " .. label) or ("▶ " .. label)
        btn.TextColor3 = Color3.fromRGB(255,255,255); btn.TextSize = 10; btn.Font = Enum.Font.GothamBold; btn.ZIndex = 103
        btn.AutoButtonColor = false; btn.Parent = content; Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)
        btn.MouseButton1Click:Connect(function()
            if not state.webhookEnabled then return end
            state[stateKey] = not state[stateKey]
            if state[stateKey] then btn.Text = "⏹ " .. label; btn.BackgroundColor3 = Color3.fromRGB(20,60,30)
            else btn.Text = "▶ " .. label; btn.BackgroundColor3 = Color3.fromRGB(60,20,20) end
        end)
        return btn
    end
    makeWebhookToggle(y, "🧬 Mutation Mode + GS Ruby", "mutationEnabled"); y = y + 30
    makeWebhookToggle(y, "👥 Join & Left Mode", "joinLeftEnabled"); y = y + 30
    makeWebhookToggle(y, "⭐ Evolved Enchant Mode", "evolvedEnabled"); y = y + 30
    makeWebhookToggle(y, "🐟 SC & Forgotten Mode", "scEnabled")
    return content
end

-- ========== CREATE TABS ==========
local blapetTabBtn = createTabButton("Blapet Auto", buildBlapetTab)
createTabButton("Walk to Loc", buildWalkToLocationTab)
createTabButton("Walk to Player", buildWalkToPlayerTab)
createTabButton("Saved Pos", buildSavedPositionsTab)
createTabButton("Auto Event", buildAutoEventTab)
createTabButton("Webhook", buildWebhookTab)

blapetTabBtn.BackgroundColor3 = Color3.fromRGB(60,60,20)
buildBlapetTab().Parent = contentFrame

-- ========== DRAG ==========
local floatDragging, floatDragStart, floatStartPos = false, nil, nil
floatBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        floatDragging = true; floatDragStart = inp.Position; floatStartPos = floatBtn.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if floatDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - floatDragStart; local vp = workspace.CurrentCamera.ViewportSize
        floatBtn.Position = UDim2.new(0, math.clamp(floatStartPos.X.Offset + delta.X, 0, vp.X - 46), 0, math.clamp(floatStartPos.Y.Offset + delta.Y, 0, vp.Y - 46))
    end
end)
UIS.InputEnded:Connect(function(inp) floatDragging = false end)

local dragging, dragStart, startPos = false, nil, nil
frame.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = inp.Position; startPos = frame.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(inp) dragging = false end)

print("ZHXHub Full Project v2.0.")
