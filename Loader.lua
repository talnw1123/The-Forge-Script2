--[[
    ████████╗██╗  ██╗███████╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
    ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
       ██║   ███████║█████╗      █████╗  ██║   ██║██████╔╝██║  ███╗█████╗  
       ██║   ██╔══██║██╔══╝      ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  
       ██║   ██║  ██║███████╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
       ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
    
    🔥 MODULAR QUEST LOADER
    📦 Auto-loads quests from GitHub based on active quest detection
    
    Usage: loadstring(game:HttpGet("YOUR_GITHUB_RAW_URL/Loader.lua"))()
--]]

repeat task.wait(1) until game:IsLoaded()

----------------------------------------------------------------
-- ⚙️ CONFIGURATION
----------------------------------------------------------------
local CONFIG = {
    -- 🔗 GitHub Raw URL (เปลี่ยนเป็น URL ของคุณ)
    GITHUB_BASE_URL = "https://raw.githubusercontent.com/talnw1123/The-Forge-Script2/refs/heads/main/",
    
    -- ⏱️ Timing
    INITIAL_WAIT = 1,          -- รอเริ่มต้น (วินาที)
    QUEST_CHECK_INTERVAL = 2,    -- เช็ค Quest ใหม่ทุกกี่วินาที
    
    -- 🎮 Quest Range
    MIN_QUEST = 1,
    MAX_QUEST = 18,
    
    -- 🔧 Debug
    DEBUG_MODE = true,
    
    -- 🚀 Optimization
    LOAD_FPS_BOOSTER = true,
    
    -- 🛡️ Anti-AFK
    ANTI_AFK_ENABLED = true,
    ANTI_AFK_INTERVAL = 120,   -- ทุกๆ 2 นาที
    ANTI_AFK_CLICK_COUNT = 5,  -- จำนวนคลิกต่อรอบ
}

----------------------------------------------------------------
-- 📦 LOAD SHARED UTILITIES
----------------------------------------------------------------
print("=" .. string.rep("=", 59))
print("🔥 THE FORGE - MODULAR QUEST LOADER")
print("=" .. string.rep("=", 59))

print("\n⏳ Initial wait: " .. CONFIG.INITIAL_WAIT .. " seconds...")
task.wait(CONFIG.INITIAL_WAIT)

print("\n📦 Loading Shared Utilities...")
local sharedUrl = CONFIG.GITHUB_BASE_URL .. "Shared.lua"
local sharedSuccess, sharedError = pcall(function()
    loadstring(game:HttpGet(sharedUrl))()
end)

if not sharedSuccess then
    warn("❌ Failed to load Shared.lua: " .. tostring(sharedError))
    warn("💡 Make sure the URL is correct: " .. sharedUrl)
    return
end

print("✅ Shared utilities loaded!")

-- ตรวจสอบว่า Shared โหลดสำเร็จ
if not _G.Shared then
    warn("❌ _G.Shared not found after loading Shared.lua")
    return
end

local Shared = _G.Shared

----------------------------------------------------------------
-- 🚀 LOAD FPS BOOSTER
----------------------------------------------------------------
if CONFIG.LOAD_FPS_BOOSTER then
    print("\n🚀 Loading FPS Booster...")
    local fpsUrl = CONFIG.GITHUB_BASE_URL .. "Utils/FPSBooster.lua"
    local fpsSuccess, fpsError = pcall(function()
        loadstring(game:HttpGet(fpsUrl))()
    end)
    
    if fpsSuccess then
        print("✅ FPS Booster loaded!")
    else
        warn("⚠️ Failed to load FPS Booster: " .. tostring(fpsError))
    end
end

----------------------------------------------------------------
-- 🛡️ ANTI-AFK SYSTEM
----------------------------------------------------------------
if CONFIG.ANTI_AFK_ENABLED then
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local GuiService = game:GetService("GuiService")
    local camera = workspace.CurrentCamera
    
    local function performAntiAfkClicks()
        local viewportSize = camera.ViewportSize
        local guiInset = GuiService:GetGuiInset()
        local centerX = viewportSize.X / 2
        local centerY = (viewportSize.Y / 2) + guiInset.Y
        
        print("🛡️ [ANTI-AFK] Performing " .. CONFIG.ANTI_AFK_CLICK_COUNT .. " virtual clicks...")
        
        for i = 1, CONFIG.ANTI_AFK_CLICK_COUNT do
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
            
            if i < CONFIG.ANTI_AFK_CLICK_COUNT then
                task.wait(0.5)
            end
        end
        
        print("🛡️ [ANTI-AFK] Clicks complete! Next in " .. CONFIG.ANTI_AFK_INTERVAL .. " seconds.")
    end
    
    task.spawn(function()
        print("🛡️ [ANTI-AFK] System started! Clicking every " .. CONFIG.ANTI_AFK_INTERVAL .. " seconds.")
        while true do
            task.wait(CONFIG.ANTI_AFK_INTERVAL)
            pcall(performAntiAfkClicks)
        end
    end)
