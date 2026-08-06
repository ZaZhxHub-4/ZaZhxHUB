-- // Simple HTTP Test ke 10.12.99.193:8080
local HttpService = game:GetService("HttpService")
local USERNAME = game:GetService("Players").LocalPlayer.Name
local APK_IP = "10.12.99.193"
local APK_PORT = 8080
local APK_URL = "http://" .. APK_IP .. ":" .. APK_PORT .. "/report"

local function log(msg)
    pcall(function()
        local f = "zhx_direct_test.txt"
        local old = (isfile and isfile(f)) and readfile(f) or ""
        writefile(f, old .. os.date("%H:%M:%S") .. " | " .. msg .. "\n")
    end)
end

log("Target: " .. APK_URL)
log("Username: " .. USERNAME)

local body = HttpService:JSONEncode({ username = USERNAME, action = "heartbeat" })

-- Metode 1: request() di task.spawn
task.spawn(function()
    local ok, err = pcall(function()
        request({
            Url = APK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = body,
        })
    end)
    log("request() -> " .. (ok and "SUKSES" or "GAGAL: " .. tostring(err)))
end)

-- Metode 2: HttpService (dipanggil langsung oleh Delta, mungkin butuh detik awal)
task.spawn(function()
    local ok, err = pcall(function()
        HttpService:PostAsync(APK_URL, body)
    end)
    log("HttpService -> " .. (ok and "SUKSES" or "GAGAL: " .. tostring(err)))
end)
