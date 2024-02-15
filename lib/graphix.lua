local paintPrototype = {};

function paintPrototype:close()
    self._handle:freeGC(self._gc);
    self._graphix._resourceAllocator:freeId(self._gc);
    for k, v in ipairs(self._graphix._paints) do
        if v == self then
            table.remove(self._graphix._paints, k);
            break;
        end
    end
end

function paintPrototype:mergeStyles(styles)
    self._handle:changeGC({
        graphicsContextId = self._gc,
        valueMask = self:_createStyleMask(styles),
        styles = self:_createStyleList(styles)
    });
end

function paintPrototype:_createStyleMask(styles)
    local mask = 0;
    if styles.background then
        mask = mask | self._handle.STYLE_MASK_BACKGROUND;
    end
    if styles.foreground then
        mask = mask | self._handle.STYLE_MASK_FOREGROUND;
    end

    return mask;
end

function paintPrototype:_createStyleList(styles)
    local formattedStyles = {};
    formattedStyles.background = styles.background;
    formattedStyles.foreground = styles.foreground;

    return formattedStyles;
end

local graphixContextPrototype = {};

function graphixContextPrototype:startFrame()
    while #self._paints > 0 do
        self._paints[1]:close();
    end
end

function graphixContextPrototype:createPaint(styles)
    local paintId = self._resourceAllocator:allocateId();

    local paint = {
        _handle = self._handle,
        _graphix = self,
        _gc = paintId
    };

    for k, v in pairs(paintPrototype) do
        paint[k] = v;
    end

    self._handle:createGC({
        graphicsContextId = paintId,
        windowId = self._windowId,
        valueMask = paint:_createStyleMask(styles),
        styles = paint:_createStyleList(styles)
    });

    return paint;
end

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

function graphixContextPrototype:fillRect(paint, x, y, width, height)
    self._handle:polyFillRectangle({
        windowId = self._windowId,
        graphicsContextId = paint._gc,
        rectangles = {
            { x, y, width, height }
        }
    });
end

local graphix = {};

function graphix.createX(windowId, handle, resourceAllocator, errorFunc)
    local graphixContext = {
        _windowId = windowId,
        _handle = handle,
        _error = errorFunc,
        _resourceAllocator = resourceAllocator,
        _paints = {}
    };

    for k, v in pairs(graphixContextPrototype) do
        graphixContext[k] = v;
    end

    return graphixContext
end

return graphix;