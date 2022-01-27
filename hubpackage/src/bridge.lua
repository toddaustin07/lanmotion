--[[
  Copyright 2021 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  SmartThings Edge driver module for handling interface with Bridge Server
  
  For use in linking devices using fixed IP:Port messages with Edge device drivers 

--]]

local cosock = require "cosock"
local socket = require "cosock.socket"
local log = require "log"
local Thread = require "st.thread"

local listen_ip = "0.0.0.0"
local listen_port = 0
local CLIENTSOCKTIMEOUT = 2
local bridge_thread
local handler_id
local server_ip
local server_port
local callback


local function validate_address(lanAddress)

  local valid = true
  
  local ip = lanAddress:match('^(%d.+):')
  local port = tonumber(lanAddress:match(':(%d+)$'))
  
  if ip then
    local chunks = {ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
    if #chunks == 4 then
      for i, v in pairs(chunks) do
        if tonumber(v) > 255 then 
          valid = false
          break
        end
      end
    else
      valid = false
    end
  else
    valid = false
  end
  
  if port then
    if type(port) == 'number' then
      if (port < 1) or (port > 65535) then 
        valid = false
      end
    else
      valid = false
    end
  else
    valid = false
  end
  
  if valid then
    return ip, port
  else
    return nil
  end
        
end


local function init_clientsocket()

  clientsock = assert(socket.tcp(), "create TCP socket")
  clientsock:settimeout(CLIENTSOCKTIMEOUT)

  return clientsock

end


local function init_serversocket()

  local serversock = assert(socket.tcp(), "create TCP socket")
  assert(serversock:bind('*', 0))
  serversock:settimeout(0)
  serversock:listen()

  return serversock

end



local function issue_request(req_method, ip, port, endpoint)

  local sock = init_clientsocket()

  if sock:connect(ip, port) then

    local our_address = sock:getsockname()
    
    local headers = table.concat (
      {
          string.upper(req_method) .. ' ' .. endpoint .. ' HTTP/1.1',
          'HOST: ' .. ip .. ':' .. tostring(port),
          '\r\n'
      },
      '\r\n'
    )

    sock:send(headers)

    local buffer, err = sock:receive()

    if buffer then
      sock:close()
      return tonumber(buffer:match('^HTTP/[%d.%.]+ (%d+)')), buffer
    else
      log.error('Failed to get response from bridge:', err)
    end
  else
    log.warn (string.format('Failed to connect to %s:%s', ip, port))
  end

  sock:close()
  return nil
    
end


local function init_bridge(device, bridgeaddr, deviceaddr, triggerfunc)

  local ip, port = validate_address(bridgeaddr)

  if ip then
  
    callback = triggerfunc

    local endpoint = '/api/register?devaddr=' .. tostring(deviceaddr) .. '&edgeid=' .. device.id ..'&hubaddr=' .. server_ip .. ':' .. tostring(server_port)
    local retcode, response = issue_request('POST', ip, port, endpoint)
    --log.debug ('HTTP Response Code: ', retcode)
    --log.debug ('\tResponse data: ', response)
    if retcode ~= 200 then
        log.error ('Registration with Bridge Server failed')
        device:offline()
    else
        device:online()
        log.info ('Registration with Bridge Server successful')
    end
  else
    log.warn ('Valid Bridge address not configured')
  end

end

-----------------------------------------------------------------------
--						SERVER SOCKET CONNECTION HANDLER
-----------------------------------------------------------------------

local function watch_socket(_, sock)

  local client, accept_err = sock:accept()

  if accept_err ~= nil then
    if accept_err == 'timeout' then return end
    log.info("Connection accept error: " .. accept_err)
    return
  end
  log.debug("Accepted connection from", client:getpeername())

  client:settimeout(1)

  local line, err

  local ip, _, _ = client:getpeername()
  if ip ~= nil then
    do -- Read first line
      line, err = client:receive()
      if err == nil then
        log.debug ('Received:', line)
      else
        log.warn("Error on client receive: " .. err)
        client:close()
        return
      end
    end

    --[[

    do -- Receive all headers until blank line is found
      local line, err = client:receive()

      if not err then
        while line ~= "" do
          log.debug ('Received:', line)

          line, err  = client:receive()
          if err ~= nil then
            log.warn("Error on client receive: " .. err)
            return
          end
        end
      end
    end

    -- Receive body here if needed (Future)
  
    --]]
    
  else
    log.warn("Could not get IP from getpeername()")
  end
  
  
  if line:find('POST', 1, plaintext) == 1 then
   
    OK_MSG = 'HTTP/1.1 200 OK\r\n\r\n'
                
    client:send(OK_MSG)
   
    -- received url format = 'POST /<device address>/<device message method>/<device message path> HTTP/1.1'
    local devaddr, devmethod, devmsgpath = line:match('^POST /([%d%.:]+)/(%a+)(.*) ')
    
    callback(devaddr, devmethod, devmsgpath)

  else
    log.error ('Unexpected message received from Bridge:', line)
    
  end
  
  client:close()
  
end

local function start_bridge_server(driver)

  -- Startup Server
  local serversock = init_serversocket()
  server_ip, server_port = serversock:getsockname()
  log.info(string.format('Server started at %s:%s', server_ip, server_port))
  if not bridge_thread then
    bridge_thread = Thread(driver, "bridge thread")
  end
  if handler_id then
    bridge_thread.unregister_socket(handler_id)
    
  end
  
  handler_id = bridge_thread.register_socket(serversock, watch_socket)

end


local function shutdown(driver)
  log.debug ('Shutting down Bridge server')
  if handler_id and bridge_thread then
    bridge_thread.unregister_socket(handler_id)
  end
  if bridge_thread then
    bridge_thread:close()
  end
end

return {
  start_bridge_server = start_bridge_server,
  init_bridge = init_bridge,
  shutdown = shutdown,
}
