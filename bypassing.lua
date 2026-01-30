        if self.Players.LocalPlayer:FindFirstChild("Banned") then
            self.Players.LocalPlayer.Banned:Destroy()
            print("[ANTIBAN]: FIXED BANNED!!")
        end
        self.Players.LocalPlayer.ChildAdded:Connect(function(v)
            if v.Name == "Banned" then
                v:Destroy()
                print("[ANTIBAN]: FIXED BANNED!!")
            end
        end)
