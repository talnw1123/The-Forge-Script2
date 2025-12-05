local Shared = _G.Shared

-- QUEST 18: Smart Teleport & Mining + Auto Sell & Auto Buy (FIXED)
-- ✅ Priority 1: Smart Teleport (If on Island1)
-- ✅ Priority 2: Auto Sell Init (One-time setup)
-- ✅ Priority 3: Background Tasks (Auto Sell + Auto Buy - Always running)
-- ✅ Priority 4: Mining (Basalt Rock)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest18Active = true
local IsMiningActive = false
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Smart Teleport & Mining + Auto Sell & Buy",
    REQUIRED_LEVEL = 10,
    
    -- Priority 1: Teleport
    ISLAND_NAME = "Forgotten Kingdom",
    
    -- Priority 2: Auto Sell
    AUTO_SELL_ENABLED = true,
    AUTO_SELL_INTERVAL = 10,
    AUTO_SELL_NPC_NAME = "Greedy Cey",
    
    -- Priority 3: Auto Buy (Background)
    AUTO_BUY_ENABLED = true,
    AUTO_BUY_INTERVAL = 15,
    TARGET_PICKAXE = "Cobalt Pickaxe",
    MIN_GOLD_TO_BUY = 10000,
    SHOP_POSITION = Vector3.new(-165, 22, -111.7),
    
    -- Priority 4: Mining (Default: Basalt Rock)
    ROCK_NAME = "Basalt Rock",
    UNDERGROUND_OFFSET = 4,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,  
    STOP_DISTANCE = 2,
    
    MINING_PATHS = {
        "Island2CaveStart",
        "Island2CaveDanger1",
        "Island2CaveDanger2",
        "Island2CaveDanger3",
        "Island2CaveDanger4",
        "Island2CaveDangerClosed",
        "Island2CaveDeep",
        "Island2CaveLavaClosed",
        "Island2CaveMid",
    },
    
    -- Priority 4.5: Basalt Core (If have Cobalt Pickaxe)
    BASALT_CORE_CONFIG = {
        ROCK_NAME = "Basalt Core",
        MINING_PATHS = {
            "Island2CaveStart",
            "Island2CaveDanger1",
            "Island2CaveDanger2",
            "Island2CaveDanger3",
            "Island2CaveDanger4",
            "Island2CaveDangerClosed",
            "Island2CaveDeep",
            "Island2CaveLavaClosed",
            "Island2CaveMid",
        },
    },
    
    WAYPOINTS = {
        Vector3.new(-154.5, 39.1, 138.8),
        Vector3.new(11, 46.5, 124.2),
        Vector3.new(65, 74.2, -44),
    },
    
    WAYPOINT_STOP_DISTANCE = 5,
    MAX_ROCKS_TO_MINE = 99999999999999,
    HOLD_POSITION_AFTER_MINE = true,
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local CharacterService = nil
local PlayerController = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
end)

local ToolController = nil
local ToolActivatedFunc = nil

pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Name") == "ToolController" and rawget(v, "ToolActivated") then
                ToolController = v
                ToolActivatedFunc = v.ToolActivated
                break
            end
        end
    end
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PORTAL_RF = nil
pcall(function()
    PORTAL_RF = SERVICES:WaitForChild("PortalService", 5):WaitForChild("RF", 3):WaitForChild("TeleportToIsland", 3)
end)

local CHAR_RF = nil
pcall(function()
    CHAR_RF = SERVICES:WaitForChild("CharacterService", 5):WaitForChild("RF", 3):WaitForChild("EquipItem", 3)
end)

local TOOL_RF_BACKUP = nil
pcall(function()
    TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService", 5):WaitForChild("RF", 3):WaitForChild("ToolActivated", 3)
end)

local DIALOGUE_RF = nil
local DialogueRE = nil
pcall(function()
    local dialogueService = SERVICES:WaitForChild("DialogueService", 5)
    DIALOGUE_RF = dialogueService:WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
    DialogueRE = dialogueService:WaitForChild("RE", 3):WaitForChild("DialogueEvent", 3)
end)

