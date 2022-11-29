local clampColor
do
    local rgbToHsl, hslToRgb
    do
        local half = 1/2
        local third = 1/3
        local onesixth = 1/6
        local twothird = 2/3

        --[[
        * Converts an RGB color value to HSL. Conversion formula
        * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
        * Assumes r, g, and b are contained in the set [0, 1] and
        * returns h, s, and l in the set [0, 1].
        *
        * @param   Number  r       The red color value
        * @param   Number  g       The green color value
        * @param   Number  b       The blue color value
        * @return  Array           The HSL representation
        ]]
        rgbToHsl = function(r, g, b)
            local max, min = math.max(r, g, b), math.min(r, g, b)
            local h, s, l

            l = (max + min) / 2

            if max == min then
                h, s = 0, 0 -- achromatic
            else
                local d = max - min
                if l > 0.5 then
                    s = d / (2 - max - min)
                else
                    s = d / (max + min)
                end
                if max == r then
                    h = (g - b) / d
                    if g < b then
                        h = h + 6
                    end
                elseif max == g then
                    h = (b - r) / d + 2
                elseif max == b then
                    h = (r - g) / d + 4
                end
                h = h / 6
            end

            return h, s, l
        end

        local function hue2rgb(p, q, t)
            if t < 0 then
                t = t + 1
            end
            if t > 1 then
                t = t - 1
            end
            if t < onesixth then
                return p + (q - p) * 6 * t
            end
            if t < half then
                return q
            end
            if t < twothird then
                return p + (q - p) * (twothird - t) * 6
            end
            return p
        end

        --[[
         * Converts an HSL color value to RGB. Conversion formula
         * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
         * Assumes h, s, and l are contained in the set [0, 1] and
         * returns r, g, and b in the set [0, 1].
         *
         * @param   Number  h       The hue value
         * @param   Number  s       The saturation value
         * @param   Number  l       The lightness value
         * @param   Number  a       The alpha value
         * @return  Array           The RGB representation
        ]]
        hslToRgb = function(h, s, l)
            local r, g, b

            if s == 0 then
                r, g, b = l, l, l -- achromatic
            else

                local q
                if l < 0.5 then
                    q = l * (1 + s)
                else
                    q = l + s - l * s
                end
                local p = 2 * l - q

                r = hue2rgb(p, q, h + third)
                g = hue2rgb(p, q, h)
                b = hue2rgb(p, q, h - third)
            end

            return r, g, b
        end
    end

    do
        local colorCache = {}
        setmetatable(colorCache, {__mode = "v"})  -- make values weak
        clampColor = function(newColor, originalColor)

            PROFILE("PowerPointLightHandler:SetLight-clampColor")

            local key = originalColor.r .. "-" .. originalColor.g .. "-" .. originalColor.b .. "-" .. newColor.r .. "-" .. newColor.g .. "-" .. newColor.b
            if not colorCache[key] then
                local oH, oS, oL = rgbToHsl(originalColor.r, originalColor.g, originalColor.b)
                local _, _, nL = rgbToHsl(newColor.r, newColor.g, newColor.b)
                local cR, cG, cB = hslToRgb(oH, oS, math.min(nL, oL, 0.1))
                colorCache[key] = Color(cR, cG, cB, newColor.a)
            end
            return colorCache[key]
        end
    end
end

--local enabled = true

--[[
Set the intensity and color for a light. If the renderlight is ambient, we set the color
the same in all directions
]]
local function SetLight(renderLight, intensity, color)

    PROFILE("PowerPointLightHandler:SetLight")

    if intensity then
        --if enabled then
            renderLight:SetIntensity(math.min(intensity, renderLight.originalIntensity))
        --else
        --    renderLight:SetIntensity(intensity)
        --end
    end
    if color then
        --if enabled then
            renderLight:SetColor(clampColor(color, renderLight.originalColor))
            if renderLight:GetType() == RenderLight.Type_AmbientVolume then
                renderLight:SetDirectionalColor(RenderLight.Direction_Right, clampColor(color, renderLight.originalRight))
                renderLight:SetDirectionalColor(RenderLight.Direction_Left, clampColor(color, renderLight.originalLeft))
                renderLight:SetDirectionalColor(RenderLight.Direction_Up, clampColor(color, renderLight.originalUp))
                renderLight:SetDirectionalColor(RenderLight.Direction_Down, clampColor(color, renderLight.originalDown))
                renderLight:SetDirectionalColor(RenderLight.Direction_Forward, clampColor(color, renderLight.originalForward))
                renderLight:SetDirectionalColor(RenderLight.Direction_Backward, clampColor(color, renderLight.originalBackward))
            end
        --else
        --    renderLight:SetColor(color)
        --    if renderLight:GetType() == RenderLight.Type_AmbientVolume then
        --        renderLight:SetDirectionalColor(RenderLight.Direction_Right, color)
        --        renderLight:SetDirectionalColor(RenderLight.Direction_Left, color)
        --        renderLight:SetDirectionalColor(RenderLight.Direction_Up, color)
        --        renderLight:SetDirectionalColor(RenderLight.Direction_Down, color)
        --        renderLight:SetDirectionalColor(RenderLight.Direction_Forward, color)
        --        renderLight:SetDirectionalColor(RenderLight.Direction_Backward, color)
        --    end
        --end
    end

