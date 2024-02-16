local windib = require("windib");

local term = require("term");
local shell = require("shell");

local display, resolution = ...;

if not display and not os.getenv("DISPLAY") then
  error("No display specified and DISPLAY environment variable not set");
end
local host, displayNum = windib.parseDisplay(display or os.getenv("DISPLAY"), true);
local handle = windib.createXwindib(host, displayNum, true);

local initialColumns, initialRows;
if resolution then
  local wstr, hstr = resolution:match("(%d+)x(%d+)");
  initialColumns, initialRows = tonumber(wstr), tonumber(hstr);
  if not initialColumns or not initialRows then
    error("Invalid resolution: " .. resolution);
  end
else
    initialColumns, initialRows = 80, 25;
end

local cellWidth, cellHeight = 20, 20;

local window = handle:openWindow({
    size = { initialColumns * cellWidth, initialRows * cellHeight },
});
window:setVisible(true);

os.sleep(5);
local oldGPU = term.gpu();

local defaultPalettes = {
    [4] = {
        0xFFFFFF, 0xFFCC33, 0xCC66CC, 0x6699FF,
        0xFFFF33, 0x33CC33, 0xFF6699, 0x333333,
        0xCCCCCC, 0x336699, 0x9933CC, 0x333399,
        0x663300, 0x336600, 0xFF3333, 0x000000
    },
    [8] = {
        0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x3C3C3C,
        0x4B4B4B, 0x5A5A5A, 0x696969, 0x787878,
        0x878787, 0x969696, 0xA5A5A5, 0xB4B4B4,
        0xC3C3C3, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0,
    }
}

for i = 1, 16 do
    local component = math.floor(0xFF / i);
    defaultPalettes[8][i] = (component << 16) | (component << 8) | component;
end

local function createGPU(columns, rows)
    local buffer = {};
    local palette = {};
    local depth = 8;
    local foreground, background = 0xFFFFFF, 0x000000;

    local function getCell(x, y)
        return buffer[y] and buffer[y][x] or {
            char = " ", fg = 0xFFFFFF, bg = 0x000000
        };
    end
    
    local function setCell(x, y, char, fg, bg)
        if x < 1 or y < 1 or x > columns or y > rows then
            return false;
        end
        if not buffer[y] then
            buffer[y] = {};
        end
        buffer[y][x] = {
            char = char, fg = fg, bg = bg
        };
    end

    local newGPU = {}
    function newGPU.getScreen()
        return oldGPU.getScreen();
    end
    function newGPU.getBackground()
        local isPaletteIndex = background < 0;
        return isPaletteIndex and (-background - 1) or background;
    end
    function newGPU.setBackground(color, isPaletteIndex)
        if isPaletteIndex then
            background = -color - 1;
        else
            background = color;
        end
    end
    function newGPU.getForeground()
        local isPaletteIndex = foreground < 0;
        return isPaletteIndex and (-foreground - 1) or foreground;
    end
    function newGPU.setForeground(color, isPaletteIndex)
        if isPaletteIndex then
            foreground = -color - 1;
        else
            foreground = color;
        end
    end
    function newGPU.getPaletteColor(index)
        return palette[index + 1];
    end
    function newGPU.setPaletteColor(index, color)
        if index > 15 or index < 0 then
            return nil, "palette index out of range";
        end
        if depth == 2 then
            return nil, "palette not supported";
        end
        local oldColor = palette[index + 1];
        palette[index + 1] = color;
        return oldColor;
    end
    function newGPU.maxDepth()
        return 8;
    end
    function newGPU.getDepth()
        return depth;
    end
    function newGPU.setDepth(newDepth)
        if newDepth ~= 1 and newDepth ~= 4 and newDepth ~= 8 then
            return nil, "unsupported depth";
        end
        local oldDepth = depth;
        depth = newDepth;
        buffer = {};

        if oldDepth == 1 then
            return "OneBit";
        elseif oldDepth == 4 then
            return "FourBit";
        else
            return "EightBit";
        end
    end
    function newGPU.maxResolution()
        return columns, rows;
    end
    function newGPU.getResolution()
        return columns, rows;
    end
    function newGPU.setResolution(w, h)
        return false;
    end
    function newGPU.getViewport()
        return columns, rows;
    end
    function newGPU.setViewport(w, h)
        return false;
    end
    function newGPU.getDataSize()
        return 1, 1;
    end
    function newGPU.get(x, y)
        local cell = getCell(x, y);
        local fgPaletteIndex = cell.fg < 0 and (-cell.fg - 1) or nil;
        local bgPaletteIndex = cell.bg < 0 and (-cell.bg - 1) or nil;
        local fg = fgPaletteIndex and palette[fgPaletteIndex + 1] or cell.fg;
        local bg = bgPaletteIndex and palette[bgPaletteIndex + 1] or cell.bg;
        return cell.char, fg, bg, fgPaletteIndex, bgPaletteIndex;
    end
    function newGPU.set(x, y, value, vertical)
        for i = 1, #value do
            local char = value:sub(i, i);
            setCell(x, y, char, foreground, background);
            if vertical then
                y = y + 1;
            else
                x = x + 1;
            end
        end
    end
    function newGPU.copy(x, y, width, height, tx, ty)
        local newBuffer = {};
        for i = 1, height do
            newBuffer[i] = {};
            for j = 1, width do
                local cell = getCell(x + j - 1, y + i - 1);
                newBuffer[i][j] = {
                    char = cell.char, fg = cell.fg, bg = cell.bg
                };
            end
        end
        for i = 1, height do
            for j = 1, width do
                setCell(tx + j - 1, ty + i - 1, newBuffer[i][j].char, newBuffer[i][j].fg, newBuffer[i][j].bg);
            end
        end
    end
    function newGPU.fill(x, y, width, height, char)
        for i = 1, height do
            for j = 1, width do
                setCell(x + j - 1, y + i - 1, char, foreground, background);
            end
        end
    end

    return newGPU;
end

term.bind(createGPU(initialColumns, initialRows));
shell.execute("/bin/sh.lua");
term.bind(oldGPU);