local ProximityDialogueRF = nil
local PURCHASE_RF = nil
pcall(function()
    local proximityService = SERVICES:WaitForChild("ProximityService", 5)
    ProximityDialogueRF = proximityService:WaitForChild("RF", 3):WaitForChild("Dialogue", 3)
    PURCHASE_RF = proximityService:WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

local FORGES_FOLDER = Workspace:WaitForChild("Forges")
local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")

if PORTAL_RF then print("✅ Portal Remote Ready!") else warn("⚠️ Portal Remote not found") end
if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ToolController then print("✅ ToolController Ready!") else warn("⚠️ ToolController not found") end
if DIALOGUE_RF then print("✅ Dialogue Remote Ready!") else warn("⚠️ Dialogue Remote not found") end
if PURCHASE_RF then print("✅ Purchase Remote Ready!") else warn("⚠️ Purchase Remote not found") end

----------------------------------------------------------------
-- STATE MANAGEMENT
----------------------------------------------------------------
local State = {
    currentTarget = nil,
    targetDestroyed = false,
    hpWatchConn = nil,
    noclipConn = nil,
    moveConn = nil,
    positionLockConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
    
    autoSellTask = nil,
    autoBuyTask = nil,
    isPaused = false,
}

-- 🛡️ BLACKLIST for rocks that someone else is mining
-- Format: { [rockModel] = expireTime }
local OccupiedRocks = {}
local OCCUPIED_TIMEOUT = 10  -- Remove from blacklist after 10 seconds

local function isRockOccupied(rock)
    if not rock then return false end
    local expireTime = OccupiedRocks[rock]
    if not expireTime then return false end
    
    if tick() > expireTime then
        OccupiedRocks[rock] = nil
        return false
    end
    return true
end

local function markRockAsOccupied(rock)
    if not rock then return end
    OccupiedRocks[rock] = tick() + OCCUPIED_TIMEOUT
    print(string.format("   🚫 Added to blacklist for %d seconds: %s", OCCUPIED_TIMEOUT, rock.Name))
end

local function cleanupExpiredBlacklist()
    local now = tick()
    for rock, expireTime in pairs(OccupiedRocks) do
        if now > expireTime or not rock.Parent then
            OccupiedRocks[rock] = nil
        end
    end
end

local AutoSellInitialized = false

local function cleanupState()
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    State.currentTarget = nil
    State.targetDestroyed = false
    
    if ToolController then
        ToolController.holdingM1 = false
    end
end

----------------------------------------------------------------
-- GOLD SYSTEM
----------------------------------------------------------------
local function getGold()
    local goldLabel = playerGui:FindFirstChild("Main")
                     and playerGui.Main:FindFirstChild("Screen")
                     and playerGui.Main.Screen:FindFirstChild("Hud")
                     and playerGui.Main.Screen.Hud:FindFirstChild("Gold")
    
    if not goldLabel or not goldLabel:IsA("TextLabel") then
        return 0
    end
    
    local goldText = goldLabel.Text
    local goldString = string.gsub(goldText, "[$,]", "")
    local gold = tonumber(goldString)
    
    return gold or 0
end

----------------------------------------------------------------
-- INVENTORY CHECK
----------------------------------------------------------------
local function hasPickaxe(pickaxeName)
    -- Check UI: PlayerGui.Menu.Frame.Frame.Menus.Tools.Frame
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then
        if DEBUG_MODE then
            warn("[Q18] Menu not found → treat as NO pickaxe")
        end
        return false
    end

    local ok, toolsFrame = pcall(function()
        local f1    = menu:FindFirstChild("Frame")
        local f2    = f1 and f1:FindFirstChild("Frame")
        local menus = f2 and f2:FindFirstChild("Menus")
        local tools = menus and menus:FindFirstChild("Tools")
        local frame = tools and tools:FindFirstChild("Frame")
        return frame
    end)

    if not ok or not toolsFrame then
        if DEBUG_MODE then
            warn("[Q18] Tools.Frame not found → treat as NO pickaxe")
        end
        return false
    end

    -- Children in Frame are like "Iron Pickaxe", "Stone Pickaxe", "Cobalt Pickaxe"
    local gui = toolsFrame:FindFirstChild(pickaxeName)
    if gui then
        if DEBUG_MODE then
            local visible = gui:IsA("GuiObject") and gui.Visible or "N/A"
            print(string.format("[Q18] ✅ UI pickaxe '%s' found (Visible=%s)", pickaxeName, tostring(visible)))
        end
        return true
    end

    if DEBUG_MODE then
        print(string.format("[Q18] ⚠️ UI pickaxe '%s' NOT found", pickaxeName))
    end
    return false
end

----------------------------------------------------------------
-- FORCE CLOSE DIALOG
----------------------------------------------------------------
local function ForceEndDialogueAndRestore()
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then
            dUI.Enabled = false
            local bb = dUI:FindFirstChild("ResponseBillboard")
            if bb then bb.Visible = false end
        end
    end
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        cam.FieldOfView = 70
    end
    
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    tag:Destroy()
                end
            end
        end
        
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
    end
    
    if DialogueRE then
        pcall(function()
            DialogueRE:FireServer("Closed")
        end)
    end
end

----------------------------------------------------------------
-- NOCLIP & MOVEMENT
----------------------------------------------------------------
local function enableNoclip()
    if State.noclipConn then return end
    
    local char = player.Character
    if not char then return end
    
    State.noclipConn = RunService.Stepped:Connect(function()
        if not char or not char.Parent then
            if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
            return
        end
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
    -- restoreCollisions() -- Not defined in this scope, assuming handled by game or not needed
end

local function smoothMoveTo(targetPos, callback)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    enableNoclip()
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    State.bodyVelocity = bv
    
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 500
    bg.Parent = hrp
    State.bodyGyro = bg
    
    if DEBUG_MODE then
        print(string.format("   🚀 Moving to (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    end
    
    local reachedTarget = false
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if reachedTarget then return end
        
        -- Check if character or BodyVelocity is destroyed
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        -- Check if BodyVelocity was destroyed by game/other script
        if not bv or not bv.Parent then
            warn("   ⚠️ BodyVelocity destroyed! Recreating...")
            
            -- Recreate BodyVelocity
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            State.bodyVelocity = bv
        end
        
        if not bg or not bg.Parent then
            bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 10000
            bg.D = 500
            bg.Parent = hrp
            State.bodyGyro = bg
        end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < QUEST_CONFIG.STOP_DISTANCE then
            if DEBUG_MODE then
                print(string.format("   ✅ Reached! (%.1f)", distance))
            end
            
            reachedTarget = true
            
            bv.Velocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            
            task.wait(0.1)
            
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            
            if callback then callback() end
            return
        end
        
        local speed = math.min(QUEST_CONFIG.MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- AUTO SELL SYSTEM
----------------------------------------------------------------
local function getSellNPC()
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(QUEST_CONFIG.AUTO_SELL_NPC_NAME) or nil
end

local function getSellNPCPos()
    local npc = getSellNPC()
    if not npc then return nil end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function getStashBackground()
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then return nil end
    local f1 = menu:FindFirstChild("Frame")
    if not f1 then return nil end
    local f2 = f1:FindFirstChild("Frame")
    if not f2 then return nil end
    local menus = f2:FindFirstChild("Menus")
    if not menus then return nil end
    local stash = menus:FindFirstChild("Stash")
    if not stash then return nil end
    return stash:FindFirstChild("Background")
end

local function parseQty(text)
    if not text or text == "" then return 1 end
    local n = string.match(text, "x?(%d+)")
    return tonumber(n) or 1
end

local function getStashItemsUI()
    local bg = getStashBackground()
    if not bg then return {} end
    
    local basket = {}
    for _, child in ipairs(bg:GetChildren()) do
        if child:IsA("GuiObject") and not string.match(child.Name, "^UI") then
            local qty = 1
            local main = child:FindFirstChild("Main")
            if main then
                local q = main:FindFirstChild("Quantity")
                if q and q:IsA("TextLabel") and q.Visible then
                    qty = parseQty(q.Text)
                end
            end
            basket[child.Name] = qty
        end
    end
    return basket
end

local function initAutoSellWithNPC()
    if AutoSellInitialized then return true end
    
    print("\n" .. string.rep("=", 60))
    print("🔧 INITIALIZING AUTO SELL (ONE-TIME)")
    print(string.rep("=", 60))
    
    local npcPos = getSellNPCPos()
    if not npcPos then
        warn("   ❌ NPC not found: " .. QUEST_CONFIG.AUTO_SELL_NPC_NAME)
        return false
    end
    
    print(string.format("   ✅ Found %s at (%.1f, %.1f, %.1f)", 
        QUEST_CONFIG.AUTO_SELL_NPC_NAME, npcPos.X, npcPos.Y, npcPos.Z))
    
    print("   🚶 Moving to NPC...")
    
    local done = false
    smoothMoveTo(npcPos, function() done = true end)
    
    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end
    
    if not done then
        warn("   ❌ Failed to reach NPC (timeout)")
        return false
    end
    
    print("   ✅ Reached NPC!")
    task.wait(1)
    
    local npc = getSellNPC()
    if npc and ProximityDialogueRF then
        print("   💬 Opening dialog...")
        pcall(function()
            ProximityDialogueRF:InvokeServer(npc)
        end)
    end
    
    task.wait(2)
    
    print("   🚪 Closing dialog...")
    ForceEndDialogueAndRestore()
    
    task.wait(1)
    
    AutoSellInitialized = true
    
    print("\n" .. string.rep("=", 60))
    print("✅ AUTO SELL INITIALIZED!")
    print(string.rep("=", 60))
    
    return true
end

local function sellAllFromUI()
    if not DIALOGUE_RF then return end
    if not AutoSellInitialized then return end
    
    local basket = getStashItemsUI()
    local hasItem = false
    for _, v in pairs(basket) do
        if v > 0 then hasItem = true break end
    end
    
    if not hasItem then
        if DEBUG_MODE then print("AutoSell: no items") end
        return
    end
    
    local args = { "SellConfirm", { Basket = basket } }
    local ok, res = pcall(function()
        return DIALOGUE_RF:InvokeServer(unpack(args))
    end)
    
    if ok then
        print("💰 AutoSell: sold items!")
    else
        warn("AutoSell failed:", res)
    end
end

local function startAutoSellTask()
    if not QUEST_CONFIG.AUTO_SELL_ENABLED or not DIALOGUE_RF then
        return
    end
    
    print("🤖 Auto Sell Background Task Started!")
    
    State.autoSellTask = task.spawn(function()
        while Quest18Active do
            task.wait(QUEST_CONFIG.AUTO_SELL_INTERVAL)
            
            if not State.isPaused then
                pcall(sellAllFromUI)
            end
        end
    end)
end

----------------------------------------------------------------
-- AUTO BUY SYSTEM (Background)
----------------------------------------------------------------
local function purchasePickaxe(pickaxeName)
    if not PURCHASE_RF then
        warn("Purchase RF missing")
        return false
    end
    
    print(string.format("   🛒 Purchasing: %s", pickaxeName))
    
    local ok, res = pcall(function()
        return PURCHASE_RF:InvokeServer(pickaxeName, 1)
    end)
    
    if ok then
        print(string.format("   ✅ Purchased: %s!", pickaxeName))
        return true
    else
        warn(string.format("   ❌ Failed: %s", tostring(res)))
        return false
    end
end

local function unlockPosition()
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
        if DEBUG_MODE then
            print("   🔓 Position unlocked")
        end
    end
end

local function tryBuyPickaxe()
    local pickaxeName = QUEST_CONFIG.TARGET_PICKAXE or "Cobalt Pickaxe"

    -- 1) Check if already have Pickaxe
    if hasPickaxe(pickaxeName) then
        if DEBUG_MODE then
            print(string.format("[Q18] ✅ Already have %s - skip auto buy", pickaxeName))
        end
        return true
    end

    -- 2) Check Gold
    local gold = getGold()
    gold = gold or 0

    if gold < QUEST_CONFIG.MIN_GOLD_TO_BUY then
        if DEBUG_MODE then
            print(string.format(
                "[Q18] ⏸ Gold not enough for %s (have %d, need > %d)",
                pickaxeName,
                gold,
                QUEST_CONFIG.MIN_GOLD_TO_BUY
            ))
        end
        return false
    end

    -- 3) Pause mining and go to Shop
    print(string.format("\n🛒 [Q18] Auto Buy: Need %s! (Gold: %d)", pickaxeName, gold))

    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️  Pausing mining...")

        if ToolController then
            ToolController.holdingM1 = false
        end

        unlockPosition()
        task.wait(1)
    end

    -- 4) Move to Shop
    local shopPos = QUEST_CONFIG.SHOP_POSITION
    print(string.format("   🚶 Going to shop (%.1f, %.1f, %.1f)...",
        shopPos.X, shopPos.Y, shopPos.Z))

    local done = false
    smoothMoveTo(shopPos, function()
        done = true
    end)

    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end

    if not done then
        warn("   ⚠️ Failed to reach shop!")
        if wasMining then
            State.isPaused = false
        end
        return false
    end

    print("   ✅ Arrived at shop!")
    task.wait(1)

    -- 5) Purchase
    local purchased = purchasePickaxe(pickaxeName)

    if purchased then
        print("   ✅ Purchase complete!")
        task.wait(2)
    else
        warn("   ❌ Purchase failed!")
    end

    -- 6) Resume Mining
    if wasMining then
        print("   ▶️  Resuming mining...")
        State.isPaused = false
    end

    return purchased
