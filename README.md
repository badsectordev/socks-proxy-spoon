# socks-proxy-spoon

## Installation

Clone the repo to your Hammerspoon spoons directory:

`git clone git@github.com:badsectordev/socks-proxy-spoon.git ~/.hammerspoon/Spoons/SocksProxy.spoon`

To your ~/.hammerspoon/init.lua add:

```lua
hs.loadSpoon("SocksProxy")
spoon.SocksProxy:config("user@somehost", 12345)
```

(Adding a host and port that is useful to you)

Reload your Hammerspoon Config.

There will be a menubar icon that you can click to toggle the proxy on and off.

By default the proxy is off.

Thats it!
