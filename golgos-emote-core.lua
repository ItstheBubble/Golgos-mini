--[[
    Minimal Admin (Server-Side)
    Philosophy: silent, minimal, secure, robust.
    Prefix: /e | Supports UserIds and Usernames in the Admins table.
]]

-- 1) SETUP ---------------------------------------------------------
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local Prefix = "/e"
local Admins = { game.CreatorId, "BickDeaq" } 

-- DataStore for permanent bans
local banDataStore = DataStoreService:GetDataStore("AdminSystem_Bans")
local bannedUsers = {} -- This will hold the UserIds of banned players for the current session

-- Stateful settings
local itemStoragePath = ServerStorage
local commandLogs = {} -- Stores a history of commands used

-- 2) CORE HELPERS --------------------------------------------------
local function isAdmin(player)
	if not player then return false end
	if player.UserId == game.CreatorId then return true end
	for _, entry in ipairs(Admins) do
		if type(entry) == "number" and entry == player.UserId then return true
		elseif type(entry) == "string" and entry:lower() == player.Name:lower() then return true end
	end
	return false
end

local function logCommand(executor, message)
	local logEntry = string.format("[%s] %s: %s", os.date("%H:%M:%S"), executor.Name, message)
	table.insert(commandLogs, 1, logEntry)
	if #commandLogs > 100 then table.remove(commandLogs) end
end

local function sendFeedback(executor, message)
	local playerGui = executor and executor:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local oldHint = playerGui:FindFirstChild("AdminHint")
		if oldHint then oldHint:Destroy() end
		local hint = Instance.new("Hint")
		hint.Name = "AdminHint"
		hint.Text = message
		hint.Parent = playerGui
		Debris:AddItem(hint, 5) 
	end
end

