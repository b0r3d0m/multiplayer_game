-------------------
-- modules
-------------------

-- common modules
require 'common.arr_utils'
require 'common.protect'
require 'common.string_utils'
require 'common.table_utils'
local UDPSocket = require 'common.udp'

-- project-related modules
local Session = require 'session'

-- third-party libraries
local Gamestate = require 'vendor.hump.gamestate'

-------------------
-- "constants"
-------------------

local colors = protect({
  --      {  R,   G,   B}
  WHITE = {255, 255, 255},
  RED   = {255,   0,   0}
})

local server = protect({
  IP = '127.0.0.1',
  PORT = 12345
})

local network = protect({
  TIMEOUT = 30.0 -- secs
})

local flags = protect({
  RELIABLE = true
})

-------------------
-- globals
-------------------

-- command line arguments
local debug = false

-- game states
local menu = {}
local load = {}
local game = {}

-- GUI stuff
local font = love.graphics.newFont(14) -- default LOVE font

-- network stuff
local udp = UDPSocket:new({
  blocking = false,
  -- according to the documentation,
  -- there is about 30% performance gain due to the call to setpeername method
  peerIP = server.IP,
  peerPort = server.PORT
})

-- session-related info
local session = nil

-------------------
-- menu
-------------------

function menu:enter(previous, err)
  session = nil

  -- enable key repeat so backspace can be held down to trigger love.keypressed multiple times
  love.keyboard.setKeyRepeat(true)

  self.err = err
  self.playerName = ''
end

function menu:draw()
  if self.err then
    love.graphics.setColor(colors.RED)
    printCenterX(font, self.err, love.graphics:getHeight() / 2 - font:getHeight() * 2)
  end

  love.graphics.setColor(colors.WHITE)
  printCenterX(font, 'Type your name', love.graphics:getHeight() / 2 - font:getHeight())
  printCenterX(font, self.playerName .. '_', love.graphics:getHeight() / 2 + font:getHeight())
end

function menu:textinput(t)
  -- let's pretend that we're working with ASCII characters only
  -- TODO: Add UTF-8 support
  local maxPlayerNameLength = 16
  if string.len(self.playerName) < maxPlayerNameLength
     and font:hasGlyphs(t) then -- check whether the Font can render our characters
    self.playerName = self.playerName .. t
  end
end

function menu:keypressed(key)
  if key == 'backspace' then
    self.playerName = removeLast(self.playerName, 1) -- remove last character
  end
end

function menu:keyreleased(key, code)
  if key == 'return' then
    if string.len(self.playerName) > 0 then
      session = Session:new(udp, {
        playerName = self.playerName,
        debug = debug
      })
      Gamestate.switch(load)
      return
    end
  end
end

-------------------
-- load
-------------------

function load:enter()
  self.lastConnectMsgTime = 0.0
  self.retries = 0
end

function load:update(dt)
  self:processIncomingMsgs(dt)
  self:sendOutgoingMsgs(dt)
end

function load:draw()
  printCenterX(font, 'Connecting...', love.graphics:getHeight() / 2 - font:getHeight())
end

function load:processIncomingMsgs(dt)
  local msgs = session:recvUDPMsgs()
  for i, msg in ipairs(msgs) do
    self:processMessage(msg)
  end
end

function load:sendOutgoingMsgs(dt)
  -- queue 'connect' message
  local now = socket.gettime()
  if now - self.lastConnectMsgTime > 2.0 then
    if self.retries > 5 then
      Gamestate.switch(menu, 'Unable to connect to server')
      return
    end
    -- TODO: Send protocol version
    session:queueUDPMsg({
      type = 'connect',
      name = session:getPlayerName()
    })
    self.lastConnectMsgTime = now
    self.retries = self.retries + 1
  end

  session:sendUDPMsgs()
end

function load:processMessage(msg)
  if msg.type == 'connect' then
    self:handleConnect(msg)
  else
    debugPrint('[load] Unknown message type: ' .. msg.type)
  end
end

function load:handleConnect(msg)
  if msg.success then
    Gamestate.switch(game, msg.player.id)
    return
  else
    Gamestate.switch(menu, msg.reason)
    return
  end
end

