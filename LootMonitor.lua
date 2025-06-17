-- Loot Monitor for Turtle WoW
-- Shows recent loot as fading text notifications

-- Local references for better performance
local strfind = string.find
local strlower = string.lower
local strsub = string.sub
local strformat = string.format
local tinsert = table.insert
local tremove = table.remove
local tgetn = table.getn
local mathsin = math.sin
local mathpi = math.pi
local gettime = GetTime
local tonumber = tonumber
local getglobal = getglobal

-- Initialize addon
LootMonitor = {}
LootMonitor.activeNotifications = {}
LootMonitor.maxNotifications = 5
LootMonitor.frame = nil
LootMonitor.moveFrame = nil
LootMonitor.moveMode = false

-- Custom print function for WoW 1.12.1 compatibility
local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

-- Create a hidden tooltip frame for scanning item tooltips
local LootMonitorTooltip = CreateFrame("GameTooltip", "LootMonitorTooltip", nil, "GameTooltipTemplate")
LootMonitorTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Check if an item is a quest item by scanning its tooltip
function LootMonitor:IsQuestItem(itemName)
    if not itemName then return false end
    
    -- First try to find the item in bags and scan its tooltip
    local texture, bag, slot = self:FindItemInBags(itemName)
    if bag and slot then
        -- Clear the tooltip
        LootMonitorTooltip:ClearLines()
        
        -- Set the tooltip to the item
        LootMonitorTooltip:SetBagItem(bag, slot)
        
        -- Scan tooltip lines for quest indicators
        for i = 1, LootMonitorTooltip:NumLines() do
            local line = getglobal("LootMonitorTooltipTextLeft" .. i)
            if line then
                local text = line:GetText()
                if text then
                    local lowerText = strlower(text)
                    -- Look for quest item indicators in tooltip
                    if strfind(lowerText, "quest item") or 
                       strfind(lowerText, "quest") or
                       strfind(lowerText, "binds when picked up") then
                        return true
                    end
                end
            end
        end
        
        -- Also check right side of tooltip
        for i = 1, LootMonitorTooltip:NumLines() do
            local line = getglobal("LootMonitorTooltipTextRight" .. i)
            if line then
                local text = line:GetText()
                if text then
                    local lowerText = strlower(text)
                    if strfind(lowerText, "quest item") or 
                       strfind(lowerText, "quest") then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Schedule a delayed quest item check (item needs time to appear in bags)
function LootMonitor:ScheduleQuestItemCheck(notification)
    local checkFrame = CreateFrame("Frame")
    local startTime = gettime()
    local maxCheckTime = 2.0 -- Check for up to 2 seconds
    local checkInterval = 0.2 -- Check every 0.2 seconds
    local lastCheck = 0
    
    checkFrame:SetScript("OnUpdate", function()
        local elapsed = gettime() - startTime
        local timeSinceLastCheck = gettime() - lastCheck
        
        -- Stop checking after max time
        if elapsed > maxCheckTime then
            checkFrame:SetScript("OnUpdate", nil)
            return
        end
        
        -- Only check at intervals
        if timeSinceLastCheck < checkInterval then
            return
        end
        
        lastCheck = gettime()
        
                 -- Try to detect quest item
         local isQuestItem = LootMonitor:IsQuestItem(notification.name)
         
         if isQuestItem and LootMonitorDB.questItemGlow then
             notification.isQuestItem = true
             notification.glow:Show()
             notification.glow:SetBackdropBorderColor(1, 0.8, 0, 1) -- Bright orange-yellow border
             notification.glow:SetBackdropColor(1, 1, 0, 0.4) -- Visible yellow background
             LootMonitor:StartGlowAnimation(notification)
             checkFrame:SetScript("OnUpdate", nil) -- Stop checking
         else
             checkFrame:SetScript("OnUpdate", nil) -- Stop checking even if glow is disabled
         end
    end)
end

-- Schedule a delayed total count update (item needs time to appear in bags)
function LootMonitor:ScheduleTotalCountUpdate(notification)
    local updateFrame = CreateFrame("Frame")
    local startTime = gettime()
    local maxUpdateTime = 1.5 -- Check for up to 1.5 seconds
    local updateInterval = 0.3 -- Update every 0.3 seconds
    local lastUpdate = 0
    
    updateFrame:SetScript("OnUpdate", function()
        local elapsed = gettime() - startTime
        local timeSinceLastUpdate = gettime() - lastUpdate
        
        -- Stop checking after max time
        if elapsed > maxUpdateTime then
            updateFrame:SetScript("OnUpdate", nil)
            return
        end
        
        -- Only update at intervals
        if timeSinceLastUpdate < updateInterval then
            return
        end
        
        lastUpdate = gettime()
        
        -- Update the total count display
        LootMonitor:UpdateNotificationText(notification)
    end)
end

-- Default settings
local defaults = {
    enabled = true,
    scale = 1.2,
    fadeInTime = 0.3,
    displayTime = 5.0,
    fadeOutTime = 1.0,
    questItemGlow = true,
    showTotalCount = true,
    position = {
        point = "CENTER",
        x = 200,
        y = 100
    }
}

-- Initialize saved variables
function LootMonitor:OnLoad()
    if not LootMonitorDB then
        LootMonitorDB = {}
    end
    
    -- Set defaults for missing values
    for key, value in pairs(defaults) do
        if LootMonitorDB[key] == nil then
            LootMonitorDB[key] = value
        end
    end
    
    self:CreateNotificationFrame()
    
    Print("[Loot Monitor] Loaded! Fading loot notifications enabled.")
end

