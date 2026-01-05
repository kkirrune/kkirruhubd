if _G.AntiKick == true then return end
_G.AntiKick = true

-- Services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- Check compatibility
if not hookmetamethod then
    warn("Anti-Kick: Executor does not support hookmetamethod")
    return
end

-- Configuration
local Config = {
    enabled = true,
    notify = true,
    autoRejoin = true, -- Automatically reconnects if kicked
    max_per_10s = 3,
    max_per_60s = 10,
    unsafeWords = {"cheat", "hack", "exploit", "inject", "byfron", "detection", "suspicious", "staff", "admin"},
    safeWords = {"maintenance", "update", "restart", "timeout", "inactivity", "teleport"}
}

-- State Management
local kicks = {}
local blocks = 0
local lastNotify = 0

-- Helper: Rejoin Function
local function rejoinServer()
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end

-- Helper: UI Notification
local function notify(title, text)
    if not Config.notify then return end
    local now = tick()
    if now - lastNotify < 3 then return end
    lastNotify = now
    
    task.spawn(function()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = 3
            })
        end)
    end)
end

-- Helper: String Search
local function containsWord(reason, wordList)
    local lowerReason = string.lower(tostring(reason))
    for _, word in ipairs(wordList) do
        if string.find(lowerReason, word:lower(), 1, true) then
            return true, word
        end
    end
    return false
end

-- Main Hook
local originalNamecall
originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if (method == "Kick" or method == "kick") and self == LocalPlayer then
        if not Config.enabled or checkcaller() then 
            return originalNamecall(self, ...) 
        end

        local reason = args[1] or "No reason provided"
        local now = tick()

        -- 1. Check for Unsafe Reasons
        local isUnsafe, detectedWord = containsWord(reason, Config.unsafeWords)
        if isUnsafe then
            blocks = blocks + 1
            notify("Kick Blocked", "Reason: " .. detectedWord)
            
            if Config.autoRejoin then
                task.wait(0.5)
                rejoinServer()
            end
            return nil
        end

        -- 2. Check for Safe Reasons
        local isSafe = containsWord(reason, Config.safeWords)
        if isSafe then
            return originalNamecall(self, ...)
        end

        -- 3. Rate Limit Logic
        table.insert(kicks, now)
        local validKicks = {}
        local count10s, count60s = 0, 0
        for _, t in ipairs(kicks) do
            if now - t < 60 then
                table.insert(validKicks, t)
                count60s = count60s + 1
                if now - t < 10 then count10s = count10s + 1 end
            end
        end
        kicks = validKicks

        if count10s > Config.max_per_10s or count60s > Config.max_per_60s then
            blocks = blocks + 1
            notify("Rate Limited", "Too many kick attempts detected")
            if Config.autoRejoin then rejoinServer() end
            return nil
        end

        -- Default Protection
        blocks = blocks + 1
        notify("Protection Active", "Blocked unknown kick attempt")
        return nil
    end

    return originalNamecall(self, ...)
end)

-- Handle unexpected disconnection (Internal kicks)
if Config.autoRejoin then
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        task.wait(0.1)
        rejoinServer()
    end)
end

-- Global API
_G.AK = {
    toggle = function()
        Config.enabled = not Config.enabled
        notify("Anti-Kick", Config.enabled and "Enabled" or "Disabled")
    end,
    rejoin = function()
        rejoinServer()
    end,
    getStats = function()
        print("Blocks: " .. blocks .. " | Recent: " .. #kicks)
        return {blocks = blocks, recent = #kicks}
    end
}

print("Anti-Kick Successfully")
