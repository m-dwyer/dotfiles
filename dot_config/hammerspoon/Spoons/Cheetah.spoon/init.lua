--- === Cheetah ===
---
--- Allow keybindings for different cheatsheets
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Cheetah"
obj.version = "1.0"
obj.author = "Em Dwyer <em@emdwyer.dev>"
obj.homepage = "https://github.com/m-dwyer/dotfiles"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.modifiers = {
    cmd = '⌘',
    shift = '⇧',
    alt = '⌥',
    ctrl = '⌃',
}

obj.theme = 'dark'
obj.position = 'top'

obj.config = {
    dir = os.getenv("HOME") .. "/.config/hammerspoon/cheatsheets"
}

obj.bindings = {}

local function getFilePath(filename)
    return obj.config.dir .. '/' .. filename .. '.csv'
end

local function createBindingHtml(row)
    local menu = ""
    for _, rowVal in pairs(row) do
        local binding = rowVal['binding']
        for text, modifier in pairs(obj.modifiers) do
            binding = string.gsub(binding, text, modifier)
        end

        menu = menu ..
        "<li><div class='cmdModifiers'>" ..
        binding .. "</div><div class='cmdtext'>" .. " " .. rowVal['description'] .. "</div></li>"
    end

    return menu
end

local function createAllBindingHtml(cheatsheetRows)
    local menu = ""
    local pos = 0
    for header, _ in ipairs(cheatsheetRows) do
        local rowHeader = cheatsheetRows[header]
        local row = cheatsheetRows[rowHeader]
        menu = menu .. "<ul class='col col" .. pos .. "'>"
        menu = menu .. "<li class='title'><strong>" .. rowHeader .. "</strong></li>"
        menu = menu .. createBindingHtml(row)
        menu = menu .. "</ul>"

        pos = pos + 1
    end

    return menu
end

local function loadCss()
    local css_path = hs.spoons.resourcePath('themes/' .. obj.theme .. '/style.css')
    local css_file = io.open(css_path, "r")

    if css_file == nil then
        hs.dialog.alert(200, 200, nil, "No style sheet", "Couldn't load theme stylesheet", "OK")
        return ''
    end
    local css = css_file:read("*a")
    css_file:close()

    return css
end

local function createHtml(cheatsheetName, cheatsheetRows)
    local theme_css = loadCss()
    local app_title = cheatsheetName

    local bindingHtml = createAllBindingHtml(cheatsheetRows)

    local html = [[
        <!DOCTYPE html>
        <html>
            <head>
            <style type="text/css">]] .. theme_css .. [[</style>
            </head>
            <body>
                <header>
                <div class="title"><strong>]] .. app_title .. [[</strong></div>
                <hr />
                </header>
                <div class="content maincontent">]] .. bindingHtml .. [[</div>
                <br>
            </body>
        </html>
        ]]

    return html
end

local function loadCheatsheet(name, filename)
    local file = io.open(filename, "r")
    if not file then
        print("Error: Could not open file " .. filename)
        return
    end

    local cheatsheetRows = {}
    for line in file:lines() do
        local values = {}
        for i in string.gmatch(line, '([^,]+)') do
            values[#values + 1] = i
        end

        if #values == 3 then
            local header = values[1]
            local binding = values[2]
            local description = values[3]

            if not cheatsheetRows[header] then
                table.insert(cheatsheetRows, header)
                local row = cheatsheetRows[#cheatsheetRows]
                cheatsheetRows[row] = {}
            end

            table.insert(cheatsheetRows[header], { binding = binding, description = description })
        else
            print("Invalid row format: " .. line)
        end
    end

    local cheatsheet = createHtml(name, cheatsheetRows)
    return cheatsheet
end

local function getCheatsheet(name)
    local filePath = getFilePath(name)
    local cheatsheet = loadCheatsheet(name, filePath)

    return cheatsheet
end

function obj:hide()
    self.sheetView:hide()
end

function obj:show(file)
    local cheatsheet = getCheatsheet(file)

    self.sheetView:html(cheatsheet)
    self.sheetView:show()

    print("done")

    return
end

function obj:toggle(file)
    if self.sheetView and self.sheetView:hswindow() and self.sheetView:hswindow():isVisible() then
        self:hide()
    else
        self:show(file)
    end
end

function obj:init()
    self.sheetView = hs.webview.new({ x = 0, y = 0, w = 0, h = 0 })
    self.sheetView:alpha(0.90)
    self.sheetView:windowTitle("CheatSheet")
    self.sheetView:windowStyle("utility")
    self.sheetView:allowGestures(true)
    self.sheetView:allowNewWindows(false)
    self.sheetView:level(hs.drawing.windowLevels.tornOffMenu)
    self:setPosition("top")
    self.sheetView:hide()

    local frame = hs.geometry.rect(100, 100, 800, 600) -- Define the webview frame

    -- Create the webview
    local webview = hs.webview.new(frame):url("https://www.example.com")
    webview:show()
end

function obj:setPosition(position)
    ---TODO: Update menu checkboxes. Fix up bottom y.
    self.position = position
    local cscreen = hs.screen.mainScreen()
    local cres = cscreen:fullFrame()
    local x_centered = cres.x + (cres.w * .5) - 512
    local y_centered = cres.y + (cres.h * .5) - (cres.h * .25)
    local width = 220
    local height = 240

    ---Default position is top
    local win_pos = {
        x = x_centered,
        y = cres.y + 10,
        w = 1024,
        h = height
    }

    ---Adjust y for bottom
    if position == "bottom" then
        win_pos.y = cres.h - 60 - height
    end
    --Adjust y,h for left, centre, right
    if position ~= "top" and position ~= "bottom" then
        win_pos.y = y_centered
        win_pos.h = cres.h * .5
    end
    ---Adjust w,x for left & right
    if position == "left" or position == "right" then
        win_pos.w = width
        if position == "left" then
            win_pos.x = 0
        else
            win_pos.x = cres.w - width
        end
    end
    self.sheetView:frame(win_pos)
end

function obj:bindHotkeys(mappings)
    for i, entry in ipairs(mappings) do
        print("i is: ", i)
        print("File: ", entry.file)
        print("Modifiers: ", table.concat(entry.toggle[1], " + "))
        print("Key: ", entry.toggle[2])
        print("---")

        hs.hotkey.bind(entry.toggle[1], entry.toggle[2], function()
            self:toggle(entry.file)
        end)
    end
end

return obj
