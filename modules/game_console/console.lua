Console = {}

-- private variables
local SpeakTypesSettings = {
  say = { speakType = SpeakSay, color = '#FFFF00' },
  whisper = { speakType = SpeakWhisper, color = '#FFFF00' },
  yell = { speakType = SpeakYell, color = '#FFFF00' },
  broadcast = { speakType = SpeakBroadcast, color = '#F55E5E' },
  private = { speakType = SpeakPrivate, color = '#5FF7F7', private = true },
  privateRed = { speakType = SpeakPrivateRed, color = '#F55E5E', private = true },
  privatePlayerToPlayer = { speakType = SpeakPrivate, color = '#9F9DFD', private = true },
  privatePlayerToNpc = { speakType = SpeakPrivatePlayerToNpc, color = '#9F9DFD', private = true, npcChat = true },
  privateNpcToPlayer = { speakType = SpeakPrivateNpcToPlayer, color = '#5FF7F7', private = true, npcChat = true },
  channelYellow = { speakType = SpeakChannelYellow, color = '#FFFF00' },
  channelWhite = { speakType = SpeakChannelWhite, color = '#FFFFFF' },
  channelRed = { speakType = SpeakChannelRed, color = '#F55E5E' },
  channelOrange = { speakType = SpeakChannelOrange, color = '#FE6500' },
  monsterSay = { speakType = SpeakMonsterSay, color = '#FE6500', hideInConsole = true},
  monsterYell = { speakType = SpeakMonsterYell, color = '#FE6500', hideInConsole = true},
}

local SpeakTypes = {
  [SpeakSay] = SpeakTypesSettings.say,
  [SpeakWhisper] = SpeakTypesSettings.whisper,
  [SpeakYell] = SpeakTypesSettings.yell,
  [SpeakBroadcast] = SpeakTypesSettings.broadcast,
  [SpeakPrivate] = SpeakTypesSettings.private,
  [SpeakPrivateRed] = SpeakTypesSettings.privateRed,
  [SpeakPrivatePlayerToNpc] = SpeakTypesSettings.privatePlayerToNpc,
  [SpeakPrivateNpcToPlayer] = SpeakTypesSettings.privateNpcToPlayer,
  [SpeakChannelYellow] = SpeakTypesSettings.channelYellow,
  [SpeakChannelWhite] = SpeakTypesSettings.channelWhite,
  [SpeakChannelRed] = SpeakTypesSettings.channelRed,
  [SpeakChannelOrange] = SpeakTypesSettings.channelOrange,
  [SpeakMonsterSay] = SpeakTypesSettings.monsterSay,
  [SpeakMonsterYell] = SpeakTypesSettings.monsterYell,
}

local SayModes = {
  [1] = { speakTypeDesc = 'whisper', icon = '/core_styles/icons/whisper.png' },
  [2] = { speakTypeDesc = 'say', icon = '/core_styles/icons/say.png' },
  [3] = { speakTypeDesc = 'yell', icon = '/core_styles/icons/yell.png' }
}

local consolePanel
local consoleBuffer
local consoleTabBar
local consoleLineEdit
local channels
local messageHistory = { }
local currentMessageIndex = 0
local MaxHistory = 1000

-- private functions
local function navigateMessageHistory(step)
  local numCommands = #messageHistory
  if numCommands > 0 then
    currentMessageIndex = math.min(math.max(currentMessageIndex + step, 0), numCommands)
    if currentMessageIndex > 0 then
      local command = messageHistory[numCommands - currentMessageIndex + 1]
      consoleLineEdit:setText(command)
    else
      consoleLineEdit:clearText()
    end
  end
end

function applyMessagePrefixies(name, level, message)
  if name then
    if Options.showLevelsInConsole and level > 0 then
      message = name .. ' [' .. level .. ']: ' .. message
    else
      message = name .. ': ' .. message
    end
  end
  return message
end

