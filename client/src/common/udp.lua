-- third-party libraries
package.path = package.path .. ";.."
local class = require 'vendor.middleclass.middleclass'
local socket = require 'socket'

local UDPSocket = class('UDPSocket')

-- TODO: Add error handling

function UDPSocket:initialize(options)
  self.sock = socket.udp()

  self.options = options
  if self.options.blocking == nil then
    self.options.blocking = true
  end

  if not self.options.blocking then
    self.sock:settimeout(0)
  end

  if self.options.peerIP and self.options.peerPort then
    self.sock:setpeername(self.options.peerIP, self.options.peerPort)
  end
end

function UDPSocket:send(datagram)
  return self.sock:send(datagram)
end

function UDPSocket:sendTo(datagram, ip, port)
  return self.sock:sendto(datagram, ip, port)
end

function UDPSocket:recv()
  return self.sock:receive()
end

function UDPSocket:recvFrom()
  return self.sock:receivefrom()
end

function UDPSocket:recvAllFrom()
  local datagrams = {}

  while true do
    local datagram = self:recvFrom()
    if datagram == nil then
      break
    end
    table.insert(datagrams, datagram)
  end

  return datagrams
end

return UDPSocket