-- Create the notification container frame
function LootMonitor:CreateNotificationFrame()
    -- Create invisible container frame for notifications
    local frame = CreateFrame("Frame", "LootMonitorNotificationFrame", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(300)
    frame:SetPoint(LootMonitorDB.position.point, UIParent, LootMonitorDB.position.point, 
                   LootMonitorDB.position.x, LootMonitorDB.position.y)
    
    -- Make it movable with Shift+Ctrl+Click (for positioning)
    frame:SetMovable(true)
    frame:EnableMouse(false) -- Disabled by default, enabled only when moving
    frame:RegisterForDrag("LeftButton")
    
    -- Store reference
    self.frame = frame
    frame:Show()
end

-- Register events to track loot
function LootMonitor:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:RegisterEvent("CHAT_MSG_MONEY")
    frame:RegisterEvent("CHAT_MSG_SYSTEM")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "LootMonitor" then
            LootMonitor:OnLoad()
        elseif event == "CHAT_MSG_LOOT" then
            LootMonitor:ProcessLootMessage(arg1)
        elseif event == "CHAT_MSG_MONEY" then
            LootMonitor:ProcessMoneyMessage(arg1)
        elseif event == "CHAT_MSG_SYSTEM" then
            LootMonitor:ProcessSystemMessage(arg1)
        end
    end)
end

-- Extract quantity from loot message (looks for x2, x3, etc.)
function LootMonitor:ExtractQuantityFromMessage(message, startPos)
    if not message or not startPos then return 1 end
    
    -- Look for "x" followed by numbers after the item name/link
    local remainingText = string.sub(message, startPos)
    local xPos = string.find(remainingText, "x")
    
    if xPos then
        -- Extract the number after "x"
        local numberStart = xPos + 1
        local numberEnd = numberStart
        
        -- Find the end of the number
        while numberEnd <= string.len(remainingText) do
            local char = string.sub(remainingText, numberEnd, numberEnd)
            if char >= "0" and char <= "9" then
                numberEnd = numberEnd + 1
            else
                break
            end
        end
        
        if numberEnd > numberStart then
            local quantityStr = string.sub(remainingText, numberStart, numberEnd - 1)
            local quantity = tonumber(quantityStr)
            if quantity and quantity > 0 then
                return quantity
            end
        end
    end
    
    return 1 -- Default to 1 if no quantity found
end