local function getTargets(executor, key)
	key = (key or ""):lower()
	if key == "me" then return {executor} end
	if key == "all" then return Players:GetPlayers() end
	local p = nil
	if key ~= "" then
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Name:lower():sub(1, #key) == key then p = player; break end
		end
	end
	return p and {p} or {}
end

local function processTarget(executor, targetName)
	if not targetName then return sendFeedback(executor, "Error: Missing target argument.") end
	local targets = getTargets(executor, targetName)
	if #targets == 0 then return sendFeedback(executor, "Error: Target not found.") end
	return targets
end

local function findItem(itemName)
	itemName = (itemName or ""):lower()
	if itemName == "" then return nil end
	for _, item in ipairs(itemStoragePath:GetChildren()) do
		if item.Name:lower():sub(1, #itemName) == itemName then return item end
	end
	return nil
end

local function findInstance(pathString)
	if not pathString then return nil end
	local parts = string.split(pathString, ".")
	local currentInstance = game
	if parts[1]:lower() ~= "game" then return nil end
	for i = 2, #parts do
		currentInstance = currentInstance:FindFirstChild(parts[i])
		if not currentInstance then return nil end
	end
	return currentInstance
end

local function findTeam(teamName)
	teamName = (teamName or ""):lower()
	if teamName == "" then return nil end
	for _, team in ipairs(Teams:GetChildren()) do
		if team:IsA("Team") and team.Name:lower():sub(1, #teamName) == teamName then return team end
	end
	return nil
end

-- 3) COMMAND DEFINITIONS -------------------------------------------
local Commands = {}

-- Helper to find instance and property for 'ep'
local function findInstanceAndProperty(pathString)
	local parts = string.split(pathString, ".")
	if #parts < 2 then return nil, nil end
	local propertyName = table.remove(parts)
	local instance = findInstance(table.concat(parts, "."))
	return instance, propertyName
end

-- Helper to parse value for 'ep'
local function parseValue(valueString)
	local refInstance, refProp = findInstanceAndProperty(valueString)
	if refInstance and refProp then
		local success, value = pcall(function() return refInstance[refProp] end)
		if success then return value, true end
	end
	local num = tonumber(valueString)
	if num then return num, true end
	if valueString:lower() == "true" then return true, true end
	if valueString:lower() == "false" then return false, true end
	return valueString, true
end

-- Command Implementations
Commands.fling = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end

	for _, p in ipairs(targets) do
		local rootPart = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local attachment = rootPart:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", rootPart)

			-- Create a powerful upward force
			local flingVelocity = Instance.new("LinearVelocity")
			flingVelocity.MaxForce = math.huge
			flingVelocity.VectorVelocity = Vector3.new(math.random(-75, 75), 400, math.random(-75, 75))
			flingVelocity.Attachment0 = attachment
			flingVelocity.Parent = rootPart

			-- Create a chaotic spinning force
			local spinVelocity = Instance.new("AngularVelocity")
			spinVelocity.MaxTorque = math.huge
			spinVelocity.AngularVelocity = Vector3.new(math.random(-300, 300), math.random(-300, 300), math.random(-300, 300))
			spinVelocity.Attachment0 = attachment
			spinVelocity.Parent = rootPart

			Debris:AddItem(flingVelocity, 0.5)
			Debris:AddItem(spinVelocity, 0.5)
		end
	end
end

Commands.explode = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end

	for _, p in ipairs(targets) do
		local rootPart = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local explosion = Instance.new("Explosion")
			explosion.BlastPressure = 500000 -- High pressure for visual effect
			explosion.BlastRadius = 10
			explosion.DestroyJointRadiusPercent = 1 -- This is the key to making it lethal
			explosion.Position = rootPart.Position
			explosion.Parent = Workspace
		end
	end
end

Commands.size = function(executor, args)
	local sizeValue = tonumber(args[2])
	if not sizeValue or sizeValue <= 0 then return sendFeedback(executor, "Error: Missing or invalid size value.") end

	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end

	-- Helper function to find or create a scale value inside a Humanoid
	local function getOrCreateScaleValue(humanoid, name)
		local scaleValue = humanoid:FindFirstChild(name)
		if not scaleValue then
			scaleValue = Instance.new("NumberValue", humanoid)
			scaleValue.Name = name
		end
		return scaleValue
	end

	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			getOrCreateScaleValue(humanoid, "BodyDepthScale").Value = sizeValue
			getOrCreateScaleValue(humanoid, "BodyWidthScale").Value = sizeValue
			getOrCreateScaleValue(humanoid, "BodyHeightScale").Value = sizeValue
			humanoid.HeadScale.Value = sizeValue -- HeadScale is also a NumberValue
		end
	end
end

Commands.music = function(executor, args)
	local id = tonumber(args[1])
	if not id then return sendFeedback(executor, "Error: Invalid sound ID.") end
	local existingMusic = SoundService:FindFirstChild("AdminMusic")
	if existingMusic then existingMusic:Stop(); existingMusic:Destroy() end
	local sound = Instance.new("Sound")
	sound.Name = "AdminMusic"
	sound.SoundId = "rbxassetid://" .. id
	sound.Parent = SoundService
	local success, err = pcall(function() sound.Loaded:Wait(10) end)
	if not success or not sound.IsLoaded then
		sound:Destroy()
		return sendFeedback(executor, "Error: Sound " .. id .. " failed to load. May be invalid or moderated.")
	end
	sound:Play()
	Debris:AddItem(sound, sound.TimeLength + 1)
end

Commands.ban = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	local target = targets[1]
	if isAdmin(target) then return sendFeedback(executor, "Error: You cannot ban another admin.") end
	bannedUsers[target.UserId] = true
	local success, err = pcall(function() banDataStore:SetAsync(tostring(target.UserId), true) end)
	if success then
		target:Kick("You have been permanently banned from this server.")
		sendFeedback(executor, target.Name .. " has been banned.")
	else sendFeedback(executor, "Error: Could not save ban data. " .. tostring(err)) end
end

Commands.unban = function(executor, args)
	local username = args[1]
	if not username then return sendFeedback(executor, "Error: Missing username argument.") end
	local userId
	local success, result = pcall(function() userId = Players:GetUserIdFromNameAsync(username) end)
	if not (success and userId) then return sendFeedback(executor, "Error: Could not find UserId for " .. username .. ". "..tostring(result)) end
	bannedUsers[userId] = nil
	local setSuccess, err = pcall(function() banDataStore:RemoveAsync(tostring(userId)) end)
	if setSuccess then sendFeedback(executor, username .. " has been unbanned.")
	else sendFeedback(executor, "Error: Could not save unban data. " .. tostring(err)) end
end

Commands.mute = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	local mutedChannel = TextChatService:FindFirstChild("MutedChannel")
	if not mutedChannel then
		mutedChannel = Instance.new("TextChannel")
		mutedChannel.Name = "MutedChannel"
		mutedChannel.Parent = TextChatService
	end
	for _, p in ipairs(targets) do
		local textSource = TextChatService:GetTextSourceForPlayer(p)
		if textSource then textSource.Parent = mutedChannel end
	end
	sendFeedback(executor, "Muted " .. args[1])
end

Commands.unmute = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	local generalChannel = TextChatService:FindFirstChild("RBXGeneral")
	if not generalChannel then return sendFeedback(executor, "Error: Could not find the General chat channel.") end
	for _, p in ipairs(targets) do
		local textSource = TextChatService:GetTextSourceForPlayer(p)
		if textSource then textSource.Parent = generalChannel end
	end
	sendFeedback(executor, "Unmuted " .. args[1])
end

Commands.logs = function(executor, args)
	local playerGui = executor:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local oldUI = playerGui:FindFirstChild("AdminLogsUI")
	if oldUI then oldUI:Destroy() end
	if #commandLogs == 0 then return sendFeedback(executor, "No commands have been logged yet.") end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AdminLogsUI"; screenGui.ResetOnSpawn = false
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(0.5, 0, 0.6, 0); textBox.Position = UDim2.fromScale(0.5, 0.5); textBox.AnchorPoint = Vector2.new(0.5, 0.5)
	textBox.BackgroundColor3, textBox.BackgroundTransparency = Color3.new(0.1, 0.1, 0.1), 0.2
	textBox.TextColor3, textBox.Font = Color3.new(0.9, 0.9, 0.9), Enum.Font.Code
	textBox.Text, textBox.TextXAlignment, textBox.TextYAlignment = table.concat(commandLogs, "\n"), Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	textBox.MultiLine, textBox.ClearTextOnFocus, textBox.TextEditable = true, false, false
	textBox.Parent = screenGui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
	padding.Parent = textBox
	screenGui.Parent = playerGui
	Debris:AddItem(screenGui, 15)
end
Commands.history = Commands.logs

Commands.gravity = function(executor, args)
	local num = tonumber(args[1])
	if not num then return sendFeedback(executor, "Error: Gravity must be a number.") end
	Workspace.Gravity = num
end

Commands.cleardebree = function(executor, args)
	local count = 0
	for _, v in ipairs(Workspace:GetChildren()) do
		if v:IsA("BasePart") and not v.Anchored then
			local hasPlayerParent = v:GetAncestorOfClass("Model") and v:GetAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")
			if not hasPlayerParent then v:Destroy(); count = count + 1 end
		end
	end
	sendFeedback(executor, "Cleared " .. count .. " pieces of debree.")
end

Commands.strip = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		for _, tool in ipairs(p.Backpack:GetChildren()) do if tool:IsA("Tool") then tool:Destroy() end end
		if p.Character then for _, tool in ipairs(p.Character:GetChildren()) do if tool:IsA("Tool") then tool:Destroy() end end end
	end
end

Commands.age = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	sendFeedback(executor, targets[1].Name .. "'s account is " .. targets[1].AccountAge .. " days old.")
end

Commands.jumppower = function(executor, args)
	local power = tonumber(args[2])
	if not power then return sendFeedback(executor, "Error: Missing or invalid power value.") end
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.JumpPower = power end
	end
end
Commands.jp = Commands.jumppower

Commands.refresh = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local char = p.Character
		if char then
			local rootPart = char:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local pos = rootPart.CFrame
				p:LoadCharacter()
				p.CharacterAdded:Wait()
				p.Character:SetPrimaryPartCFrame(pos)
			else p:LoadCharacter() end
		end
	end
end

Commands.fire = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local rootPart = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and not rootPart:FindFirstChild("AdminFire") then
			local fire = Instance.new("Fire")
			fire.Name = "AdminFire"; fire.Size = 5; fire.Parent = rootPart
		end
	end
end

Commands.unfire = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local rootPart = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then local fire = rootPart:FindFirstChild("AdminFire") if fire then fire:Destroy() end end
	end
end

Commands.setstoragepath = function(executor, args)
	local path = args[1]
	if not path then return sendFeedback(executor, "Error: Missing path argument.") end
	local newPathInstance = findInstance(path)
	if not newPathInstance then return sendFeedback(executor, "Error: The provided path is invalid.") end
	itemStoragePath = newPathInstance
	sendFeedback(executor, "Item storage path set to: " .. itemStoragePath:GetFullName())
end

Commands.give = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	local itemName = table.concat(args, " ", 2)
	if itemName == "" then return sendFeedback(executor, "Error: Missing item name.") end
	local itemToGive = findItem(itemName)
	if not itemToGive then return sendFeedback(executor, "Error: Item matching '"..itemName.."' not found in " .. itemStoragePath:GetFullName()) end
	for _, p in ipairs(targets) do itemToGive:Clone().Parent = p.Backpack end
end

Commands.team = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	local teamName = table.concat(args, " ", 2)
	if teamName == "" then return sendFeedback(executor, "Error: Missing team name.") end
	local teamObject = findTeam(teamName)
	if not teamObject then return sendFeedback(executor, "Error: Team matching '"..teamName.."' not found.") end
	for _, p in ipairs(targets) do p.Team = teamObject end
end

Commands.getchildren = function(executor, args)
	local path = args[1]
	if not path then return sendFeedback(executor, "Error: Missing path argument.") end
	local targetInstance = findInstance(path)
	if not targetInstance then return sendFeedback(executor, "Error: Instance path not found.") end
	local playerGui = executor:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local oldUI = playerGui:FindFirstChild("GetChildrenUI")
	if oldUI then oldUI:Destroy() end
	local children = targetInstance:GetChildren()
	if #children == 0 then return sendFeedback(executor, "Instance '"..targetInstance.Name.."' has no children.") end
	local childNames = {}
	for _, child in ipairs(children) do table.insert(childNames, child.ClassName .. " - " .. child.Name) end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GetChildrenUI"; screenGui.ResetOnSpawn = false
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(0.3, 0, 0.5, 0); textBox.Position = UDim2.fromScale(0.5, 0.5); textBox.AnchorPoint = Vector2.new(0.5, 0.5)
	textBox.BackgroundColor3, textBox.BackgroundTransparency = Color3.new(0.1, 0.1, 0.1), 0.2
	textBox.TextColor3, textBox.Font = Color3.new(0.9, 0.9, 0.9), Enum.Font.Code
	textBox.Text, textBox.TextXAlignment, textBox.TextYAlignment = table.concat(childNames, "\n"), Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	textBox.MultiLine, textBox.ClearTextOnFocus, textBox.TextEditable = true, false, false
	textBox.Parent = screenGui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
	padding.Parent = textBox
	screenGui.Parent = playerGui
	Debris:AddItem(screenGui, 10)
end

Commands.editproperty = function(executor, args)
	local targetPath, valueString = args[1], args[2]
	if not targetPath or not valueString then return sendFeedback(executor, "Error: Usage: /e ep <path.to.property> <value>") end
	local targetInstance, targetPropName = findInstanceAndProperty(targetPath)
	if not targetInstance then return sendFeedback(executor, "Error: Invalid target instance path.") end
	local valueToSet, wasParsed = parseValue(valueString)
	if not wasParsed then return sendFeedback(executor, "Error: Invalid value or reference path.") end
	local success, err = pcall(function() targetInstance[targetPropName] = valueToSet end)
	if not success then sendFeedback(executor, "Error: " .. tostring(err)) end
end
Commands.ep = Commands.editproperty

Commands.kick = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	local reason = table.concat(args, " ", 2)
	if reason == "" then reason = "You have been kicked from the server." end
	for _, p in ipairs(targets) do if p ~= executor and not isAdmin(p) then p:Kick(reason) end end
end

Commands.ff = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do if p.Character then Instance.new("ForceField", p.Character) end end
end

Commands.unff = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		if p.Character then local ff = p.Character:FindFirstChildOfClass("ForceField") if ff then ff:Destroy() end end
	end
end

Commands.god = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.MaxHealth = math.huge; humanoid.Health = humanoid.MaxHealth end
	end
end

Commands.ungod = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.MaxHealth = 100; humanoid.Health = 100 end
	end
end

Commands.heal = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.Health = humanoid.MaxHealth end
	end
end

Commands.health = function(executor, args)
	local health = tonumber(args[2])
	if not health then return sendFeedback(executor, "Error: Missing or invalid health value.") end
	local targets = processTarget(executor, args[1])
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.Health = health end
	end
end

Commands.sit = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.Sit = true end
	end
end

Commands.invis = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		if p.Character then for _, part in ipairs(p.Character:GetDescendants()) do if part:IsA("BasePart") then part.Transparency = 1 end end end
	end
end

Commands.vis = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do
		if p.Character then
			for _, part in ipairs(p.Character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Transparency = 0
				end
			end
		end
	end
end

Commands.hint = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	local hintText = table.concat(args, " ", 2)
	if hintText == "" then return sendFeedback(executor, "Error: Hint text cannot be empty.") end
	for _, p in ipairs(targets) do sendFeedback(p, hintText) end
end

Commands.m = function(executor, args)
	local message = table.concat(args, " ")
	if message == "" then return sendFeedback(executor, "Error: Message cannot be empty.") end
	for _, p in ipairs(Players:GetPlayers()) do sendFeedback(p, "[SERVER]: " .. message) end
end

Commands.time = function(executor, args)
	local timeValue = tonumber(args[1])
	if not timeValue then return sendFeedback(executor, "Error: Invalid time value.") end
	Lighting.ClockTime = timeValue
end

Commands.shutdown = function(executor, args)
	for _, p in ipairs(Players:GetPlayers()) do
		p:Kick("Server is shutting down. Executed by " .. executor.Name)
	end
end

Commands.kill = function(executor, args)
	local targets = processTarget(executor, args[1])
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.Health = 0 end
	end
end

Commands.respawn = function(executor, args)
	local targetName = args[1] or "me"
	local targets = processTarget(executor, targetName)
	if not targets then return end
	for _, p in ipairs(targets) do p:LoadCharacter() end
end

Commands.speed = function(executor, args)
	local speed = tonumber(args[2])
	if not speed then return sendFeedback(executor, "Error: Missing or invalid speed value.") end
	local targets = processTarget(executor, args[1])
	if not targets then return end
	for _, p in ipairs(targets) do
		local humanoid = p.Character and p.Character:FindFirstChild("Humanoid")
		if humanoid then humanoid.WalkSpeed = speed end
	end
end

Commands.bring = function(executor, args)
	if not executor.Character then return sendFeedback(executor, "Error: Your character does not exist.") end
	local targets = processTarget(executor, args[1])
	if not targets then return end
	for _, p in ipairs(targets) do if p.Character then p.Character:PivotTo(executor.Character:GetPivot()) end end
end

Commands.to = function(executor, args)
	if not executor.Character then return sendFeedback(executor, "Error: Your character does not exist.") end
	local targets = processTarget(executor, args[1])
	if not targets then return end
	if targets[1].Character then executor.Character:PivotTo(targets[1].Character:GetPivot()) end
end

Commands.tp = function(executor, args)
	local destTargets = processTarget(executor, args[2])
	if not destTargets then return end
	local targets = processTarget(executor, args[1])
	if not targets then return end
	if destTargets[1].Character then
		for _, p in ipairs(targets) do if p.Character then p.Character:PivotTo(destTargets[1].Character:GetPivot()) end end
	end
end

-- 4) INITIALIZATION ------------------------------------------------
-- Load bans and check new players
Players.PlayerAdded:Connect(function(player)
	local success, isBanned = pcall(function()
		return banDataStore:GetAsync(tostring(player.UserId))
	end)
	if success and isBanned then
		bannedUsers[player.UserId] = true
		player:Kick("You are permanently banned from this server.")
	elseif not success then
		warn("Could not check ban status for " .. player.Name)
	end
end)

-- Listener for Chat Commands
local AdminCommand = Instance.new("TextChatCommand")
AdminCommand.Parent = TextChatService
AdminCommand.Name = "Admin"
AdminCommand.PrimaryAlias = Prefix

AdminCommand.Triggered:Connect(function(source, message)
	local player = Players:GetPlayerByUserId(source.UserId)
	if not (player and isAdmin(player)) then return end
	local parts = string.split(message, " ")
	local commandName = parts[2]
	if not commandName then return end
	local args = {}
	for i = 3, #parts do table.insert(args, parts[i]) end
	local commandFunc = Commands[commandName:lower()]
	if commandFunc then
		logCommand(player, message)
		pcall(commandFunc, player, args)
	else
		sendFeedback(player, "Error: Unknown command '" .. commandName .. "'.")
	end
end)
