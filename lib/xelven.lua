local X_MAJOR_VERSION = 11;
local X_MINOR_VERSION = 0;

local handlePrototype = {
  BACKING_STORES_NEVER = 0,
  BACKING_STORES_WHEN_MAPPED = 1,
  BACKING_STORES_ALWAYS = 2,

  VISUAL_CLASS_STATIC_GRAY = 0,
  VISUAL_CLASS_GRAY_SCALE = 1,
  VISUAL_CLASS_STATIC_COLOR = 2,
  VISUAL_CLASS_PSEUDO_COLOR = 3,
  VISUAL_CLASS_TRUE_COLOR = 4,
  VISUAL_CLASS_DIRECT_COLOR = 5,
};

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

function handlePrototype:_readBool()
  return self:_readCard8() ~= 0;
end

function handlePrototype:_skipRead(n)
  self._position = self._position + (n or 1);
  self._socket:read(n or 1);
end

function handlePrototype:_parseFormat()
  local format = {};
  format.depth = self:_readCard8();
  format.bitsPerPixel = self:_readCard8();
  format.scanlinePad = self:_readCard8();
  self:_skipRead(5);
  return format;
end

function handlePrototype:_readVisualType()
  local visual = {};
  visual.visualId = self:_readCard32();
  visual.class = self:_readCard8();
  visual.bitsPerRgbValue = self:_readCard8();
  visual.colormapEntries = self:_readCard16();
  visual.redMask = self:_readCard32();
  visual.greenMask = self:_readCard32();
  visual.blueMask = self:_readCard32();
  self:_skipRead(4);

  return visual;
end

function handlePrototype:_readDepth()
  local depth = {
    visuals = {}
  };
  depth.depth = self:_readCard8();
  self:_skipRead(1);
  depth.numVisuals = self:_readCard16();
  self:_skipRead(4);
  for _ = 1, depth.numVisuals do
    table.insert(depth.visuals, self:_readVisualType());
  end

  return depth;
end

function handlePrototype:_readScreen()
  local screen = {
    allowedDepths = {}
  };
  screen.root = self:_readCard32();
  screen.defaultColormap = self:_readCard32();
  screen.whitePixel = self:_readCard32();
  screen.blackPixel = self:_readCard32();
  screen.currentInputMasks = self:_readCard32();
  screen.widthInPixels = self:_readCard16();
  screen.heightInPixels = self:_readCard16();
  screen.widthInMillimeters = self:_readCard16();
  screen.heightInMillimeters = self:_readCard16();
  screen.minInstalledMaps = self:_readCard16();
  screen.maxInstalledMaps = self:_readCard16();
  screen.rootVisual = self:_readCard32();
  screen.backingStores = self:_readCard8();
  screen.saveUnders = self:_readBool();
  screen.rootDepth = self:_readCard8();
  screen.numDepths = self:_readCard8();
  for _ = 1, screen.numDepths do
      table.insert(screen.allowedDepths, self:_readDepth());
  end

  return screen;
end

function handlePrototype:_parseServerInfo()
  local serverInfo = {
    pixmapFormats = {}
  };
  self:_skipRead();
  serverInfo.protocolMajorVersion = self:_readCard16();
  serverInfo.protocolMinorVersion = self:_readCard16();
  self:_skipRead(2);
  serverInfo.releaseNumber = self:_readCard32();
  serverInfo.resourceIdBase = self:_readCard32();
  serverInfo.resourceIdMask = self:_readCard32();
  serverInfo.motionBufferSize = self:_readCard32();
  serverInfo.vendorLength = self:_readCard16();
  serverInfo.maximumRequestLength = self:_readCard16();
  serverInfo.numRoots = self:_readCard8();
  serverInfo.numPixmapFormats = self:_readCard8();
  serverInfo.imageByteOrder = self:_readCard8();
  serverInfo.bitmapFormatBitOrder = self:_readCard8();
  serverInfo.bitmapFormatScanlineUnit = self:_readCard8();
  serverInfo.bitmapFormatScanlinePad = self:_readCard8();
  serverInfo.minKeycode = self:_readCard8();
  serverInfo.maxKeycode = self:_readCard8();
  self:_skipRead(4);
  serverInfo.vendor = self:_readString8(serverInfo.vendorLength);
  print(serverInfo.vendor);
  self:_skipRead(self:_pad(serverInfo.vendorLength));
  for _ = 1, serverInfo.numPixmapFormats do
    table.insert(serverInfo.pixmapFormats, self:_parseFormat());
  end
  for _ = 1, serverInfo.numRoots do
    self:_readScreen();
  end

  return serverInfo;
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

  self.serverInfo = self:_parseServerInfo();
end

local xelven = {};

xelven.connect = function(host, display)
---@diagnostic disable-next-line: undefined-field
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

local handle, err = xelven.connect("127.0.0.1", 0);
if not handle then
  error(err);
end
handle:close();

xelven.X_MAJOR_VERSION = X_MAJOR_VERSION;
xelven.X_MINOR_VERSION = X_MINOR_VERSION;
return xelven;