-- Process loot messages and extract item information
function LootMonitor:ProcessLootMessage(message)
    if not message then return end
    

    
    -- Check for coin loot messages first (e.g., "You loot 2 Copper")
    if strfind(message, "You loot") and (strfind(message, "Copper") or strfind(message, "Silver") or strfind(message, "Gold")) then
        self:ProcessCoinLoot(message)
        return
    end
    
    -- Check if this is a "You receive loot:", "You receive item:", or "Received item" message
    if strfind(message, "You receive loot:") or strfind(message, "You receive item:") or strfind(message, "Received item") then
        -- Look for full item links (|cXXXXXXXX|Hitem:...|h[Name]|h|r)
        local linkStart = strfind(message, "|c")
        if linkStart then
            local hStart = strfind(message, "|H", linkStart)
            if hStart then
                local linkEnd = strfind(message, "|r", hStart)
                if linkEnd then
                    local itemLink = strsub(message, linkStart, linkEnd + 1)
                    -- Validate that it's a proper item link with |Hitem:
                    if strfind(itemLink, "|Hitem:") then
                        -- Extract quantity after the link
                        local quantity = self:ExtractQuantityFromMessage(message, linkEnd + 2)
                        self:AddLootItem(itemLink, false, quantity)
                        return
                    end
                end
            end
        end
        
        -- Extract item name in brackets (this is what we're actually getting)
        local bracketStart = strfind(message, "%[")
        if bracketStart then
            local bracketEnd = strfind(message, "%]", bracketStart)
            if bracketEnd then
                local itemName = strsub(message, bracketStart + 1, bracketEnd - 1)
                -- Extract quantity after the brackets
                local quantity = self:ExtractQuantityFromMessage(message, bracketEnd + 1)
                self:AddLootItem(itemName, true, quantity) -- true indicates it's just a name, not a full link
            end
        end
    end
end

-- Process coin loot messages (e.g., "You loot 2 Copper")
function LootMonitor:ProcessCoinLoot(message)
    if not message then return end
    
    -- Extract coin information from message
    local coinAmount = 0
    local coinType = ""
    
    -- Look for patterns like "You loot 2 Copper", "You loot 1 Silver", etc.
    local amountStart = string.find(message, "You loot ")
    if amountStart then
        local afterLoot = string.sub(message, amountStart + 9) -- Skip "You loot "
        
        -- Find the number
        local spacePos = string.find(afterLoot, " ")
        if spacePos then
            local amountStr = string.sub(afterLoot, 1, spacePos - 1)
            coinAmount = tonumber(amountStr) or 0
            
            -- Find the coin type
            local coinTypeStr = string.sub(afterLoot, spacePos + 1)
            if string.find(coinTypeStr, "Copper") then
                coinType = "Copper"
            elseif string.find(coinTypeStr, "Silver") then
                coinType = "Silver"
            elseif string.find(coinTypeStr, "Gold") then
                coinType = "Gold"
            end
        end
    end
    
    if coinAmount > 0 and coinType ~= "" then
        local coinText = coinAmount .. " " .. coinType
        self:AddLootItem(coinText, true, 1) -- Treat as name-only item
    end
end

-- Process money loot messages from CHAT_MSG_MONEY event
function LootMonitor:ProcessMoneyMessage(message)
    if not message then return end
    
    -- Money messages might be in different formats
    -- Common patterns might be "You loot 2 Copper" or just "2 Copper"
    local coinAmount = 0
    local coinType = ""
    
    -- Try different patterns
    if string.find(message, "Copper") then
        coinType = "Copper"
    elseif string.find(message, "Silver") then
        coinType = "Silver"  
    elseif string.find(message, "Gold") then
        coinType = "Gold"
    end
    
    if coinType ~= "" then
        -- Extract the number - look for any number in the message
        local numberMatch = string.gsub(message, ".*(%d+).*", "%1")
        coinAmount = tonumber(numberMatch) or 0
        
        if coinAmount > 0 then
            local coinText = coinAmount .. " " .. coinType
            self:AddLootItem(coinText, true, 1)
        end
    end
end

-- Process system messages for quest rewards and other item gains
function LootMonitor:ProcessSystemMessage(message)
    if not message then return end
    

    
    -- Debug: Print system messages that might contain item information
    if LootMonitor.debugMode and (
       strfind(message, "You receive") or 
       strfind(message, "%[")) then
        Print("[LootMonitor Debug] System message: " .. message)
    end
    
    -- Check for various quest reward patterns
    if strfind(message, "You receive item:") or
       strfind(message, "You receive") or
       strfind(message, "receive") then
        
        -- Look for full item links (|cXXXXXXXX|Hitem:...|h[Name]|h|r)
        local linkStart = strfind(message, "|c")
        if linkStart then
            local hStart = strfind(message, "|H", linkStart)
            if hStart then
                local linkEnd = strfind(message, "|r", hStart)
                if linkEnd then
                    local itemLink = strsub(message, linkStart, linkEnd + 1)
                    -- Validate that it's a proper item link with |Hitem:
                    if strfind(itemLink, "|Hitem:") then
                        -- Extract quantity after the link
                        local quantity = self:ExtractQuantityFromMessage(message, linkEnd + 2)
                        self:AddLootItem(itemLink, false, quantity)
                        return
                    end
                end
            end
        end
        
        -- Extract item name in brackets
        local bracketStart = strfind(message, "%[")
        if bracketStart then
            local bracketEnd = strfind(message, "%]", bracketStart)
            if bracketEnd then
                local itemName = strsub(message, bracketStart + 1, bracketEnd - 1)
                -- Extract quantity after the brackets
                local quantity = self:ExtractQuantityFromMessage(message, bracketEnd + 1)
                self:AddLootItem(itemName, true, quantity)
            end
        end
    end
end

-- Add a looted item and create fading notification
function LootMonitor:AddLootItem(itemData, isNameOnly, quantity)
    if not LootMonitorDB.enabled then return end
    
    local itemName
    local actualQuantity = quantity or 1
    
    -- Extract item name
    if not isNameOnly then
        -- It's a full item link, extract name
        local bracketStart = string.find(itemData, "%[")
        local bracketEnd = string.find(itemData, "%]")
        if bracketStart and bracketEnd then
            itemName = string.sub(itemData, bracketStart + 1, bracketEnd - 1)
        else
            itemName = "Unknown Item"
        end
    else
        -- It's just a name
        itemName = itemData
    end
    
    -- Check if we already have a notification for this item
    local existingNotification = nil
    for _, notification in ipairs(self.activeNotifications) do
        if notification.name == itemName and not notification.fadingOut then
            existingNotification = notification
            break
        end
    end
    
    if existingNotification then
        -- Update existing notification
        existingNotification.count = existingNotification.count + actualQuantity
        existingNotification.startTime = GetTime() -- Reset timer
        self:UpdateNotificationText(existingNotification)
    else
        -- Create new notification
        self:CreateLootNotification(itemName, actualQuantity, itemData, isNameOnly)
    end
end

-- Find item texture and bag position in player's bags (optimized)
function LootMonitor:FindItemInBags(itemName)
    if not itemName then return nil, nil, nil end
    
    -- Search through bags (start with bag 0 which is most likely to have recent loot)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            -- Search backwards through slots (recent items are often at the end)
            for slot = numSlots, 1, -1 do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    -- Use more efficient string matching
                    local linkStart = string.find(itemLink, "%[")
                    local linkEnd = string.find(itemLink, "%]")
                    if linkStart and linkEnd then
                        local linkName = string.sub(itemLink, linkStart + 1, linkEnd - 1)
                        if linkName == itemName then
                            local texture = GetContainerItemInfo(bag, slot)
                            if texture then
                                return texture, bag, slot
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil, nil, nil
end

-- Find item texture in player's bags (backward compatibility)
function LootMonitor:FindItemTextureInBags(itemName)
    local texture, _, _ = self:FindItemInBags(itemName)
    return texture
end

-- Count total amount of an item in all bags
function LootMonitor:CountItemInBags(itemName)
    if not itemName then return 0 end
    
    local totalCount = 0
    
    -- Search through all bags
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    -- Extract item name from link
                    local linkStart = strfind(itemLink, "%[")
                    local linkEnd = strfind(itemLink, "%]")
                    if linkStart and linkEnd then
                        local linkName = strsub(itemLink, linkStart + 1, linkEnd - 1)
                        if linkName == itemName then
                            local _, itemCount = GetContainerItemInfo(bag, slot)
                            if itemCount then
                                totalCount = totalCount + itemCount
                            end
                        end
                    end
                end
            end
        end
    end
    
    return totalCount
end

-- Create a new loot notification
function LootMonitor:CreateLootNotification(itemName, quantity, itemData, isNameOnly)
    -- Clean up old notifications first
    self:CleanupNotifications()
    
    -- Limit active notifications
    while tgetn(self.activeNotifications) >= self.maxNotifications do
        local oldest = self.activeNotifications[tgetn(self.activeNotifications)]
        self:RemoveNotification(oldest)
    end
    
    -- Create notification frame
    local notification = CreateFrame("Frame", nil, self.frame)
    notification:SetWidth(350)
    notification:SetHeight(40)
    
    -- Position notifications vertically
    local yOffset = tgetn(self.activeNotifications) * -35
    notification:SetPoint("TOP", self.frame, "TOP", 0, yOffset)
    
    -- Create icon
    local icon = notification:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(32)
    icon:SetHeight(32)
    icon:SetPoint("LEFT", notification, "LEFT", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") -- Default icon
    
    -- Create glow effect for quest items (much more visible)
    local glow = CreateFrame("Frame", nil, notification)
    glow:SetWidth(38)  -- Slightly bigger than icon
    glow:SetHeight(38)
    glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
    glow:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    glow:SetBackdropColor(1, 1, 0, 0.3) -- Yellow background
    glow:SetBackdropBorderColor(1, 0.8, 0, 1) -- Bright yellow-orange border
    glow:Hide() -- Hidden by default
    
    -- Create main text
    local text = notification:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    text:SetJustifyH("LEFT")
    
    -- Create total count text (purple)
    local totalText = notification:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalText:SetPoint("LEFT", text, "RIGHT", 5, 0)
    totalText:SetPoint("RIGHT", notification, "RIGHT", -5, 0)
    totalText:SetJustifyH("LEFT")
    totalText:SetTextColor(0.8, 0.4, 1) -- Purple color
    
    -- Store notification data (we'll check for quest item status after a delay)
    local notificationData = {
        frame = notification,
        icon = icon,
        glow = glow,
        text = text,
        totalText = totalText,
        name = itemName,
        count = quantity,
        data = itemData,
        isNameOnly = isNameOnly,
        isQuestItem = false, -- Will be set later
        startTime = gettime(),
        fadingOut = false
    }
    
    -- Set initial text
    self:UpdateNotificationText(notificationData)
    
    -- Add to active notifications
    tinsert(self.activeNotifications, 1, notificationData)
    
    -- Schedule quest item check with a slight delay (item needs to be in bags first)
    self:ScheduleQuestItemCheck(notificationData)
    
    -- Schedule total count update with a slight delay (item needs to be in bags first)
    if LootMonitorDB.showTotalCount then
        self:ScheduleTotalCountUpdate(notificationData)
    end
    
    -- Start fade animation
    self:StartNotificationAnimation(notificationData)
    
    -- Search for icon asynchronously
    self:ScheduleIconSearch(notificationData)
end

-- Update notification text display
function LootMonitor:UpdateNotificationText(notification)
    local displayText = notification.name
    if notification.count > 1 then
        displayText = displayText .. " x" .. notification.count
    end
    notification.text:SetText(displayText)
    
    -- Get total count in bags and display in purple (if enabled)
    if LootMonitorDB.showTotalCount then
        local totalCount = self:CountItemInBags(notification.name)
        if totalCount > 0 then
            notification.totalText:SetText("(" .. totalCount .. ")")
        else
            notification.totalText:SetText("")
        end
    else
        notification.totalText:SetText("")
    end
    
    -- Set color based on item quality if available
    if not notification.isNameOnly and notification.data then
        local colorStart = strfind(notification.data, "|c")
        if colorStart then
            local colorCode = strsub(notification.data, colorStart + 2, colorStart + 9)
            if string.len(colorCode) == 8 then
                local r = tonumber(strsub(colorCode, 3, 4), 16) / 255
                local g = tonumber(strsub(colorCode, 5, 6), 16) / 255
                local b = tonumber(strsub(colorCode, 7, 8), 16) / 255
                notification.text:SetTextColor(r, g, b)
            else
                notification.text:SetTextColor(1, 1, 1)
            end
        else
            notification.text:SetTextColor(1, 1, 1)
        end
    else
        notification.text:SetTextColor(1, 1, 1)
    end
end



-- Schedule asynchronous icon search with retry mechanism
function LootMonitor:ScheduleIconSearch(notification)
    local searchFrame = CreateFrame("Frame")
    local startTime = gettime()
    local maxSearchTime = 3.0 -- Search for up to 3 seconds
    local searchInterval = 0.2 -- Check every 0.2 seconds
    local lastSearch = 0
    local fallbackUsed = false
    
    searchFrame:SetScript("OnUpdate", function()
        local elapsed = gettime() - startTime
        local timeSinceLastSearch = gettime() - lastSearch
        
        -- Stop searching after max time
        if elapsed > maxSearchTime then
            -- Use fallback icon if we haven't found anything
            if not fallbackUsed then
                local fallbackTexture = LootMonitor:GetFallbackIcon(notification.name)
                if fallbackTexture then
                    notification.icon:SetTexture(fallbackTexture)
                end
            end
            searchFrame:SetScript("OnUpdate", nil)
            return
        end
        
        -- Only search at intervals
        if timeSinceLastSearch < searchInterval then
            return
        end
        
        lastSearch = gettime()
        
        -- Search for item texture
        local texture = LootMonitor:FindItemTextureInBags(notification.name)
        
        if texture then
            notification.icon:SetTexture(texture)
            searchFrame:SetScript("OnUpdate", nil) -- Stop searching once found
        elseif not fallbackUsed and elapsed > 0.5 then
            -- Use fallback icon after 0.5 seconds if still no real icon found
            local fallbackTexture = LootMonitor:GetFallbackIcon(notification.name)
            if fallbackTexture then
                notification.icon:SetTexture(fallbackTexture)
                fallbackUsed = true
                -- Continue searching for real icon in case it appears later
            end
        end
    end)
end

-- Get fallback icon based on item name patterns
function LootMonitor:GetFallbackIcon(itemName)
    if not itemName then return nil end
    
    local name = string.lower(itemName)
    
    -- Check for coins first
    if string.find(name, "copper") then
        return "Interface\\Icons\\INV_Misc_Coin_01"
    elseif string.find(name, "silver") then
        return "Interface\\Icons\\INV_Misc_Coin_03"
    elseif string.find(name, "gold") then
        return "Interface\\Icons\\INV_Misc_Coin_05"
    -- Common item type patterns
    elseif string.find(name, "potion") or string.find(name, "elixir") then
        return "Interface\\Icons\\INV_Potion_52"
    elseif string.find(name, "cloth") or string.find(name, "linen") then
        return "Interface\\Icons\\INV_Fabric_Linen_01"
    elseif string.find(name, "leather") or string.find(name, "hide") then
        return "Interface\\Icons\\INV_Misc_LeatherScrap_02"
    elseif string.find(name, "ore") or string.find(name, "metal") then
        return "Interface\\Icons\\INV_Ore_Copper_01"
    elseif string.find(name, "herb") or string.find(name, "flower") then
        return "Interface\\Icons\\INV_Misc_Herb_07"
    elseif string.find(name, "gem") or string.find(name, "stone") then
        return "Interface\\Icons\\INV_Misc_Gem_01"
    elseif string.find(name, "food") or string.find(name, "bread") or string.find(name, "meat") then
        return "Interface\\Icons\\INV_Misc_Food_15"
    elseif string.find(name, "fang") or string.find(name, "tooth") or string.find(name, "claw") then
        return "Interface\\Icons\\INV_Misc_MonsterClaw_04"
    elseif string.find(name, "remnant") or string.find(name, "essence") then
        return "Interface\\Icons\\INV_Misc_Dust_02"
    else
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end
end

-- Start glow animation for quest items
function LootMonitor:StartGlowAnimation(notification)
    local glowFrame = CreateFrame("Frame")
    notification.glowAnimFrame = glowFrame
    
    local startTime = gettime()
    local glowDuration = 1.0 -- Faster pulsing
    
    glowFrame:SetScript("OnUpdate", function()
        local elapsed = gettime() - startTime
        local cycle = mod(elapsed, glowDuration) / glowDuration
        
        -- Create a visible pulsing effect (smaller size)
        local borderAlpha = 0.5 + 0.5 * (1 + mathsin(cycle * 2 * mathpi)) / 2
        local bgAlpha = 0.1 + 0.4 * (1 + mathsin(cycle * 2 * mathpi)) / 2
        local scale = 1.0 + 0.08 * (1 + mathsin(cycle * 2 * mathpi)) / 2
        
        if notification.glow then
            -- Pulse the border and background
            notification.glow:SetBackdropBorderColor(1, 0.8, 0, borderAlpha)
            notification.glow:SetBackdropColor(1, 1, 0, bgAlpha)
            
            -- Scale the glow frame (smaller scaling)
            local baseSize = 38
            local newSize = baseSize * scale
            notification.glow:SetWidth(newSize)
            notification.glow:SetHeight(newSize)
        end
    end)
end

-- Start fade animation for notification
function LootMonitor:StartNotificationAnimation(notification)
    local animFrame = CreateFrame("Frame")
    notification.animFrame = animFrame
    
    -- Set initial alpha
    notification.frame:SetAlpha(0)
    notification.frame:SetScale(LootMonitorDB.scale * 0.8) -- Start smaller
    
    animFrame:SetScript("OnUpdate", function()
        local elapsed = GetTime() - notification.startTime
        local fadeInTime = LootMonitorDB.fadeInTime
        local displayTime = LootMonitorDB.displayTime
        local fadeOutTime = LootMonitorDB.fadeOutTime
        
        if elapsed < fadeInTime then
            -- Fade in phase
            local progress = elapsed / fadeInTime
            local alpha = progress
            local scale = LootMonitorDB.scale * (0.8 + 0.2 * progress) -- Scale from 80% to 100%
            
            notification.frame:SetAlpha(alpha)
            notification.frame:SetScale(scale)
            
        elseif elapsed < fadeInTime + displayTime then
            -- Display phase
            notification.frame:SetAlpha(1)
            notification.frame:SetScale(LootMonitorDB.scale)
            
        elseif elapsed < fadeInTime + displayTime + fadeOutTime then
            -- Fade out phase
            if not notification.fadingOut then
                notification.fadingOut = true
            end
            
            local fadeProgress = (elapsed - fadeInTime - displayTime) / fadeOutTime
            local alpha = 1 - fadeProgress
            local scale = LootMonitorDB.scale * (1 + 0.1 * fadeProgress) -- Scale up slightly while fading
            
            notification.frame:SetAlpha(alpha)
            notification.frame:SetScale(scale)
            
        else
            -- Animation complete, remove notification
            LootMonitor:RemoveNotification(notification)
        end
    end)
end

-- Remove a notification
function LootMonitor:RemoveNotification(notification)
    if notification.animFrame then
        notification.animFrame:SetScript("OnUpdate", nil)
    end
    
    if notification.glowAnimFrame then
        notification.glowAnimFrame:SetScript("OnUpdate", nil)
    end
    
    if notification.frame then
        notification.frame:Hide()
        notification.frame:SetParent(nil)
    end
    
    -- Remove from active list
    for i, activeNotification in ipairs(self.activeNotifications) do
        if activeNotification == notification then
            tremove(self.activeNotifications, i)
            break
        end
    end
    
    -- Reposition remaining notifications
    self:RepositionNotifications()
end

-- Clean up finished notifications
function LootMonitor:CleanupNotifications()
    local toRemove = {}
    
    for i, notification in ipairs(self.activeNotifications) do
        local elapsed = GetTime() - notification.startTime
        local totalTime = LootMonitorDB.fadeInTime + LootMonitorDB.displayTime + LootMonitorDB.fadeOutTime
        
        if elapsed > totalTime then
            table.insert(toRemove, notification)
        end
    end
    
    for _, notification in ipairs(toRemove) do
        self:RemoveNotification(notification)
    end
end

-- Reposition all active notifications
function LootMonitor:RepositionNotifications()
    for i, notification in ipairs(self.activeNotifications) do
        local yOffset = (i - 1) * -35
        notification.frame:ClearAllPoints()
        notification.frame:SetPoint("TOP", self.frame, "TOP", 0, yOffset)
    end
end

-- Toggle move mode for repositioning notifications
function LootMonitor:ToggleMoveMode()
    if self.moveMode then
        self:ExitMoveMode()
    else
        self:EnterMoveMode()
    end
end

-- Enter move mode
function LootMonitor:EnterMoveMode()
    self.moveMode = true
    
    -- Create visible move frame
    if not self.moveFrame then
        local moveFrame = CreateFrame("Frame", "LootMonitorMoveFrame", UIParent)
        moveFrame:SetWidth(250)
        moveFrame:SetHeight(150)
        moveFrame:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
        
        -- Background
        local bg = moveFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(moveFrame)
        bg:SetTexture(0, 0, 0, 0.5)
        
        -- Border
        local border = CreateFrame("Frame", nil, moveFrame)
        border:SetAllPoints(moveFrame)
        border:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        
        -- Title
        local title = moveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", moveFrame, "TOP", 0, -10)
        title:SetText("Loot Notifications Area")
        title:SetTextColor(1, 1, 1)
        
        -- Instructions
        local instructions = moveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        instructions:SetPoint("CENTER", moveFrame, "CENTER", 0, 0)
        instructions:SetTextColor(1, 1, 0)
        instructions:SetJustifyH("CENTER")
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, moveFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", moveFrame, "TOPRIGHT", -5, -5)
        closeBtn:SetScript("OnClick", function() 
            LootMonitor:ExitMoveMode()
            LootMonitor:ShowSettings()
        end)
        
        -- Make it movable
        moveFrame:SetMovable(true)
        moveFrame:EnableMouse(true)
        moveFrame:RegisterForDrag("LeftButton")
        moveFrame:SetScript("OnDragStart", function() 
            moveFrame:StartMoving()
        end)
        moveFrame:SetScript("OnDragStop", function() 
            moveFrame:StopMovingOrSizing()
            -- Update the main frame position to match
            local point, _, _, x, y = moveFrame:GetPoint()
            if point and x and y then
                LootMonitor.frame:ClearAllPoints()
                LootMonitor.frame:SetPoint(point, UIParent, point, x, y)
            end
        end)
        
        self.moveFrame = moveFrame
    end
    
    -- Show move frame
    self.moveFrame:Show()
    
    -- Create sample notifications to show positioning
    self:CreateSampleNotifications()
    
    Print("[Loot Monitor] Move mode enabled. Drag the frame to reposition notifications.")
    Print("Type '/lootmonitor move' again to save position and exit move mode.")
end

-- Exit move mode
function LootMonitor:ExitMoveMode()
    self.moveMode = false
    
    -- Hide and save position
    if self.moveFrame then
        local point, _, _, x, y = self.moveFrame:GetPoint()
        if point and x and y then
            -- Save position to settings
            LootMonitorDB.position.point = point
            LootMonitorDB.position.x = x
            LootMonitorDB.position.y = y
            
            -- Update main frame position
            self.frame:ClearAllPoints()
            self.frame:SetPoint(point, UIParent, point, x, y)
        end
        
        self.moveFrame:Hide()
    end
    
    -- Clear sample notifications
    self:ClearSampleNotifications()
    
    Print("[Loot Monitor] Position saved. Move mode disabled.")
end

-- Create sample notifications for positioning
function LootMonitor:CreateSampleNotifications()
    -- Clear existing notifications first
    for _, notification in ipairs(self.activeNotifications) do
        self:RemoveNotification(notification)
    end
    
    -- Create sample notifications
    local sampleItems = {
        {name = "Sample Item 1", count = 1},
        {name = "Sample Potion", count = 3},
        {name = "Sample Cloth", count = 5}
    }
    
    for _, item in ipairs(sampleItems) do
        self:CreateLootNotification(item.name, item.count, item.name, true)
    end
end

-- Clear sample notifications
function LootMonitor:ClearSampleNotifications()
    for _, notification in ipairs(self.activeNotifications) do
        self:RemoveNotification(notification)
    end
end

-- Create settings panel
function LootMonitor:CreateSettingsPanel()
    -- Create main frame (much taller and modern)
    local frame = CreateFrame("Frame", "LootMonitorSettingsFrame", UIParent)
    frame:SetWidth(450)
    frame:SetHeight(600)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    -- Modern gradient background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    bg:SetGradientAlpha("VERTICAL", 0.1, 0.1, 0.2, 0.95, 0.05, 0.05, 0.15, 0.95)
    
    -- Modern border with rounded corners effect
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.05, 0.05, 0.15, 0.9)
    frame:SetBackdropBorderColor(0.3, 0.5, 0.8, 1)
    
    -- Simple title section (no weird gradient)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -25)
    title:SetText("Loot Monitor Settings")
    title:SetTextColor(1, 1, 1)
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Subtitle
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -8)
    subtitle:SetText("Configure your loot notification preferences")
    subtitle:SetTextColor(0.7, 0.7, 0.8)
    
    -- Modern close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Content area with better spacing
    local contentY = -70
    
    -- General Settings Section
    local generalHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    generalHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
    generalHeader:SetText("General Settings")
    generalHeader:SetTextColor(0.4, 0.8, 1)
    
    contentY = contentY - 30
    
    -- Enable/Disable checkbox with modern styling
    local enableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, contentY)
    enableCheck:SetChecked(LootMonitorDB.enabled)
    local enableLabel = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 8, 0)
    enableLabel:SetText("Enable Loot Notifications")
    enableLabel:SetTextColor(0.9, 0.9, 1)
    enableCheck:SetScript("OnClick", function()
        LootMonitorDB.enabled = enableCheck:GetChecked()
    end)
    
    contentY = contentY - 35
    
    -- Display Features Section
    local featuresHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    featuresHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
    featuresHeader:SetText("Display Features")
    featuresHeader:SetTextColor(0.4, 0.8, 1)
    
    contentY = contentY - 30
    
    -- Quest Item Glow checkbox
    local questGlowCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    questGlowCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, contentY)
    questGlowCheck:SetChecked(LootMonitorDB.questItemGlow)
    local questGlowLabel = questGlowCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    questGlowLabel:SetPoint("LEFT", questGlowCheck, "RIGHT", 8, 0)
    questGlowLabel:SetText("Quest Item Glow Effect")
    questGlowLabel:SetTextColor(0.9, 0.9, 1)
    questGlowCheck:SetScript("OnClick", function()
        LootMonitorDB.questItemGlow = questGlowCheck:GetChecked()
    end)
    
    contentY = contentY - 35
    
    -- Show Total Count checkbox
    local totalCountCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    totalCountCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, contentY)
    totalCountCheck:SetChecked(LootMonitorDB.showTotalCount)
    local totalCountLabel = totalCountCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalCountLabel:SetPoint("LEFT", totalCountCheck, "RIGHT", 8, 0)
    totalCountLabel:SetText("Show Total Count in Bags")
    totalCountLabel:SetTextColor(0.9, 0.9, 1)
    totalCountCheck:SetScript("OnClick", function()
        LootMonitorDB.showTotalCount = totalCountCheck:GetChecked()
    end)
    
    contentY = contentY - 45
    
    -- Animation Settings Section
    local animHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    animHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
    animHeader:SetText("Animation Settings")
    animHeader:SetTextColor(0.4, 0.8, 1)
    
    contentY = contentY - 35
    
    -- Scale slider with modern styling
    local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, contentY)
    scaleLabel:SetText("Scale: " .. format("%.1f", LootMonitorDB.scale))
    scaleLabel:SetTextColor(0.9, 0.9, 1)
    
    local scaleSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -15)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValue(LootMonitorDB.scale)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetWidth(300)
    scaleSlider:SetScript("OnValueChanged", function()
        local value = scaleSlider:GetValue()
        LootMonitorDB.scale = value
        scaleLabel:SetText("Scale: " .. format("%.1f", value))
    end)
    
    contentY = contentY - 65
    
    -- Fade In Time slider
    local fadeInLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fadeInLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, contentY)
    fadeInLabel:SetText("Fade In Time: " .. format("%.1f", LootMonitorDB.fadeInTime) .. "s")
    fadeInLabel:SetTextColor(0.9, 0.9, 1)
    
    local fadeInSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    fadeInSlider:SetPoint("TOPLEFT", fadeInLabel, "BOTTOMLEFT", 0, -15)
    fadeInSlider:SetMinMaxValues(0.1, 2.0)
    fadeInSlider:SetValue(LootMonitorDB.fadeInTime)
    fadeInSlider:SetValueStep(0.1)
    fadeInSlider:SetWidth(300)
    fadeInSlider:SetScript("OnValueChanged", function()
        local value = fadeInSlider:GetValue()
        LootMonitorDB.fadeInTime = value
        fadeInLabel:SetText("Fade In Time: " .. format("%.1f", value) .. "s")
    end)
    
    contentY = contentY - 65
    
    -- Display Time slider
    local displayLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    displayLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, contentY)
    displayLabel:SetText("Display Time: " .. format("%.1f", LootMonitorDB.displayTime) .. "s")
    displayLabel:SetTextColor(0.9, 0.9, 1)
    
    local displaySlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    displaySlider:SetPoint("TOPLEFT", displayLabel, "BOTTOMLEFT", 0, -15)
    displaySlider:SetMinMaxValues(1.0, 10.0)
    displaySlider:SetValue(LootMonitorDB.displayTime)
    displaySlider:SetValueStep(0.5)
    displaySlider:SetWidth(300)
    displaySlider:SetScript("OnValueChanged", function()
        local value = displaySlider:GetValue()
        LootMonitorDB.displayTime = value
        displayLabel:SetText("Display Time: " .. format("%.1f", value) .. "s")
    end)
    
    contentY = contentY - 65
    
    -- Fade Out Time slider
    local fadeOutLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fadeOutLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, contentY)
    fadeOutLabel:SetText("Fade Out Time: " .. format("%.1f", LootMonitorDB.fadeOutTime) .. "s")
    fadeOutLabel:SetTextColor(0.9, 0.9, 1)
    
    local fadeOutSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    fadeOutSlider:SetPoint("TOPLEFT", fadeOutLabel, "BOTTOMLEFT", 0, -15)
    fadeOutSlider:SetMinMaxValues(0.5, 3.0)
    fadeOutSlider:SetValue(LootMonitorDB.fadeOutTime)
    fadeOutSlider:SetValueStep(0.1)
    fadeOutSlider:SetWidth(300)
    fadeOutSlider:SetScript("OnValueChanged", function()
        local value = fadeOutSlider:GetValue()
        LootMonitorDB.fadeOutTime = value
        fadeOutLabel:SetText("Fade Out Time: " .. format("%.1f", value) .. "s")
    end)
    
    -- Button area inside the window
    local buttonY = 25 -- Distance from bottom, inside the frame
    
    -- Test button with even bigger size
    local testBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    testBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, buttonY)
    testBtn:SetWidth(140)
    testBtn:SetHeight(35)
    testBtn:SetText("Test Notification")
    testBtn:GetFontString():SetTextColor(1, 1, 1)
    testBtn:SetScript("OnClick", function()
        LootMonitor:CreateLootNotification("Test Item", 1, "Test Item", true)
    end)
    
    -- Move button with even bigger size
    local moveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    moveBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, buttonY)
    moveBtn:SetWidth(140)
    moveBtn:SetHeight(35)
    moveBtn:SetText("Position Window")
    moveBtn:GetFontString():SetTextColor(1, 1, 1)
    moveBtn:SetScript("OnClick", function()
        frame:Hide()
        LootMonitor:ToggleMoveMode()
    end)
    
    -- Reset button with even bigger size and full visual reset functionality
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, buttonY)
    resetBtn:SetWidth(140)
    resetBtn:SetHeight(35)
    resetBtn:SetText("Reset Settings")
    resetBtn:GetFontString():SetTextColor(1, 0.8, 0.8)
    resetBtn:SetScript("OnClick", function()
        -- Reset to defaults with proper deep copy for nested tables
        LootMonitorDB.enabled = defaults.enabled
        LootMonitorDB.scale = defaults.scale
        LootMonitorDB.fadeInTime = defaults.fadeInTime
        LootMonitorDB.displayTime = defaults.displayTime
        LootMonitorDB.fadeOutTime = defaults.fadeOutTime
        LootMonitorDB.questItemGlow = defaults.questItemGlow
        LootMonitorDB.showTotalCount = defaults.showTotalCount
        LootMonitorDB.position = {
            point = defaults.position.point,
            x = defaults.position.x,
            y = defaults.position.y
        }
        
        -- Update all checkboxes visually
        enableCheck:SetChecked(defaults.enabled)
        questGlowCheck:SetChecked(defaults.questItemGlow)
        totalCountCheck:SetChecked(defaults.showTotalCount)
        
        -- Update all sliders and labels visually
        scaleSlider:SetValue(defaults.scale)
                 scaleLabel:SetText("Scale: " .. format("%.1f", defaults.scale))
         
         fadeInSlider:SetValue(defaults.fadeInTime)
         fadeInLabel:SetText("Fade In Time: " .. format("%.1f", defaults.fadeInTime) .. "s")
         
         displaySlider:SetValue(defaults.displayTime)
         displayLabel:SetText("Display Time: " .. format("%.1f", defaults.displayTime) .. "s")
         
         fadeOutSlider:SetValue(defaults.fadeOutTime)
         fadeOutLabel:SetText("Fade Out Time: " .. format("%.1f", defaults.fadeOutTime) .. "s")
        
        Print("[Loot Monitor] Settings reset to defaults.")
    end)
    
    self.settingsFrame = frame
    frame:Hide()