end

local function startAutoBuyTask()
    if not QUEST_CONFIG.AUTO_BUY_ENABLED or not PURCHASE_RF then
        return
    end
    
    print("🤖 Auto Buy Background Task Started!")
    
    State.autoBuyTask = task.spawn(function()
        while Quest18Active do
            task.wait(QUEST_CONFIG.AUTO_BUY_INTERVAL)
            
            if State.isPaused then
                continue
            end
            
            pcall(function()
                tryBuyPickaxe()
            end)
        end
    end)
end

----------------------------------------------------------------
-- ISLAND DETECTION
----------------------------------------------------------------
local function getCurrentIsland()
    for _, child in ipairs(FORGES_FOLDER:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            if string.match(child.Name, "Island%d+") then
                return child.Name
            end
        end
    end
    return nil
end

local function needsTeleport()
    local currentIsland = getCurrentIsland()
    
    if not currentIsland then
        return true
    end
    
    if currentIsland == "Island1" then
        print(string.format("   ✅ On %s → Need teleport!", currentIsland))
        return true
    elseif currentIsland == "Island2" then
        print(string.format("   ✅ On %s → Ready to mine!", currentIsland))
        return false
    else
        warn(string.format("   ⚠️ Unknown: %s", currentIsland))
        return true
    end
end

----------------------------------------------------------------
-- LEVEL SYSTEM
----------------------------------------------------------------
local function getPlayerLevel()
    local levelLabel = playerGui:FindFirstChild("Main")
                      and playerGui.Main:FindFirstChild("Screen")
                      and playerGui.Main.Screen:FindFirstChild("Hud")
                      and playerGui.Main.Screen.Hud:FindFirstChild("Level")
    
    if not levelLabel or not levelLabel:IsA("TextLabel") then
        return nil
    end
    
    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    
    return level
end

local function hasRequiredLevel()
    local level = getPlayerLevel()
    
    if not level then
        warn("   ❌ Cannot determine level!")
        return false
    end
    
    if level >= QUEST_CONFIG.REQUIRED_LEVEL then
        print(string.format("   ✅ Level %d >= %d", level, QUEST_CONFIG.REQUIRED_LEVEL))
        return true
    else
        print(string.format("   ⏸️  Level %d < %d", level, QUEST_CONFIG.REQUIRED_LEVEL))
        return false
    end
end

----------------------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five,
    ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven,
    ["8"] = Enum.KeyCode.Eight,
    ["9"] = Enum.KeyCode.Nine,
    ["0"] = Enum.KeyCode.Zero,
}

