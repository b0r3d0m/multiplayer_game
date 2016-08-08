-- common modules
require 'common.arr_utils'

-- project-related modules
local Message = require 'message'

-- third-party libraries
local class = require 'vendor.middleclass.middleclass'

local Session = class('Session')

function Session:initialize(udp, options)
  self.udp = udp
  self.options = options

  self.sendQueue = {}
  self.sendSeqNum = 0
  self.recvSeqNum = -1
end

function Session:getPlayerName()
  return self.options.playerName
end

function Session:getRecvSeqNum()
  return self.recvSeqNum
end

function Session:setRecvSeqNum(newValue)
  self.recvSeqNum = newValue
end

function Session:recvUDPMsgs()
  local msgs = {}

  while true do
    local datagram = self.udp:recv()
    if datagram == nil then
      break
    end

    local msg = Message:fromString(datagram)
    self:debugPrint('[recv]: ' .. msg:toString())
    table.insert(msgs, msg)
  end

  return msgs
end

function Session:queueUDPMsg(msg, reliable)
  msg.reliable = reliable or false
  if msg.reliable then
    msg.id = self.sendSeqNum
    self.sendSeqNum = self.sendSeqNum + 1 -- TODO: Handle overflow
  end

  local m = Message:new(msg)
  table.insert(self.sendQueue, m)
end

function Session:sendUDPMsgs()
  -- TODO: Think about MTU

  local relMsgs = {}

  -- note that we have to iterate over array-like table from back to front
  -- otherwise we'll skip some of the elements because they are downshifting on remove
  for i=#self.sendQueue,1,-1 do
    local msg = self.sendQueue[i]
    if msg.reliable then
      table.insert(relMsgs, 1, msg.fields) -- Add to the beginning to preserve messages order
    else
      self:debugPrint('[send]: ' .. msg:toString())
      self.udp:send(msg:toString())
      table.remove(self.sendQueue, i)
    end
  end

  if not tableEmpty(relMsgs) then
    local rel = Message:new({
      type = 'rel',
      msgs = relMsgs
    })
    self:debugPrint('[send]: ' .. rel:toString())
    self.udp:send(rel:toString())
  end
end

function Session:removeRelMsgs(lastID)
  removeIf(self.sendQueue, function(sendMsg) return sendMsg.reliable and sendMsg.id <= lastID end)
end

function Session:debugPrint(msg)
  if self.options.debug then
    print(msg)
  end
end

return Session

