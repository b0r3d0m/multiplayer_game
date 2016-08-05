-- third-party libraries
local class = require 'vendor.middleclass.middleclass'
local json = require 'vendor.json.json'

local Message = class('Message')

function Message:initialize(fields)
  self.fields = fields

  -- this is a little hack to be able to use Message objects
  -- as wrappers around tables passed on theirs constructions
  -- e.g.
  -- msg = Message:new({type = 'connect', name = 'player'})
  -- print(msg.type) -- connect
  for k,v in pairs(self.fields) do self[k] = v end
end

function Message:toString()
  return json.encode(self.fields)
end

function Message:fromString(data)
  return Message:new(json.decode(data))
end

return Message

