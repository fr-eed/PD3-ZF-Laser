-- The mod's section in Settings > Interface: a group title, toggle rows,
-- slider rows and a reset row built from the game's own settings widgets,
-- appended to the screen's list whenever that screen gains focus.
-- The rows are from ui/menu_rows.lua.
--
-- Rows the screen did not create itself get hover and focus but their inner
-- buttons never receive clicks, and their native setters are no-ops.
-- So clicks are handled here, a left-click keybind acting on whichever of our
-- rows is hovered, and values are written straight into the row's fields
-- followed by its own redraw functions. Slider knobs do report drags through
-- the row's value event, which is hooked.
local Game = require("engine.game")
local Color = require("core.color")
local Rows = require("ui.menu_rows")
local Version = require("version")

local Menu = {}

local Path = "/Game/UI/Widgets/Menus/Settings/"
local ScreenClass = Path .. "WBP_Settings_Screen_Category.WBP_Settings_Screen_Category_C"
local SliderClass = Path .. "WBP_Settings_SliderButton.WBP_Settings_SliderButton_C"
local SliderMoved = SliderClass .. ":BndEvt__WBP_Settings_SliderButton_Slider_Value_K2Node_ComponentBoundEvent_0_OnFloatValueChangedEvent__DelegateSignature"
local InterfaceScreen = "Widget_Settings_UserInterface"
local Category = "ZFLaser"   -- not a game category, so its own lookups find nothing

local Config = nil
local OnChanged = nil
local Populated = {}   -- screen address -> true once our rows are added
local Widgets = {}     -- { Widget, Row, Kind } for every row we created
local Hooked = false

-- The first existing row of a class, whose slot padding ours copy.
local function TemplateRow(Box, ClassName)
    for Index = 0, Box:GetChildrenCount() - 1 do
        local Child = Box:GetChildAt(Index)
        if Child:GetClass():GetFName():ToString() == ClassName then return Child end
    end
    return nil
end

-- Calls one of the row's Blueprint redraw functions, with the value if the
-- function wants an argument.
local function Redraw(Widget, Name, Value)
    if pcall(function() Widget[Name](Widget) end) then return end
    local Ok, Err = pcall(function() Widget[Name](Widget, Value) end)
    if not Ok then Game.Log("%s failed: %s", Name, tostring(Err)) end
end

local function Refresh(Widget)
    pcall(function() Widget:RefreshVisuals() end)
end

local function ShowToggle(Widget, Row)
    Widget.bToggleValue = Row.Get(Config)
    Redraw(Widget, "ToggleValueVisuals", Row.Get(Config))
    Refresh(Widget)
end

local function ShowSliderValue(Widget, Value)
    Widget.SliderValue = Value
    Redraw(Widget, "UpdateSliderValue", Value)
end

-- Rows marked Tint get a swatch under them: a dot glyph in the row's color.
-- The game's slider repaints itself on hover, so its own colors are left alone.
local Swatches = {}   -- row name -> text block
local function ShowSwatch(Row)
    local Swatch = Swatches[Row.Name]
    if not Row.Tint or not Swatch or not Swatch:IsValid() then return end
    pcall(function()
        local C = Color.FromHue(Row.Get(Config))
        Swatch:SetColorAndOpacity({ SpecifiedColor = { R = C.R, G = C.G, B = C.B, A = 1.0 }, ColorUseRule = 0 })
    end)
end

-- A dot glyph on its own line under the row.
local function AddSwatch(Screen, Box, Row)
    local Swatch = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), Screen.WidgetTree, FName(Row.Name .. "_Swatch"))
    Swatch:SetText(FText("●"))
    Box:AddChild(Swatch)
    Swatches[Row.Name] = Swatch
    ShowSwatch(Row)
end

local function ShowSlider(Widget, Row)
    Widget.SliderMinValue = Row.Min
    Widget.SliderMaxValue = Row.Max
    Widget.SliderIncrementValue = Row.Step
    Redraw(Widget, "UpdateMinSliderValue", Row.Min)
    Redraw(Widget, "UpdateMaxSliderValue", Row.Max)
    Redraw(Widget, "UpdateSliderStepSize", Row.Step)
    ShowSliderValue(Widget, Row.Get(Config))
    ShowSwatch(Row)
end

local function NewRow(Screen, Box, Class, Row, Template, Kind)
    local Library = Game.Default("/Script/UMG.Default__WidgetBlueprintLibrary")
    local Widget = Library:Create(Screen, Class, Screen:GetOwningPlayer())
    Widget:SetSettingCategoryName(FName(Category))
    Widget:SetSettingName(FName(Row.Name))
    Widget:SetSettingNameLocalized(FText(Row.Label))
    Widget:SetCanResetSetting(false)
    Box:AddChild(Widget)
    if Template then Widget.Slot:SetPadding(Template.Slot.Padding) end
    table.insert(Widgets, { Widget = Widget, Row = Row, Kind = Kind })
    return Widget
end

