DrSpammerEditingSlot = nil
DrSpammerEditingOriginalPattern = nil
DrSpammerEditingOriginalSettings = nil
DrSpammerClickTime = nil
DrSpammerTooltip = CreateFrame("GameTooltip", "DrSpammerTooltip", nil, "GameTooltipTemplate")
DrSpammerSlotTimers = {}
DrSpammerMouseOver = false

DrSpammer = DrSpammer or CreateFrame("Frame", "DrSpammer", UIParent)

DrSpammerDB = {
	posx , posy, posx1, posy1,
	Tumbler = false,
	Flag = false,
	Pattern = {},
	PatternSettings = {},
	CheckedPattern = 1,
	Channel = 1,
	ChatType = "CHANNEL",
	Interval = 30,
	LastTimeSpam = 0,
	SpamTasks = {},
	SavedSettings = {},
	NextTaskId = 1,
	NextSlotId = 1,
	Opacity = 0.5,
}

function DrSpammer_ShowIsengardDialog()
    local dialog = CreateFrame("Frame", "DrSpammerIsengardDialog", UIParent, "DialogBoxFrame")
    dialog:SetSize(350, 150)
    dialog:SetPoint("CENTER")
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    dialog:SetBackdropColor(0, 0, 0, 1)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Ссылка на сервер Isengard")
    
    local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    editBox:SetPoint("TOP", 0, -50)
    editBox:SetSize(300, 30)
    editBox:SetAutoFocus(true)
    editBox:SetText("https://ezwow.org/")
    editBox:HighlightText()
    editBox:SetFontObject(GameFontHighlight)
    
    local closeButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    closeButton:SetPoint("BOTTOM", 0, 20)
    closeButton:SetSize(100, 25)
    closeButton:SetScript("OnClick", function() dialog:Hide() end)
    
    dialog:Show()
end

function DrSpammer_FormatTime(seconds)
    if seconds < 0 then seconds = 0 end
    
    local days = floor(seconds / 86400)
    local hours = floor((seconds % 86400) / 3600)
    local minutes = floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    local result = ""
    
    if days > 0 then
        result = result .. days .. "д"
        if hours > 0 or minutes > 0 or secs > 0 then
            result = result .. ":"
        end
    end
    
    if hours > 0 then
        result = result .. hours .. "ч"
        if minutes > 0 or secs > 0 then
            result = result .. ":"
        end
    end
    
    if minutes > 0 then
        result = result .. minutes .. "м"
        if secs > 0 then
            result = result .. ":"
        end
    end
    
    if secs > 0 or (days == 0 and hours == 0 and minutes == 0) then
        if secs < 10 then
            result = result .. "0" .. secs .. "с"
        else
            result = result .. secs .. "с"
        end
    end
    
    return result
end

