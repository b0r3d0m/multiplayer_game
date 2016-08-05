-- third-party libraries
local socket = require 'socket'

function gettime()
  return socket.gettime()
end