end

----------------------------------------------------------------
-- � QUEST 15 BACKGROUND (Auto Claim Index)
----------------------------------------------------------------
-- Start immediately, run every 10 seconds
local quest15Running = false

local function startQuest15Background()
    if quest15Running then return end
    quest15Running = true
    
    task.spawn(function()
        print("\n🐉 Starting Quest 15 (Auto Claim Index) in BACKGROUND...")
        print("   ⏰ Running every 10 seconds")
        
        while quest15Running do
            pcall(function()
                loadQuest(15)
            end)
            
            task.wait(10)  -- Run every 10 seconds
        end
    end)
end

-- Start Quest 15 Background immediately
startQuest15Background()

----------------------------------------------------------------
-- �🔍 QUEST DETECTION SYSTEM
----------------------------------------------------------------
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function getActiveQuestNumber()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return nil end
    
    -- หา Quest ที่ active อยู่
    for _, child in ipairs(list:GetChildren()) do
        local id = string.match(child.Name, "^Introduction(%d+)Title$")
        if id and child:FindFirstChild("Frame") and child.Frame:FindFirstChild("TextLabel") then
            local questName = child.Frame.TextLabel.Text
            local questNum = tonumber(id) + 1
            
            if questNum and questName ~= "" then
                -- เช็คว่า quest ยังไม่เสร็จ
                local objList = list:FindFirstChild("Introduction" .. id .. "List")
                if objList then
                    for _, item in ipairs(objList:GetChildren()) do
                        if item:IsA("Frame") and tonumber(item.Name) then
                            local check = item:FindFirstChild("Main") 
                                and item.Main:FindFirstChild("Frame") 
                                and item.Main.Frame:FindFirstChild("Check")
                            if check and not check.Visible then
                                -- พบ objective ที่ยังไม่เสร็จ
                                return questNum, questName
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

local function isQuestComplete(questNum)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return true end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return true end
    
    -- Convert 1-based QuestNum back to 0-based UI ID
    local uiID = questNum - 1
    local objList = list:FindFirstChild("Introduction" .. uiID .. "List")
    if not objList then return true end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            local check = item:FindFirstChild("Main") 
                and item.Main:FindFirstChild("Frame") 
                and item.Main.Frame:FindFirstChild("Check")
            if check and not check.Visible then
                return false
            end
        end
    end
    
    return true
end

----------------------------------------------------------------
-- 📥 QUEST LOADER
----------------------------------------------------------------
local loadedQuests = {}

