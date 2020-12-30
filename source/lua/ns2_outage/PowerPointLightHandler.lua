do
    local enabled = true
    --[[
 * Converts an RGB color value to HSL. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
 * Assumes r, g, and b are contained in the set [0, 1] and
 * returns h, s, and l in the set [0, 1].
 *
 * @param   Number  r       The red color value
 * @param   Number  g       The green color value
 * @param   Number  b       The blue color value
 * @param   Number  a       The alpha value
 * @return  Array           The HSL representation
]]
    local function rgbToHsl(r, g, b, a)
        local max, min = math.max(r, g, b), math.min(r, g, b)
        local h, s, l
        
        l = (max + min) / 2
        
        if max == min then
            h, s = 0, 0 -- achromatic
        else
            local d = max - min
            if l > 0.5 then s = d / (2 - max - min) else s = d / (max + min) end
            if max == r then
                h = (g - b) / d
                if g < b then h = h + 6 end
            elseif max == g then h = (b - r) / d + 2
            elseif max == b then h = (r - g) / d + 4
            end
            h = h / 6
        end
        
        return h, s, l, a
    end
    
    local function hue2rgb(p, q, t)
        if t < 0   then t = t + 1 end
        if t > 1   then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
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
    function hslToRgb(h, s, l, a)
        local r, g, b
        
        if s == 0 then
            r, g, b = l, l, l -- achromatic
        else
            
            local q
            if l < 0.5 then q = l * (1 + s) else q = l + s - l * s end
            local p = 2 * l - q
            
            r = hue2rgb(p, q, h + 1/3)
            g = hue2rgb(p, q, h)
            b = hue2rgb(p, q, h - 1/3)
        end
        
        return r, g, b, a
    end
    
    local function clampColor( color1, color2)
        
        --local h2,s2,l2,a2 = rgbToHsl(color2.r,color2.g,color2.b,color2.a)
        --local h1,s1,l1,a1 = rgbToHsl(color1.r,color1.g,color1.b,color1.a)
        --local r,g,b,a = hslToRgb(h1, s1, l1 * l2, a2)
        
        return Color(Clamp(color1.r, 0, color2.r), Clamp(color1.g, 0, color2.g), Clamp(color1.b, 0, color2.b), Clamp(color1.a, 0, color2.a))
    end
    -- set the intensity and color for a light. If the renderlight is ambient, we set the color
    -- the same in all directions
    local function SetLight(renderLight, intensity, color)
        
        PROFILE("PowerPointLightHandler:SetLight")
        
        if intensity then
            if enabled then
                renderLight:SetIntensity(Clamp(intensity, 0, renderLight.originalIntensity))
            else
                renderLight:SetIntensity(intensity)
            end
        end
        
        if color then
    
            if enabled then
                renderLight:SetColor(clampColor(color, renderLight.originalColor))
        
                if renderLight:GetType() == RenderLight.Type_AmbientVolume then
            
                    renderLight:SetDirectionalColor(RenderLight.Direction_Right,    clampColor(color, renderLight.originalRight))
                    renderLight:SetDirectionalColor(RenderLight.Direction_Left,     clampColor(color, renderLight.originalLeft))
                    renderLight:SetDirectionalColor(RenderLight.Direction_Up,       clampColor(color, renderLight.originalUp))
                    renderLight:SetDirectionalColor(RenderLight.Direction_Down,     clampColor(color, renderLight.originalDown))
                    renderLight:SetDirectionalColor(RenderLight.Direction_Forward,  clampColor(color, renderLight.originalForward))
                    renderLight:SetDirectionalColor(RenderLight.Direction_Backward, clampColor(color, renderLight.originalBackward))
        
                end
                
            else
                renderLight:SetColor(color)
    
                if renderLight:GetType() == RenderLight.Type_AmbientVolume then
        
                    renderLight:SetDirectionalColor(RenderLight.Direction_Right,    color)
                    renderLight:SetDirectionalColor(RenderLight.Direction_Left,     color)
                    renderLight:SetDirectionalColor(RenderLight.Direction_Up,       color)
                    renderLight:SetDirectionalColor(RenderLight.Direction_Down,     color)
                    renderLight:SetDirectionalColor(RenderLight.Direction_Forward,  color)
                    renderLight:SetDirectionalColor(RenderLight.Direction_Backward, color)
    
                end
            end
        
        end
    
    end
    
    debug.setupvaluex (NormalLightWorker.Run, "SetLight", SetLight, true)
    debug.setupvaluex (DamagedLightWorker.Run, "SetLight", SetLight, true)
    debug.setupvaluex (LowPowerLightWorker.Run, "SetLight", SetLight, true)
    debug.setupvaluex (NoPowerLightWorker.Run, "SetLight", SetLight, true)
    debug.setupvaluex (LightGroup.RunCycle, "SetLight", SetLight, true)
    
    
    --if Server then
        Event.Hook("Console_outage_mod", function(arg1, arg)
            enabled = not enabled
            if enabled then
                Print("Outage enabled")
            else
                Print("Outage disabled")
            end
        end)
   -- end

end