-- public functions
function Console.create()
  consolePanel = displayUI('console.otui', { parent = Game.gameBottomPanel } )
  consoleLineEdit = consolePanel:getChildById('consoleLineEdit')
  consoleBuffer = consolePanel:getChildById('consoleBuffer')
  consoleTabBar = consolePanel:getChildById('consoleTabBar')
  consoleTabBar:setContentWidget(consoleBuffer)
  channels = {}

  Console.addChannel('Default', 0)
  Console.addTab('Server Log', false)

  Hotkeys.bindKeyDown('Shift+Up', function() navigateMessageHistory(1) end, consolePanel)
  Hotkeys.bindKeyDown('Shift+Down', function() navigateMessageHistory(-1) end, consolePanel)
  Hotkeys.bindKeyDown('Tab', function() consoleTabBar:selectNextTab() end, consolePanel)
  Hotkeys.bindKeyDown('Shift+Tab', function() consoleTabBar:selectPrevTab() end, consolePanel)
  Hotkeys.bindKeyDown('Enter', Console.sendCurrentMessage, consolePanel)

  -- apply buttom functions after loaded
  connect(consolePanel:getChildById('nextChannelButton'), { onClick = function() consoleTabBar:selectNextTab() end } )
  connect(consolePanel:getChildById('prevChannelButton'), { onClick = function() consoleTabBar:selectPrevTab() end } )
  connect(consoleTabBar, { onTabChange = Console.onTabChange })

  -- tibia like hotkeys
  Hotkeys.bindKeyDown('Ctrl+O', Game.requestChannels)
  Hotkeys.bindKeyDown('Ctrl+E', Console.removeCurrentTab)
end

function Console.destroy()
  consolePanel:destroy()
  consolePanel = nil
end

function Console.addTab(name, focus)
  local tab = consoleTabBar:addTab(name)
  if focus then
  consoleTabBar:selectTab(tab)
  else
  consoleTabBar:blinkTab(tab)
  end
  return tab
end

function Console.onTabChange(tabBar, tab)
  if tab:getText() == "Default" or tab:getText() == "Server Log" then
    consolePanel:getChildById('closeChannelButton'):disable()
  else
    consolePanel:getChildById('closeChannelButton'):enable()
  end
end

function Console.removeCurrentTab()
  local tab = consoleTabBar:getCurrentTab()
  if tab:getText() == "Default" or tab:getText() == "Server Log" then return end

  consoleTabBar:removeTab(tab)
end

function Console.getTab(name)
  return consoleTabBar:getTab(name)
end

function Console.getCurrentTab()
  return consoleTabBar:getCurrentTab()
end

function Console.addChannel(name, id)
  channels[id] = name
  local tab = Console.addTab(name, true)
  tab.channelId = id
  return tab
end

function Console.addPrivateText(text, speaktype, name, isPrivateCommand)
  if speaktype.speakType == SpeakPrivateNpcToPlayer then
    name = 'NPCs'
  end

  local privateTab = Console.getTab(name)
  if privateTab == nil then
    if Options.showPrivateMessagesInConsole or (isPrivateCommand and not privateTab) then
      privateTab = Console.getTab('Default')
    else
      privateTab = Console.addTab(name, false)
    end
    privateTab.npcChat = speaktype.npcChat
  end
  Console.addTabText(text, speaktype, privateTab)
end

function Console.addText(text, speaktype, tabName)
  local tab = Console.getTab(tabName)
  if tab ~= nil then
    Console.addTabText(text, speaktype, tab)
  end
end

function Console.addTabText(text, speaktype, tab)
  if Options.showTimestampsInConsole then
    text = os.date('%H:%M') .. ' ' .. text
  end

  local panel = consoleTabBar:getTabPanel(tab)
  local label = createWidget('ConsoleLabel', panel)
  label:setText(text)
  label:setColor(speaktype.color)
  consoleTabBar:blinkTab(tab)

  if panel:getChildCount() > 10 then
    panel:removeChild(panel:getFirstChild())
  end
end

