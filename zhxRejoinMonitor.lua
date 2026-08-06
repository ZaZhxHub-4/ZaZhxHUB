-- // Script Tester Koneksi Delta ke APK Rejoiner
-- // Akan mencoba berbagai metode dan menulis hasil ke file debug

local HttpService = game:GetService("HttpService")
local LP = game:GetService("Players").LocalPlayer
local USERNAME = LP.Name
local DEBUG_FILE = "zhx_connection_test.txt"

local function log(msg)
    local existing = ""
    pcall(function()
        if isfile and isfile(DEBUG_FILE) then
            existing = readfile(DEBUG_FILE) or ""
        end
    end)
    pcall(function()
        writefile(DEBUG_FILE, existing .. os.date("%H:%M:%S") .. " | " .. msg .. "\n")
    end)
end

log("========== MEMULAI TEST KONEKSI ==========")
log("Username: " .. USERNAME)

-- Daftar lokasi file IP yang mungkin
local IP_FILES = {
    "/data/local/tmp/zhx_apk_ip.txt",
    "/storage/emulated/0/Delta/Workspace/zhx_apk_ip.txt",
    "/storage/emulated/0/zhx_apk_ip.txt"
}

local APK_IP = nil

-- Baca IP dari semua kemungkinan file
log("\n-- Mencari file IP --")
for _, file in ipairs(IP_FILES) do
    local ok, content = pcall(function()
        if isfile and isfile(file) then
            return readfile(file)
        end
        return nil
    end)
    if ok and content then
        local ip = content:gsub("%s+", "")
        if ip ~= "" then
            APK_IP = ip
            log("✅ IP ditemukan di " .. file .. " : " .. ip)
            break
        end
    else
        log("❌ Tidak ditemukan di " .. file)
    end
end

if not APK_IP then
    APK_IP = "127.0.0.1"
    log("⚠ Tidak ada file IP! Gunakan default: " .. APK_IP)
end

-- Port yang akan dicoba
local PORTS = {8080, 80, 9090}

-- Data yang akan dikirim
local BODY = HttpService:JSONEncode({
    username = USERNAME,
    action = "heartbeat"
})

log("\n-- Menguji metode HTTP --")

-- ==================== METODE 1: request() ====================
log("\n[Metode 1: request()]")
for _, port in ipairs(PORTS) do
    local url = "http://" .. APK_IP .. ":" .. port .. "/report"
    log("  Mencoba " .. url)
    local ok, err = pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = BODY,
        })
    end)
    if ok then
        log("  ✅ request() SUKSES ke port " .. port .. "!")
        break
    else
        log("  ❌ request() GAGAL ke port " .. port .. ": " .. tostring(err))
    end
end

-- ==================== METODE 2: HttpService (blocking, pake spawn) ====================
log("\n[Metode 2: HttpService:PostAsync dengan spawn]")
for _, port in ipairs(PORTS) do
    local url = "http://" .. APK_IP .. ":" .. port .. "/report"
    log("  Mencoba " .. url)
    local ok, err = pcall(function()
        HttpService:PostAsync(url, BODY)
    end)
    if ok then
        log("  ✅ HttpService SUKSES ke port " .. port .. "!")
        break
    else
        log("  ❌ HttpService GAGAL ke port " .. port .. ": " .. tostring(err))
    end
end

-- ==================== METODE 3: syn.request (jika ada) ====================
log("\n[Metode 3: syn.request]")
if syn and syn.request then
    for _, port in ipairs(PORTS) do
        local url = "http://" .. APK_IP .. ":" .. port .. "/report"
        log("  Mencoba " .. url)
        local ok, err = pcall(function()
            syn.request({
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = BODY,
            })
        end)
        if ok then
            log("  ✅ syn.request SUKSES ke port " .. port .. "!")
            break
        else
            log("  ❌ syn.request GAGAL ke port " .. port .. ": " .. tostring(err))
        end
    end
else
    log("  ⏭ syn.request tidak tersedia")
end

-- ==================== METODE 4: http_request (beberapa executor) ====================
log("\n[Metode 4: http_request]")
if http_request then
    for _, port in ipairs(PORTS) do
        local url = "http://" .. APK_IP .. ":" .. port .. "/report"
        log("  Mencoba " .. url)
        local ok, err = pcall(function()
            http_request({
                url = url,
                method = "POST",
                headers = {["Content-Type"] = "application/json"},
                body = BODY,
            })
        end)
        if ok then
            log("  ✅ http_request SUKSES ke port " .. port .. "!")
            break
        else
            log("  ❌ http_request GAGAL ke port " .. port .. ": " .. tostring(err))
        end
    end
else
    log("  ⏭ http_request tidak tersedia")
end

-- ==================== METODE 5: http.post (beberapa executor) ====================
log("\n[Metode 5: http.post]")
if http and http.post then
    for _, port in ipairs(PORTS) do
        local url = "http://" .. APK_IP .. ":" .. port .. "/report"
        log("  Mencoba " .. url)
        local ok, err = pcall(function()
            http.post(url, BODY, "application/json")
        end)
        if ok then
            log("  ✅ http.post SUKSES ke port " .. port .. "!")
            break
        else
            log("  ❌ http.post GAGAL ke port " .. port .. ": " .. tostring(err))
        end
    end
else
    log("  ⏭ http.post tidak tersedia")
end

log("\n========== TEST SELESAI ==========")
log("Cek file ini untuk hasil lengkap.")
