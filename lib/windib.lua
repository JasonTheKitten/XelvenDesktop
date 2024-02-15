local xelven = require("xelven");

local xwindowHandlePrototype = {};
function xwindowHandlePrototype:setVisible(visible)
    if visible then
        self._handle:mapWindow(self._windowId);
    else
        self._handle:unmapWindow(self._windowId);
    end
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

    local windowId = self._nextId;
    self._nextId = self._nextId + 1;

    local settings = {
        depth = 24,
        windowId = windowId,
        parentId = self._handle.serverInfo.roots[screenNumber].root,
        width = size[1],
        height = size[2],
        x = position[1],
        y = position[2],
        borderWidth = 1,
        windowClass = self._handle.WINDOW_CLASS_INPUT_OUTPUT,
        visualId = visual.visualId,
        valueMask = 0
    };

    self._handle:createWindow(settings);
    local window = {
        _handle = self._handle,
        _windowId = windowId
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

    local xwindib = {
        _handle = handle,
        _nextId = handle.serverInfo.resourceIdBase
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