function DrSpammer_UpdateTooltip()
    if not DrSpammerMouseOver then return end
    
    GameTooltip_SetDefaultAnchor(DrSpammerTooltip, DrSpammer)
    DrSpammerTooltip:ClearLines()
    
    if DrSpammerDB.SpamTasks and next(DrSpammerDB.SpamTasks) ~= nil then
        DrSpammerTooltip:AddLine("Идет спам!", 0.77, 0.12, 0.23)
        local count = 0
        for k,v in pairs(DrSpammerDB.SpamTasks) do count = count + 1 end
        DrSpammerTooltip:AddLine("Активных задач: " .. count, 1, 1, 1)
        DrSpammerTooltip:AddLine(" ")
        
        local currentTime = time()
        for id, task in pairs(DrSpammerDB.SpamTasks) do
            local slotNumber = DrSpammer_GetSlotNumber(task.slotId)
            
            local patternNumber = "?"
            for i = 1, 10 do
                if DrSpammerDB.Pattern and DrSpammerDB.Pattern[i] == task.pattern then
                    patternNumber = i
                    break
                end
            end
            
            local typeText = task.chatType
            if task.chatType == "CHANNEL" then
                typeText = "Канал " .. task.channel
            elseif task.chatType == "SAY" then
                typeText = "Сказать"
            elseif task.chatType == "YELL" then
                typeText = "Крикнуть"
            elseif task.chatType == "GUILD" then
                typeText = "Гильдия"
            end
            
            local timeLeft = (task.lastTime + task.interval) - currentTime
            if timeLeft < 0 then timeLeft = 0 end
            local formattedTime = DrSpammer_FormatTime(timeLeft)
            
            DrSpammerTooltip:AddLine("Слот " .. slotNumber .. " | ш. " .. patternNumber .. " | Тип: " .. typeText .. " | Интервал: " .. task.interval .. "c | " .. formattedTime, 0.5, 1, 0.5)
            
            local messageText = task.pattern or ""
            
            for i = 1, 8 do
                messageText = string.gsub(messageText, "{rt" .. i .. "}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":0|t")
            end
            
            local textForLength = messageText
            textForLength = string.gsub(textForLength, "|c%x%x%x%x%x%x%x%x", "")
            textForLength = string.gsub(textForLength, "|r", "")
            textForLength = string.gsub(textForLength, "|H.-|h(.-)|h", "%1")
            textForLength = string.gsub(textForLength, "|T.-:0|t", "II")
            
            if strlen(textForLength) > 100 then
                local result = ""
                local currentPos = 1
                local charCount = 0
                local maxChars = 97
                local inTag = false
                local tagType = ""
                local tagStart = 1
                
                while currentPos <= strlen(messageText) and charCount < maxChars do
                    local char = strsub(messageText, currentPos, currentPos)
                    
                    if char == "|" and not inTag then
                        local nextChar = strsub(messageText, currentPos + 1, currentPos + 1)
                        
                        if nextChar == "T" then
                            inTag = true
                            tagType = "icon"
                            tagStart = currentPos
                            currentPos = currentPos + 1
                        elseif nextChar == "H" then
                            inTag = true
                            tagType = "link"
                            tagStart = currentPos
                            currentPos = currentPos + 1
                        elseif nextChar == "c" then
                            inTag = true
                            tagType = "color"
                            tagStart = currentPos
                            currentPos = currentPos + 1
                        elseif nextChar == "r" then
                            result = result .. "|r"
                            currentPos = currentPos + 2
                        else
                            result = result .. char
                            currentPos = currentPos + 1
                            charCount = charCount + 1
                        end
                    elseif inTag then
                        if tagType == "icon" then
                            local iconEnd = strfind(messageText, ":0|t", currentPos)
                            if iconEnd then
                                result = result .. strsub(messageText, tagStart, iconEnd + 3)
                                currentPos = iconEnd + 4
                                inTag = false
                            else
                                currentPos = currentPos + 1
                            end
                        elseif tagType == "link" then
                            local firstH = strfind(messageText, "|h", currentPos)
                            if firstH then
                                local secondH = strfind(messageText, "|h", firstH + 2)
                                if secondH then
                                    result = result .. strsub(messageText, tagStart, secondH + 1)
                                    local linkText = strsub(messageText, firstH + 2, secondH - 1)
                                    charCount = charCount + strlen(linkText)
                                    currentPos = secondH + 2
                                    inTag = false
                                else
                                    currentPos = currentPos + 1
                                end
                            else
                                currentPos = currentPos + 1
                            end
                        elseif tagType == "color" then
                            if currentPos - tagStart >= 9 then
                                result = result .. strsub(messageText, tagStart, tagStart + 9)
                                currentPos = tagStart + 10
                                inTag = false
                            else
                                currentPos = currentPos + 1
                            end
                        else
                            currentPos = currentPos + 1
                        end
                    else
                        result = result .. char
                        currentPos = currentPos + 1
                        charCount = charCount + 1
                    end
                end
                
                if currentPos <= strlen(messageText) then
                    result = result .. "..."
                end
                
                messageText = result
            end
            
            DrSpammerTooltip:AddLine(messageText, 1, 1, 1)
            DrSpammerTooltip:AddLine(" ")
        end
    else
        DrSpammerTooltip:AddLine("Нет активных задач", 1, 1, 1)
    end
    
    DrSpammerTooltip:Show()
end

function DrSpammer_UpdateSlotTimers()
    if not DrSpammerDB.SpamTasks then return end
    
    local currentTime = time()
    
    for id, task in pairs(DrSpammerDB.SpamTasks) do
        local timeLeft = (task.lastTime + task.interval) - currentTime
        if timeLeft < 0 then timeLeft = 0 end
        
        local slotNumber = DrSpammer_GetSlotNumber(task.slotId)
        if slotNumber and slotNumber ~= "?" then
            local frame = _G["DrSpammerSlotFrame" .. slotNumber]
            if frame then
                local stopButton = _G["DrSpammerSlotFrame" .. slotNumber .. "Stop"]
                local timerText = _G["DrSpammerSlotFrame" .. slotNumber .. "Timer"]
                
                if stopButton and stopButton:IsShown() then
                    if not timerText then
                        timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        timerText:SetPoint("LEFT", frame, "RIGHT", 11, 0)
                        timerText:SetTextColor(0, 1, 0)
                        timerText:SetFontObject(GameFontNormal)
                        timerText:SetJustifyH("LEFT")
                        
                        _G["DrSpammerSlotFrame" .. slotNumber .. "Timer"] = timerText
                    end
                    
                    local formattedTime = DrSpammer_FormatTime(timeLeft)
                    timerText:SetText("[" .. formattedTime .. "]")
                    timerText:Show()
                end
            end
        end
    end
    
    for i = 1, 10 do
        local timerText = _G["DrSpammerSlotFrame" .. i .. "Timer"]
        if timerText then
            local stopButton = _G["DrSpammerSlotFrame" .. i .. "Stop"]
            if not stopButton or not stopButton:IsShown() then
                timerText:Hide()
            end
        end
    end
end

function DrSpammer_InitPatterns()
    if not DrSpammerDB.Pattern then
        DrSpammerDB.Pattern = {}
    end
    if not DrSpammerDB.PatternSettings then
        DrSpammerDB.PatternSettings = {}
    end
    
    for i = 1, 10 do
        if not DrSpammerDB.Pattern[i] or DrSpammerDB.Pattern[i] == "Пусто" then
            DrSpammerDB.Pattern[i] = ""
        end
        
        if not DrSpammerDB.PatternSettings[i] then
            DrSpammerDB.PatternSettings[i] = {
                chatType = "CHANNEL",
                channel = 1,
                interval = 30,
            }
        end
    end
end

local DrSpammerRaidIconList = {
[1] = { text = RAID_TARGET_1, color = {r = 1.0, g = 0.92, b = 0}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0, tCoordRight = 0.25, tCoordTop = 0, tCoordBottom = 0.25 };
[2] = { text = RAID_TARGET_2, color = {r = 0.98, g = 0.57, b = 0}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.25, tCoordRight = 0.5, tCoordTop = 0, tCoordBottom = 0.25 };
[3] = { text = RAID_TARGET_3, color = {r = 0.83, g = 0.22, b = 0.9}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.5, tCoordRight = 0.75, tCoordTop = 0, tCoordBottom = 0.25 };
[4] = { text = RAID_TARGET_4, color = {r = 0.04, g = 0.95, b = 0}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.75, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 0.25 };
[5] = { text = RAID_TARGET_5, color = {r = 0.7, g = 0.82, b = 0.875}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0, tCoordRight = 0.25, tCoordTop = 0.25, tCoordBottom = 0.5 };
[6] = { text = RAID_TARGET_6, color = {r = 0, g = 0.71, b = 1}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.25, tCoordRight = 0.5, tCoordTop = 0.25, tCoordBottom = 0.5 };
[7] = { text = RAID_TARGET_7, color = {r = 1.0, g = 0.24, b = 0.168}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.5, tCoordRight = 0.75, tCoordTop = 0.25, tCoordBottom = 0.5 };
[8] = { text = RAID_TARGET_8, color = {r = 0.98, g = 0.98, b = 0.98}, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", tCoordLeft = 0.75, tCoordRight = 1, tCoordTop = 0.25, tCoordBottom = 0.5 };
}

function DrSpammer_Translit(text)
    if not text then return "" end
    local result = text
    result = string.gsub(result, "А", "A"); result = string.gsub(result, "Б", "6"); result = string.gsub(result, "В", "B")
    result = string.gsub(result, "Г", "r"); result = string.gsub(result, "Д", "g"); result = string.gsub(result, "Е", "E")
    result = string.gsub(result, "Ё", "E"); result = string.gsub(result, "Ж", ">|<"); result = string.gsub(result, "З", "3")
    result = string.gsub(result, "И", "U"); result = string.gsub(result, "Й", "U`"); result = string.gsub(result, "К", "K")
    result = string.gsub(result, "Л", "Jl"); result = string.gsub(result, "М", "M"); result = string.gsub(result, "Н", "H")
    result = string.gsub(result, "О", "O"); result = string.gsub(result, "П", "n"); result = string.gsub(result, "Р", "P")
    result = string.gsub(result, "С", "C"); result = string.gsub(result, "Т", "T"); result = string.gsub(result, "У", "Y")
    result = string.gsub(result, "Ф", "O|O"); result = string.gsub(result, "Х", "X"); result = string.gsub(result, "Ц", "U,")
    result = string.gsub(result, "Ч", "4"); result = string.gsub(result, "Ш", "W"); result = string.gsub(result, "Щ", "W,")
    result = string.gsub(result, "Ъ", "b"); result = string.gsub(result, "Ы", "bI"); result = string.gsub(result, "Ь", "b")
    result = string.gsub(result, "Э", "3"); result = string.gsub(result, "Ю", "|-O"); result = string.gsub(result, "Я", "9|")
    result = string.gsub(result, "а", "a"); result = string.gsub(result, "б", "6"); result = string.gsub(result, "в", "B")
    result = string.gsub(result, "г", "r"); result = string.gsub(result, "д", "g"); result = string.gsub(result, "е", "e")
    result = string.gsub(result, "ё", "e"); result = string.gsub(result, "ж", ">|<"); result = string.gsub(result, "з", "3")
    result = string.gsub(result, "и", "u"); result = string.gsub(result, "й", "u`"); result = string.gsub(result, "к", "k")
    result = string.gsub(result, "л", "Jl"); result = string.gsub(result, "м", "m"); result = string.gsub(result, "н", "H")
    result = string.gsub(result, "о", "o"); result = string.gsub(result, "п", "n"); result = string.gsub(result, "р", "p")
    result = string.gsub(result, "с", "c"); result = string.gsub(result, "т", "m"); result = string.gsub(result, "у", "y")
    result = string.gsub(result, "ф", "o|o"); result = string.gsub(result, "х", "x"); result = string.gsub(result, "ц", "u,")
    result = string.gsub(result, "ч", "4"); result = string.gsub(result, "ш", "w"); result = string.gsub(result, "щ", "w,")
    result = string.gsub(result, "ъ", "b"); result = string.gsub(result, "ы", "bI"); result = string.gsub(result, "ь", "b")
    result = string.gsub(result, "э", "3"); result = string.gsub(result, "ю", "|-o"); result = string.gsub(result, "я", "9|")
    return result
end

function DrSpammer_DoTranslit()
    local text = DrSpammerSettingTextBox:GetText() or ""
    text = DrSpammer_Translit(text)
    DrSpammerSettingTextBox:SetText(text)
    DrSpammerSettingTextBox_OnTextChanged()
end

function DrSpammer_CleanText(text)
    if not text then return "" end
    local cleaned = string.gsub(text, "\n", " ")
    cleaned = string.gsub(cleaned, "%s+", " ")
    cleaned = string.gsub(cleaned, "^%s*(.-)%s*$", "%1")
    return cleaned
end

function DrSpammer_FillTable()
	for i=1,10 do DrSpammerDB.Pattern[i] = "" end
	DrSpammerDB.CheckedPattern = 1
	DrSpammerDB.Channel = 1
	DrSpammerDB.ChatType = "CHANNEL"
	DrSpammerDB.Interval = 30
	DrSpammerDB.Tumbler = false
	DrSpammerDB.Flag = true
	DrSpammerDB.LastTimeSpam = 0
	DrSpammerDB.SpamTasks = {}
	DrSpammerDB.SavedSettings = {}
	DrSpammerDB.NextTaskId = 1
	DrSpammerDB.NextSlotId = 1
	DrSpammer_InitPatterns()
end

function DrSpammer_LoadPatternSettings(patternIndex)
    if not DrSpammerDB.PatternSettings then DrSpammerDB.PatternSettings = {} end
    if not DrSpammerDB.PatternSettings[patternIndex] then
        DrSpammerDB.PatternSettings[patternIndex] = { 
            chatType = "CHANNEL",
            channel = 1, 
            interval = 30 
        }
    end
    local settings = DrSpammerDB.PatternSettings[patternIndex]
    DrSpammerDB.ChatType = settings.chatType
    DrSpammerDB.Channel = settings.channel or 1
    DrSpammerDB.Interval = settings.interval or 30
    DrSpammerIntervalButton:SetText(DrSpammerDB.Interval .. " cек.")
    DrSpammerSettingChatTypeEditBox:SetText(DrSpammerDB.ChatType)
    if DrSpammerDB.ChatType == "GUILD" then
        DrSpammerSettingChanelEditBox:SetText("Гильдия")
    elseif DrSpammerDB.ChatType == "CHANNEL" then
        DrSpammerSettingChanelEditBox:SetText("Канал " .. DrSpammerDB.Channel)
    else
        DrSpammerSettingChanelEditBox:SetText(DrSpammerDB.ChatType)
    end
    if DrSpammerDB.ChatType ~= "CHANNEL" then
        DrSpammerSettingChanelButton:Disable()
        DrSpammerSettingChanelEditBox:SetTextColor(0.5, 0.5, 0.5)
    else
        DrSpammerSettingChanelButton:Enable()
        DrSpammerSettingChanelEditBox:SetTextColor(1, 1, 1)
    end
end

function DrSpammer_SavePatternSettings()
    local patternIndex = DrSpammerDB.CheckedPattern
    if not DrSpammerDB.PatternSettings then DrSpammerDB.PatternSettings = {} end
    DrSpammerDB.PatternSettings[patternIndex] = {
        chatType = DrSpammerDB.ChatType,
        channel = DrSpammerDB.Channel,
        interval = DrSpammerDB.Interval,
    }
    local currentText = DrSpammerSettingTextBox:GetText() or ""
    currentText = DrSpammer_CleanText(currentText)
    DrSpammerDB.Pattern[patternIndex] = currentText
end

function DrSpammer_SetText()
    if not DrSpammerText then return end
	if not DrSpammerDB.SpamTasks or not next(DrSpammerDB.SpamTasks) then
		DrSpammerText:SetText("DrSpam |cffff0000выкл|r")
	else
		local count = 0
		for k,v in pairs(DrSpammerDB.SpamTasks) do count = count + 1 end
		DrSpammerText:SetText("DrSpam |cff00ff00вкл (" .. count .. ")|r")
	end	
end

function DrSpammer:OnMouseDown(self, arg1)
    if arg1 == "LeftButton" then
        DrSpammerClickTime = GetTime()
        self:StartMoving()
        self.isMoving = true
        return
    end
    if ( arg1 == "RightButton" ) then  
        if DrSpammerSetting:IsShown() then
            DrSpammerSetting:Hide()
        else
            DrSpammerSetting:Show()
            if DrSpammerSettingTextBox then
                DrSpammerSettingTextBox:ClearFocus()
            end
        end		
        return
    end
	if DrSpammerDB.Flag == false then DrSpammer_FillTable() end
	DrSpammerSettingTextPatternEditBox:SetText("Шаблон " .. tostring(DrSpammerDB.CheckedPattern))
	DrSpammerSettingTextBox:SetText(DrSpammerDB.Pattern[DrSpammerDB.CheckedPattern])
    DrSpammer_LoadPatternSettings(DrSpammerDB.CheckedPattern)
    DrSpammerIntervalButton:SetText(DrSpammerDB.Interval .. " cек.")
    if DrSpammerDB.ChatType == "GUILD" then
        DrSpammerSettingChanelEditBox:SetText("Гильдия")
    else
        DrSpammerSettingChanelEditBox:SetText("Канал " .. DrSpammerDB.Channel)
    end
	DrSpammerSettingChatTypeEditBox:SetText(DrSpammerDB.ChatType)
	DrSpammer_UpdateSlotsList()
    if DrSpammerIntervalEditBox then
        DrSpammerIntervalEditBox:Hide()
        DrSpammerIntervalButton:Show()
    end
    if DrSpammerTextEditButton and DrSpammerTextEditButton:GetText() ~= "Редактировать" then
        DrSpammer_ToggleTextEditMode()
    end
    DrSpammerEditingSlot = nil
    DrSpammerEditingOriginalPattern = nil
    DrSpammerEditingOriginalSettings = nil
    if DrSpammerSettingSaveButton then
	    DrSpammerSettingSaveButton:Enable()
        DrSpammerSettingSaveButton:SetText("Сохранить слот")
    end
    if DrSpammerTextEditButton then
        DrSpammerTextEditButton:Enable()
        DrSpammerTextEditButton:SetText("Редактировать")
    end
	if DrSpammerDB.ChatType ~= "CHANNEL" then
		DrSpammerSettingChanelButton:Disable()
		DrSpammerSettingChanelEditBox:SetTextColor(0.5, 0.5, 0.5)
	else
		DrSpammerSettingChanelButton:Enable()
		DrSpammerSettingChanelEditBox:SetTextColor(1, 1, 1)
	end
end

function DrSpammer:OnMouseUp(self, arg1)
    if arg1 == "LeftButton" then
        if DrSpammerClickTime and (GetTime() - DrSpammerClickTime <= 0.2) then
            if DrSpammerDB.SpamTasks and next(DrSpammerDB.SpamTasks) ~= nil then
                local count = 0
                for id, task in pairs(DrSpammerDB.SpamTasks) do
                    DrSpammerDB.SpamTasks[id] = nil
                    count = count + 1
                end
                DrSpammer_UpdateSlotsList()
                DrSpammer_SetText()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Остановлено " .. count .. " активных слотов|r")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Нет активных слотов|r")
            end
        end
        if self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false
            DrSpammer:SavePosition(1)
        end
        DrSpammerClickTime = nil
    end
end

function DrSpammer_UpdateSlotsList()
    if not DrSpammerDB.SavedSettings then DrSpammerDB.SavedSettings = {} end
    for i = 1, 10 do
        local frame = _G["DrSpammerSlotFrame" .. i]
        if frame then frame:Hide() end
    end
    local slotsArray = {}
    for id, settings in pairs(DrSpammerDB.SavedSettings) do
        table.insert(slotsArray, {id = id, settings = settings})
    end
    table.sort(slotsArray, function(a, b)
        return (a.settings.timeAdded or 0) > (b.settings.timeAdded or 0)
    end)
    for index = 1, math.min(#slotsArray, 10) do
        local slotData = slotsArray[index]
        local id = slotData.id
        local settings = slotData.settings
        local frame = _G["DrSpammerSlotFrame" .. index]
        if not frame then break end
        local textLine = _G["DrSpammerSlotFrame" .. index .. "Text"]
        local startButton = _G["DrSpammerSlotFrame" .. index .. "Start"]
        local stopButton = _G["DrSpammerSlotFrame" .. index .. "Stop"]
        local editButton = _G["DrSpammerSlotFrame" .. index .. "Edit"]
        local deleteButton = _G["DrSpammerSlotFrame" .. index .. "Delete"]
        local timerText = _G["DrSpammerSlotFrame" .. index .. "Timer"]
        
        if timerText then
            timerText:Hide()
            timerText = nil
        end
        
        local typeText = settings.chatType
        if settings.chatType == "CHANNEL" then
            typeText = "Канал " .. settings.channel
        elseif settings.chatType == "SAY" then
            typeText = "Сказать"
        elseif settings.chatType == "YELL" then
            typeText = "Крикнуть"
        elseif settings.chatType == "GUILD" then
            typeText = "Гильдия"
        end
        
        local patternNumber = "?"
        for i = 1, 10 do
            if DrSpammerDB.Pattern[i] == settings.pattern then
                patternNumber = i
                break
            end
        end
        
        if textLine then
            local patternText = settings.pattern
            local displayText = "[" .. index .. "] (ш." .. patternNumber .. ") " .. typeText .. " [" .. settings.interval .. "c] " .. patternText
            for i = 1, 8 do
                displayText = string.gsub(displayText, "{rt" .. i .. "}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":0|t")
            end
            textLine:SetText(displayText)
        end
        
        frame:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(DrSpammerTooltip, self)
            DrSpammerTooltip:ClearLines()
            DrSpammerTooltip:AddLine("Полный текст:", 1, 1, 1)
            local fullText = settings.pattern
            local lineLength = 60
            local startPos = 1
            while startPos <= strlen(fullText) do
                local endPos = math.min(startPos + lineLength - 1, strlen(fullText))
                local line = strsub(fullText, startPos, endPos)
                DrSpammerTooltip:AddLine(line, 0.5, 1, 0.5, true)
                startPos = endPos + 1
            end
            DrSpammerTooltip:AddLine(" ")
            DrSpammerTooltip:AddLine("Тип: " .. typeText, 0.7, 0.7, 1)
            DrSpammerTooltip:AddLine("Интервал: " .. settings.interval .. " сек", 0.7, 0.7, 1)
            DrSpammerTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self) DrSpammerTooltip:Hide() end)
        
        if startButton then
            startButton:SetID(id)
            startButton:Show()
            local isActive = false
            for taskId, task in pairs(DrSpammerDB.SpamTasks) do
                if task.slotId == id then isActive = true break end
            end
            if isActive then
                startButton:SetText("|cff00ff00Start|r")
            else
                startButton:SetText("|cff888888Start|r")
            end
            startButton:SetScript("OnEnter", function(self)
                GameTooltip_SetDefaultAnchor(DrSpammerTooltip, self)
                DrSpammerTooltip:ClearLines()
                DrSpammerTooltip:AddLine("Запустить спам", 0, 1, 0)
                local params = "Тип чата: " .. typeText .. " | Интервал: " .. settings.interval .. "c"
                DrSpammerTooltip:AddLine(params, 0.7, 0.7, 1)
                DrSpammerTooltip:AddLine(" ")
                local fullText = settings.pattern
                local displayText = fullText
                for i = 1, 8 do
                    displayText = string.gsub(displayText, "{rt" .. i .. "}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":0|t")
                end
                DrSpammerTooltip:AddLine(displayText, 1, 1, 1, true)
                DrSpammerTooltip:SetMinimumWidth(300)
                DrSpammerTooltip:Show()
            end)
            startButton:SetScript("OnLeave", function(self) DrSpammerTooltip:Hide() end)
        end
        
        if stopButton then
            stopButton:SetID(id)
            stopButton:SetScript("OnEnter", function(self)
                GameTooltip_SetDefaultAnchor(DrSpammerTooltip, self)
                DrSpammerTooltip:ClearLines()
                DrSpammerTooltip:AddLine("Остановить спам", 1, 0, 0)
                local params = "Тип чата: " .. typeText .. " | Интервал: " .. settings.interval .. "c"
                DrSpammerTooltip:AddLine(params, 0.7, 0.7, 1)
                DrSpammerTooltip:AddLine(" ")
                local fullText = settings.pattern
                local displayText = fullText
                for i = 1, 8 do
                    displayText = string.gsub(displayText, "{rt" .. i .. "}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":0|t")
                end
                DrSpammerTooltip:AddLine(fullText, 1, 1, 1, true)
                DrSpammerTooltip:SetMinimumWidth(300)
                DrSpammerTooltip:Show()
            end)
            stopButton:SetScript("OnLeave", function(self) DrSpammerTooltip:Hide() end)
            
            local isActive = false
            for taskId, task in pairs(DrSpammerDB.SpamTasks) do
                if task.slotId == id then isActive = true break end
            end
            if isActive then
                stopButton:Show()
                if startButton then startButton:Hide() end
            else
                stopButton:Hide()
                if startButton then startButton:Show() end
            end
        end
        
        if editButton then
            editButton:SetID(id)
            editButton:Show()
            editButton:SetScript("OnEnter", function(self)
                GameTooltip_SetDefaultAnchor(DrSpammerTooltip, self)
                DrSpammerTooltip:ClearLines()
                DrSpammerTooltip:AddLine("Редактировать слот " .. index, 1, 1, 0)
                DrSpammerTooltip:AddLine("ID: " .. id, 0.5, 0.5, 1)
                DrSpammerTooltip:AddLine("Загрузить настройки в интерфейс", 1, 1, 1)
                DrSpammerTooltip:Show()
            end)
            editButton:SetScript("OnLeave", function(self) DrSpammerTooltip:Hide() end)
        end
        
        if deleteButton then
            deleteButton:SetID(id)
            deleteButton:Show()
            deleteButton:SetScript("OnEnter", function(self)
                GameTooltip_SetDefaultAnchor(DrSpammerTooltip, self)
                DrSpammerTooltip:ClearLines()
                DrSpammerTooltip:AddLine("Удалить слот " .. index, 1, 0.5, 0)
                DrSpammerTooltip:Show()
            end)
            deleteButton:SetScript("OnLeave", function(self) DrSpammerTooltip:Hide() end)
        end
        
        frame:Show()
    end
end

function DrSpammer_GetSlotNumber(slotId)
    if not DrSpammerDB.SavedSettings then return "?" end
    local slotsArray = {}
    for id, settings in pairs(DrSpammerDB.SavedSettings) do
        table.insert(slotsArray, {id = id, settings = settings})
    end
    table.sort(slotsArray, function(a, b)
        return (a.settings.timeAdded or 0) > (b.settings.timeAdded or 0)
    end)
    for index, slotData in ipairs(slotsArray) do
        if slotData.id == slotId then return index end
    end
    return "?"
end

function DrSpammer_ToggleTextEditMode()
    local button = DrSpammerTextEditButton
    local editBox = DrSpammerSettingTextBox
    local saveButton = DrSpammerSettingSaveButton
    
    if button:GetText() == "Редактировать" or button:GetText() == "|cff888888Редактировать|r" then
        editBox:SetScript("OnTextChanged", DrSpammerSettingTextBox_OnTextChanged)
        editBox:EnableMouse(true)
        editBox:EnableKeyboard(true)
        editBox:SetFocus()
        button:SetText("|cff87cefaСохранить текст|r")
        DrSpammerSettingTextBox_OnTextChanged()
        
        if saveButton then
            saveButton:Disable()
            saveButton:SetText("|cff888888Сохранить слот|r")
        end
        
    else
        editBox:ClearFocus()
        editBox:SetScript("OnTextChanged", nil)
        editBox:EnableMouse(false)
        editBox:EnableKeyboard(false)
        editBox:SetScript("OnEditFocusGained", nil)
        editBox:SetScript("OnEditFocusLost", nil)
        
        button:SetText("Редактировать")
        
        if saveButton and not DrSpammerEditingSlot then
            saveButton:Enable()
            saveButton:SetText("Сохранить слот")
        elseif saveButton and DrSpammerEditingSlot then
            saveButton:Enable()
            saveButton:SetText("|cff00ff00Обновить слот|r")
        end
        
        local newText = editBox:GetText()
        newText = DrSpammer_CleanText(newText)
        DrSpammerDB.Pattern[DrSpammerDB.CheckedPattern] = newText
        DrSpammer_SavePatternSettings()
        DrSpammerSettingTextBox_OnTextChanged()
        
        if DrSpammerEditingSlot then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Шаблон сохранен. Для обновления слота нажмите 'Обновить слот'|r")
        end
    end
end

function DrSpammer_SaveCurrentSettings()
    if not DrSpammerDB.SavedSettings then DrSpammerDB.SavedSettings = {} end
    
    local currentText = DrSpammerSettingTextBox:GetText() or ""
    currentText = DrSpammer_CleanText(currentText)
    
    if currentText == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Нельзя сохранить пустой текст в слот!|r")
        return
    end
    
    local originalPattern = DrSpammerDB.CheckedPattern
    local originalPatternSettings = nil
    if DrSpammerDB.PatternSettings and DrSpammerDB.PatternSettings[originalPattern] then
        originalPatternSettings = {
            chatType = DrSpammerDB.PatternSettings[originalPattern].chatType,
            channel = DrSpammerDB.PatternSettings[originalPattern].channel,
            interval = DrSpammerDB.PatternSettings[originalPattern].interval,
        }
    end
    
    if DrSpammerEditingSlot then
        if not DrSpammerDB.SavedSettings[DrSpammerEditingSlot] then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Ошибка: слот не найден!|r")
            DrSpammerEditingSlot = nil
            DrSpammerSettingSaveButton:SetText("Сохранить слот")
            if DrSpammerTextEditButton then
                DrSpammerTextEditButton:Enable()
                DrSpammerTextEditButton:SetText("Редактировать")
            end
            return
        end
        local originalTime = DrSpammerDB.SavedSettings[DrSpammerEditingSlot].timeAdded or time()
        DrSpammerDB.SavedSettings[DrSpammerEditingSlot] = {
            id = DrSpammerEditingSlot,
            pattern = currentText,
            chatType = DrSpammerDB.ChatType,
            channel = DrSpammerDB.Channel,
            interval = DrSpammerDB.Interval,
            timeAdded = originalTime,
        }
        for id, task in pairs(DrSpammerDB.SpamTasks) do
            if task.slotId == DrSpammerEditingSlot then
                task.pattern = currentText
                task.chatType = DrSpammerDB.ChatType
                task.channel = DrSpammerDB.Channel
                task.interval = DrSpammerDB.Interval
                break
            end
        end
        
        if originalPatternSettings then
            DrSpammerDB.ChatType = originalPatternSettings.chatType
            DrSpammerDB.Channel = originalPatternSettings.channel
            DrSpammerDB.Interval = originalPatternSettings.interval
            DrSpammerIntervalButton:SetText(DrSpammerDB.Interval .. " cек.")
            DrSpammerSettingChatTypeEditBox:SetText(DrSpammerDB.ChatType)
            if DrSpammerDB.ChatType == "GUILD" then
                DrSpammerSettingChanelEditBox:SetText("Гильдия")
            elseif DrSpammerDB.ChatType == "CHANNEL" then
                DrSpammerSettingChanelEditBox:SetText("Канал " .. DrSpammerDB.Channel)
            else
                DrSpammerSettingChanelEditBox:SetText(DrSpammerDB.ChatType)
            end
            if DrSpammerDB.ChatType ~= "CHANNEL" then
                DrSpammerSettingChanelButton:Disable()
                DrSpammerSettingChanelEditBox:SetTextColor(0.5, 0.5, 0.5)
            else
                DrSpammerSettingChanelButton:Enable()
                DrSpammerSettingChanelEditBox:SetTextColor(1, 1, 1)
            end
            DrSpammerSettingTextBox:SetText(DrSpammerDB.Pattern[originalPattern] or "")
        end
        
        local slotNumber = DrSpammer_GetSlotNumber(DrSpammerEditingSlot)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Слот " .. slotNumber .. " обновлен!|r")
        
        DrSpammerEditingSlot = nil
        DrSpammerSettingSaveButton:SetText("Сохранить слот")
        
        if DrSpammerTextEditButton then
            DrSpammerTextEditButton:Enable()
            DrSpammerTextEditButton:SetText("Редактировать")
        end
        
        local editBox = DrSpammerSettingTextBox
        if editBox then
            editBox:ClearFocus()
            editBox:SetScript("OnTextChanged", nil)
            editBox:EnableMouse(false)
            editBox:EnableKeyboard(false)
            editBox:SetScript("OnEditFocusGained", nil)
            editBox:SetScript("OnEditFocusLost", nil)
        end
        
    else
        if not DrSpammerDB.NextSlotId then DrSpammerDB.NextSlotId = 1 end
        local count = 0
        for k, v in pairs(DrSpammerDB.SavedSettings) do count = count + 1 end
        if count >= 10 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Достигнут максимум слотов (10)!|r")
            return
        end
        local newId = DrSpammerDB.NextSlotId
        while DrSpammerDB.SavedSettings[newId] do newId = newId + 1 end
        local settings = {
            id = newId,
            pattern = currentText,
            chatType = DrSpammerDB.ChatType,
            channel = DrSpammerDB.Channel,
            interval = DrSpammerDB.Interval,
            timeAdded = time(),
        }
        DrSpammerDB.SavedSettings[newId] = settings
        DrSpammerDB.NextSlotId = newId + 1
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Новый слот сохранен!|r")
        if DrSpammerTextEditButton then
            DrSpammerTextEditButton:Enable()
            DrSpammerTextEditButton:SetText("Редактировать")
        end
        local editBox = DrSpammerSettingTextBox
        if editBox then
            editBox:ClearFocus()
            editBox:SetScript("OnTextChanged", nil)
            editBox:EnableMouse(false)
            editBox:EnableKeyboard(false)
        end
    end
    
    DrSpammer_UpdateSlotsList()
end

function DrSpammer_EditSlot(slotId)
    if not DrSpammerDB.SavedSettings or not DrSpammerDB.SavedSettings[slotId] then return end
    
    -- for id, task in pairs(DrSpammerDB.SpamTasks) do
        -- if task.slotId == slotId then
            -- DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Сначала остановите спам этого слота!|r")
            -- return
        -- end
    -- end
    
    DrSpammerEditingSlot = slotId
    DrSpammerEditingOriginalPattern = DrSpammerDB.CheckedPattern
    DrSpammerEditingOriginalSettings = {
        chatType = DrSpammerDB.ChatType,
        channel = DrSpammerDB.Channel,
        interval = DrSpammerDB.Interval,
    }
    
    local slotNumber = DrSpammer_GetSlotNumber(slotId)
    local settings = DrSpammerDB.SavedSettings[slotId]
    
    DrSpammerDB.ChatType = settings.chatType
    DrSpammerDB.Channel = settings.channel
    DrSpammerDB.Interval = settings.interval
    DrSpammerIntervalButton:SetText(DrSpammerDB.Interval .. " cек.")
    
    DrSpammerSettingChatTypeEditBox:SetText(DrSpammerDB.ChatType)
    if DrSpammerDB.ChatType == "GUILD" then
        DrSpammerSettingChanelEditBox:SetText("Гильдия")
    elseif DrSpammerDB.ChatType == "CHANNEL" then
        DrSpammerSettingChanelEditBox:SetText("Канал " .. DrSpammerDB.Channel)
    else
        DrSpammerSettingChanelEditBox:SetText(DrSpammerDB.ChatType)
    end
    
    if DrSpammerDB.ChatType ~= "CHANNEL" then
        DrSpammerSettingChanelButton:Disable()
        DrSpammerSettingChanelEditBox:SetTextColor(0.5, 0.5, 0.5)
    else
        DrSpammerSettingChanelButton:Enable()
        DrSpammerSettingChanelEditBox:SetTextColor(1, 1, 1)
    end
    
    DrSpammerSettingTextBox:SetText(settings.pattern)
    DrSpammerSettingTextPatternEditBox:SetText("Шаблон " .. DrSpammerDB.CheckedPattern)
    
    if DrSpammerSettingSaveButton then
        DrSpammerSettingSaveButton:Enable()
        DrSpammerSettingSaveButton:SetText("|cff00ff00Обновить слот|r")
    end
    
    if DrSpammerTextEditButton then
        DrSpammerTextEditButton:Disable()
        DrSpammerTextEditButton:SetText("|cff888888Редактировать|r")
    end
    
    local editBox = DrSpammerSettingTextBox
    if editBox then
        editBox:SetScript("OnTextChanged", DrSpammerSettingTextBox_OnTextChanged)
        editBox:EnableMouse(true)
        editBox:EnableKeyboard(true)
        editBox:SetFocus()
        DrSpammerSettingTextBox_OnTextChanged()
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Редактирование слота " .. slotNumber .. ". Измените и нажмите 'Обновить слот'|r")
end

function TextPattern_OnClick(arg1)
    if not DrSpammerSettingTextBox then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Ошибка: поле ввода не найдено!|r")
        return
    end
    
    if not DrSpammerEditingSlot then
        local currentText = DrSpammerSettingTextBox:GetText() or ""
        if currentText ~= "" then
            DrSpammerDB.Pattern[DrSpammerDB.CheckedPattern] = currentText
            DrSpammer_SavePatternSettings()
        end
    end
    
    DrSpammerDB.CheckedPattern = arg1
    DrSpammerSettingTextPatternEditBox:SetText("Шаблон " .. arg1)
    local newText = DrSpammerDB.Pattern[arg1] or ""
    DrSpammerSettingTextBox:SetText(newText)
    
    if not DrSpammerEditingSlot then
        DrSpammer_LoadPatternSettings(arg1)
    end
    
    DrSpammerSettingTextBox_OnTextChanged()
    
    if DrSpammerTextEditButton and DrSpammerTextEditButton:GetText() ~= "Редактировать" then
        DrSpammerSettingTextBox:SetFocus()
    end
    
    if DrSpammerEditingSlot then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Шаблон изменен. Нажмите 'Обновить слот' для сохранения в текущий слот|r")
    end
end

function DrSpammer_OnSettingHide()
    DrSpammerEditingSlot = nil
    DrSpammerEditingOriginalPattern = nil
    DrSpammerEditingOriginalSettings = nil
    
    if DrSpammerSettingSaveButton then
        DrSpammerSettingSaveButton:Enable()
        DrSpammerSettingSaveButton:SetText("Сохранить слот")
    end
    
    if DrSpammerTextEditButton then
        DrSpammerTextEditButton:Enable()
        DrSpammerTextEditButton:SetText("Редактировать")
    end
    
    local editBox = DrSpammerSettingTextBox
    if editBox then
        editBox:ClearFocus()
        editBox:SetScript("OnTextChanged", nil)
        editBox:EnableMouse(false)
        editBox:EnableKeyboard(false)
    end
end

function DrSpammer_StartSlot(slotId)
	if not DrSpammerDB.SavedSettings or not DrSpammerDB.SavedSettings[slotId] then return end
	if not DrSpammerDB.SpamTasks then DrSpammerDB.SpamTasks = {} end
	if not DrSpammerDB.NextTaskId then DrSpammerDB.NextTaskId = 1 end
	
	local settings = DrSpammerDB.SavedSettings[slotId]
	
	if settings.chatType == "GUILD" and not IsInGuild() then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Нельзя запустить - у вас нет гильдии!|r")
		return
	end
	
	local cleanPattern = DrSpammer_CleanText(settings.pattern)
	
	local task = {
		id = DrSpammerDB.NextTaskId,
		slotId = slotId,
		pattern = cleanPattern,
		chatType = settings.chatType,
		channel = settings.channel,
		interval = settings.interval,
		lastTime = time(),
	}
	
	DrSpammerDB.SpamTasks[DrSpammerDB.NextTaskId] = task
	DrSpammerDB.NextTaskId = DrSpammerDB.NextTaskId + 1
	DrSpammer_UpdateSlotsList()
	DrSpammer_SetText()
	
	if cleanPattern ~= "" then
		if task.chatType == "CHANNEL" then
			SendChatMessage(cleanPattern, "CHANNEL", nil, task.channel);
		elseif task.chatType == "GUILD" then
			SendChatMessage(cleanPattern, "GUILD");
		else
			SendChatMessage(cleanPattern, task.chatType);
		end
	end
end

function DrSpammer_StopSlot(slotId)
	if not DrSpammerDB.SpamTasks then return end
	for id, task in pairs(DrSpammerDB.SpamTasks) do
		if task.slotId == slotId then
			DrSpammerDB.SpamTasks[id] = nil
			break
		end
	end
	DrSpammer_UpdateSlotsList()
	DrSpammer_SetText()
end

function DrSpammer_DeleteSlot(slotId)
	DrSpammer_StopSlot(slotId)
	if DrSpammerDB.SavedSettings then
		DrSpammerDB.SavedSettings[slotId] = nil
	end
	DrSpammer_UpdateSlotsList()
end

function DrSpammer_ToggleIntervalEdit()
    local button = DrSpammerIntervalButton
    local editFrame = DrSpammerIntervalEditFrame
    local editBox = DrSpammerIntervalEditBox
    
    if editFrame:IsShown() then
        editFrame:Hide()
        button:Show()
    else
        button:Hide()
        editFrame:Show()
        editBox:SetText(DrSpammerDB.Interval)
        editBox:HighlightText()
        editBox:SetFocus()
    end
end

function DrSpammer_SaveIntervalEdit()
    local button = DrSpammerIntervalButton
    local editFrame = DrSpammerIntervalEditFrame
    local editBox = DrSpammerIntervalEditBox
    local newInterval = tonumber(editBox:GetText())
    
    if newInterval and newInterval >= 1 and newInterval <= 99999 then
        DrSpammerDB.Interval = newInterval
        button:SetText(DrSpammerDB.Interval .. " cек.")
        editFrame:Hide()
        button:Show()
        
        if not DrSpammerEditingSlot then
            DrSpammer_SavePatternSettings()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Интервал должен быть числом от 1 до 99999|r")
        editBox:SetText(DrSpammerDB.Interval)
        editBox:HighlightText()
        editBox:SetFocus()
    end
end

function DrSpammer_CancelIntervalEdit()
    local button = DrSpammerIntervalButton
    local editFrame = DrSpammerIntervalEditFrame
    editFrame:Hide()
    button:Show()
end

function DrSpammer_OnEditFocusGained()
end

function DrSpammer_OnEditFocusLost()
end

function DrSpammerSettingTextBox_OnTextChanged()
    local text = DrSpammerSettingTextBox:GetText() or ""
    local len = strlen(text)
    if len > 255 then
        if len > 500 then
            text = strsub(text, 1, 500)
            DrSpammerSettingTextBox:SetText(text)
            len = 500
        end
        if DrSpammerSettingTextSymbols then
            DrSpammerSettingTextSymbols:SetText("Символы: |cffff0000" .. len .. "|r/255")
        end
    else
        if DrSpammerSettingTextSymbols then
            DrSpammerSettingTextSymbols:SetText("Символы: " .. len .. "/255")
        end
    end
    if not DrSpammerEditingSlot then
        DrSpammerDB.Pattern[DrSpammerDB.CheckedPattern] = text
    end
end

local function DrSpammer_GetCursorScaledPosition()
	local scale, x, y = UIParent:GetScale(), GetCursorPosition()
	return x / scale, y / scale
end

function DrSpammerSettingTextBox_OnMouseDown(self,arg1)
	if ( arg1 == "RightButton" ) then
		local x,y = DrSpammer_GetCursorScaledPosition()
		ToggleDropDownMenu(1, nil, DrSpammerMarkersDropdown, "UIParent", x, y)
	end
end

function DrSpammerSettingChanelButton_OnClick()
	ToggleDropDownMenu(1, nil, DrSpammerChannelsDropdown, "DrSpammerSettingChanelButton", 0, 0)
end

function DrSpammerSettingTextPatternButton_OnClick()
	ToggleDropDownMenu(1, nil, TextPatternDropdown, "DrSpammerSettingTextPatternButton", 0, 0)
end

function DrSpammerChatTypeDropdown_OnClick()
	ToggleDropDownMenu(1, nil, DrSpammerChatTypeDropdown, "DrSpammerSettingChatTypeButton", 0, 0)
end

function DrSpammer:OnUpdate()
    DrSpammer_UpdateSlotTimers()
    
    if DrSpammerMouseOver then
        DrSpammer_UpdateTooltip()
    end
    
    if not DrSpammerDB.SpamTasks or not next(DrSpammerDB.SpamTasks) then 
        return 
    end
    
    local currentTime = time()
    local updated = false
    
    for id, task in pairs(DrSpammerDB.SpamTasks) do
        if currentTime - task.lastTime >= task.interval then
            if task.pattern ~= "" then
                local cleanPattern = DrSpammer_CleanText(task.pattern)
                if task.chatType == "CHANNEL" then
                    SendChatMessage(cleanPattern, "CHANNEL", nil, task.channel);
                elseif task.chatType == "GUILD" then
                    if IsInGuild() then
                        SendChatMessage(cleanPattern, "GUILD");
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Остановлен слот " .. task.slotId .. " - нет гильдии|r")
                        DrSpammerDB.SpamTasks[id] = nil
                    end
                else
                    SendChatMessage(cleanPattern, task.chatType);
                end
                task.lastTime = currentTime;
                updated = true
            end
        end
    end
    
    if updated then
        DrSpammer_UpdateSlotsList()
    end
end

function DrSpammer:SavePosition(argpos)
	if argpos == 1 then
		local Left = DrSpammer:GetLeft()
		local Top = DrSpammer:GetTop()
		if Left and Top then
			DrSpammerDB.posx = Left
			DrSpammerDB.posy = Top
		end
	end
	if argpos == 2 then
		local Left = DrSpammerSetting:GetLeft()
		local Top = DrSpammerSetting:GetTop()
		if Left and Top then
			DrSpammerDB.posx1 = Left
			DrSpammerDB.posy1 = Top
		end
	end
end

local info = {}

function DrSpammerChannelsDropdown_OnClick(arg1)
	if arg1 == "GUILD" then
		DrSpammerSettingChanelEditBox:SetText("Гильдия")
		DrSpammerDB.Channel = 0
		DrSpammerDB.ChatType = "GUILD"
	else
		DrSpammerSettingChanelEditBox:SetText("Канал " .. arg1)
		DrSpammerDB.Channel = tonumber(arg1) or 1
		DrSpammerDB.ChatType = "CHANNEL"
	end
end

function DrSpammerChatTypeDropdown_OnClickFunc(arg1)
	DrSpammerSettingChatTypeEditBox:SetText(arg1)
	DrSpammerDB.ChatType = arg1
	if arg1 == "CHANNEL" then
		DrSpammerSettingChanelButton:Enable()
		DrSpammerSettingChanelEditBox:SetTextColor(1, 1, 1)
	else
		DrSpammerSettingChanelButton:Disable()
		DrSpammerSettingChanelEditBox:SetTextColor(0.5, 0.5, 0.5)
	end
end

local DrSpammerChannelsDropdown = CreateFrame("Frame", "DrSpammerChannelsDropdown");
DrSpammerChannelsDropdown.displayMode = "MENU"
DrSpammerChannelsDropdown.point = "TOPRIGHT"
DrSpammerChannelsDropdown.relativePoint = "BOTTOMRIGHT"
DrSpammerChannelsDropdown.relativeTo = "DrSpammerSettingChanelButton"
DrSpammerChannelsDropdown.initialize = function(self, level)
	if not level then return end
	wipe(info)
	if IsInGuild() then
		info.text = "Гильдия"
		info.arg1 = "GUILD"
		info.func = function(self, arg1, arg2, checked)
			CloseDropDownMenus()
			DrSpammerChannelsDropdown_OnClick(arg1)
		end
		UIDropDownMenu_AddButton(info);
	end
	local channels = { GetChannelList() }
	local chan = {}
	local j = 0
	for key, name in ipairs(channels) do
		if key % 2 ~= 0 then
			j = j + 1
			chan[j] = name
		else
			chan[j] = chan[j] .. ". " .. name
		end
	end
	for key, name in ipairs(chan) do
		info.text = name
		info.arg1 = string.sub(name, 1, 1)
		info.func = function(self, arg1, arg2, checked)
			CloseDropDownMenus()
			DrSpammerChannelsDropdown_OnClick(arg1)
		end
		UIDropDownMenu_AddButton(info);
	end
	info.text = CLOSE
	info.func = function() CloseDropDownMenus() end
	UIDropDownMenu_AddButton(info)
end

local DrSpammerChatTypeDropdown = CreateFrame("Frame", "DrSpammerChatTypeDropdown");
DrSpammerChatTypeDropdown.displayMode = "MENU"
DrSpammerChatTypeDropdown.point = "TOPRIGHT"
DrSpammerChatTypeDropdown.relativePoint = "BOTTOMRIGHT"
DrSpammerChatTypeDropdown.relativeTo = "DrSpammerSettingChatTypeButton"
DrSpammerChatTypeDropdown.initialize = function(self, level)
	if not level then return end
	wipe(info)
	info.text = "Канал (CHANNEL)"
	info.arg1 = "CHANNEL"
	info.func = function(self, arg1, arg2, checked)
		CloseDropDownMenus()
		DrSpammerChatTypeDropdown_OnClickFunc("CHANNEL")
	end
	UIDropDownMenu_AddButton(info);
	info.text = "Сказать (SAY)"
	info.arg1 = "SAY"
	info.func = function(self, arg1, arg2, checked)
		CloseDropDownMenus()
		DrSpammerChatTypeDropdown_OnClickFunc("SAY")
	end
	UIDropDownMenu_AddButton(info);
	info.text = "Крикнуть (YELL)"
	info.arg1 = "YELL"
	info.func = function(self, arg1, arg2, checked)
		CloseDropDownMenus()
		DrSpammerChatTypeDropdown_OnClickFunc("YELL")
	end
	UIDropDownMenu_AddButton(info);
	info.text = CLOSE
	info.func = function() CloseDropDownMenus() end
	UIDropDownMenu_AddButton(info)
end

local TextPatternDropdown = CreateFrame("Frame", "TextPatternDropdown");
TextPatternDropdown.displayMode = "MENU"
TextPatternDropdown.point = "TOPRIGHT"
TextPatternDropdown.relativePoint = "BOTTOMRIGHT"
TextPatternDropdown.relativeTo = "DrSpammerSettingTextPatternButton"
TextPatternDropdown.initialize = function(self, level)
    if not level then return end
    wipe(info)
    for i = 1, 10 do
        info = UIDropDownMenu_CreateInfo()
        info.text = "Шаблон " .. i
        info.arg1 = i
        info.func = function(self, arg1, arg2, checked)
            CloseDropDownMenus()
            TextPattern_OnClick(arg1)
        end
        info.tooltipTitle = "Шаблон " .. i

        local patternSettings = DrSpammerDB.PatternSettings and DrSpammerDB.PatternSettings[i]
        local chatType = "SAY"
        local interval = 30
        local channel = 1
        local patternText = DrSpammerDB.Pattern and DrSpammerDB.Pattern[i] or ""
        
        if patternSettings then
            chatType = patternSettings.chatType or "SAY"
            channel = patternSettings.channel or 1
            interval = patternSettings.interval or 30
        end
        
        local typeText = chatType
        if chatType == "CHANNEL" then
            typeText = "Канал " .. channel
        elseif chatType == "SAY" then
            typeText = "Сказать"
        elseif chatType == "YELL" then
            typeText = "Крикнуть"
        elseif chatType == "GUILD" then
            typeText = "Гильдия"
        end

        local headerText = typeText .. " | Интервал: " .. interval .. " сек"
        if patternText ~= "" then
            headerText = headerText .. "\n\n"
        end

        local displayText = patternText
        for j = 1, 8 do
            displayText = string.gsub(displayText, "{rt" .. j .. "}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. j .. ":0|t")
        end

        if patternText ~= "" then
            info.tooltipText = headerText .. displayText
        else
            info.tooltipText = headerText .. "\n\nПустой шаблон"
        end
        
        UIDropDownMenu_AddButton(info);
    end

    info = UIDropDownMenu_CreateInfo()
    info.text = CLOSE
    info.func = function() CloseDropDownMenus() end

    UIDropDownMenu_AddButton(info)
end


function DrSpammerMarkersDropdown_OnClick(arg1)
	DrSpammerSettingTextBox:Insert("{rt"..arg1.."}")
end

local DrSpammerMarkersDropdown = CreateFrame("Frame", "DrSpammerMarkersDropdown");
DrSpammerMarkersDropdown.displayMode = "MENU"
DrSpammerMarkersDropdown.initialize = function(self, level)
	if not level then return end
	local color
	wipe(info)
	for i = 1,8 do
		info = UIDropDownMenu_CreateInfo()
		info.text = DrSpammerRaidIconList[i].text
		color = DrSpammerRaidIconList[i].color
		info.colorCode = string.format("|cFF%02x%02x%02x", color.r*255, color.g*255, color.b*255)
		info.icon = DrSpammerRaidIconList[i].icon
		info.tCoordLeft = DrSpammerRaidIconList[i].tCoordLeft
		info.tCoordRight = DrSpammerRaidIconList[i].tCoordRight
		info.tCoordTop = DrSpammerRaidIconList[i].tCoordTop
		info.tCoordBottom = DrSpammerRaidIconList[i].tCoordBottom
		info.arg1 = i
		info.func = function(self, arg1, arg2, checked)
			CloseDropDownMenus()
			DrSpammerMarkersDropdown_OnClick(arg1)
		end
		UIDropDownMenu_AddButton(info)
	end
	info = UIDropDownMenu_CreateInfo()
	info.text = CLOSE
	info.func = function() CloseDropDownMenus() end
	UIDropDownMenu_AddButton(info)
end

function DrSpammer:SetupFrames()
	if DrSpammerDB.posx ~= nil and DrSpammerDB.posy ~= nil then
		DrSpammer:ClearAllPoints()
		DrSpammer:SetPoint("TOPLEFT","UIParent", "BOTTOMLEFT", DrSpammerDB.posx, DrSpammerDB.posy)
	end
	if DrSpammerDB.posx1 ~= nil and DrSpammerDB.posy1 ~= nil then
		DrSpammerSetting:ClearAllPoints()
		DrSpammerSetting:SetPoint("TOPLEFT","UIParent", "BOTTOMLEFT", DrSpammerDB.posx1, DrSpammerDB.posy1)
	end
	
	if DrSpammerDB.ChatType and DrSpammerDB.ChatType ~= "CHANNEL" then
		DrSpammerSettingChanelButton:Disable()
		DrSpammerSettingChanelEditBox:SetTextColor(0.5, 0.5, 0.5)
	else
		DrSpammerSettingChanelButton:Enable()
		DrSpammerSettingChanelEditBox:SetTextColor(1, 1, 1)
	end
	
    DrSpammerIntervalButton:SetText(DrSpammerDB.Interval .. " cек.")
    
    if DrSpammerIntervalEditFrame then
        DrSpammerIntervalEditFrame:Hide()
        DrSpammerIntervalButton:Show()
    end
    
    if DrSpammerSettingTextBox then
        local editBox = DrSpammerSettingTextBox
        editBox:SetScript("OnTextChanged", nil)
        editBox:EnableMouse(false)
        editBox:EnableKeyboard(false)
        editBox:ClearFocus()
        editBox:SetScript("OnEditFocusGained", nil)
        editBox:SetScript("OnEditFocusLost", nil)
        local text = DrSpammerDB.Pattern[DrSpammerDB.CheckedPattern] or ""
        editBox:SetText(text)
        DrSpammer_LoadPatternSettings(DrSpammerDB.CheckedPattern)
    end
    
    if DrSpammerSettingTextScrollFrame and DrSpammerSettingTextBox then
        DrSpammerSettingTextScrollFrame:SetScrollChild(DrSpammerSettingTextBox)
    end
    
    if DrSpammerTextEditButton then
        DrSpammerTextEditButton:SetText("Редактировать")
    end
    
    if DrSpammerSettingSaveButton then
        DrSpammerSettingSaveButton:SetText("Сохранить слот")
    end
    
    if DrSpammerSettingTextSymbols then
        local text = DrSpammerDB.Pattern[DrSpammerDB.CheckedPattern] or ""
        DrSpammerSettingTextSymbols:SetText("Символы: " .. strlen(text) .. "/255")
    end
    if DrSpammerOpacitySlider and DrSpammerDB.Opacity then
        local savedValue = DrSpammerDB.Opacity * 100
        DrSpammerOpacitySlider:SetValue(savedValue)
        if DrSpammerOpacityText then
            DrSpammerOpacityText:SetText("Прозрачность: " .. savedValue .. "%")
        end
    end
    DrSpammerEditingSlot = nil
	DrSpammer_UpdateSlotsList()
end

function DrSpammer_OnEvent(DrSpammer_self, DrSpammer_event, DrSpammer_arg1, ...)
	if( DrSpammer_event == "ADDON_LOADED" and DrSpammer_arg1 == "DrSpammer") then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DrSpammer Загружен.|r Команды: /drsp, /drsp reset")
		DrSpammer:SetupFrames()
	end
	if ( DrSpammer_event == "VARIABLES_LOADED" ) then
		if DrSpammerDB == nil then 
  		   DrSpammerDB = {}
  		   DrSpammerDB.Flag = false
		end
		if DrSpammerDB.Opacity == nil then
			DrSpammerDB.Opacity = 0.5
		end
		if not DrSpammerDB.ChatType then 
            DrSpammerDB.ChatType = "CHANNEL"
        end
		if not DrSpammerDB.SpamTasks then DrSpammerDB.SpamTasks = {} end
		if not DrSpammerDB.SavedSettings then DrSpammerDB.SavedSettings = {} end
		if not DrSpammerDB.NextTaskId then DrSpammerDB.NextTaskId = 1 end
		if not DrSpammerDB.NextSlotId then DrSpammerDB.NextSlotId = 1 end
		if not DrSpammerDB.Pattern then
			DrSpammerDB.Pattern = {}
			for i=1,10 do DrSpammerDB.Pattern[i] = "" end
		else
			for i=1,10 do
				if DrSpammerDB.Pattern[i] == "Пусто" then DrSpammerDB.Pattern[i] = "" end
			end
		end
		DrSpammer_InitPatterns()
		if not DrSpammerDB.Interval then DrSpammerDB.Interval = 30 end
		if not DrSpammerDB.Channel then 
            DrSpammerDB.Channel = 1
        end
		if not DrSpammerDB.CheckedPattern then DrSpammerDB.CheckedPattern = 1 end
		DrSpammerDB.Tumbler = false
		DrSpammerDB.LastTimeSpam = 0
		
		if DrSpammerDB.SpamTasks and next(DrSpammerDB.SpamTasks) ~= nil then
			local currentTime = time()
			for id, task in pairs(DrSpammerDB.SpamTasks) do
				local slotExists = false
				for slotId, settings in pairs(DrSpammerDB.SavedSettings) do
					if slotId == task.slotId then
						slotExists = true
						break
					end
				end
				
				if not slotExists then
					DrSpammerDB.SpamTasks[id] = nil
				else
					local timePassed = currentTime - task.lastTime
					if timePassed >= task.interval then
						task.lastTime = currentTime - task.interval
					end
				end
			end
			
			DrSpammer_UpdateSlotsList()
			DrSpammer_SetText()
			
			local count = 0
			for k,v in pairs(DrSpammerDB.SpamTasks) do count = count + 1 end
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Восстановлено " .. count .. " активных слотов спама|r")
		else
			DrSpammer_SetText()
		end
	end
end

function DrSpammer_CheckSpamTasks()
	if not DrSpammerDB.SpamTasks or not next(DrSpammerDB.SpamTasks) then
		DrSpammer_SetText()
		return
	end
	
	local currentTime = time()
	local validTasks = 0
	
	for id, task in pairs(DrSpammerDB.SpamTasks) do
		local slotExists = false
		for slotId, settings in pairs(DrSpammerDB.SavedSettings) do
			if slotId == task.slotId then
				slotExists = true
				break
			end
		end
		
		if not slotExists then
			DrSpammerDB.SpamTasks[id] = nil
		else
			local timePassed = currentTime - task.lastTime
			if timePassed >= task.interval then
				task.lastTime = currentTime - (timePassed % task.interval)
			end
			validTasks = validTasks + 1
		end
	end
	
	if validTasks > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Активно " .. validTasks .. " слотов спама|r")
	else
		DrSpammerDB.SpamTasks = {}
	end
	
	DrSpammer_UpdateSlotsList()
	DrSpammer_SetText()
end

DrSpammer:SetScript("OnEvent", DrSpammer_OnEvent);
DrSpammer:RegisterEvent("ADDON_LOADED");
DrSpammer:RegisterEvent("VARIABLES_LOADED");

DrSpammer:SetScript("OnUpdate", function(self, elapsed)
    DrSpammer:OnUpdate()
end)

function DrSpammerGetLink(lnk)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffffffLink: " .. tostring(lnk) .. "|r")
    if DrSpammerSetting and DrSpammerSetting:IsShown() and DrSpammerSettingTextBox then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Окно открыто. Вставляем...|r")
        local currentText = DrSpammerSettingTextBox:GetText() or ""
        local newText = currentText .. " " .. lnk
        if strlen(newText) > 500 then
            local available = 500 - strlen(currentText)
            if available > 0 then
                lnk = strsub(lnk, 1, available)
                DrSpammerSettingTextBox:Insert(lnk)
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Текст обрезан до 500 символов!|r")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Достигнут лимит 500 символов!|r")
            end
        else
            DrSpammerSettingTextBox:Insert(lnk)
        end
        DrSpammerSettingTextBox_OnTextChanged()
        if ChatFrame1EditBox and ChatFrame1EditBox:IsShown() then
            ChatFrame1EditBox:ClearFocus()
            ChatFrame1EditBox:Hide()
            DrSpammerChatOpen = false
        end
        return
    end
    ChatEdit_InsertLink_Default(lnk)
end

ChatEdit_InsertLink_Default=ChatEdit_InsertLink
ChatEdit_InsertLink=DrSpammerGetLink

function DrSpammer_StopAllSlots()
    if not DrSpammerDB.SpamTasks then return end
    local count = 0
    for id, task in pairs(DrSpammerDB.SpamTasks) do
        DrSpammerDB.SpamTasks[id] = nil
        count = count + 1
    end
    DrSpammer_UpdateSlotsList()
    DrSpammer_SetText()
    if count > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Остановлено " .. count .. " активных спамов|r")
    end
end

function DrSpammer:OnEnter()
    DrSpammerMouseOver = true
    DrSpammer_UpdateTooltip()
end

DrSpammerChatOpen = false

function DrSpammer_ToggleChat()
    if DrSpammerChatOpen then
        if ChatFrame1EditBox and ChatFrame1EditBox:IsShown() then
            ChatFrame1EditBox:ClearFocus()
            ChatFrame1EditBox:Hide()
            DrSpammerChatOpen = false
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Чат закрыт|r")
        end
    else
        if ChatFrame1EditBox then
            ChatFrame1EditBox:Show()
            ChatFrame1EditBox:SetFocus()
            DrSpammerChatOpen = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Чат открыт. Shift+клик для вставки квестов|r")
        end
    end
end

function DrSpammer:OnLeave()
    DrSpammerMouseOver = false
    DrSpammerTooltip:Hide()
end

SLASH_DRSPAMMER1 = "/drsp"
SLASH_DRSPAMMER2 = "/drspammer"
SlashCmdList["DRSPAMMER"] = function(msg)
    msg = msg and msg:lower() or ""

    msg = msg:trim()
    
    if msg == "reset" then

        DrSpammer:ClearAllPoints()
        DrSpammer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        
        DrSpammerSetting:ClearAllPoints()
        DrSpammerSetting:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

        DrSpammer:SavePosition(1)
        DrSpammer:SavePosition(2)

        if DrSpammerDB and DrSpammerDB.Opacity then
            DrSpammerDB.Opacity = 0.5
            if DrSpammerOpacitySlider then
                DrSpammerOpacitySlider:SetValue(50)
                DrSpammerSetting:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            end
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DrSpammer] Положение окна сброшено к центру экрана|r")
        
    elseif msg == "" then
        if DrSpammerSetting:IsShown() then
            DrSpammerSetting:Hide()
        else
            DrSpammerSetting:Show()
            if DrSpammerSettingTextBox then
                DrSpammerSettingTextBox:SetText(DrSpammerDB.Pattern[DrSpammerDB.CheckedPattern] or "")
                DrSpammerSettingTextBox_OnTextChanged()
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DrSpammer] Неизвестная команда. Используйте:|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00/drsp|r - открыть/закрыть окно")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00/drsp reset|r - сбросить положение окна к центру")
    end
end