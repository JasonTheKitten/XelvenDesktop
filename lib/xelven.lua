local X_MAJOR_VERSION = 11;
local X_MINOR_VERSION = 0;

local handlePrototype = {};

function handlePrototype:close()
  self._socket:close();
end

function handlePrototype:_pad(n)
  return (4 - (n % 4)) % 4;
end

function handlePrototype:_sendCard8(value)
  self._socket:write(string.char(value));
end

function handlePrototype:_sendCard16(value)
  self:_sendCard8(value >> 8);
  self:_sendCard8(value & 0xFF);
end

function handlePrototype:_sendCard32(value)
  self:_sendCard8(value >> 24);
  self:_sendCard8((value >> 16) & 0xFF);
  self:_sendCard8((value >> 8) & 0xFF);
  self:_sendCard8(value & 0xFF);
end

function handlePrototype:_sendString8(value)
  self._socket:write(value);
end

function handlePrototype:_sendNone(times)
  for i = 0, times or 0 do
    self._socket:write(0);
  end
end

function handlePrototype:_readCard8()
  self._position = self._position + 1;
  return string.byte(self._socket:read(1))
end

function handlePrototype:_readCard16()
  return (self:_readCard8() << 8) + self:_readCard8();
end

function handlePrototype:_readCard32()
  return (self:_readCard16() << 16) + self:_readCard16();
end

function handlePrototype:_readString8(n)
  self._position = self._position + n;
  return self._socket:read(n);
end

function handlePrototype:_skipRead(n)
  self._position = self._position + n;
  self._socket:read(n);
end

function handlePrototype:_connectionSetup()
  self:_sendCard8(66);
  self:_sendNone();
  self:_sendCard16(X_MAJOR_VERSION);
  self:_sendCard16(X_MINOR_VERSION);
  -- Authentication is not supported at this time
  self:_sendCard16(0);
  self:_sendCard16(0);
  self:_sendNone();
  self:_sendNone();
  self:_sendNone(self:_pad(0));
  self:_sendNone(self:_pad(0));
  
  local success = self:_readCard8();
  if success == 2 then
    return nil, "Authentication is not supported at this time";
  elseif success == 0 then
    local strlen = self:_readCard8();
    self:_skipRead(6);
    return nil, self:_readString8(strlen);
  end
end

local xelven = {};

xelven.connect = function(host, display)
  return xelven.wrap(require("internet").open(host, display + 6000));
end

xelven.wrap = function(socket)
  local handle = {
    _socket = socket,
    _position = 0
  };
  for k, v in pairs(handlePrototype) do
    handle[k] = v;
  end
  
  local err = handle:_connectionSetup()
  if err then
    return nil, err;
  end
  
  return handle;
end

local handle = xelven.connect("127.0.0.1", 0);
handle:close();

xelven.X_MAJOR_VERSION = X_MAJOR_VERSION;
xelven.X_MINOR_VERSION = X_MINOR_VERSION;
return xelven;