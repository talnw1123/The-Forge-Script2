--[[
    ⚔️ QUEST 01: Getting Started!
    📋 Talk to Sensei Moro
    📍 Extracted from 0.lua (lines 209-587)
--]]

-- Full Quest 1 Automation Script (Smooth Movement + UI Force Restore)
-- Features: Quest Check -> Smooth BodyMove -> Dialogue -> Force Restore ALL UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------
local QUEST_NAME = "Getting Started!"
local NPC_NAME = "Sensei Moro"
local QUEST_OPTION_ARG = "GiveIntroduction1"
local MOVE_SPEED = 25

----------------------------------------------------------------
-- STATE MANAGEMENT
----------------------------------------------------------------
local State = {
    noclipConn = nil,
    moveConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

local function restoreCollisions()
    local char = player.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

local function cleanupState()
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
    if State.moveConn then
        State.moveConn:Disconnect()
        State.moveConn = nil
    end
    if State.bodyVelocity then
        State.bodyVelocity:Destroy()
        State.bodyVelocity = nil
    end
    if State.bodyGyro then
        State.bodyGyro:Destroy()
        State.bodyGyro = nil
    end

    -- ✅ สำคัญ: คืน CanCollide ให้ตัวละคร
    restoreCollisions()
end

----------------------------------------------------------------
-- NOCLIP
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
    -- ✅ ปิด noclip แล้วคืนการชนให้ตัวละคร
    restoreCollisions()
end

----------------------------------------------------------------
-- SMOOTH MOVEMENT
----------------------------------------------------------------
local function smoothMoveTo(targetPos, callback)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Cleanup previous movement
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    -- Enable noclip
    enableNoclip()
    
    -- Create BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    State.bodyVelocity = bv
    
    -- Create BodyGyro
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 500
    bg.Parent = hrp
    State.bodyGyro = bg
    
    print(string.format("   🚀 Moving to (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < 5 then  -- Stop at 5 studs (NPC proximity)
            print("   ✅ Reached NPC!")
            
            bv.Velocity = Vector3.zero
            task.wait(0.1)
            
            bv:Destroy()
            bg:Destroy()
            State.bodyVelocity = nil
            State.bodyGyro = nil
            
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            
            if callback then callback() end
            return
        end
        
        local speed = math.min(MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- REMOTE FUNCTIONS
----------------------------------------------------------------
local function invokeDialogueStart(npcModel)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("ProximityService")
        :WaitForChild("RF"):WaitForChild("Dialogue")
    if remote then
        remote:InvokeServer(npcModel)
        print("📡 1. Started Dialogue")
    end
end

local function invokeRunCommand(commandName)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RF"):WaitForChild("RunCommand")
    if remote then
        print("📡 2. Selecting Option: " .. commandName)
        pcall(function() remote:InvokeServer(commandName) end)
    end
end

----------------------------------------------------------------
-- HELPER: FORCE RESTORE (Fix Missing UI)
----------------------------------------------------------------
local function ForceEndDialogueAndRestore()
    print("🔧 3. Forcing Cleanup & UI Restore...")

    -- A. ปิด Dialogue & แก้ Camera
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

    -- B. ลบ Status ที่ทำให้ UI หาย
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    tag:Destroy()
                    print("   - Removed Status Tag: " .. tag.Name)
                end
            end
        end
        
        -- คืนค่า Humanoid
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end

    -- C. บังคับเปิด UI ที่สำคัญกลับมา
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then 
            main.Enabled = true 
            print("   - Main UI (Quest) Restored")
        end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then 
            backpack.Enabled = true 
            print("   - Backpack Restored")
        end
        
        local compass = gui:FindFirstChild("Compass")
        if compass then compass.Enabled = true end
        
        local mobile = gui:FindFirstChild("MobileButtons")
        if mobile then mobile.Enabled = true end
    end

    -- D. บอก Server ว่าปิดแล้ว
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RE"):WaitForChild("DialogueEvent")
    if remote then
        remote:FireServer("Closed")
    end
    
    print("✅ Restore Complete")
end

----------------------------------------------------------------
-- HELPER: QUEST & MOVEMENT
----------------------------------------------------------------
local function getActiveQuestName()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                 and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
    if not list then return nil end
    for _, child in ipairs(list:GetChildren()) do
        if string.match(child.Name, "^Introduction%d+Title$") then
            local frame = child:FindFirstChild("Frame")
            if frame then
                local label = frame:FindFirstChild("TextLabel")
                if label and label.Text ~= "" then return label.Text end
            end
        end
    end
    return nil
end

local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

----------------------------------------------------------------
-- MAIN EXECUTION
----------------------------------------------------------------
local function Run_Quest1()
    print(string.rep("=", 50))
    print("🚀 QUEST 1: " .. QUEST_NAME)
    print(string.rep("=", 50))
    
    local activeQuest = getActiveQuestName()
    if activeQuest ~= QUEST_NAME then
        warn("⚠️ Quest mismatch. Active: " .. tostring(activeQuest))
    else
        print("✅ Quest Active: " .. activeQuest)
    end

    local npcModel = getNpcModel(NPC_NAME)
    if not npcModel then 
        cleanupState()
        disableNoclip()
        return warn("❌ NPC Not Found") 
    end
    
    local targetPart = npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
    if not targetPart then
        cleanupState()
        disableNoclip()
        return warn("❌ NPC has no valid part")
    end
    
    local targetPos = targetPart.Position
    
    print(string.format("\n🚶 Moving to NPC '%s' at (%.1f, %.1f, %.1f)...", 
        NPC_NAME, targetPos.X, targetPos.Y, targetPos.Z))
    
    -- Start smooth movement
    local moveComplete = false
    smoothMoveTo(targetPos, function()
        moveComplete = true
    end)
    
    -- Wait for movement to complete
    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    -- Cleanup movement
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    if not moveComplete then
        cleanupState()
        disableNoclip()
        return warn("❌ Failed to reach NPC (timeout)")
    end
    
    print("\n📞 Starting Dialogue...")
    task.wait(0.5)
    invokeDialogueStart(npcModel)
    
    print("⏳ Waiting for dialogue to open...")
    task.wait(1.5)
    
    print("✅ Selecting quest option...")
    invokeRunCommand(QUEST_OPTION_ARG)
    
    print("⏳ Processing...")
    task.wait(0.5)
    
    ForceEndDialogueAndRestore()
    
    -- Final cleanup
    cleanupState()
    disableNoclip()
    
    print("\n" .. string.rep("=", 50))
    print("🎉 Quest 1 Sequence Finished!")
    print(string.rep("=", 50))
end

Run_Quest1()
