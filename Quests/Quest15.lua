local Shared = _G.Shared

-- QUEST 15: Auto Claim Index (Codex System)
-- ✅ Check Gold from PlayerGui.Main.Screen.Hud.Gold
-- ✅ If Gold < 3340 → Auto Claim all Index items
-- ✅ Claim Ores, Enemies, Equipments
-- ✅ Supports both List and Direct Item formats

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest15Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Auto Claim Index",
    MIN_GOLD = 3340,  -- If Gold < 3340, start claiming
    
    CLAIM_DELAY = 0.5,  -- Delay after each claim (seconds)
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local CodexService = nil

pcall(function()
    CodexService = Knit.GetService("CodexService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local CLAIM_ORE_RF = nil
pcall(function()
    CLAIM_ORE_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimOre", 3)
end)

local CLAIM_ENEMY_RF = nil
pcall(function()
    CLAIM_ENEMY_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimEnemy", 3)
end)

local CLAIM_EQUIPMENT_RF = nil
pcall(function()
    CLAIM_EQUIPMENT_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimEquipment", 3)
end)

if CodexService then print("✅ CodexService Ready!") else warn("⚠️ CodexService not found") end
if CLAIM_ORE_RF then print("✅ ClaimOre Remote Ready!") else warn("⚠️ ClaimOre Remote not found") end
if CLAIM_ENEMY_RF then print("✅ ClaimEnemy Remote Ready!") else warn("⚠️ ClaimEnemy Remote not found") end
if CLAIM_EQUIPMENT_RF then print("✅ ClaimEquipment Remote Ready!") else warn("⚠️ ClaimEquipment Remote not found") end

----------------------------------------------------------------
-- GOLD SYSTEM
----------------------------------------------------------------
local function getPlayerGold()
    -- Path: PlayerGui.Main.Screen.Hud.Gold
    local goldLabel = playerGui:FindFirstChild("Main")
                     and playerGui.Main:FindFirstChild("Screen")
                     and playerGui.Main.Screen:FindFirstChild("Hud")
                     and playerGui.Main.Screen.Hud:FindFirstChild("Gold")
    
    if not goldLabel then
        return nil
    end
    
    if not goldLabel:IsA("TextLabel") then
        return nil
    end
    
    local goldText = goldLabel.Text
    
    -- Extract Gold from text (e.g., "$3,722.72" → 3722.72)
    local goldString = string.gsub(goldText, "[$,]", "")
    local gold = tonumber(goldString)
    
    return gold
end


----------------------------------------------------------------
-- INDEX UI HELPERS
----------------------------------------------------------------
local function getIndexUI()
    local indexUI = playerGui:FindFirstChild("Menu")
                   and playerGui.Menu:FindFirstChild("Frame")
                   and playerGui.Menu.Frame:FindFirstChild("Frame")
                   and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                   and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Index")
    
    if not indexUI then
        return nil
    end
    
    return indexUI
end

local function getOresPage()
    local indexUI = getIndexUI()
    if not indexUI then return nil end
    
    local pages = indexUI:FindFirstChild("Pages")
    if not pages then return nil end
    
    local oresPage = pages:FindFirstChild("Ores")
    if not oresPage then return nil end
    
    return oresPage
end

local function getEnemiesPage()
    local indexUI = getIndexUI()
    if not indexUI then return nil end
    
    local pages = indexUI:FindFirstChild("Pages")
    if not pages then return nil end
    
    local enemiesPage = pages:FindFirstChild("Enemies")
    if not enemiesPage then return nil end
    
    local scrollingFrame = enemiesPage:FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return nil end
    
    return scrollingFrame
end

local function getEquipmentsPage()
    local indexUI = getIndexUI()
    if not indexUI then return nil end
    
    local pages = indexUI:FindFirstChild("Pages")
    if not pages then return nil end
    
    local equipmentsPage = pages:FindFirstChild("Equipments")
    if not equipmentsPage then return nil end
    
    local scrollingFrame = equipmentsPage:FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return nil end
    
    return scrollingFrame
end

----------------------------------------------------------------
-- ORE CLAIM SYSTEM
----------------------------------------------------------------
local function findClaimableOres()
    local claimableOres = {}
    
    local oresPage = getOresPage()
    if not oresPage then return claimableOres end
    
    -- Loop through Map Lists (e.g., "Iron Valley List")
    for _, child in ipairs(oresPage:GetChildren()) do
        if string.find(child.Name, "List$") then
            -- Loop through Ores in each Map
            for _, oreItem in ipairs(child:GetChildren()) do
                if oreItem:IsA("Frame") or oreItem:IsA("GuiObject") then
                    local main = oreItem:FindFirstChild("Main")
                    if main then
                        local claimButton = main:FindFirstChild("Claim")
                        if claimButton then
                            local oreName = oreItem.Name
                            table.insert(claimableOres, {
                                Name = oreName,
                                MapList = child.Name,
                                Frame = oreItem,
                            })
                        end
                    end
                end
            end
        end
    end
    
    return claimableOres
end

local function claimOre(oreName)
    if not CLAIM_ORE_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_ORE_RF:InvokeServer(oreName)
    end)
    
    if success then
        print(string.format("   ✅ Claimed: %s", oreName))
        return true
    else
        warn(string.format("   ❌ Failed to claim %s: %s", oreName, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- ENEMY CLAIM SYSTEM
----------------------------------------------------------------
local function findClaimableEnemies()
    local claimableEnemies = {}
    
    local enemiesPage = getEnemiesPage()
    if not enemiesPage then return claimableEnemies end
    
    -- Loop through Map Lists
    for _, child in ipairs(enemiesPage:GetChildren()) do
        if string.find(child.Name, "List$") then
            -- Loop through Enemies in each Map
            for _, enemyItem in ipairs(child:GetChildren()) do
                if enemyItem:IsA("Frame") or enemyItem:IsA("GuiObject") then
                    local main = enemyItem:FindFirstChild("Main")
                    if main then
                        local claimButton = main:FindFirstChild("Claim")
                        if claimButton then
                            local enemyName = enemyItem.Name
                            table.insert(claimableEnemies, {
                                Name = enemyName,
                                MapList = child.Name,
                                Frame = enemyItem,
                            })
                        end
                    end
                end
            end
        end
    end
    
    return claimableEnemies
end

local function claimEnemy(enemyName)
    if not CLAIM_ENEMY_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_ENEMY_RF:InvokeServer(enemyName)
    end)
    
    if success then
        print(string.format("   ✅ Claimed: %s", enemyName))
        return true
    else
        warn(string.format("   ❌ Failed to claim %s: %s", enemyName, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- EQUIPMENT CLAIM SYSTEM
----------------------------------------------------------------
local function findClaimableEquipments()
    local claimableEquipments = {}
    
    local equipmentsPage = getEquipmentsPage()
    if not equipmentsPage then return claimableEquipments end
    
    -- Loop through both Direct Items and Lists
    for _, child in ipairs(equipmentsPage:GetChildren()) do
        -- Case 1: List (e.g., "MediumHelmet List")
        if string.find(child.Name, "List$") then
            -- Loop through Equipment inside List
            for _, equipItem in ipairs(child:GetChildren()) do
                if equipItem:IsA("Frame") or equipItem:IsA("GuiObject") then
                    local main = equipItem:FindFirstChild("Main")
                    if main then
                        local claimButton = main:FindFirstChild("Claim")
                        if claimButton then
                            local equipName = equipItem.Name
                            table.insert(claimableEquipments, {
                                Name = equipName,
                                ListName = child.Name,
                                Frame = equipItem,
                            })
                        end
                    end
                end
            end
        else
            -- Case 2: Direct Item (e.g., "ColossalSword", "Gauntlet")
            if child:IsA("Frame") or child:IsA("GuiObject") then
                local main = child:FindFirstChild("Main")
                if main then
                    local claimButton = main:FindFirstChild("Claim")
                    if claimButton then
                        local equipName = child.Name
                        table.insert(claimableEquipments, {
                            Name = equipName,
                            ListName = nil,  -- Direct item, no list
                            Frame = child,
                        })
                    end
                end
            end
        end
    end
    
    return claimableEquipments
end

local function claimEquipment(equipmentName)
    if not CLAIM_EQUIPMENT_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_EQUIPMENT_RF:InvokeServer(equipmentName)
    end)
    
    if success then
        print(string.format("   ✅ Claimed: %s", equipmentName))
        return true
    else
        warn(string.format("   ❌ Failed to claim %s: %s", equipmentName, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- MAIN CLAIM EXECUTION
----------------------------------------------------------------
local function claimAllIndex()
    local totalClaimed = 0
    local totalFailed = 0
    
    -- 1. Claim Ores
    local claimableOres = findClaimableOres()
    for i, ore in ipairs(claimableOres) do
        local success = claimOre(ore.Name)
        if success then totalClaimed = totalClaimed + 1 else totalFailed = totalFailed + 1 end
        task.wait(QUEST_CONFIG.CLAIM_DELAY)
    end
    
    -- 2. Claim Enemies
    local claimableEnemies = findClaimableEnemies()
    for i, enemy in ipairs(claimableEnemies) do
        local success = claimEnemy(enemy.Name)
        if success then totalClaimed = totalClaimed + 1 else totalFailed = totalFailed + 1 end
        task.wait(QUEST_CONFIG.CLAIM_DELAY)
    end
    
    -- 3. Claim Equipments
    local claimableEquipments = findClaimableEquipments()
    for i, equipment in ipairs(claimableEquipments) do
        local success = claimEquipment(equipment.Name)
        if success then totalClaimed = totalClaimed + 1 else totalFailed = totalFailed + 1 end
        task.wait(QUEST_CONFIG.CLAIM_DELAY)
    end
    
    return totalClaimed > 0
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 15: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Auto Claim Index (Codex)")
print("✅ Strategy: Auto Claim All Index (No Gold Check)")
print(string.rep("=", 50))

-- Always claim (no Gold restriction)

-- If Gold < MIN_GOLD, Claim
local maxAttempts = 1
local attempt = 0

while Quest15Active and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Attempt #%d", attempt))
    
    local success = claimAllIndex()
    
    if success then
        print("\n✅ Claiming complete!")
        
        -- Check Gold after Claim
        task.wait(2)
        local newGold = getPlayerGold()
        if newGold then
            print(string.format("\n💰 New Gold: $%.2f", newGold))
        end
        
        break
    else
        warn("\n❌ No items claimed or all failed")
        break
    end
end

task.wait(1)

print("\n" .. string.rep("=", 50))
print("✅ Quest 15 Complete!")
print(string.rep("=", 50))

Quest15Active = false
