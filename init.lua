--- === SocksProxy ===
---
--- Manages SSH SOCKS proxy connections via menubar
local M = {}
M.__index = M
M.logger = hs.logger.new("default")
M.logger.setLogLevel("debug")

-- Metadata
M.name = "SocksProxy"
M.version = "1.0"
M.author = "Bad Sector"
M.homepage = "https://github.com/badsectordev/socks-proxy-spoon"
M.license = "MIT - https://opensource.org/licenses/MIT"

-- Internal variables
M.menubar = nil
M.task = nil
M.timer = nil
M.isConnected = false
M.sshHost = nil
M.localPort = nil

function M:init()
  self.logger.i("Initializing SocksProxy")
  self.menubar = hs.menubar.new(true, "SocksProxyHammer")
  self.disconnectedIconPath = hs.spoons.resourcePath("icons/disconnected.tiff")
  self.connectedIconPath = hs.spoons.resourcePath("icons/connected.tiff")
  self.disconnectedIcon = hs.image.imageFromPath(self.disconnectedIconPath):setSize({ w = 16, h = 16 })
  self.connectedIcon = hs.image.imageFromPath(self.connectedIconPath):setSize({ w = 16, h = 16 })
  self:updateMenu()
end

function M:updateMenu()
  self.logger.i("Updating menu")
  if not self.menubar then
    self.logger.e("Menubar not initialized")
    return
  end

  local menu = {
    {
      title = self.isConnected and "Disconnect" or "Connect",
      fn = function()
        if self.isConnected then
          self:disconnect()
        else
          self:connect()
        end
      end,
    },
    {
      title = "-",
    },
    {
      title = "Status: " .. (self.isConnected and "Connected" or "Disconnected"),
      disabled = true,
    },
  }

  self.menubar:setMenu(menu)
  if self.isConnected then
    self.logger.i("Connected")
    self.menubar:setIcon(self.connectedIcon)
  else
    self.logger.i("Disconnected")
    self.menubar:setIcon(self.disconnectedIcon)
  end
end

function M:connect()
  if not self.sshHost or not self.localPort then
    self.logger.e("Missing required connection parameters")
    return false
  end

  self.logger.i("Connecting to SSH host")
  if self.isConnected then
    self.logger.w("Already connected")
    return false
  end

  local cmd = string.format("/usr/bin/ssh -D %d -C -N %s", self.localPort, self.sshHost)
  self.task = hs.task.new("/bin/sh", nil, { "-c", cmd })
  self.task:setCallback(function(exitCode, stdOut, stdErr)
    if exitCode ~= 0 then
      self.logger.e(string.format("SSH connection failed: %s", stdErr))
      self:handleDisconnect()
      -- Attempt reconnection after 30 seconds
      hs.timer.doAfter(30, function()
        self:connect()
      end)
    end
  end)

  if self.task:start() then
    self.isConnected = true
    self:updateMenu()
    -- Start keepalive timer
    self.timer = hs.timer.new(60, function()
      self:checkConnection()
    end)
    self.timer:start()
    return true
  end

  return false
end

function M:disconnect()
  self.logger.i("Disconnecting")
  if self.task then
    self.task:terminate()
    self.task = nil
  end
  if self.timer then
    self.timer:stop()
    self.timer = nil
  end
  self:handleDisconnect()
end

function M:handleDisconnect()
  self.isConnected = false
  self:updateMenu()
end

function M:checkConnection()
  local cmd = string.format([[netstat -an | grep 'LISTEN' | grep '%d' | grep -q '.*']], self.localPort)
  local task = hs.task.new("/bin/sh", function(exitCode, _, _)
    if exitCode ~= 0 and self.isConnected then
      self.logger.w("Connection check failed, reconnecting...")
      self:handleDisconnect()
      self:connect()
    end
  end, { "-c", cmd })
  task:start()
end

function M:config(sshHost, localPort)
  self.logger.i("SocksProxy spoon starting")
  if not sshHost then
    self.logger.e("SSH host is required")
    return false
  end

  self.sshHost = sshHost
  self.localPort = tonumber(localPort) or 8080

  if self.localPort < 1024 or self.localPort > 65535 then
    self.logger.e("Invalid port number")
    return false
  end

  return true
end

function M:stop()
  self.logger.i("SocksProxy spoon stopping")
  self:disconnect()
end

return M