local function loadQuest(questNum)
    local questFile = string.format("Quest%02d.lua", questNum)
    local questUrl = CONFIG.GITHUB_BASE_URL .. "Quests/" .. questFile
    
    print(string.format("\n📥 Loading %s from GitHub...", questFile))
    print("   URL: " .. questUrl)
    
    local success, result = pcall(function()
        local code = game:HttpGet(questUrl)
        local func = loadstring(code)
        if func then
            return func()
        else
            error("Failed to compile quest code")
        end
    end)
    
    if success then
        print(string.format("✅ %s loaded successfully!", questFile))
        loadedQuests[questNum] = true
        return true
    else
        warn(string.format("❌ Failed to load %s: %s", questFile, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- 🎮 MAIN QUEST RUNNER
----------------------------------------------------------------
local function runQuestLoop()
    print("\n" .. string.rep("=", 60))
    print("🎮 STARTING AUTO QUEST RUNNER")
    print(string.rep("=", 60))
    
    local currentQuest = CONFIG.MIN_QUEST
    local maxAttempts = 3
    local reachedQuest18 = false
    local quest13Run = false  -- Track Quest 13 execution
    
    -- เช็คว่าเริ่มที่ Quest 18 หรือยัง
    local activeNum, _ = getActiveQuestNumber()
    if activeNum and activeNum >= 18 then
        reachedQuest18 = true
        print("\n🌋 Quest 18 detected! Skipping Quest 1-17 checks...")
    end
    
    while currentQuest <= CONFIG.MAX_QUEST do
        -- ถ้าถึง Quest 18 แล้ว ให้ skip ไป Quest 18 เลย
        if reachedQuest18 and currentQuest < 18 then
            currentQuest = 18
            continue
        end
        
        -- ============================================
        -- 🛠️ CUSTOM QUEST LOGIC (13, 14, 17, 18)
        -- ไม่เช็ค UI, รันตาม internal logic
        -- ============================================
        if currentQuest == 13 then
            -- Quest 13: Run once per session
            if not quest13Run then
                print("\n🎵 Loading Quest 13 (Bard Quest) [Run Once Per Session]...")
                loadQuest(13)
                quest13Run = true
            else
                print("   ⏭️ Quest 13 already ran this session, skipping.")
            end
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 14 then
            -- Quest 14: Lost Guitar (internal check, uses BardQuest not Introduction{N})
            print("\n🎸 Loading Quest 14 (Lost Guitar)...")
            loadQuest(14)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 17 then
            -- Quest 17: Auto mining until level 10 (internal check)
            print("\n⛏️ Loading Quest 17 (Auto Mining Until Level 10)...")
            loadQuest(17)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 18 then
            -- Quest 18: Smart mining (internal check)
            print("\n🌋 Loading Quest 18 (Smart Mining)...")
            loadQuest(18)
            break  -- Quest 18 is infinite loop
        end
        
        -- ============================================
        -- 📋 STANDARD UI-BASED QUEST LOGIC (1-12, 15-16)
        -- ============================================
        print(string.format("\n🔍 Checking Quest %d...", currentQuest))
        
        -- เช็คว่า Quest นี้ active หรือยัง
        activeNum, activeName = getActiveQuestNumber()
        
        if activeNum then
            print(string.format("   📋 Active Quest: #%d - %s", activeNum, activeName or "Unknown"))
            
            -- ถ้าถึง Quest 18 ให้ mark ว่าไม่ต้องเช็ค Quest เก่าอีก
            if activeNum >= 18 then
                reachedQuest18 = true
            end
            
            -- โหลดและรัน Quest
            local attempts = 0
            while attempts < maxAttempts do
                attempts = attempts + 1
                print(string.format("\n🚀 Running Quest %d (Attempt %d/%d)...", activeNum, attempts, maxAttempts))
                
                local success = loadQuest(activeNum)
                
                if success then
                    -- รอให้ Quest เสร็จ
                    print("   ⏳ Waiting for quest to complete...")
                    
                    local timeout = 600  -- 10 นาที timeout
                    local startTime = tick()
                    
                    while not isQuestComplete(activeNum) and (tick() - startTime) < timeout do
                        task.wait(CONFIG.QUEST_CHECK_INTERVAL)
                    end
                    
                    if isQuestComplete(activeNum) then
                        print(string.format("✅ Quest %d Complete!", activeNum))
                        break
                    else
                        warn(string.format("⏰ Quest %d timed out!", activeNum))
                    end
                else
                    warn(string.format("❌ Failed to load Quest %d", activeNum))
                    task.wait(5)
                end
            end
            
            currentQuest = activeNum + 1
        else
            print("   ⚠️ No active quest found, checking next...")
            currentQuest = currentQuest + 1
        end
        
        task.wait(2)
    end
    
    -- ============================================
    -- 🌋 QUEST 18 INFINITE LOOP MODE
    -- ============================================
    if reachedQuest18 then
        print("\n" .. string.rep("=", 60))
        print("🌋 QUEST 18 - INFINITE FARMING MODE")
        print("   ⚠️ Will NOT check Quest 1-17 anymore")
        print("   🐉 Quest 15 running in background")
        print(string.rep("=", 60))
        
        local loopCount = 0
        
        while true do
            loopCount = loopCount + 1
            print(string.format("\n🔄 Quest 18 Loop #%d", loopCount))
            
            -- รัน Quest 18
            local success = loadQuest(18)
            
            if success then
                -- รอให้ Quest 18 เสร็จ (ถ้าเสร็จได้)
                local timeout = 300  -- 5 นาที
                local startTime = tick()
                
                while not isQuestComplete(18) and (tick() - startTime) < timeout do
                    task.wait(5)
                end
            end
            
            -- รอก่อน loop ใหม่
            task.wait(5)
        end
    else
        print("\n" .. string.rep("=", 60))
        print("🎉 ALL QUESTS COMPLETED!")
        print(string.rep("=", 60))
    end
end

----------------------------------------------------------------
-- 🚀 START
----------------------------------------------------------------
-- Wait for UI to load
print("\n⏳ Waiting for Quest UI to load...")
local uiReady = false
for i = 1, 5 do
    local activeNum = getActiveQuestNumber()
    if activeNum then
        uiReady = true
        print(string.format("✅ Quest UI ready! Active Quest: #%d", activeNum))
        break
    end
    task.wait(1)
end

if not uiReady then
    warn("⚠️ Quest UI not detected, starting anyway...")
end

-- Start quest loop
runQuestLoop()
