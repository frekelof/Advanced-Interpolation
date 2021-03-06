-- Changelog --
-- 2019-10-22: First version considered done
-- 2019-10-27: Made x I/O box active at program launch and window resizing
-- 2019-11-07: Also made x I/O box active when Lua gets focus
--             Added check for program running on a CAS calculator
--             Optimized BASIC functions. Same function used to calculate y value and graph.
--             Made graphs piecewise functions.
--             Added check if x is outside xi range in lagrange interpolation.
--             Found out tabular equations requires xi to be in ascending order, corrected. (Descending order results in strange behaviour)
--             Added copy/cut/paste text functionality.
--             Added Spline Interpolation.
-- 2020-10-04: Added linear interpolation.

-- References --
-- https://en.wikipedia.org/wiki/Lagrange_polynomial
-- https://www.dcode.fr/lagrange-interpolating-polynomial
-- Astronomical Algorithms 2nd Ed - Jean Meeus, ISBN: 0-943396-61-1
-- https://en.wikipedia.org/wiki/Spline_(mathematics)
-- https://en.wikipedia.org/wiki/Linear_interpolation

-- Minimum requirements: TI Nspire CX CAS (color resulution 318x212)

platform.apilevel = '2.4'
local appversion = "201005" -- Made by: Fredrik Ekelöf, fredrik.ekelof@gmail.com

-- !All positions and sizes uses hand held unit as reference!
-- !Program will scale relative to size on held unit!

-- App layout configuration
local lines = 6 -- Total lines program contains. Lines are evenly split horizonatally.
local padding = 5 -- Empty space between borders and working area

-- Font size configuration. Availible sizes are 7,9,10,11,12,16,24.
local fnthdgset = 9 -- Heading font size
local fntbodyset = 9 -- Label and body text font size

-- Colors
local bgcolor = 0xCFE2F3 -- Background, light blue
local brdcoloract = 0x2478CF -- Active box border, blue
local brdcolorinact = 0xEBEBEB -- Inactive box border, grey
local errorcolor = 0xF02600 -- Error text, dark red

-- Variabels for internal use
local isCAS = nil -- Used for CAS check. Variabel is set in on.resize() function
local fnthdg,fntbody = fnthdgset,fntbodyset -- Font size variabels used by functions
local lblhdg = "" -- Empty variabel for storing heading
local calcmode = 4 -- Defaults to Lagrange interpolation at program launch (ID 5 = tabular interpolation, ID 8 = Spline interpolation, ID 9 = Linear interpolation)
local ioidtable = {} -- Initial empty table for storing I/O editor boxes unique ID:s
local ioexptable = {} -- Initial empty table for storing I/O editor boxes values
local btncalcdis = nil -- Initial value for flagging calc button as disabled
local escrst = 0 -- Tracks how many times Esc key has been pressed
local esccounter = 0 -- Timer for Esc key press reset
local btnresetflash = false -- Tracks reset button flash when Esc has been pressed two times
local btnresetflashcounter = 0 -- Timer for reset button blue flash when pressing Esc key two times
local enterpress = false -- Tracks if Enter key is being pressed in box x
local entercounter = 0 -- Timer for calc button blue flash when pressing Enter key

-- Mouse movement button tracking variabels
local optbtnlagrangeclick = false -- Tracks if Lagrange button is being clicked
local optbtnlagrangehover = false -- Tracks if mouse hovers over Lagrange button
local optbtntabularclick = false -- Tracks if Tabular button is being clicked
local optbtntabularhover = false -- Tracks if mouse hovers over Tabular button
local optbtnsplineclick = false -- Tracks if Spline button is being clicked
local optbtnsplinehover = false -- Tracks if mouse hovers over Spline button
local optbtnlinearclick = false -- Tracks if Linear button is being clicked
local optbtnlinearhover = false -- Tracks if mouse hovers over Linear button
local btncalcclick = false -- Tracks if calc button is being clicked
local btncalchover = false -- Tracks if mouse hovers over calc button
local btnresetclick = false -- Tracks if reset button is being clicked
local btnresethover = false -- Tracks if mouse hovers over reset button

-- Screen properties
local scr = platform.window -- Shortcut
local scrwh,scrht = scr:width(),scr:height() -- Stores screen dimensions

-- Images used for push buttons
local buttonblue = image.new(_R.IMG.buttonblue)
local buttongreylight = image.new(_R.IMG.buttongreylight)
local buttonwhite = image.new(_R.IMG.buttonwhite)

-- Images used for option buttons
local radiobuttonchecked = image.new(_R.IMG.radiobuttonchecked)
local radiobuttoncheckedgrey = image.new(_R.IMG.radiobuttoncheckedgrey)
local radiobuttonunchecked = image.new(_R.IMG.radiobuttonunchecked)
local radiobuttonuncheckedgrey = image.new(_R.IMG.radiobuttonuncheckedgrey)