local function AddTitle(Screen, Box)
    local Title = StaticConstructObject(Screen.SettingsGroupTitleClass, Screen.WidgetTree, FName("ZFLaser_Title"))
    Title:SetText(FText("ZF-LASER v" .. Version))
    Box:AddChild(Title)
end

local function AddToggle(Screen, Box, Row, Template)
    local Widget = NewRow(Screen, Box, Screen.SettingsButtonClassTwoChoice, Row, Template, "toggle")
    -- The row highlights option one for true, as the game's own ON/OFF rows do.
    Widget:SetOptionOneName(FText("ON"))
    Widget:SetOptionTwoName(FText("OFF"))
    ShowToggle(Widget, Row)
end

local function AddSlider(Screen, Box, Row, Template)
    local Widget = NewRow(Screen, Box, Screen.SettingsButtonClassSlider, Row, Template, "slider")
    if Row.Tint then AddSwatch(Screen, Box, Row) end
    ShowSlider(Widget, Row)
end

local function AddReset(Screen, Box, Template)
    local Widget = NewRow(Screen, Box, Screen.SettingsButtonClassActionClick, Rows.Reset, Template, "reset")
    Widget:SetActionButtonLabelLocalized(FText("RESET"))
    Refresh(Widget)
end

-- Appends the section to the Interface screen, once per screen instance.
local function Populate(Screen)
    if Screen:GetFName():ToString() ~= InterfaceScreen then return end
    if Populated[Screen:GetAddress()] then return end
    local Box = Screen.ScrollBox_SettingsItems
    if not Box or not Box:IsValid() then return end
    Populated[Screen:GetAddress()] = true
    local ToggleTemplate = TemplateRow(Box, "WBP_Settings_TwoChoiceButton_C")
    local SliderTemplate = TemplateRow(Box, "WBP_Settings_SliderButton_C")
    AddTitle(Screen, Box)
    for _, Row in ipairs(Rows.Toggles) do AddToggle(Screen, Box, Row, ToggleTemplate) end
    for _, Row in ipairs(Rows.Sliders) do AddSlider(Screen, Box, Row, SliderTemplate) end
    AddReset(Screen, Box, ToggleTemplate)
    Game.Log("settings section added")
end

local function Store(Row, Value)
    if Row.Get(Config) == Value then return end
    Row.Set(Config, Value)
    Config.Save()
    Game.Log("%s: %s", Row.Label, tostring(Value))
    if OnChanged then OnChanged() end
end

-- Every row we created shows the config's current values again.
local function ShowAll()
    for _, Entry in ipairs(Widgets) do
        if Entry.Widget:IsValid() then
            if Entry.Kind == "toggle" then ShowToggle(Entry.Widget, Entry.Row) end
            if Entry.Kind == "slider" then ShowSlider(Entry.Widget, Entry.Row) end
        end
    end
end

-- Left click: whichever of our rows is under the mouse acts.
local function Clicked()
    for _, Entry in ipairs(Widgets) do
        local Widget = Entry.Widget
        if Widget:IsValid() and Widget:IsHovered() then
            if Entry.Kind == "toggle" then
                Store(Entry.Row, not Entry.Row.Get(Config))
                ShowToggle(Widget, Entry.Row)
            elseif Entry.Kind == "reset" then
                Config.Reset()
                ShowAll()
                Game.Log("laser defaults restored")
                if OnChanged then OnChanged() end
            end
            return
        end
    end
end

-- A slider row's knob moved; the value is snapped to the row's step.
local function SliderChanged(Widget, Value)
    for _, Entry in ipairs(Widgets) do
        if Entry.Kind == "slider" and Entry.Widget:GetAddress() == Widget:GetAddress() then
            local Row = Entry.Row
            local Snapped = math.floor(Value / Row.Step + 0.5) * Row.Step
            if Widget.SliderValue ~= Snapped then ShowSliderValue(Widget, Snapped) end
            Store(Row, Snapped)
            ShowSwatch(Row)
            return
        end
    end
end

-- Hook callbacks get the widget and the event's first parameter, unwrapped.
local function Guarded(Body)
    return function(Context, Param)
        local Ok, Err = pcall(function()
            Body(Context:get(), Param and Param:get())
        end)
        if not Ok then Game.Log("menu error: %s", tostring(Err)) end
    end
end

-- The widget classes only exist once the settings menu has been opened, so
-- hooking waits for the first settings screen to be created.
local function Hook()
    if Hooked then return end
    if not StaticFindObject(ScreenClass) or not StaticFindObject(SliderClass) then return end
    RegisterHook(ScreenClass .. ":OnGainedStackFocused", Guarded(Populate))
    RegisterHook(SliderMoved, Guarded(SliderChanged))
    Hooked = true
    Game.Log("settings hooks installed")
end

-- Changed is called after a value was changed from the menu.
function Menu.Install(InConfig, Changed)
    Config = InConfig
    OnChanged = Changed
    NotifyOnNewObject("/Script/Starbreeze.SBZSettingsCategoryScreen", function()
        Game.OnGameThread(Hook)
    end)
    RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, {}, function()
        if #Widgets == 0 then return end
        Game.OnGameThread(Clicked)
    end)
end

return Menu
