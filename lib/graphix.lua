local graphixContextPrototype = {};

function graphixContextPrototype:clear()
    local geometry, err = self._handle:getGeometry(self._windowId);
    if not geometry then return self:_error(err); end

    self._handle:clearArea({
        windowId = self._windowId,
        x = 0,
        y = 0,
        width = geometry.width,
        height = geometry.height,
        exposures = false
    });
end

local graphix = {};

function graphix.createX(windowId, handle, errorFunc)
    local graphixContext = {
        _windowId = windowId,
        _handle = handle,
        _error = errorFunc
    };

    for k, v in pairs(graphixContextPrototype) do
        graphixContext[k] = v;
    end

    return graphixContext
end

return graphix;