function Console.sendCurrentMessage()
  local message = consoleLineEdit:getText()
  if #message == 0 then return end
  consoleLineEdit:clearText()

  -- get current channel
  local tab = Console.getCurrentTab()

  -- handling chat commands
  local originalMessage = message
  local chatCommandSayMode
  local chatCommandPrivate
  local chatCommandPrivateReady

  local chatCommandMessage = message:match("^%#y (.*)")
  if chatCommandMessage ~= nil then chatCommandSayMode = 'yell' end -- player used yell command
  message = chatCommandMessage or message

  local chatCommandMessage = message:match("^%#w (.*)")
  if chatCommandMessage ~= nil then chatCommandSayMode = 'whisper' end -- player used whisper
  message = chatCommandMessage or message

  local findIni, findEnd, chatCommandInitial, chatCommandPrivate, chatCommandEnd, chatCommandMessage = message:find("([%*%@])(.+)([%*%@])(.*)")
  if findIni ~= nil and findIni == 1 then -- player used private chat command
    if chatCommandInitial == chatCommandEnd then
      chatCommandPrivateRepeat = false
      if chatCommandInitial == "*" then
        consoleLineEdit:setText('*'.. chatCommandPrivate .. '* ')
      end
      message = chatCommandMessage:trim()
      chatCommandPrivateReady = true
    end
  end

  message = message:gsub("^(%s*)(.*)","%2") -- remove space characters from message init
  if #message == 0 then return end

  -- add new command to history
  currentMessageIndex = 0
  table.insert(messageHistory, originalMessage)
  if #messageHistory > MaxHistory then
    table.remove(messageHistory, 1)
  end

  -- when talking on server log, the message goes to default channel
  local name = tab:getText()
  if name == 'Server Log' then
    tab = Console.getTab('Default')
    name = 'Default'
  end
  local speaktypedesc

  if tab.channelId and not chatCommandPrivateReady then
    if tab.channelId == 0 then
      speaktypedesc = chatCommandSayMode or SayModes[consolePanel:getChildById('sayModeButton').sayMode].speakTypeDesc
      if speaktypedesc ~= 'say' then Console.sayModeChange(2) end -- head back to say mode
    else
      speaktypedesc = 'channelYellow'
    end

    Game.talkChannel(SpeakTypesSettings[speaktypedesc].speakType, tab.channelId, message)
    return
  else
    local isPrivateCommand = false
    if chatCommandPrivateReady then
      speaktypedesc = 'privatePlayerToPlayer'
      name = chatCommandPrivate
      isPrivateCommand = true
    elseif tab.npcChat then
      speaktypedesc = 'privatePlayerToNpc'
    else
      speaktypedesc = 'privatePlayerToPlayer'
    end


    local speaktype = SpeakTypesSettings[speaktypedesc]
    local player = Game.getLocalPlayer()
    Game.talkPrivate(speaktype.speakType, name, message)

    message = applyMessagePrefixies(player:getName(), player:getLevel(), message)
    Console.addPrivateText(message, speaktype, name, isPrivateCommand)
  end
end

function Console.sayModeChange(sayMode)
  local buttom = consolePanel:getChildById('sayModeButton')
  if sayMode == nil then
    sayMode = buttom.sayMode + 1
  end

  if sayMode > #SayModes then sayMode = 1 end

  buttom:setIcon(SayModes[sayMode].icon)
  buttom.sayMode = sayMode
end

-- hooked events
local function onCreatureSpeak(name, level, speaktype, message, channelId, creaturePos)
  speaktype = SpeakTypes[speaktype]
  if speaktype.hideInConsole then return end

  message = applyMessagePrefixies(name, level, message)

  if speaktype.private then
    Console.addPrivateText(message, speaktype, name, false)
  else
    Console.addText(message, speaktype, channels[channelId])
  end
end

local function onOpenChannel(channelId, channelName)
  Console.addChannel(channelName, channelId)
end

local function onOpenPrivateChannel(receiver)
  local privateTab = Console.getTab(receiver)
  if privateTab == nil then
    Console.addTab(receiver, true)
  end
end

local function doChannelListSubmit(channelsWindow)
  local channelListPanel = channelsWindow:getChildById('channelList')
  local openPrivateChannelWith = channelsWindow:getChildById('openPrivateChannelWith'):getText()
  if openPrivateChannelWith ~= '' then
    Game.openPrivateChannel(openPrivateChannelWith)
  else
    local selectedChannelLabel = channelListPanel:getFocusedChild()
    if not selectedChannelLabel then return end
    Game.joinChannel(selectedChannelLabel.channelId)
  end
  channelsWindow:destroy()
end

local function onChannelList(channelList)
  local channelsWindow = displayUI('channelswindow.otui')
  local channelListPanel = channelsWindow:getChildById('channelList')
  connect(channelsWindow, { onEnter = function () doChannelListSubmit(channelsWindow) end } )

  for k,v in pairs(channelList) do
    local channelId = v[1]
    local channelName = v[2]

    if channelId ~= 0 and #channelName > 0 then
      local label = createWidget('ChannelListLabel', channelListPanel)
      label.channelId = channelId
      label:setText(channelName)

      label:setPhantom(false)
      connect(label, { onMouseDoubleClick = function () doChannelListSubmit(channelsWindow) end } )
    end
  end
end

connect(Game, { onLogin = Console.create,
                onLogout = Console.destroy,
                onCreatureSpeak = onCreatureSpeak,
                onChannelList = onChannelList,
                onOpenChannel = onOpenChannel,
                onOpenPrivateChannel = onOpenPrivateChannel})