-------------------
-- game
-------------------

function game:enter(previous, playerID)
  -- disable key repeat previously set in the menu
  love.keyboard.setKeyRepeat(false)

  self.playerID = playerID
  self.players = {}

  self.lastPingDt = 0.0
  self.lastServerMsgDt = 0.0
end

function game:update(dt)
  self:processIncomingMsgs(dt)
  self:handleInput(dt)
  self:sendOutgoingMsgs(dt)
end

function game:draw()
  local playerSize = {
    w = 10,
    h = 10
  }
  for addr, player in pairs(self.players) do
    -- draw character
    love.graphics.setColor(colors.RED)
    love.graphics.rectangle('fill', player.x, player.y, playerSize.w, playerSize.h)
    -- draw player's name
    love.graphics.setColor(colors.WHITE)
    love.graphics.print(
      player.name,
      player.x + playerSize.w / 2 - font:getWidth(player.name) / 2,
      player.y - playerSize.h / 2 - font:getHeight()
    )
  end
end

function game:processIncomingMsgs(dt)
  local msgs = session:recvUDPMsgs()
  if tableEmpty(msgs) then
    self.lastServerMsgDt = self.lastServerMsgDt + dt
    if self.lastServerMsgDt > network.TIMEOUT then
      Gamestate.switch(menu, 'You were disconnected from server')
      return
    end
  else
    for i, msg in ipairs(msgs) do
      self:processMessage(msg)
    end
    self.lastServerMsgDt = 0.0
  end
end

function game:sendOutgoingMsgs(dt)
  -- queue 'ping' message
  self.lastPingDt = self.lastPingDt + dt
  if self.lastPingDt > 1.0 then
    session:queueUDPMsg({
      type = 'ping'
    })
    self.lastPingDt = 0.0
  end

  session:sendUDPMsgs()
end

function game:processMessage(msg)
  if msg.type == 'pong' then
    self:handlePong(msg)
  elseif msg.type == 'ack' then
    self:handleAck(msg)
  elseif msg.type == 'update' then
    self:handleUpdate(msg)
  else
    debugPrint('[game] Unknown message type: ' .. msg.type)
  end
end

function game:handlePong(msg)
  -- TODO: Calculate latency
end

function game:handleAck(msg)
  session:removeRelMsgs(msg.ack)
end

function game:handleUpdate(msg)
  if msg.id > session:getRecvSeqNum() then
    for i, change in ipairs(msg.changes) do
      if change.x == -1 or change.y == -1 then
        -- player has been removed
        self.players[change.id] = nil
      else
        self.players[change.id] = change
      end
    end
    session:setRecvSeqNum(msg.id)
  end

  session:queueUDPMsg({
    type = 'ack',
    ack = msg.id
  })
end

function game:handleInput(dt)
  local speed = 50

  local player = self.players[self.playerID]

  if love.keyboard.isDown('up') then 
    player.y = player.y - speed * dt
  elseif love.keyboard.isDown('down') then 
    player.y = player.y + speed * dt
  elseif love.keyboard.isDown('left') then 
    player.x = player.x - speed * dt
  elseif love.keyboard.isDown('right') then
    player.x = player.x + speed * dt
  end
end

function game:keypressed(key)
  session:queueUDPMsg({
    type = 'keypressed',
    key = key
  }, flags.RELIABLE)
end

function game:keyreleased(key)
  session:queueUDPMsg({
    type = 'keyreleased',
    key = key
  }, flags.RELIABLE)
end

-------------------
-- helpers
-------------------

function printCenterX(font, text, y)
  local x = love.graphics:getWidth() / 2 - font:getWidth(text) / 2
  love.graphics.print(text, x, y)
end

function debugPrint(msg)
  if debug then
    print(msg)
  end
end

-------------------
-- main
-------------------

function love.load(arg)
  debug = arrContains(arg, '-debug')

  Gamestate.registerEvents()
  Gamestate.switch(menu)
end

function love.keypressed(key)
  if key == 'escape' then
    love.event.push('quit')
  end
end

function love.quit()
  if session then
    session:queueUDPMsg({
      type = 'disconnect'
    })
    session:sendUDPMsgs()
  end
  return true
end

