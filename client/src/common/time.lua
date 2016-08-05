-- third-party libraries
local socket = require 'socket'

function gettime()
  -- standard os.time() function provides full seconds only
  return socket.gettime()
end

