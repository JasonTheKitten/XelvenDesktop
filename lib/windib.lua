local xelven = require("xelven");

local allocatorPrototype = {};

function allocatorPrototype:allocateId()
    if #self._availableIds > 0 then
        local id = table.remove(self._availableIds);
        table.insert(self._allocatedIds, id);
        return id;
    end

    table.insert(self._allocatedIds, self._nextId);
    self._nextId = self._nextId + 1;
    return self._nextId - 1;
end

function allocatorPrototype:freeId(id)
    for k, v in pairs(self._allocatedIds) do
        if v == id then
            table.remove(self._allocatedIds, k);
            table.insert(self._availableIds, id);
            return;
        end
    end
end

local function createAllocator(startId)
    local allocator = {
        _nextId = startId or 1,
        _allocatedIds = {},
        _availableIds = {}
    };

    for k, v in pairs(allocatorPrototype) do
        allocator[k] = v;
    end

    return allocator;
end

local xwindowHandlePrototype = {};
function xwindowHandlePrototype:setVisible(visible)
    if visible then
        self._handle:mapWindow(self._windowId);
    else
        self._handle:unmapWindow(self._windowId);
    end
end

function xwindowHandlePrototype:mergeAttributes(attributes)
    local attributeMask = 0;
    local formattedAttributes = {};
    if attributes.backgroundColor then
        attributeMask = attributeMask | self._handle.ATTRIB_MASK_BACKGROUND_PIXEL;
        formattedAttributes.backgroundPixel = attributes.backgroundColor;
    end

    self._handle:changeWindowAttributes({
        windowId = self._windowId,
        valueMask = attributeMask,
        attributes = formattedAttributes
    });
end

function xwindowHandlePrototype:getBounds()
    local geometry, err = self._handle:getGeometry(self._windowId);
    if not geometry then return self:_error(err); end

    return {
        position = { geometry.x, geometry.y },
        size = { geometry.width, geometry.height }
    };
end

function xwindowHandlePrototype:createGraphics(graphicsFactory)
    return graphicsFactory(
        self._windowId, self._handle, self._xwindib._resourceAllocator, self._error);
end

local xwindibPrototype = {};

function xwindibPrototype:close()
    self._handle:close();
end

function xwindibPrototype:openWindow(options)
    options = options or {};
    
    local size = options.size or { 800, 600 };
    local position = options.position or { 100, 100 };
    local screenNumber = options.screen or 1;

    local visual, err = self:_findVisual(screenNumber, 24, self._handle.VISUAL_CLASS_TRUE_COLOR);
    if not visual then return self:_error(err) end

    local windowId = self._resourceAllocator:allocateId();
    local screen = self._handle.serverInfo.roots[screenNumber];

    self._handle:createWindow({
        depth = 24,
        windowId = windowId,
        parentId = screen.root,
        width = size[1],
        height = size[2],
        x = position[1],
        y = position[2],
        borderWidth = 1,
        windowClass = self._handle.WINDOW_CLASS_INPUT_OUTPUT,
        visualId = visual.visualId,
        valueMask = self._handle.ATTRIB_MASK_BACKGROUND_PIXEL,
        attributes = {
            backgroundPixel = screen.blackPixel
        }
    });

    local window = {
        _handle = self._handle,
        _xwindib = self,
        _windowId = windowId,
        _error = self._error
    };

    for k, v in pairs(xwindowHandlePrototype) do
        window[k] = v;
    end

    return window;
end

function xwindibPrototype:_findVisual(screenNumber, depth, class)
    for _, allowedDepth in ipairs(self._handle.serverInfo.roots[screenNumber].allowedDepths) do
        if allowedDepth.depth == depth then
            for _, visual in ipairs(allowedDepth.visuals) do
                if visual.class == class then
                    return visual;
                end
            end
        end
    end

    return self:_error("Could not find visual for window");
end

function xwindibPrototype:_error(err)
    return nil, err
end

local function createXwindib(host, display, throws)
    local handle, err = xelven.connect(host, display);
    if not handle then
        if throws then
            error(err);
        end
        return nil, err;
    end

    local baseId = handle.serverInfo.resourceIdBase;
    local xwindib = {
        _handle = handle,
        _resourceAllocator = createAllocator(baseId),
    };

    for k, v in pairs(xwindibPrototype) do
        xwindib[k] = v;
    end

    if throws then xwindib._error = function(_, e) error(e) end end

    return xwindib;
end

local function parseDisplay(display, throws)
    local host, display = display:match("^(.-):(%d+)$");
    if not display or display == "" then
        if throws then
            error("Invalid display");
        end
        return nil, "Invalid display";
    end
    if host == "" then
        host = "127.0.0.1";
    end

    return host, tonumber(display);
end

return {
    createXwindib = createXwindib,
    parseDisplay = parseDisplay
};