function on.construction()

    timer.start(1/5) -- Starts timer with 5 ticks per second

    -- Sets background colour
    scr:setBackgroundColor(bgcolor)

    -- Activates copy/cut/paste functionality
    toolpalette.enableCopy(true)
    toolpalette.enableCut(true)
    toolpalette.enablePaste(true)

    -- Defines editor boxes variabels, var = iobox(ID,"label text",rows in box,line number,read only,text wrap)
    inpx = iobox(1,"x = ",1,1,0,0)
    outpy = iobox(2,"y = ",1,2,1,0)
    outpeq = iobox(3,"y = ",2,3,1,1)

    -- Defines option button optbtnxxx = optionbutton(id,heading,label,xpos,ypos,width,height)
    -- Position xy ref is bottom right corner
    optbtnlagrange = optionbutton(4,"Lagrange Interpolation","Lagrange",136,24,12,12)
    optbtntabular = optionbutton(5,"Tabular Interpolation","Tabular",48,41,12,12)
    optbtnspline = optionbutton(8,"Spline Interpolation","Spline",48,24,12,12)
    optbtnlinear = optionbutton(9,"Linear Interpolation","Linear",136,41,12,12)

    -- Defines push buttons, btnname = pushbutton(ID,"label text",xpos,ypos,width,height)
    -- Position xy ref is bottom right corner
    btncalc = pushbutton(6,"Calc",0,0,38,16)
    btnreset = pushbutton(7,"Reset",42,0,38,16)

end

-- Shortcut for update/refresh screen
function scrupdate()

    return scr:invalidate()

end

function on.timer() -- Updates screen 5 times per second

    scrupdate()

end

function on.getFocus()

    for i = 1,3 do -- Makes all I/O box borders grey
        ioidtable[i]:setBorderColor(brdcolorinact)
    end

    -- Makes x I/O box active at program launch and window resizing
    ioidtable[1]:setFocus()
    ioidtable[1]:setBorderColor(brdcoloract)

end

function on.resize()

    -- Fetches new screen dimensions when window resizes
    scrwh,scrht = scr:width(),scr:height() -- Stores updated screen dimensions

    -- Checks if program is running on a CAS calculator
    isCAS = not not math.evalStr("?")

    -- Adjusts font size to screen size. Program is designed to have vertical split screen with spreadsheet.
    if scrwh >= 158 then
        fnthdg = fnthdgset*scrwh/158
        fntbody = fntbodyset*scrwh/158
    else --Sets minimum font to 7
        fnthdg = 7
        fntbody = 7
    end

    -- Prints editor boxes to above defined variabels
    inpx:ioeditor()
    outpy:ioeditor()
    outpeq:ioeditor()

    -- Makes x I/O box active at program launch and window resizing
    ioidtable[1]:setFocus()
    ioidtable[1]:setBorderColor(brdcoloract)

end

-- Menu Start --
function menubar(menuoption)

    -- Sets Lagrange or tabular interpolation from toolpalette commands
    calcmode = menuoption

end

menu = {
    {"Interpolation Mode",
        {"Linear",function() menubar(9) end},
        {"Tabular",function() menubar(5) end},
        {"Lagrange",function() menubar(4) end},
        {"Spline",function() menubar(8) end},
    },
}
toolpalette.register(menu)
-- Menu End --

function on.paint(gc)

    -- Prints buttons
    optbtnlagrange:paint(gc)
    optbtntabular:paint(gc)
    optbtnspline:paint(gc)
    optbtnlinear:paint(gc)
    btncalc:paint(gc)
    btnreset:paint(gc)

    -- Prints labels to above defined editor boxes
    inpx:lblpaint(gc)
    outpy:lblpaint(gc)
    outpeq:lblpaint(gc)

    -- Prints app version at bottom of page
    gc:setFont("sansserif","r",7)
    gc:setColorRGB(0x000000)
    gc:drawString("Version: "..appversion,0,scrht,"bottom")

    -- Prints heading
    gc:setFont("sansserif","b",fnthdg) -- Heading font
    local hdgwh,hdght = gc:getStringWidth(lblhdg),gc:getStringHeight(lblhdg) -- Fetches heading dimensions
    if scrht/scrwh < 1.3 or scrht/scrwh > 1.4 or scrht < 212 then -- Prints warning for incorrect screen split
        gc:setColorRGB(errorcolor)
        gc:drawString("Screen ratio not supported!",0,0,"top")
    elseif isCAS == false then
        gc:setColorRGB(errorcolor)
        gc:drawString("Calculator not supported!",0,0,"top")
    else
        gc:setColorRGB(0x000000)
        gc:drawString(lblhdg,scrwh/2-hdgwh/2,0,"top") -- Prints heading
    end
    gc:setPen("thin", "dotted")
    gc:drawLine(0,hdght,scrwh,hdght) -- Draws line below heading

end

-- Checks heading string size outside of paint function
function gethdgsize(str,gc)

    gc:setFont("sansserif","b",fnthdg)
    local strwh,strht = gc:getStringWidth(str),gc:getStringHeight(str)
    return strwh,strht

end

-- Checks body string size outside of paint function
function getbodysize(str,gc)

    gc:setFont("sansserif","r",fntbody)
    local strwh,strht = gc:getStringWidth(str),gc:getStringHeight(str)
    return strwh,strht

end

iobox = class()

function iobox:init(id,lbl,rows,line,read,wrap)

    self.id = id
    self.lbl = lbl
    self.rows = rows
    self.line = line
    self.read = read
    self.wrap = wrap
    self.boxid = D2Editor.newRichText() -- Generates the input box
    ioidtable[id] = self.boxid -- Stores input box unique ID

end

function iobox:lblpaint(gc)

    -- Fetches string sizes of heading and labels
    local lblwh,lblht = platform.withGC(getbodysize,self.lbl)
    local hdgwh,hdght = platform.withGC(gethdgsize,lblhdg)

    local scrht = scrht-hdght -- Removes heading from line equations

    -- Properties for labels
    gc:setFont("sansserif","r",fntbody)
    gc:setColorRGB(0x000000)
    gc:drawString(self.lbl,padding*scrwh/158,hdght+padding*scrwh/158+scrht*(self.line-1)/lines,"top")

end