local function pressKey(keyCode)
    if not keyCode then return end
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function findPickaxeSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local hotbar = gui:FindFirstChild("BackpackGui") 
                   and gui.BackpackGui:FindFirstChild("Backpack") 
                   and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and string.find(label.Text, "Pickaxe") then
                return HOTKEY_MAP[slotFrame.Name]
            end
        end
    end
    
    return nil
end

local function checkMiningError()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local notif = gui:FindFirstChild("Notifications")
    if notif and notif:FindFirstChild("Screen") and notif.Screen:FindFirstChild("NotificationsFrame") then
        for _, child in ipairs(notif.Screen.NotificationsFrame:GetChildren()) do
            local lbl = child:FindFirstChild("TextLabel", true)
            if lbl and string.find(lbl.Text, "Someone else is already mining") then
                return true
            end
        end
    end
    
    return false
end

----------------------------------------------------------------
-- POSITION LOCK
----------------------------------------------------------------
local function lockPositionLayingDown(targetPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    local baseCFrame = CFrame.new(targetPos)
    local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        hrp.CFrame = layingCFrame
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    
    if DEBUG_MODE then
        print("   🔒 Position locked")
    end
end

local function transitionToNewTarget(newTargetPos)
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local moveComplete = false
    smoothMoveTo(newTargetPos, function()
        lockPositionLayingDown(newTargetPos)
        moveComplete = true
    end)
    
    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    if not moveComplete then
        warn("   ⚠️ Transition timeout!")
        return false
    end
    
    return true
end

----------------------------------------------------------------
-- TELEPORT SYSTEM
----------------------------------------------------------------
local function teleportToIsland(islandName)
    if not PORTAL_RF then
        warn("   ❌ Portal Remote not available!")
        return false
    end
    
    print(string.format("   🌀 Teleporting to: %s", islandName))
    
    local args = {islandName}
    
    local success, result = pcall(function()
        return PORTAL_RF:InvokeServer(unpack(args))
    end)
    
    if success then
        print(string.format("   ✅ Teleported to: %s", islandName))
        return true
    else
        warn(string.format("   ❌ Failed: %s", tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- ROCK HELPERS
----------------------------------------------------------------
local function getRockUndergroundPosition(rockModel)
    if not rockModel or not rockModel.Parent then
        return nil
    end
    
    local pivotCFrame = nil
    pcall(function()
        if rockModel.GetPivot then
            pivotCFrame = rockModel:GetPivot()
        elseif rockModel.WorldPivot then
            pivotCFrame = rockModel.WorldPivot
        end
    end)
    
    if pivotCFrame then
        local pos = pivotCFrame.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    if rockModel.PrimaryPart then
        local pos = rockModel.PrimaryPart.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    local part = rockModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local pos = part.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

local function getRockHP(rock)
    if not rock or not rock.Parent then
        return 0
    end
    
    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)
    
    return success and result or 0
end

local function isTargetValid(rock)
    if not rock or not rock.Parent then
        return false
    end
    
    if not rock:FindFirstChildWhichIsA("BasePart") then
        return false
    end
    
    local hp = getRockHP(rock)
    return hp > 0
end

-- Get current rock name and paths based on pickaxe
local function getCurrentMiningConfig()
    local pickaxeName = QUEST_CONFIG.TARGET_PICKAXE or "Cobalt Pickaxe"
    
    if hasPickaxe(pickaxeName) then
        -- Have Cobalt Pickaxe → Farm Basalt Core
        return {
            ROCK_NAME = QUEST_CONFIG.BASALT_CORE_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.BASALT_CORE_CONFIG.MINING_PATHS,
        }
    else
        -- No Cobalt Pickaxe → Farm Basalt Rock
        return {
            ROCK_NAME = QUEST_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.MINING_PATHS,
        }
    end
end

local function findNearestBasaltRock(excludeRock)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    cleanupExpiredBlacklist()
    
    -- Get current mining config based on pickaxe
    local miningConfig = getCurrentMiningConfig()
    local rockName = miningConfig.ROCK_NAME
    local miningPaths = miningConfig.MINING_PATHS
    
    local targetRock, minDist = nil, math.huge
    local skippedOccupied = 0
    
    for _, pathName in ipairs(miningPaths) do
        local folder = MINING_FOLDER_PATH:FindFirstChild(pathName)
        
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
                    local rock = child:FindFirstChild(rockName)
                    
                    if rock and rock ~= excludeRock and isTargetValid(rock) then
                        if isRockOccupied(rock) then
                            skippedOccupied = skippedOccupied + 1
                        else
                            local pos = getRockUndergroundPosition(rock)
                            if pos then
                                local dist = (pos - hrp.Position).Magnitude
                                
                                if dist < minDist then
                                    minDist = dist
                                    targetRock = rock
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if skippedOccupied > 0 then
        print(string.format("   ⏭️ Skipped %d occupied rocks (blacklisted)", skippedOccupied))
    end
    
    return targetRock, minDist, rockName
end

local function watchRockHP(rock)
    if State.hpWatchConn then
        State.hpWatchConn:Disconnect()
    end
    
    if not rock then return end
    
    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0
        
        if hp <= 0 then
            print("   ✅ Rock destroyed!")
            State.targetDestroyed = true
            
            if ToolController then
                ToolController.holdingM1 = false
            end
        end
    end)
end

----------------------------------------------------------------
-- MINING EXECUTION
----------------------------------------------------------------
local function doMineBasaltRock()
    -- Check pickaxe and determine rock type
    local miningConfig = getCurrentMiningConfig()
    local currentRockName = miningConfig.ROCK_NAME
    
    print("\n⛏️ Mining Started...")
    print(string.format("   🎯 Mining: %s", currentRockName))
    print(string.format("   Target: %d rocks", QUEST_CONFIG.MAX_ROCKS_TO_MINE))
    
    IsMiningActive = true
    
    local miningCount = 0
    
    print("\n" .. string.rep("=", 50))
    print(string.format("⛏️ Mining Loop (%s)...", currentRockName))
    print(string.rep("=", 50))
    
    while Quest18Active and miningCount < QUEST_CONFIG.MAX_ROCKS_TO_MINE do
        if State.isPaused then
            print("   ⏸️  Paused (Auto Buy running)...")
            task.wait(2)
            continue
        end
        
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ Waiting for character...")
            task.wait(2)
            continue
        end
        
        if not State.positionLockConn and not State.moveConn and not State.bodyVelocity then
            cleanupState()
        end
        
        local targetRock, dist, rockName = findNearestBasaltRock(State.currentTarget)
        
        if not targetRock then
            warn(string.format("   ❌ No %s found!", rockName or "rocks"))
            unlockPosition()
            cleanupState()
            task.wait(3)
            continue
        end
        
        local previousTarget = State.currentTarget
        State.currentTarget = targetRock
        State.targetDestroyed = false
        
        local targetPos = getRockUndergroundPosition(targetRock)
        
        if not targetPos then
            warn("   ❌ Cannot get position!")
            task.wait(1)
            continue
        end
        
        local currentHP = getRockHP(targetRock)
        
        print(string.format("\n🎯 Target #%d: %s (HP: %d, Dist: %.1f)", 
            miningCount + 1,
            targetRock.Parent.Parent.Name,
            currentHP, 
            dist))
        
        watchRockHP(targetRock)
        
        -- If we're locked to a DIFFERENT target, use smooth transition
        -- Otherwise, always use smoothMoveTo (even for same target after respawn)
        if State.positionLockConn and previousTarget and previousTarget ~= targetRock then
            print("   🔄 Transition to new target...")
            transitionToNewTarget(targetPos)
        else
            -- Unlock any existing position lock first
            if State.positionLockConn then
                unlockPosition()
            end
            
            local moveStarted = false
            smoothMoveTo(targetPos, function()
                lockPositionLayingDown(targetPos)
                moveStarted = true
            end)
            
            local timeout = 60
            local startTime = tick()
            while not moveStarted and tick() - startTime < timeout do
                task.wait(0.1)
            end
            
            if not moveStarted then
                warn("   ⚠️ Move timeout, skip this rock")
                State.targetDestroyed = true
                unlockPosition()
                continue
            end
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and Quest18Active and not State.isPaused do
            if not char or not char.Parent then
                break
            end
            
            if not targetRock or not targetRock.Parent then
                State.targetDestroyed = true
                break
            end
            
            if checkMiningError() then
                print("   ⚠️ Someone else mining! Switching target...")
                markRockAsOccupied(targetRock)
                State.targetDestroyed = true
                if ToolController then
                    ToolController.holdingM1 = false
                end
                break
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isPickaxeHeld = toolInHand and string.find(toolInHand.Name, "Pickaxe")
            
            if not isPickaxeHeld then
                if ToolController then
                    ToolController.holdingM1 = false
                end
                
                local key = findPickaxeSlotKey()
                if key then
                    pressKey(key)
                    task.wait(0.3)
                else
                    pcall(function()
                        if PlayerController and PlayerController.Replica then
                            local replica = PlayerController.Replica
                            if replica.Data and replica.Data.Inventory and replica.Data.Inventory.Equipments then
                                for id, item in pairs(replica.Data.Inventory.Equipments) do
                                    if type(item) == "table" and item.Type and string.find(item.Type, "Pickaxe") then
                                        CHAR_RF:InvokeServer({Runes = {}}, item)
                                        break
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.5)
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end
            
            task.wait(0.15)
        end
        
        if State.targetDestroyed then
            miningCount = miningCount + 1
        end
        
        if QUEST_CONFIG.HOLD_POSITION_AFTER_MINE then
            print("   ⏸️  Holding position, searching for next target...")
        else
            unlockPosition()
        end
        
        task.wait(0.5)
    end
    
    print("\n" .. string.rep("=", 50))
    print("✅ Mining ended")
    print(string.rep("=", 50))
    
    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 18: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Smart Teleport & Mining + Auto Sell & Buy")
print(string.rep("=", 50))

-- Check Level
print("\n🔍 Pre-check: Verifying level requirement...")
if not hasRequiredLevel() then
    print("\n❌ Level requirement not met!")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

-- Priority 1: Teleport
print("\n🔍 Priority 1: Checking Location...")
if needsTeleport() then
    print("   ⚠️ Not on target island!")
    teleportToIsland(QUEST_CONFIG.ISLAND_NAME)
    task.wait(3)
end

-- Priority 2: Auto Sell Init
print("\n🔍 Priority 2: Auto Sell Initialization...")
if QUEST_CONFIG.AUTO_SELL_ENABLED then
    if not AutoSellInitialized then
        local success = initAutoSellWithNPC()
        if not success then
            warn("   ⚠️ Auto Sell Init Failed - Skipping")
        end
    else
        print("   ✅ Auto Sell already initialized")
    end
end

-- Priority 3: Background Tasks
print("\n🔍 Priority 3: Starting Background Tasks...")
startAutoSellTask()
startAutoBuyTask()

-- Priority 4: Mining
print("\n🔍 Priority 4: Starting Mining...")
doMineBasaltRock()

Quest18Active = false
cleanupState()
disableNoclip()
