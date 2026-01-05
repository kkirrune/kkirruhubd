-- Minimal bypass - Maximum stability
local function SafeBypass()
    -- Safe logging without crash
    local function logInfo(msg) print("[BY] " .. msg) end
    local function logWarn(msg) warn("[BY] " .. msg) end
    
    logInfo("Initializing...")
    
    -- Wait for game properly
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    local RunService = game:GetService("RunService")
    if not RunService:IsClient() then
        repeat task.wait(0.1) until RunService:IsClient()
    end
    
    task.wait(0.1)
    
    -- 1. Hook metamethod with safety
    if type(hookmetamethod) == "function" then
        local success, originalNamecall = pcall(function()
            return hookmetamethod(game, "__namecall", function(self, ...)
                -- Safe getnamecallmethod with guard
                local method = ""
                if type(getnamecallmethod) == "function" then
                    method = getnamecallmethod() or ""
                end
                
                -- Block kicks
                if method == "Kick" or method == "kick" then
                    return nil
                end
                
                -- Guard original call
                if not originalNamecall then
                    return nil
                end
                
                return originalNamecall(self, ...)
            end)
        end)
        
        if not success then
            logWarn("Metamethod hook failed")
        end
    end
    
    -- 2. Scan for target function
    if type(getgc) ~= "function" then
        logWarn("getgc not available")
        return false
    end
    
    local gc = getgc()
    if type(gc) ~= "table" then
        logWarn("getgc didn't return table")
        return false
    end
    
    local targetFunc = nil
    
    for _, v in pairs(gc) do
        if type(v) == "function" then
            -- Safe getinfo with pcall
            local success, funcInfo = pcall(function()
                return getinfo(v)
            end)
            
            if success and funcInfo and funcInfo.name == "_check" then
                targetFunc = v
                break
            end
        end
    end
    
    -- 3. Hook target function if found
    if targetFunc then
        local function replacement()
            return true
        end
        
        -- Try hookfunction
        if type(hookfunction) == "function" then
            local success = pcall(hookfunction, targetFunc, replacement)
            if success then
                return true
            end
        end
        
        -- Try replaceclosure
        if type(replaceclosure) == "function" then
            local success = pcall(replaceclosure, targetFunc, replacement)
            if success then
                logInfo("Bypass applied successfully")
                return true
            end
        end
        
        logWarn("Found function but couldn't hook")
    else
        logWarn("Target function not found")
    end
    
    return false
end

-- Run with top-level protection
local success, result = pcall(SafeBypass)
if not success then
    warn("Bypass failed completely: " .. tostring(result))
end