function iobox:ioeditor()

    function inpexp()

        local boxexp = self.boxid:getExpression() -- Fetches I/O boxes input data

        -- Number validation of input box x
        if self.id == 1 then
            if boxexp ~= nil then
                boxexp = boxexp:gsub(string.uchar(8722),"-") -- Replaces (-) negative sign with "-" minus sign
            end
            if boxexp == "-" then -- Checks if expressen is a minus sign char(45) only, marks it as OK
                ioexptable[self.id] = "-"
                self.boxid:setTextColor(0x000000)
                self.boxid:setMainFont("sansserif","r",fntbody)
            else
                ioexptable[self.id] = tonumber(boxexp)
                if ioexptable[self.id] == nil then -- Flags expression in red text if not a number
                    self.boxid:setTextColor(errorcolor)
                    self.boxid:setMainFont("sansserif","i",fntbody)
                else -- If number is OK, text is set to normal black.
                    self.boxid:setTextColor(0x000000)
                    self.boxid:setMainFont("sansserif","r",fntbody)
                end
            end
        end
    end

    -- Fetches string sizes of heading and labels
    local lblwh,lblht = platform.withGC(getbodysize,self.lbl)
    local hdgwh,hdght = platform.withGC(gethdgsize,lblhdg)

    local scrht = scrht-hdght

    -- Properties for input boxes
    self.boxid:setMainFont("sansserif","r",fntbody)
    self.boxid:move(padding*scrwh/158+lblwh,hdght+padding*scrwh/158+(scrht*(self.line-1))/lines)
    self.boxid:resize(scrwh-lblwh-2*padding*scrwh/158,self.rows*(27+2*(fntbody-10))) -- Height formula concluded from different screen size tests
    self.boxid:setBorder(1) -- Border = 1 px
    self.boxid:setBorderColor(brdcolorinact) -- Default border color (grey)
    self.boxid:setColorable(false) -- Disables manual colors
    self.boxid:setWordWrapWidth(-1) -- Disables word wrap
    self.boxid:setReadOnly(false)
    self.boxid:setDisable2DinRT(true) -- Disables mathprint
    if self.read == 1 then -- Enable read only
        self.boxid:setReadOnly(true)
    end
    if self.wrap == 1 then  -- Enables word wrap
        self.boxid:setWordWrapWidth(scrwh-lblwh-fntbody-1.15*scrwh/158) -- Adjust value 1.15 as needed
    end
    self.boxid:setTextChangeListener(inpexp) -- Checks function inpexp() during writing
    self.boxid:registerFilter { -- Keyboard/mouse actions, Start
        tabKey = function()  -- Changes calc method
            if calcmode == 4 then
                calcmode = 8
            elseif calcmode == 5 then
                calcmode = 4
            elseif calcmode == 8 then
                calcmode = 9
            elseif calcmode == 9 then
                calcmode = 5
            end
            ioidtable[2]:setText("") -- Resets output text
            ioidtable[3]:setText("")
            return true
        end,
        backtabKey = function() -- Changes calc method
            if calcmode == 4 then
                calcmode = 5
            elseif calcmode == 5 then
                calcmode = 9
            elseif calcmode == 8 then
                calcmode = 4
            elseif calcmode == 9 then
                calcmode = 8
            end
            ioidtable[2]:setText("") -- Resets output text
            ioidtable[3]:setText("")
            return true
        end,
        arrowDown = function() -- Moves curser to next input box
            if self.id >= 1 and self.id <= 2 then
                self.boxid:setBorderColor(brdcolorinact)
                ioidtable[self.id+1]:setBorderColor(brdcoloract)
                ioidtable[self.id+1]:setFocus()
                return true
            else
                self.boxid:setBorderColor(brdcolorinact)
                ioidtable[1]:setBorderColor(brdcoloract)
                ioidtable[1]:setFocus()
                return true
            end
        end,
        arrowUp = function() -- Moves curser to previous input box
            if self.id >= 2 and self.id <= 3 then
                self.boxid:setBorderColor(brdcolorinact)
                ioidtable[self.id-1]:setBorderColor(brdcoloract)
                ioidtable[self.id-1]:setFocus()
                return true
            else
                self.boxid:setBorderColor(brdcolorinact)
                ioidtable[3]:setBorderColor(brdcoloract)
                ioidtable[3]:setFocus()
                return true
            end
        end,
        escapeKey = function() -- Clears all values when Esc is being pressed quickly two times
            esccounter = timer.getMilliSecCounter()+500 -- Triggers timer for 2 press reset
            escrst = escrst+1
            if escrst == 2 then
                btnresetflashcounter = timer.getMilliSecCounter()+100
                btnresetflash = true -- Activates blue button flash
                escrst = 0 -- Resets counter
                reset() -- Command is sent to reset function
            end
            return true
        end,
        enterKey = function() -- Performs calculation
            entercounter = timer.getMilliSecCounter()+200 -- Triggers calc button blue flash
            enterpress = true
            if btncalcdis == false then -- Checks if calc button is disabled
                if calcmode == 4 then
                    calclagrange() -- Sends command to calculate Lagrange
                elseif calcmode == 5 then
                    calctab() -- Sends command to calculate Tabulars
                elseif calcmode == 8 then
                    calcspline() -- Sends command to calculate Splines
                elseif calcmode == 9 then
                    calclinear() -- Sends command to calculate Linear
                end
            end
            return true
        end,
        returnKey = function()
            entercounter = timer.getMilliSecCounter()+200 -- Triggers calc button blue flash
            enterpress = true
            if btncalcdis == false then -- Checks if calc button is disabled
                if calcmode == 4 then
                    calclagrange() -- Sends command to calculate Lagrange
                elseif calcmode == 5 then
                    calctab() -- Sends command to calculate Tabulars
                elseif calcmode == 8 then
                    calcspline()  -- Sends command to calculate Splines
                elseif calcmode == 9 then
                    calclinear()  -- Sends command to calculate Linear
                end
            end
            return true
        end,
        mouseDown = function() -- Moves curser to clicked input box
            if ioidtable[self.id]:hasFocus() == false then
                for i = 1,3 do -- Makes all I/O box borders grey
                    ioidtable[i]:setBorderColor(brdcolorinact)
                end
                ioidtable[self.id]:setBorderColor(brdcoloract) -- Makes active I/O box blue
            end
            return false -- Must be false, otherwise not possible to select text with mouse
        end
    } -- Keyboard/mouse actions, End

