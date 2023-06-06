-- Author: alchemistis
-- Provides functionality for rendering in-game triggers.
-- Happy skip/glitch hunting.

-- Singletons
local interact_manager = sdk.get_managed_singleton("chainsaw.InteractManager")

-- "Constants"
local COLOR_RED = 0xff0000ff
local COLOR_WHITE = 0xffffffff

-- Config
local should_render_triggers = true
local is_debug_mode = false
local trigger_type_filter_map = {
    ["InteractTriggerAreaHit"] = true,
    ["InteractTriggerKey"] = false,
    ["InteractTriggerUseItem"] = false
}

-- Variables
local trigger_color = COLOR_RED

-- Debug
local debug_game_objects = {}
local contact_count = 0
local current_trigger_shape = ""
local quat_string = ""

-- Trigger definitions
local previously_hit_triggers = {}

local Trigger = {}
Trigger.__index = Trigger

function Trigger.new(name, obb, type)
    local self = setmetatable({}, Trigger)
    self.name = name
    self.obb = obb
    self.type = type
    self.draw = true
    return self
end

function Trigger:equals(other)
    return self.name == other.name and self.obb == other.obb
end

-- Helper functions
local function entry_exists(table, entry)
    for _, e in ipairs(table) do
        if e:equals(entry) then
            return true
        end
    end
    return false
end

