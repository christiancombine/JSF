-- originally by alurion, edited by project syn team 
-- Optimized by joyjak.st on discord
-- NOT THE ALURION VERSION!

task.spawn(function()

    
    local header = "--[[ joyjak's ServerScript Finder (YSS Fork) Join For more https://discord.gg/MDKjs7gRVN ]]"
    
    local allowed_roots = {
        server_storage = true,
        server_script_service = true,
    }
    
    local debug_mode = _G.Debug == true
    
    local function dbg_log(...)
        if debug_mode then
            print("[JSF DEBUG]:", ...)
        end
    end
    

    local function is_folder(name)
        return name:sub(-1):lower() == "s"
    end
    
    local function detect_script_type(source)
        if source:find("return%s+") then
            return "ModuleScript"
        end
        return "Script"
    end
    
    local function extract_function(source, func_name)
        local pattern = "function%s+" .. func_name .. "%s*%b()%s*(.-)\nend"
        local body = string.match(source, pattern)
    
        if body then
            return "function " .. func_name .. "()\n" .. body .. "\nend"
        end
    
        local pattern2 = func_name .. "%s*=%s*function%s*%b()%s*(.-)\nend"
        local body2 = string.match(source, pattern2)
    
        if body2 then
            return "function " .. func_name .. "()\n" .. body2 .. "\nend"
        end
    
        return nil
    end
    
    local function get_instance_type(name, index, total_parts, source_code)
        local is_last = (index == total_parts)
    
        if is_folder(name) then
            return "Folder"
        end
    
        if is_last then
            return detect_script_type(source_code)
        end
    
        return "Folder"
    end
    
    local function create_gui()
        local screen_gui = Instance.new("ScreenGui")
        screen_gui.Name = "YSS_Debug_Reconstruct"
        screen_gui.ResetOnSpawn = false
        screen_gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 600, 0, 400)
        frame.Visible = false
        frame.Position = UDim2.new(0.5, -300, 0.5, -200)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.Parent = screen_gui
    
        local scrolling = Instance.new("ScrollingFrame")
        scrolling.Size = UDim2.new(1, -10, 1, -10)
        scrolling.Position = UDim2.new(0, 5, 0, 5)
        scrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrolling.Parent = frame
    
        return scrolling
    end
    
    local log_container = create_gui()
    
    local function gui_log(text)
        print("[JSF 1]: " .. text)
    
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = text
        label.Parent = log_container
    
        label.Position = UDim2.new(0, 0, 0, #log_container:GetChildren() * 20)
        log_container.CanvasSize = UDim2.new(0, 0, 0, #log_container:GetChildren() * 20)
    end
    
    local function recreate_path(path_string, source_name, source_code, raw_path)
        local parts = string.split(path_string, ".")
        if #parts < 2 then return false end
    
        local root_name = parts[1]
        if not allowed_roots[root_name] then return false end
    
        local root = game:FindFirstChild(root_name == "server_storage" and "ServerStorage" or "ServerScriptService")
        if not root then return false end
    
        local current = root
        local created = {}
    
        for i = 2, #parts do
            local name = parts[i]
            local instance_type = get_instance_type(name, i, #parts, source_code)
    
            local existing = current:FindFirstChild(name)
    
            if not existing then
                local new_inst = Instance.new(instance_type)
                new_inst.Name = name
    
                if instance_type == "ModuleScript" then
                    local func_name = parts[#parts]
                    local extracted = extract_function(source_code, func_name)
    
                    if extracted then
                        new_inst.Source =
                            header .. "\n\nlocal module = {}\n\n" ..
                            extracted .. "\n\nreturn module"
                    else
                        new_inst.Source =
                            header .. "\n\nlocal module = {}\n\n-- fallback\n" ..
                            source_code .. "\n\nreturn module"
                    end
    
                elseif instance_type == "Script" then
                    new_inst.Source =
                        header .. "\n\n-- reconstructed script\n" ..
                        source_code
                end
    
                new_inst.Parent = current
                table.insert(created, new_inst.Name .. " [" .. instance_type .. "]")
                current = new_inst
            else
                current = existing
            end
        end
    
        if #created > 0 then
            gui_log("Created: " .. table.concat(created, " → "))
            gui_log("   ↳ From: " .. source_name)
        end
    
        return true
    end
    
    local function scan_source(source, source_name)
        local service_variables = {}
    
        for var_name in string.gmatch(source, 'local%s+([%w_]+)%s*=%s*game:GetService%("([%w_]+)"%)') do
            if source:find('ServerStorage') then
                service_variables[var_name] = "server_storage"
            elseif source:find('ServerScriptService') then
                service_variables[var_name] = "server_script_service"
            end
        end
    
        for var_name, service_name in pairs(service_variables) do
            for path in string.gmatch(source, var_name .. "%.([%w_%.]+)") do
                recreate_path(service_name .. "." .. path, source_name, source, path)
            end
        end
    
        for path in string.gmatch(source, "ServerStorage%.([%w_%.]+)") do
            recreate_path("server_storage." .. path, source_name, source, path)
        end
    
        for path in string.gmatch(source, "ServerScriptService%.([%w_%.]+)") do
            recreate_path("server_script_service." .. path, source_name, source, path)
        end
    end
    
    gui_log("JSF Reconstruction Scan Starting...")
    
    local function scan_container(container)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                local success, result = pcall(function()
                    return decompile(obj)
                end)
                print("[JSF] Trying Remote Name" obj)
                task.wait(0.15)
    
                if success and type(result) == "string" then
                    scan_source(result, obj:GetFullName())
                end
            end
        end
    end
    
    local replicated = game:FindFirstChild("ReplicatedStorage")
    if replicated then
        scan_container(replicated)
    end
    
    for _, obj in ipairs(game:GetChildren()) do
        if obj.Name ~= "ReplicatedStorage" then
            scan_container(obj)
        end
    end
    
    gui_log("Reconstruction Scan Complete √.")

end)