end

-- Show settings panel
function LootMonitor:ShowSettings()
    if not self.settingsFrame then
        self:CreateSettingsPanel()
    end
    self.settingsFrame:Show()
end



-- Slash command
SLASH_LOOTMONITOR1 = "/lootmonitor"
SLASH_LOOTMONITOR2 = "/lm"
SlashCmdList["LOOTMONITOR"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "toggle" then
        LootMonitorDB.enabled = not LootMonitorDB.enabled
        if LootMonitorDB.enabled then
            Print("[Loot Monitor] Fading loot notifications enabled.")
        else
            Print("[Loot Monitor] Fading loot notifications disabled.")
            -- Clear active notifications
            for _, notification in ipairs(LootMonitor.activeNotifications) do
                LootMonitor:RemoveNotification(notification)
            end
        end
    elseif cmd == "" then
        -- Default action for /lootmonitor and /lm - open settings
        LootMonitor:ShowSettings()
    elseif cmd == "clear" then
        -- Clear active notifications
        for _, notification in ipairs(LootMonitor.activeNotifications) do
            LootMonitor:RemoveNotification(notification)
        end
        Print("[Loot Monitor] Active notifications cleared.")
    elseif cmd == "test" then
        -- Test notification with fallback icon
        LootMonitor:CreateLootNotification("Test Item", 1, "Test Item", true)
        Print("[Loot Monitor] Test notification created.")
    elseif cmd == "move" then
        LootMonitor:ToggleMoveMode()
    elseif cmd == "settings" or cmd == "config" then
        LootMonitor:ShowSettings()
    elseif cmd == "debug" then
        if LootMonitor.debugMode then
            LootMonitor.debugMode = false
            Print("[Loot Monitor] Debug mode disabled.")
        else
            LootMonitor.debugMode = true
            Print("[Loot Monitor] Debug mode enabled. All system messages with items will be printed.")
        end
    elseif cmd == "help" then
        Print("[Loot Monitor] Commands:")
        Print("  /lootmonitor or /lm - Open settings panel")
        Print("  /lootmonitor toggle or /lm toggle - Toggle notifications on/off")
        Print("  /lootmonitor clear - Clear active notifications")
        Print("  /lootmonitor test - Create test notification")
        Print("  /lootmonitor move - Toggle move mode to reposition notifications")
        Print("  /lootmonitor settings - Open settings panel")
        Print("  /lootmonitor debug - Toggle debug mode to see system messages")
        Print("  /lootmonitor help - Show this help")
    else
        Print("[Loot Monitor] Unknown command. Use '/lootmonitor help' for help.")
    end
end

-- Initialize when addon loads
if not LootMonitor.initialized then
    LootMonitor:RegisterEvents()
    LootMonitor.initialized = true
end 