end

debug.setupvaluex(NormalLightWorker.Run, "SetLight", SetLight, true)
debug.setupvaluex(DamagedLightWorker.Run, "SetLight", SetLight, true)
debug.setupvaluex(LowPowerLightWorker.Run, "SetLight", SetLight, true)
debug.setupvaluex(NoPowerLightWorker.Run, "SetLight", SetLight, true)
debug.setupvaluex(LightGroup.RunCycle, "SetLight", SetLight, true)

--Event.Hook("Console_outage_mod", function(arg1, arg)
--    enabled = not enabled
--    if enabled then
--        Print("Outage enabled")
--    else
--        Print("Outage disabled")
--    end
--end)

local kMinCommanderLightIntensityScalar = 0.3
local kOffTime = 12
local disabledColor = 0.2
function NoPowerLightWorker:Run()

    PROFILE("NoPowerLightWorker:Run")

    local timeOfChange = self.handler.powerPoint:GetTimeOfLightModeChange()
    local time = Shared.GetTime()
    local timePassed = time - timeOfChange

    local probeTint

    if self.activeProbes then
        if timePassed < kOffTime then
            probeTint = Color(0, 0, 0, 1)
        elseif timePassed < kOffTime + PowerPoint.kAuxPowerCycleTime then

            -- Fade red in smoothly. t will stay at zero during the individual delay time
            local t = timePassed - kOffTime
            -- angle goes from zero to 90 degres in one kAuxPowerCycleTime
            local angleRad = (t / PowerPoint.kAuxPowerCycleTime) * math.pi / 2
            -- and scalar goes 0->1
            local scalar = math.sin(angleRad)

            probeTint = Color(disabledColor * scalar,
                    disabledColor * scalar,
                    disabledColor * scalar,
                    1)
        else

            -- It's possible the player wasn't close enough to the room, and thus the probes never
            -- changed to the no power state.  Do one last update to ensure they're up-to-date.
            probeTint = Color(disabledColor,
                    disabledColor,
                    disabledColor, 1)

            self.activeProbes = false
        end
    end

    if probeTint then
        for _, probe in ipairs(self.handler.probeTable) do
            probe:SetTint( probeTint )
        end
    end

    self.handler:SetEmissiveModValue(0)

    for renderLight in self.activeLights:Iterate() do

        local randomValue = renderLight.randomValue
        -- aux light starting to come on
        local startAuxLightTime = kOffTime + randomValue * PowerPoint.kMaxAuxLightDelay
        -- ... fully on
        local fullAuxLightTime = startAuxLightTime + PowerPoint.kAuxPowerCycleTime

        local intensity
        local color

        local showCommanderLight = false

        local player = Client.GetLocalPlayer()
        if player and player:isa("Commander") then
            showCommanderLight = true
        end

        if timePassed < startAuxLightTime then

            if showCommanderLight then
                intensity = renderLight.originalIntensity * kMinCommanderLightIntensityScalar
            else
                intensity = 0
            end

        elseif timePassed < fullAuxLightTime then

            -- Fade red in smoothly. t will stay at zero during the individual delay time
            local t = timePassed - startAuxLightTime
            -- angle goes from zero to 90 degres in one kAuxPowerCycleTime
            local angleRad = (t / PowerPoint.kAuxPowerCycleTime) * math.pi / 2
            -- and scalar goes 0->1
            local scalar = math.sin(angleRad)

            if showCommanderLight then
                scalar = math.max(kMinCommanderLightIntensityScalar, scalar)
            end

            intensity = scalar * renderLight.originalIntensity

            intensity = intensity * self:CheckFlicker(renderLight, PowerPoint.kAuxFlickerChance, scalar)

            if showCommanderLight then
                color = PowerPoint.kDisabledCommanderColor
            else
                color = PowerPoint.kDisabledColor
            end

        else

            -- Deactivate from initial state
            self.activeLights:Remove(renderLight)

            -- in steady state, we shift lights between a constant state and a varying state.
            -- We assign each light to one of several groups, and then randomly start/stop cycling for each group.
            local lightGroupIndex = math.random(1, NoPowerLightWorker.kNumGroups)
            table.insert(self.lightGroups[lightGroupIndex].lights, renderLight)

        end

        SetLight(renderLight, intensity, color)

    end

    -- handle the light-cycling groups.
    for _, lightGroup in ipairs(self.lightGroups) do
        lightGroup:Run(timePassed)
    end

end