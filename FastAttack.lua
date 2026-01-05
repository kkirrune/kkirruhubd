_G.FastAttack = true

if _G.FastAttack then
    -- Services
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    
    -- Player
    local Player = Players.LocalPlayer
    if not Player then return end
    
    -- Config
    local Config = {
        Enabled = true,
        AttackDelay = 0.15,
        AttackDistance = 30,
        AttackMobs = true,
        AttackPlayers = false
    }
    
    -- Cache
    local lastAttack = 0
    local attackThread = nil
    local cachedEnemies = nil
    
    -- Find remotes efficiently
    local function GetAttackRemotes()
        local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
        if not Modules then return nil, nil end
        
        local Net = Modules:WaitForChild("Net", 5)
        if not Net then return nil, nil end
        
        local RE = Net:WaitForChild("RE", 5)
        if not RE then return nil, nil end
        
        return RE:FindFirstChild("RegisterAttack"), RE:FindFirstChild("RegisterHit")
    end
    
    local RegisterAttack, RegisterHit = GetAttackRemotes()
    if not RegisterAttack or not RegisterHit then
        warn("Attack remotes not found")
        return
    end
    
    -- Get enemy folder if exists
    local function GetEnemyFolder()
        if cachedEnemies then return cachedEnemies end
        
        -- Try common enemy locations
        local enemyLocations = {
            Workspace:FindFirstChild("Enemies"),
            Workspace:FindFirstChild("_WorldOrigin"):FindFirstChild("EnemySpawns"),
            Workspace:FindFirstChild("_WorldOrigin"):FindFirstChild("Enemies"),
            Workspace:FindFirstChild("Map"):FindFirstChild("Enemies")
        }
        
        for _, folder in ipairs(enemyLocations) do
            if folder and folder:IsA("Folder") then
                cachedEnemies = folder
                return folder
            end
        end
        
        return Workspace -- Fallback to entire workspace
    end
    
    -- Get valid targets
    local function GetValidTargets()
        local targets = {}
        local character = Player.Character
        if not character then return targets end
        
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return targets end
        
        local enemyFolder = GetEnemyFolder()
        local scanList = {}
        
        -- Get scanning targets
        if enemyFolder ~= Workspace then
            scanList = enemyFolder:GetChildren()
        else
            -- Fallback: scan only models with Humanoid
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                    table.insert(scanList, obj)
                end
            end
        end
        
        -- Process targets
        for _, model in ipairs(scanList) do
            if model == character then continue end
            
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local targetPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
            
            if humanoid and humanoid.Health > 0 and targetPart then
                local isPlayer = Players:GetPlayerFromCharacter(model)
                
                if (isPlayer and Config.AttackPlayers) or (not isPlayer and Config.AttackMobs) then
                    local distance = (targetPart.Position - root.Position).Magnitude
                    if distance <= Config.AttackDistance then
                        table.insert(targets, {
                            Model = model,
                            Part = targetPart,
                            Distance = distance
                        })
                    end
                end
            end
        end
        
        -- Sort by distance
        table.sort(targets, function(a, b)
            return a.Distance < b.Distance
        end)
        
        return targets
    end
    
    -- Attack function
    local function Attack()
        if tick() - lastAttack < Config.AttackDelay then return end
        
        local targets = GetValidTargets()
        if #targets == 0 then return end
        
        -- Format targets for remote
        local formattedTargets = {}
        for _, target in ipairs(targets) do
            table.insert(formattedTargets, {target.Model, target.Part})
        end
        
        -- Send attack
        local success, err = pcall(function()
            RegisterAttack:FireServer()
            RegisterHit:FireServer(targets[1].Part, formattedTargets)
        end)
        
        if not success then
            warn("Attack failed:", err)
        else
            lastAttack = tick()
        end
    end
    
    -- Main loop
    local function StartAttackLoop()
        if attackThread then return end
        
        attackThread = task.spawn(function()
            while Config.Enabled do
                local char = Player.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                
                -- Only attack if character is alive
                if char and humanoid and humanoid.Health > 0 then
                    Attack()
                else
                    lastAttack = tick() -- Reset attack cooldown when dead
                end
                
                -- Adaptive wait time
                local waitTime = 0.05
                local targets = GetValidTargets()
                if #targets == 0 then
                    waitTime = 0.2 -- Wait longer if no targets
                end
                
                task.wait(waitTime)
            end
            attackThread = nil
        end)
    end
    
    -- Controls
    local Controls = {}
    
    function Controls.Toggle(state)
        if state ~= nil then
            Config.Enabled = state
        else
            Config.Enabled = not Config.Enabled
        end
        
        if Config.Enabled then
            StartAttackLoop()
        end
        
        return Config.Enabled
    end
    
    function Controls.SetDelay(delay)
        local num = tonumber(delay)
        if num and num > 0 then
            Config.AttackDelay = math.max(0.05, num)
            return true
        end
        return false
    end
    
    function Controls.SetDistance(dist)
        local num = tonumber(dist)
        if num then
            Config.AttackDistance = math.clamp(num, 10, 100)
            return true
        end
        return false
    end
    
    -- Initialize
    Controls.Toggle(true)
    
    -- Store controls globally
    getgenv().FastAttack = Controls
    
    print("Fast Attack Initialized | Controls: FastAttack.Toggle(), FastAttack.SetDelay(), FastAttack.SetDistance()")
end