end

-- Class defines option button properties and actions
optionbutton = class()

function optionbutton:init(id,hdg,lbl,xpos,ypos,wh,ht)

    self.id = id
    self.hdg = hdg
    self.lbl = lbl
    self.x = xpos
    self.y = ypos
    self.wh = wh
    self.ht = ht
    self.selected = false

end

function optionbutton:paint(gc)

    -- Fetches string sizes of labels
    local btnlblwh,btnlblht = platform.withGC(getbodysize,self.lbl)

    -- Properties for labels
    gc:setFont("sansserif","r",fntbody)
    gc:setColorRGB(0x000000)
    gc:drawString(self.lbl,scrwh-self.x*scrwh/158,scrht-(self.ht+self.y+padding+3)*scrht/212,"top") -- Number three center label on icon, change when value when needed

    -- Sets properties for Lagrange radio button
    if calcmode == 4 and self.id == 4 then
        lblhdg = self.hdg -- Sets heading Lagrange Interpolation
        radiobuttonchecked = radiobuttonchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtnlagrangehover == true then
            radiobuttoncheckedgrey = radiobuttoncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttoncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    elseif self.id == 4 and calcmode ~= 4 then
        radiobuttonunchecked = radiobuttonunchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonunchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtnlagrangehover == true then
            radiobuttonuncheckedgrey = radiobuttonuncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttonuncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    end

    -- Sets properties for tabular radio button
    if calcmode == 5 and self.id == 5 then
        lblhdg = self.hdg -- Sets heading Tabular Interpolation
        radiobuttonchecked = radiobuttonchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtntabularhover == true then
            radiobuttoncheckedgrey = radiobuttoncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttoncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    elseif self.id == 5 and calcmode ~= 5 then
        radiobuttonunchecked = radiobuttonunchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonunchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtntabularhover == true then
            radiobuttonuncheckedgrey = radiobuttonuncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttonuncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    end

    -- Sets properties for spline radio button
    if calcmode == 8 and self.id == 8 then
        lblhdg = self.hdg -- Sets heading Spline Interpolation
        radiobuttonchecked = radiobuttonchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtnsplinehover == true then
            radiobuttoncheckedgrey = radiobuttoncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttoncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    elseif self.id == 8 and calcmode ~= 8 then
        radiobuttonunchecked = radiobuttonunchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonunchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtnsplinehover == true then
            radiobuttonuncheckedgrey = radiobuttonuncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttonuncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    end

    -- Sets properties for linear radio button
    if calcmode == 9 and self.id == 9 then
        lblhdg = self.hdg -- Sets heading Linear Interpolation
        radiobuttonchecked = radiobuttonchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtnlinearhover == true then
            radiobuttoncheckedgrey = radiobuttoncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttoncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    elseif self.id == 9 and calcmode ~= 9 then
        radiobuttonunchecked = radiobuttonunchecked:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(radiobuttonunchecked,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        if optbtnlinearhover == true then
            radiobuttonuncheckedgrey = radiobuttonuncheckedgrey:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(radiobuttonuncheckedgrey,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        end
    end

end

function optionbutton:hover(mx,my)

    -- Returns true or false depending on mouse position. Within button areas function return true.
    return mx >= scrwh-(self.wh+self.x+padding)*scrwh/158 and mx <= scrwh-(self.wh+self.x+padding)*scrwh/158+self.wh*scrwh/158 and my >= scrht-(self.ht+self.y+padding)*scrht/212 and my <= scrht-(self.ht+self.y+padding)*scrht/212+self.ht*scrht/212

end

-- Class defines push buttons properties and actions
pushbutton = class()

function pushbutton:init(id,lbl,xpos,ypos,wh,ht)

    self.id = id
    self.lbl = lbl
    self.x = xpos
    self.y = ypos
    self.wh = wh
    self.ht = ht
    self.selected = false

end

function pushbutton:paint(gc)

    local xi = var.recall("xi")
    local yi = var.recall("yi")

    -- Flags calc button as disabled if xi and yi tables are empty or table contains invalid data
    if xi ~= nil and yi ~= nil then
        if #xi ~= 0 and #yi ~= 0 then
            btncalcdis = false
        else
            btncalcdis = true
        end
    else
        btncalcdis = true
    end

    -- Fetches string sizes of heading and labels
    local btnlblwh,btnlblht = platform.withGC(getbodysize,self.lbl)
    local hdgwh,hdght = platform.withGC(gethdgsize,lblhdg)

    -- Calc button will flash for 200 ms
    if entercounter < timer.getMilliSecCounter() then
        enterpress = false
    end

    -- Resets Esc key button press after 500 ms
    if esccounter < timer.getMilliSecCounter()  then
        escrst = 0
    end

    -- Resets calc button blue flash after 200 ms on Esc clear
    if btnresetflashcounter < timer.getMilliSecCounter() then
        btnresetflash = false
    end

    -- Calc button coloring
    if self.id == 6 and btncalcdis == false then -- Makes calc button blue during mouse click
        if btncalcclick == true or enterpress == true then
            buttonblue = buttonblue:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(buttonblue,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
            gc:setFont("sansserif","b",fnthdg)
            gc:setColorRGB(0xFFFFFF)
            gc:drawString(self.lbl,scrwh-(self.x+padding+self.wh/2)*scrwh/158-btnlblwh/2,scrht-(self.y+padding+self.ht/2)*scrht/212-btnlblht/2,"top")
        else  -- Normal mode, white button with black text
            buttonwhite = buttonwhite:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(buttonwhite,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
            gc:setFont("sansserif","r",fnthdg)
            gc:setColorRGB(0x000000)
            gc:drawString(self.lbl,scrwh-(self.x+padding+self.wh/2)*scrwh/158-btnlblwh/2,scrht-(self.y+padding+self.ht/2)*scrht/212-btnlblht/2,"top")
        end
        if btncalchover == true and btncalcclick == false then -- Makes calc button gray on mouse hover
            buttongreylight = buttongreylight:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(buttongreylight,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
            gc:setFont("sansserif","b",fnthdg)
            gc:setColorRGB(0x000000)
            gc:drawString(self.lbl,scrwh-(self.x+padding+self.wh/2)*scrwh/158-btnlblwh/2,scrht-(self.y+padding+self.ht/2)*scrht/212-btnlblht/2,"top")
        end
    end

    -- Disables calc button if tables are empty
    if self.id == 6 and btncalcdis == true then
        buttongreylight = buttongreylight:copy(self.wh*scrwh/158,self.ht*scrht/212)
        gc:drawImage(buttongreylight,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
        gc:setFont("sansserif","r",fnthdg)
        gc:setColorRGB(0xffffff)
        gc:drawString(self.lbl,scrwh-(self.x+padding+self.wh/2)*scrwh/158-btnlblwh/2,scrht-(self.y+padding+self.ht/2)*scrht/212-btnlblht/2,"top")
    end

    -- Reset button coloring
    if self.id == 7 then -- Makes reset button blue during mouse click
        if btnresetclick == true or btnresetflash == true then
            buttonblue = buttonblue:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(buttonblue,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
            gc:setFont("sansserif","b",fnthdg)
            gc:setColorRGB(0xFFFFFF)
            gc:drawString(self.lbl,scrwh-(self.x+padding+self.wh/2)*scrwh/158-btnlblwh/2,scrht-(self.y+padding+self.ht/2)*scrht/212-btnlblht/2,"top")
        else  -- Normal mode, white button with black text
            buttonwhite = buttonwhite:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(buttonwhite,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
            gc:setFont("sansserif","r",fnthdg)
            gc:setColorRGB(0x000000)
            gc:drawString(self.lbl,scrwh-(self.x+padding+self.wh/2)*scrwh/158-btnlblwh/2,scrht-(self.y+padding+self.ht/2)*scrht/212-btnlblht/2,"top")
        end
        if btnresethover == true and btnresetclick == false then -- Makes reset button gray on mouse hover
            buttongreylight = buttongreylight:copy(self.wh*scrwh/158,self.ht*scrht/212)
            gc:drawImage(buttongreylight,scrwh-(self.wh+self.x+padding)*scrwh/158,scrht-(self.ht+self.y+padding)*scrht/212)
            gc:setFont("sansserif","b",fnthdg)
            gc:setColorRGB(0x000000)
            gc:drawString(self.lbl,scrwh-(self.x+padding+self.wh/2)*scrwh/158-btnlblwh/2,scrht-(self.y+padding+self.ht/2)*scrht/212-btnlblht/2,"top")
        end
    end

end

function pushbutton:hover(mx,my)

    -- Returns true or false depending on mouse position. Within button areas function return true.
    return mx >= scrwh-(self.wh+self.x+padding)*scrwh/158 and mx <= scrwh-(self.wh+self.x+padding)*scrwh/158+self.wh*scrwh/158 and my >= scrht-(self.ht+self.y+padding)*scrht/212 and my <= scrht-(self.ht+self.y+padding)*scrht/212+self.ht*scrht/212

end

-- Tracks mouse movement
function on.mouseMove(mx,my)

    -- Sends command to make option button Lagrange grey
    if optbtnlagrange:hover(mx,my) then
        optbtnlagrangehover = true
    else
        optbtnlagrangehover = false
    end

    -- Sends command to make option button Tabular grey
    if optbtntabular:hover(mx,my) then
        optbtntabularhover = true
    else
        optbtntabularhover = false
    end

    -- Sends command to make option button Spline grey
    if optbtnspline:hover(mx,my) then
        optbtnsplinehover = true
    else
        optbtnsplinehover = false
    end

    -- Sends command to make option button Linear grey
    if optbtnlinear:hover(mx,my) then
        optbtnlinearhover = true
    else
        optbtnlinearhover = false
    end

    -- Sends command to make calc button grey
    if btncalc:hover(mx,my) then
        btncalchover = true
    else
        btncalchover = false
    end

    -- Sends command to make reset button grey
    if btnreset:hover(mx,my) then
        btnresethover = true
    else
        btnresethover = false
    end

end

function on.mouseUp(mx,my)

    -- Sends command to make buttons white background when mouse button is released
    optbtnlagrangeclick = false
    optbtntabularclick = false
    optbtnsplineclick = false
    optbtnlinearclick = false
    btncalcclick = false
    btnresetclick = false

end

function on.mouseDown(mx,my)

    -- Lagrange button, sends command to use Lagrange calc mode
    if optbtnlagrange:hover(mx,my) then
        optbtnlagrangeclick = true
        calcmode = 4
        ioidtable[2]:setText("")
        ioidtable[3]:setText("")
    end

    -- Tabular button, sends command to use Tabular calc mode
    if optbtntabular:hover(mx,my) then
        optbtntabularclick = true
        calcmode = 5
        ioidtable[2]:setText("")
        ioidtable[3]:setText("")
    end

    -- Spline button, sends command to use spline calc mode
    if optbtnspline:hover(mx,my) then
        optbtnsplineclick = true
        calcmode = 8
        ioidtable[2]:setText("")
        ioidtable[3]:setText("")
    end

    -- Linear button, sends command to use spline calc mode
    if optbtnlinear:hover(mx,my) then
        optbtnlinearclick = true
        calcmode = 9
        ioidtable[2]:setText("")
        ioidtable[3]:setText("")
    end

    -- Calc button, sends command to do calculations on mouse click
    if btncalc:hover(mx,my) then
        btncalcclick = true
        if btncalcdis == false then -- Checks if calc button is disabled
            if calcmode == 4 then
                calclagrange() -- Sends command to calculate Lagrange
            elseif calcmode == 5 then
                calctab() -- Sends command to calculate Tabulars
            elseif calcmode == 8 then
                calcspline() -- Sends command to calculate Splines
            elseif calcmode == 9 then
                calclinear() -- Sends command to calculate Linear
            end
        end
    end

    -- Reset button, sends command to do reset on mouse click
    if btnreset:hover(mx,my) then
        btnresetclick = true
        reset()
    end

end

function calclagrange()

    local xi = var.recall("xi") -- Stores xi table from Nspire in Lua
    local yi = var.recall("yi")-- Stores yi table from Nspire in Lua
    local x = ioexptable[1] -- Fetches x
    local dup = 0 -- Initial value for checking unique xi values
    local xiyicheck = 0 -- Initial value to verify tables in spreadsheet are OK.
    local xrange = nil -- Initial value to verify x value is within xi table range

    -- Verifies xi and yi contain valid numbers
    if xi == nil or yi == nil then
        ioidtable[2]:setText("- - -")
        ioidtable[3]:setText("Aw, Snap! Something is wrong.")
        xiyicheck = 1
    elseif #xi < 2 or #yi < 2 then
        ioidtable[2]:setText("- - -")
        ioidtable[3]:setText("Table is to short")
        xiyicheck = 1
    else

        -- Sorts xi table in ascending order
        table.sort(xi)

        -- Verifies unique xi values
        for i = 1, #xi-1 do
            if xi[i] == xi[i+1] then
                dup = dup+1
            end

        end

        -- Checks if x is a valid number within xi table range
        if type(x) == "number" then
            if x >= xi[1] and x <= xi[#xi] then
                xrange = 0 -- x is inside xi table range
            else
                xrange = 1 -- x is outside xi table range
            end
        else
            xrange = nil -- x is not a number
        end

        if dup ~= 0 then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("xi's must be unique")
        end

        if xrange == 1 then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("x is out of range")
        elseif xrange == nil then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("x is unknown")
        end

    end

    -- Calculates equation
    if dup == 0 and xiyicheck == 0 and xrange == 0 then
        math.eval("delvar x")
        local printeq = math.evalStr("lagrangefunction:=lagrange(x,xi,yi,0)") -- Calculates graph
        ioidtable[3]:setText("\\0el {"..printeq.."}") -- Prints equation
        if type(ioexptable[1]) == "number" then
            local printy = math.eval("lagrange("..x..",xi,yi,1)")
            if tonumber(printy) == nil then
                printy = "Error in CAS math engine"
            end
            var.store("xplot",ioexptable[1])
            var.store("yplot",printy)
            ioidtable[2]:setText(printy) -- Print answer y
        else
            ioidtable[3]:setText("x must be a number")
        end
    end

end

function calctab()

    local xi = var.recall("xi") -- Stores xi table from Nspire in Lua
    local yi = var.recall("yi")-- Stores yi table from Nspire in Lua
    local x = ioexptable[1] -- Fetches x
    local intcheck = 0 -- Error flag for integrity checks of xi and yi
    local dup = 0 -- Flag for duplicates in xi (all values are same)
    local chklinans = 0 -- Flag for verification that x is within calculation range
    local tablewarn = 0 -- Warning if x is closer to end point then center point
    local xsort = 0 -- Initial value for checking if xi table is ascending

    -- 3 & 5 tabular, verifies integrity of table xi and yi
    -- TI math engine must be used due to 1.3-2.4+1.1 does not equal zero in Lua
    if xi ~= nil and yi ~= nil then -- Tables are not empty
        if #xi == 3 and #yi == 3 or #xi == 5 and #yi == 5 then -- Tables must contain 3 or 5 coordinates
            if #xi == 3 and math.eval("xicheckdist(3,xi)") ~= 0 then -- 3 tabular, x values must be evenly distributed
                ioidtable[2]:setText("- - -") -- Error message
                ioidtable[3]:setText("x values must be evenly distributed")
                intcheck = 1 -- Flag: Do not calculate
            end
            if #xi == 5 and math.eval("xicheckdist(5,xi)") ~= 0 then -- 5 tabular, x values are evenly distributed
                ioidtable[2]:setText("- - -") -- Error message
                ioidtable[3]:setText("x values must be evenly distributed")
                intcheck = 1 -- Flag: Do not calculate
            end
            -- Verifies xi table is sorted in ascending order
            for i = 1, #xi-1 do
                if xi[i+1] < xi[i] then
                    xsort = 1
                end
            end
            for i = 1, #xi-1 do -- Checks for duplicates
                if xi[i] == xi[i+1] then
                    dup = dup+1 -- Flag: Do not calculate
                end
            end
            if dup ~= 0 then
                ioidtable[2]:setText("- - -") -- Error message
                ioidtable[3]:setText("xi's must be unique")
            end
            if xsort ~= 0 then
                ioidtable[2]:setText("- - -")
                ioidtable[3]:setText("xi's must be sorted in ascending order")
            end
        else -- Error message
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("Table must contain 3 or 5 coordinates")
            intcheck = 1 -- Flag: Do not calculate
        end
    else -- Error message
        ioidtable[2]:setText("- - -")
        ioidtable[3]:setText("Aw, Snap! Something is wrong.")
        intcheck = 1 -- Flag: Do not calculate
    end

    -- 3 tabular, verifies x is within range
    if #xi == 3 and #yi == 3 and intcheck == 0 and tonumber(x) ~= nil then
        local chklinstr1 = "when("..xi[1].."<"..x..">"..xi[3]..",1,0,0)"
        local chklinstr2 = "when("..xi[1]..">"..x.."<"..xi[3]..",1,0,0)"
        chklinans =  math.eval(chklinstr1)+math.eval(chklinstr2)
        if chklinans > 0 then
            ioidtable[3]:setText("x is out of range")
        end
    end

    -- 5 tabular, verifies x is within range
    if #xi == 5 and #yi == 5 and intcheck == 0 and tonumber(x) ~= nil then
        local chklinstr1 = "when("..xi[2].."<"..x..">"..xi[4]..",1,0,0)"
        local chklinstr2 = "when("..xi[2]..">"..x.."<"..xi[4]..",1,0,0)"
        chklinans =  math.eval(chklinstr1)+math.eval(chklinstr2)
        if chklinans > 0 then
            ioidtable[3]:setText("x is out of range")
        end
    end

    -- 3 tabular values, checks if x is closer to center then the ends
    if #xi == 3 and #yi == 3 and x ~= nil and chklinans == 0 then
        if x < xi[2] and xi[2] > xi[1] and x < (xi[2]+xi[1])/2 then
            tablewarn = 1
        elseif x > xi[2] and xi[2] < xi[1] and x > (xi[2]+xi[1])/2 then
            tablewarn = 1
        elseif x < xi[2] and xi[2] > xi[3] and x < (xi[2]+xi[3])/2 then
            tablewarn = 1
        elseif x > xi[2] and xi[2] < xi[3] and x > (xi[2]+xi[3])/2 then
            tablewarn = 1
        else
            tablewarn = 0
        end
    end

    -- 5 tabular values, checks if x is closer to center then the ends
    if #xi == 5 and #yi == 5 and x ~= nil and chklinans == 0 then
        if x < xi[3] and xi[3] > xi[2] and x < (xi[3]+xi[2])/2 then
            tablewarn = 1
        elseif x > xi[3] and xi[3] < xi[2] and x > (xi[3]+xi[2])/2 then
            tablewarn = 1
        elseif x < xi[3] and xi[3] > xi[4] and x < (xi[3]+xi[4])/2 then
            tablewarn = 1
        elseif x > xi[3] and xi[3] < xi[4] and x > (xi[3]+xi[4])/2 then
            tablewarn = 1
        else
            tablewarn = 0
        end
    end

    -- 3 tabular, sends command to math engine
    if #xi == 3 and #yi == 3 and intcheck == 0 and dup == 0 and chklinans == 0 and xsort == 0 then
        math.eval("delvar x")
        local printeq = math.evalStr("tabular3function:=tabular3(x,xi,yi,0)") -- Calculates graph
        ioidtable[3]:setText("\\0el {"..printeq.."}") -- Prints equation
        if type(x) == "number" then
            local printy = math.eval("tabular3("..x..",xi,yi,1)") -- Calculates y
            if tonumber(printy) == nil then
                printy = "Error in math engine"
            else -- Displays answer
                var.store("xplot",x)
                var.store("yplot",printy)
                ioidtable[2]:setText(printy)
                if tablewarn == 1 then
                    ioidtable[3]:setText("Note: Consider range where x is closer to center point.")
                end
            end
        else
            ioidtable[3]:setText("x must be a number")
        end
    end

    -- 5 tabular, sends command to math engine
    if #xi == 5 and #yi == 5 and intcheck == 0 and dup == 0 and chklinans == 0 and xsort == 0 then
        math.eval("delvar x")
        local printeq = math.evalStr("tabular5function:=tabular5(x,xi,yi,0)") -- Calculates graph
        ioidtable[3]:setText("\\0el {"..printeq.."}") -- Prints equation
        if type(x) == "number" then
            local printy = math.eval("tabular5("..x..",xi,yi,1)") -- Calculates y
            if tonumber(printy) == nil then
                printy = "Error in math engine"
            else -- Displays answer
                var.store("xplot",x)
                var.store("yplot",printy)
                ioidtable[2]:setText(printy)
                if tablewarn == 1 then
                    ioidtable[3]:setText("Note: Consider range where x is closer to center point.")
                end
            end
        else
            ioidtable[3]:setText("Aw, Snap! Something is wrong.")
        end
    end

end

function calcspline()

    local xi = var.recall("xi") -- Stores xi table from Nspire in Lua
    local yi = var.recall("yi")-- Stores yi table from Nspire in Lua
    local x = ioexptable[1] -- Fetches x
    local dup = 0 -- Initial value for checking unique xi values
    local xiyicheck = 0 -- Initial value to verify tables in spreadsheet are OK.
    local xrange = nil -- Initial value to verify x value is within xi table range
    local xsort = 0 -- Initial value for checking if xi table is ascending

    -- Verifies xi and yi contain valid numbers
    if xi == nil or yi == nil then
        ioidtable[2]:setText("- - -")
        ioidtable[3]:setText("Aw, Snap! Something is wrong.")
        xiyicheck = 1
    elseif #xi < 3 or #yi < 3 then
        ioidtable[2]:setText("- - -")
        ioidtable[3]:setText("Table is to short")
        xiyicheck = 1
    else

        -- Verifies xi table is sorted in ascending order
        for i = 1, #xi-1 do
            if xi[i+1] < xi[i] then
                xsort = 1
            end
        end

         -- Sorts xi table in ascending order
        table.sort(xi)

        -- Verifies unique xi values
        for i = 1, #xi-1 do
            if xi[i] == xi[i+1] then
                dup = dup+1
            end
        end

        -- Checks if x is a valid number within xi table range
        if type(x) == "number" then
            if x >= xi[1] and x <= xi[#xi] then
                xrange = 0 -- x is inside xi table range
            else
                xrange = 1 -- x is outside xi table range
            end
        else
            xrange = nil -- x is not a number
        end

        if xsort ~= 0 then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("xi's must be sorted in ascending order")
        end

        if dup ~= 0 then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("xi's must be unique")
        end

        if xrange == 1 then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("x is out of range")
        elseif xrange == nil then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("x is unknown")
        end

    end

    -- Calculates equation
    if dup == 0 and xiyicheck == 0 and xrange == 0 and xsort == 0 then
        math.eval("delvar x")
        local printeq = math.evalStr("splinefunction:=spline(x,xi,yi,0)") -- Calculates graph
        ioidtable[3]:setText("\\0el {"..printeq.."}") -- Prints equation
        if type(ioexptable[1]) == "number" then
            local printy = math.eval("spline("..x..",xi,yi,1)")
            if tonumber(printy) == nil then
                printy = "Error in CAS math engine"
            end
            var.store("xplot",ioexptable[1])
            var.store("yplot",printy)
            ioidtable[2]:setText(printy) -- Print answer y
        else
            ioidtable[3]:setText("x must be a number")
        end

    end
end

function calclinear()

    local xi = var.recall("xi") -- Stores xi table from Nspire in Lua
    local yi = var.recall("yi")-- Stores yi table from Nspire in Lua
    local x = ioexptable[1] -- Fetches x
    local dup = 0 -- Initial value for checking unique xi values
    local xiyicheck = 0 -- Initial value to verify tables in spreadsheet are OK.
    local xrange = nil -- Initial value to verify x value is within xi table range

    -- Verifies xi and yi contain valid numbers
    if xi == nil or yi == nil then
        ioidtable[2]:setText("- - -")
        ioidtable[3]:setText("Aw, Snap! Something is wrong.")
        xiyicheck = 1
    elseif #xi < 3 or #yi < 3 then
        ioidtable[2]:setText("- - -")
        ioidtable[3]:setText("Table is to short")
        xiyicheck = 1
    else

        -- Sorts xi table in ascending order
        table.sort(xi)

        -- Verifies unique xi values
        for i = 1, #xi-1 do
            if xi[i] == xi[i+1] then
                dup = dup+1
            end
        end

        -- Checks if x is a valid number within xi table range
        if type(x) == "number" then
            if x >= xi[1] and x <= xi[#xi] then
                xrange = 0 -- x is inside xi table range
            else
                xrange = 1 -- x is outside xi table range
            end
        else
            xrange = nil -- x is not a number
        end

        if dup ~= 0 then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("xi's must be unique")
        end

        if xrange == 1 then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("x is out of range")
        elseif xrange == nil then
            ioidtable[2]:setText("- - -")
            ioidtable[3]:setText("x is unknown")
        end

    end

    -- Calculates equation
    if dup == 0 and xiyicheck == 0 and xrange == 0 then
        math.eval("delvar x")
        local printeq = math.evalStr("linearfunction:=linear(x,xi,yi,0)") -- Calculates graph
        ioidtable[3]:setText("\\0el {"..printeq.."}") -- Prints equation
        if type(ioexptable[1]) == "number" then
            local printy = math.eval("linear("..x..",xi,yi,1)")
            if tonumber(printy) == nil then
                printy = "Error in CAS math engine"
            end
            var.store("xplot",ioexptable[1])
            var.store("yplot",printy)
            ioidtable[2]:setText(printy) -- Print answer y
        else
            ioidtable[3]:setText("x must be a number")
        end
    end

end

function reset()

    for i = 1,3 do
        ioidtable[i]:setText("")
        ioidtable[i]:setBorderColor(brdcolorinact)
        ioexptable[i] = nil
    end
    var.store("lagrangefunction",0)
    var.store("tabular3function",0)
    var.store("tabular5function",0)
    var.store("splinefunction",0)
    var.store("linearfunction",0)
    var.store("xi",{})
    var.store("yi",{})
    var.store("xplot",0)
    var.store("yplot",0)
    ioidtable[1]:setBorderColor(brdcoloract)
    ioidtable[1]:setFocus() -- Focus is set in box x

end