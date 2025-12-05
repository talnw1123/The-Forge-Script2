local _G = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"))
local Shared = _G.Shared

-- QUEST 9: "The First Upgrade!" (Auto Enhance to +3)
-- ✅ No need to Move to NPC
-- ✅ Use Enhance Equipment Remote directly
-- ✅ Loop Enhance until Quest is complete

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest9Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "The First Upgrade",
    TARGET_UPGRADE_LEVEL = 3,  -- Must enhance to +3
    ENHANCE_DELAY = 1.0,       -- Wait 1s between enhances
    MAX_ENHANCE_ATTEMPTS = 50, -- Prevent infinite loop
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local PlayerController = nil
local EnhanceService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    EnhanceService = Knit.GetService("EnhanceService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local ENHANCE_RF = nil
pcall(function()
    ENHANCE_RF = SERVICES:WaitForChild("EnhanceService", 5):WaitForChild("RF", 3):WaitForChild("EnhanceEquipment", 3)
end)

local FIND_EQUIPMENT_RF = nil
pcall(function()
    FIND_EQUIPMENT_RF = SERVICES:WaitForChild("EnhanceService", 5):WaitForChild("RF", 3):WaitForChild("FindEquipmentByGUID", 3)
end)

if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if EnhanceService then print("✅ EnhanceService Ready!") else warn("⚠️ EnhanceService not found") end
if ENHANCE_RF then print("✅ Enhance Remote Ready!") else warn("⚠️ Enhance Remote not found") end
if FIND_EQUIPMENT_RF then print("✅ FindEquipment Remote Ready!") else warn("⚠️ FindEquipment Remote not found") end

----------------------------------------------------------------
-- QUEST SYSTEM
----------------------------------------------------------------
local function getQuestObjectives(questName)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    
    local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                 and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
    if not list then return nil, nil end
    
    local questID = nil
    for _, child in ipairs(list:GetChildren()) do
        local id = string.match(child.Name, "^Introduction(%d+)Title$")
        if id and child:FindFirstChild("Frame") and child.Frame:FindFirstChild("TextLabel") then
            if child.Frame.TextLabel.Text == questName then
                questID = id
                break
            end
        end
    end
    
    if not questID then return nil, nil end
    
    local objList = list:FindFirstChild("Introduction" .. questID .. "List")
    return questID, objList
end

local function isObjectiveComplete(item)
    if not item then return false end
    local check = item:FindFirstChild("Main") and item.Main:FindFirstChild("Frame") and item.Main.Frame:FindFirstChild("Check")
    return check and check.Visible
end

local function getObjectiveText(item)
    local lbl = item:FindFirstChild("Main") and item.Main:FindFirstChild("TextLabel")
    return lbl and lbl.Text or ""
end

local function isQuest9StillActive()
    if not Quest9Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest9Active = false
        return false
    end
    
    return true
end

local function areAllObjectivesComplete()
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then return true end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            if not isObjectiveComplete(item) then
                return false
            end
        end
    end
    
    return true
end

----------------------------------------------------------------
-- EQUIPMENT HELPERS
----------------------------------------------------------------
local function getPlayerEquipments()
    if not PlayerController or not PlayerController.Replica then
        warn("   ⚠️ Replica not available!")
        return {}
    end
    
    local replica = PlayerController.Replica
    
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ⚠️ Equipments not found in Replica!")
        return {}
    end
    
    local equipments = replica.Data.Inventory.Equipments
    local items = {}
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type and item.GUID then
            -- No Pickaxe
            if not string.find(item.Type, "Pickaxe") then
                table.insert(items, {
                    ID = id,
                    GUID = item.GUID,
                    Type = item.Type,
                    Name = item.Name or item.Type,
                    Upgrade = item.Upgrade or 0,
                    Quality = item.Quality or 0,
                    Dmg = item.Dmg or 0,
                })
            end
        end
    end
    
    return items
end

local function findLowestUpgradeItem()
    local items = getPlayerEquipments()
    
    if #items == 0 then
        return nil, "No enhanceable items found!"
    end
    
    -- Sort by Upgrade (Ascending) -> Dmg (Ascending)
    table.sort(items, function(a, b)
        if a.Upgrade ~= b.Upgrade then
            return a.Upgrade < b.Upgrade
        else
            return a.Dmg < b.Dmg
        end
    end)
    
    return items[1], nil
end

local function getItemCurrentUpgrade(guid)
    if not FIND_EQUIPMENT_RF then return nil end
    
    local success, result = pcall(function()
        return FIND_EQUIPMENT_RF:InvokeServer(guid)
    end)
    
    if success and result and type(result) == "table" then
        return result.Upgrade or 0
    end
    
    return nil
end

----------------------------------------------------------------
-- ENHANCE SYSTEM
----------------------------------------------------------------
local function enhanceItem(guid)
    if not ENHANCE_RF then
        warn("   ❌ Enhance Remote not available!")
        return false, "Remote not available"
    end
    
    local success, result = pcall(function()
        return ENHANCE_RF:InvokeServer(guid)
    end)
    
    if success then
        if result == true or (type(result) == "table" and result.Success) then
            return true, "Success"
        elseif type(result) == "table" and result.Error then
            return false, result.Error
        else
            return false, "Unknown result"
        end
    else
        return false, tostring(result)
    end
end

local function printItemInfo(item)
    print(string.format("   🎯 Selected Item: %s", item.Name))
    print(string.format("      - Type: %s", item.Type))
    print(string.format("      - Current Upgrade: +%d", item.Upgrade))
    print(string.format("      - Dmg: %.1f", item.Dmg))
    print(string.format("      - Quality: %.1f", item.Quality))
    print(string.format("      - GUID: %s", item.GUID))
end

----------------------------------------------------------------
-- MAIN QUEST EXECUTION
----------------------------------------------------------------
local function doEnhanceToPlus3()
    print("⚡ Objective: Enhance Item to +3...")
    
    local targetItem, errorMsg = findLowestUpgradeItem()
    
    if not targetItem then
        warn("   ❌ ERROR: " .. errorMsg)
        return false
    end
    
    printItemInfo(targetItem)
    
    if targetItem.Upgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
        print(string.format("   ✅ Item already at +%d or higher!", targetItem.Upgrade))
        return true
    end
    
    print(string.format("\n   🔨 Starting Enhancement Loop (Target: +%d)...\n", QUEST_CONFIG.TARGET_UPGRADE_LEVEL))
    
    local enhanceCount = 0
    local successCount = 0
    local failCount = 0
    
    while isQuest9StillActive() and not areAllObjectivesComplete() do
        enhanceCount = enhanceCount + 1
        
        if enhanceCount > QUEST_CONFIG.MAX_ENHANCE_ATTEMPTS then
            warn(string.format("   ⚠️ Max attempts reached (%d)! Stopping...", QUEST_CONFIG.MAX_ENHANCE_ATTEMPTS))
            break
        end
        
        -- Check current level
        local currentUpgrade = getItemCurrentUpgrade(targetItem.GUID)
        
        if currentUpgrade then
            print(string.format("   📊 Current Status: +%d / +%d", currentUpgrade, QUEST_CONFIG.TARGET_UPGRADE_LEVEL))
            
            if currentUpgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
                print(string.format("   🎉 Target reached! Item is now +%d", currentUpgrade))
                break
            end
        end
        
        -- Try Enhance
        print(string.format("   ⚡ Enhance Attempt #%d...", enhanceCount))
        
        local success, result = enhanceItem(targetItem.GUID)
        
        if success then
            successCount = successCount + 1
            print(string.format("      ✅ Enhancement SUCCESS! (+%d successful)", successCount))
        else
            failCount = failCount + 1
            print(string.format("      ❌ Enhancement FAILED! (%s) (+%d failed)", result, failCount))
        end
        
        -- Check if quest is complete
        task.wait(0.5)
        if areAllObjectivesComplete() then
            print("\n   🎉 Quest objective completed!")
            break
        end
        
        -- Wait before next attempt
        print(string.format("   ⏸️  Waiting %.1fs before next attempt...\n", QUEST_CONFIG.ENHANCE_DELAY))
        task.wait(QUEST_CONFIG.ENHANCE_DELAY)
    end
    
    print("\n   📊 Enhancement Summary:")
    print(string.format("      - Total Attempts: %d", enhanceCount))
    print(string.format("      - Successful: %d", successCount))
    print(string.format("      - Failed: %d", failCount))
    
    -- Check final level
    local finalUpgrade = getItemCurrentUpgrade(targetItem.GUID)
    if finalUpgrade then
        print(string.format("      - Final Upgrade: +%d", finalUpgrade))
        
        if finalUpgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
            print("   ✅ Enhancement complete!")
            return true
        else
            warn(string.format("   ⚠️ Failed to reach +%d (current: +%d)", QUEST_CONFIG.TARGET_UPGRADE_LEVEL, finalUpgrade))
            return false
        end
    end
    
    return false
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 9: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Enhance Item to +" .. QUEST_CONFIG.TARGET_UPGRADE_LEVEL)
print("✅ Strategy: Remote-based Enhancement (No Movement)")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    Quest9Active = false
    return
end

print("✅ Quest found (ID: " .. questID .. ")")

print("\n" .. string.rep("=", 50))
print("⚙️  Quest Objectives:")
local objectiveCount = 0
for _, item in ipairs(objList:GetChildren()) do
    if item:IsA("Frame") and tonumber(item.Name) then
        objectiveCount = objectiveCount + 1
        local text = getObjectiveText(item)
        local complete = isObjectiveComplete(item)
        print(string.format("   %d. %s [%s]", objectiveCount, text, complete and "✅" or "⏳"))
    end
end
print(string.rep("=", 50))

if areAllObjectivesComplete() then
    print("\n✅ Quest already complete!")
    return
end

print("\n" .. string.rep("=", 50))
print("⚡ Starting Enhancement Process...")
print(string.rep("=", 50))

local success = doEnhanceToPlus3()

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 9 Complete!")
    print(string.rep("=", 50))
else
    if success then
        print("\n   ⚠️ Enhancement complete but quest not marked done")
        print("   💡 Try checking quest status manually")
    else
        warn("\n" .. string.rep("=", 50))
        warn("⚠️ Quest 9 incomplete - Enhancement failed")
        warn(string.rep("=", 50))
    end
end

Quest9Active = false