local function clear_table(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function get_component(game_object, type_name)
    local t = sdk.typeof(type_name)

    if t == nil then 
        return nil
    end

    return game_object:call("getComponent(System.Type)", t)
end

local function get_components(game_object)
    local transform = game_object:call("get_Transform")

    if not transform then
        return {}
    end

    return game_object:call("get_Components"):get_elements()
end

local function draw_wireframe_box(lower_corner_pos, upper_corner_pos, color)
    if lower_corner_pos ~= nil and upper_corner_pos ~= nil then
        local lower = lower_corner_pos
        local upper = upper_corner_pos

        local front_face_vertex1 = draw.world_to_screen(Vector3f.new(lower.x, lower.y, lower.z))
        local front_face_vertex2 = draw.world_to_screen(Vector3f.new(lower.x, upper.y, lower.z))
        local front_face_vertex3 = draw.world_to_screen(Vector3f.new(upper.x, upper.y, lower.z))
        local front_face_vertex4 = draw.world_to_screen(Vector3f.new(upper.x, lower.y, lower.z))

        local back_face_vertex1 = draw.world_to_screen(Vector3f.new(lower.x, lower.y, upper.z))
        local back_face_vertex2 = draw.world_to_screen(Vector3f.new(lower.x, upper.y, upper.z))
        local back_face_vertex3 = draw.world_to_screen(Vector3f.new(upper.x, upper.y, upper.z))
        local back_face_vertex4 = draw.world_to_screen(Vector3f.new(upper.x, lower.y, upper.z))

        -- Front face
        if front_face_vertex1 ~= nil and front_face_vertex2 ~= nil then
            draw.line(front_face_vertex1.x, front_face_vertex1.y, front_face_vertex2.x, front_face_vertex2.y, color)
        end
        if front_face_vertex2 ~= nil and front_face_vertex3 ~= nil then
            draw.line(front_face_vertex2.x, front_face_vertex2.y, front_face_vertex3.x, front_face_vertex3.y, color)
        end
        if front_face_vertex3 ~= nil and front_face_vertex4 ~= nil then
            draw.line(front_face_vertex3.x, front_face_vertex3.y, front_face_vertex4.x, front_face_vertex4.y, color)
        end
        if front_face_vertex4 ~= nil and front_face_vertex1 ~= nil then
            draw.line(front_face_vertex4.x, front_face_vertex4.y, front_face_vertex1.x, front_face_vertex1.y, color)
        end

        -- Back face
        if back_face_vertex1 ~= nil and back_face_vertex2 ~= nil then
            draw.line(back_face_vertex1.x, back_face_vertex1.y, back_face_vertex2.x, back_face_vertex2.y, color)
        end
        if back_face_vertex2 ~= nil and back_face_vertex3 ~= nil then
            draw.line(back_face_vertex2.x, back_face_vertex2.y, back_face_vertex3.x, back_face_vertex3.y, color)
        end
        if back_face_vertex3 ~= nil and back_face_vertex4 ~= nil then
            draw.line(back_face_vertex3.x, back_face_vertex3.y, back_face_vertex4.x, back_face_vertex4.y, color)
        end
        if back_face_vertex4 ~= nil and back_face_vertex1 ~= nil then
            draw.line(back_face_vertex4.x, back_face_vertex4.y, back_face_vertex1.x, back_face_vertex1.y, color)
        end

        -- Connecting lines
        if front_face_vertex1 ~= nil and back_face_vertex1 ~= nil then
            draw.line(front_face_vertex1.x, front_face_vertex1.y, back_face_vertex1.x, back_face_vertex1.y, color)
        end
        if front_face_vertex2 ~= nil and back_face_vertex2 ~= nil then
            draw.line(front_face_vertex2.x, front_face_vertex2.y, back_face_vertex2.x, back_face_vertex2.y, color)
        end
        if front_face_vertex3 ~= nil and back_face_vertex3 ~= nil then
            draw.line(front_face_vertex3.x, front_face_vertex3.y, back_face_vertex3.x, back_face_vertex3.y, color)
        end
        if front_face_vertex4 ~= nil and back_face_vertex4 ~= nil then
            draw.line(front_face_vertex4.x, front_face_vertex4.y, back_face_vertex4.x, back_face_vertex4.y, color)
        end
    end
end

function euler_to_quat(pitch, yaw, roll)
    -- First, convert pitch, yaw, and roll to radians.
    -- pitch = pitch * (pi / 180)
    -- yaw = yaw * (pi / 180)
    -- roll = roll * (pi / 180)

    -- Pre-calculate sine and cosine of half angles
    local cp = math.cos(pitch * 0.5)
    local sp = math.sin(pitch * 0.5)
    local cy = math.cos(yaw * 0.5)
    local sy = math.sin(yaw * 0.5)
    local cr = math.cos(roll * 0.5)
    local sr = math.sin(roll * 0.5)

    -- Create the quaternion
    local w = cp * cy * cr + sp * sy * sr
    local x = sp * cy * cr - cp * sy * sr
    local y = cp * sy * cr + sp * cy * sr
    local z = cp * cy * sr - sp * sy * cr

    return Quaternion:new(w, x, y, z)
end

local function render_trigger(trigger, color)
    if trigger.obb == nil then
        return
    end

    local pos = trigger.obb:call("get_Position")
    local extent = trigger.obb:call("get_Extent")
    local rotation = trigger.obb:call("get_RotateAngle")

    rotation = euler_to_quat(rotation.x, rotation.y, rotation.z)

    quat_string = type(rotation) .. " x = " .. rotation.x .. " y = " .. rotation.y .. " z = " .. rotation.z .. " w = " .. rotation.w

    local name_label = "TRIGGER (" .. trigger.name .. ")"
    
    local name_label_pos = draw.world_to_screen(pos)
    local name_label_bounds = imgui.calc_text_size(name_label)

    if (name_label_pos ~= nil) then
        draw.text(name_label, name_label_pos.x - (name_label_bounds.x / 2), name_label_pos.y, COLOR_WHITE)
    end

    local corner_offsets = {
        Vector3f.new(-extent.x, -extent.y, -extent.z),
        Vector3f.new(extent.x, -extent.y, -extent.z),
        Vector3f.new(-extent.x, extent.y, -extent.z),
        Vector3f.new(extent.x, extent.y, -extent.z),
        Vector3f.new(-extent.x, -extent.y, extent.z),
        Vector3f.new(extent.x, -extent.y, extent.z),
        Vector3f.new(-extent.x, extent.y, extent.z),
        Vector3f.new(extent.x, extent.y, extent.z)
    }

    local corners = {}
    for i, offset in ipairs(corner_offsets) do
        corners[i] = draw.world_to_screen(pos + rotation * offset)
    end

    if corners[1] ~= nil and corners[2] ~= nil then
        draw.line(corners[1].x, corners[1].y, corners[2].x, corners[2].y, color)
    end

    if corners[1] ~= nil and corners[3] ~= nil then
        draw.line(corners[1].x, corners[1].y, corners[3].x, corners[3].y, color)
    end

    if corners[1] ~= nil and corners[5] ~= nil then
        draw.line(corners[1].x, corners[1].y, corners[5].x, corners[5].y, color)
    end

    if corners[2] ~= nil and corners[4] ~= nil then
        draw.line(corners[2].x, corners[2].y, corners[4].x, corners[4].y, color)
    end

    if corners[2] ~= nil and corners[6] ~= nil then
        draw.line(corners[2].x, corners[2].y, corners[6].x, corners[6].y, color)
    end

    if corners[3] ~= nil and corners[4] ~= nil then
        draw.line(corners[3].x, corners[3].y, corners[4].x, corners[4].y, color)
    end

    if corners[3] ~= nil and corners[7] ~= nil then
        draw.line(corners[3].x, corners[3].y, corners[7].x, corners[7].y, color)
    end

    if corners[4] ~= nil and corners[8] ~= nil then
        draw.line(corners[4].x, corners[4].y, corners[8].x, corners[8].y, color)
    end

    if corners[5] ~= nil and corners[6] ~= nil then
        draw.line(corners[5].x, corners[5].y, corners[6].x, corners[6].y, color)
    end

    if corners[5] ~= nil and corners[7] ~= nil then
        draw.line(corners[5].x, corners[5].y, corners[7].x, corners[7].y, color)
    end

    if corners[6] ~= nil and corners[8] ~= nil then
        draw.line(corners[6].x, corners[6].y, corners[8].x, corners[8].y, color)
    end

    if corners[7] ~= nil and corners[8] ~= nil then
        draw.line(corners[7].x, corners[7].y, corners[8].x, corners[8].y, color)
    end
end

-- local function render_trigger(trigger, color)
--     if trigger.aabb.minpos ~= nil and trigger.aabb.maxpos ~= nil then    
--         local v1 = draw.world_to_screen(trigger.aabb.minpos)
--         local v2 = draw.world_to_screen(trigger.aabb.maxpos)

--         if v1 ~= nil and v2 ~= nil then
--             draw.line(v1.x, v1.y, v2.x, v2.y, COLOR_WHITE)
--             draw_wireframe_box(trigger.aabb.minpos, trigger.aabb.maxpos, color)
--         end

--         aabb_center = trigger.aabb:call("getCenter()")

--         if aabb_center ~= nil then
--             local name_label = "TRIGGER (" .. trigger.name .. ")"
    
--             local name_label_pos = draw.world_to_screen(aabb_center)
--             local name_label_bounds = imgui.calc_text_size(name_label)
    
--             if (name_label_pos ~= nil) then
--                 draw.text(name_label, name_label_pos.x - (name_label_bounds.x / 2), name_label_pos.y, COLOR_WHITE)
--             end
    
--             draw.world_text("+", trigger.aabb.minpos, COLOR_WHITE)
--             draw.world_text("+", trigger.aabb.maxpos, COLOR_WHITE)
--         end
--     end
-- end

-- Additional functions
local function config_allows_trigger_type(type)
    return trigger_type_filter_map[type] ~= nil and trigger_type_filter_map[type]
end

local function on_pre_trigger_generate_work(args)
    local current_trigger_activated = sdk.to_managed_object(args[2])
    local trigger_runtime_type = current_trigger_activated:get_type_definition():get_name()

    local trigger_display_name = current_trigger_activated.UniqueName .. "_" .. trigger_runtime_type

    local owner_game_object = sdk.to_managed_object(current_trigger_activated:call("get_Owner()"))

    local game_object_colliders = get_component(owner_game_object, "via.physics.Colliders")
    if game_object_colliders == nil then
        error("Failed to get via.physics.Colliders component for Game Object")
    end

    local game_object_interact_holder = get_component(owner_game_object, "chainsaw.InteractHolder")
    if game_object_interact_holder == nil then
        error("Failed to get chainsaw.InteractHolder component for Game Object")
    end

    if is_debug_mode then
        table.insert(debug_game_objects, owner_game_object)
    end

    local colliders_count = game_object_colliders:call("get_NumColliders()")

    contact_count = colliders_count

    for i = 0, colliders_count do
        local collider = game_object_colliders:call("getColliders", i)
        if collider then
            local collider_shape = collider:call("get_TransformedShape")
            current_trigger_shape = collider_shape:get_type_definition():get_name()
            if collider_shape and collider_shape:get_type_definition():get_name() == "BoxShape" then
                local obb = collider_shape:call("get_Box()")
                if obb then
                    local trigger = Trigger.new(trigger_display_name, obb, trigger_runtime_type)
                    if not entry_exists(previously_hit_triggers, trigger) then
                        table.insert(previously_hit_triggers, trigger)
                    end
                end
            end
        end
    end

    -- for i = 0, colliders_count do
    --     local collider = game_object_colliders:call("getColliders()", i)

    --     local collider_shape = collider:call("get_Shape()")

    --     if collider_shape and collider_shape:get_type_definition():get_name() == "AabbShape" then
    --         local trigger_bounding_box = collider_shape:call("get_Aabb()")
    --         local trigger = Trigger.new(trigger_display_name, trigger_bounding_box, trigger_runtime_type)
    --         if not entry_exists(previously_hit_triggers, trigger) then
    --             table.insert(previously_hit_triggers, trigger)
    --         end
    --     end
    -- end
end

local function on_post_trigger_generate_work(ret)
    return ret
end

-- chainsaw.InteractTriggerActivated.generateWork(chainsaw.InteractTrigger.TargetType, chainsaw.InteractManager.WorkIndex)
sdk.hook(sdk.find_type_definition("chainsaw.InteractTriggerActivated"):get_method("generateWork(chainsaw.InteractTrigger.TargetType, chainsaw.InteractManager.WorkIndex)"),
    on_pre_trigger_generate_work,
    on_post_trigger_generate_work)

re.on_frame(function()
    if not should_render_triggers then
        return
    end

    for i,t in ipairs(previously_hit_triggers) do
        if config_allows_trigger_type(t.type) and t.draw then
            render_trigger(t, trigger_color)
        end
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Trigger Trace") then

        imgui.text("Colliders: " .. tostring(contact_count))
        imgui.text("Shape: " .. current_trigger_shape)

        imgui.text("Debug Quaternion: " .. quat_string)

        changed, should_render_triggers = imgui.checkbox("Render Triggers", should_render_triggers)

        changed, trigger_type_filter_map["InteractTriggerAreaHit"] = imgui.checkbox("Area Hit", trigger_type_filter_map["InteractTriggerAreaHit"])
        changed, trigger_type_filter_map["InteractTriggerKey"] = imgui.checkbox("Key", trigger_type_filter_map["InteractTriggerKey"])
        changed, trigger_type_filter_map["InteractTriggerUseItem"] = imgui.checkbox("Use Item", trigger_type_filter_map["InteractTriggerUseItem"])

        imgui.spacing()
        imgui.spacing()
        imgui.spacing()

        if imgui.begin_list_box("Triggers hit") then
            for i,t in ipairs(previously_hit_triggers) do
                changed, t.draw = imgui.checkbox(tostring(i) .. ". " .. t.name, t.draw)
            end
            imgui.end_list_box()
        end

        if imgui.button("Clear") then 
            clear_table(previously_hit_triggers)
        end

        if imgui.tree_node("Visuals") then
            changed, trigger_color = imgui.color_picker("Trigger color", trigger_color)
            imgui.tree_pop()
        end

        changed, is_debug_mode = imgui.checkbox("Debug Mode", is_debug_mode)

        if changed and not is_debug_mode then
            clear_table(debug_game_objects)
        end

        if is_debug_mode then
            if imgui.tree_node("Debug") then
                for i,o in ipairs(debug_game_objects) do
                    if imgui.tree_node(tostring(i) .. ". " .. o:get_type_definition():get_name()) then
                        local game_object_components = get_components(o)
                        for j,c in ipairs(game_object_components) do
                            if imgui.tree_node(tostring(j) .. ". " .. c:get_type_definition():get_name()) then
                                imgui.tree_pop()
                            end
                        end
                        imgui.tree_pop()
                    end
                end
                imgui.tree_pop()
            end
        end
        imgui.tree_pop()
    end
    imgui.spacing()
end)