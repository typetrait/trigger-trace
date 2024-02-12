-- Author: typetrait
-- Provides functionality for rendering in-game triggers.

-- LSP Type definitions for development
local TT = require("trigger-trace.types")
if TT then
    imgui = TT.REF.imgui
    d2d = TT.REF.d2d
    Vector3f = TT.REF.Vector3f
    Quaternion = TT.REF.Quaternion
    draw = TT.REF.draw
    ext = TT.ext
end

-- Singletons
local interact_manager = sdk.get_managed_singleton("chainsaw.InteractManager")

-- "Constants"
local COLOR_RED = 0xffff0000
local COLOR_GREEN = 0xff00ff00
local COLOR_WHITE = 0xffffffff

-- Config
local trigger_type_filter_map = {
    ["InteractTriggerAreaHit"] = true,
    ["InteractTriggerKey"] = false,
    ["InteractTriggerUseItem"] = false
}

local config = {
    should_render_scene_triggers = true,
    should_render_activated_triggers = true,
    scene_trigger_color = COLOR_RED,
    activated_trigger_color = COLOR_GREEN,
    trigger = {
        should_render_labels = true,
        label_color = COLOR_WHITE
    },
    is_debug = false
}

-- Debug
local debug_game_objects = {}
local contact_count = 0
local debug_text = ""

-- D2D
local font = nil

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

    if not t then
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

local function euler_to_quat(pitch, yaw, roll)
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

    return Quaternion.new(w, x, y, z)
end

local function draw_line(p1, p2, color)
    if p1 and p2 then
        d2d.line(p1.x, p1.y, p2.x, p2.y, 2, color)
    end
end

---@param label_text string
---@param pos Vector3f
---@param color number
local function draw_label(label_text, pos, color)
    local font_metrics_width, font_metrics_height = font:measure(label_text)
    d2d.text(font, label_text, pos.x - (font_metrics_width / 2), pos.y - (font_metrics_height / 2), color)
end

---@param aabb any
---@param color number
local function draw_aabb(aabb, color)
    if aabb == nil then
        return
    end

    local lower = aabb.minpos
    local upper = aabb.maxpos

    local front_face_vertex1 = draw.world_to_screen(Vector3f.new(lower.x, lower.y, lower.z))
    local front_face_vertex2 = draw.world_to_screen(Vector3f.new(lower.x, upper.y, lower.z))
    local front_face_vertex3 = draw.world_to_screen(Vector3f.new(upper.x, upper.y, lower.z))
    local front_face_vertex4 = draw.world_to_screen(Vector3f.new(upper.x, lower.y, lower.z))

    local back_face_vertex1 = draw.world_to_screen(Vector3f.new(lower.x, lower.y, upper.z))
    local back_face_vertex2 = draw.world_to_screen(Vector3f.new(lower.x, upper.y, upper.z))
    local back_face_vertex3 = draw.world_to_screen(Vector3f.new(upper.x, upper.y, upper.z))
    local back_face_vertex4 = draw.world_to_screen(Vector3f.new(upper.x, lower.y, upper.z))

    -- Front face
    draw_line(front_face_vertex1, front_face_vertex2, color)
    draw_line(front_face_vertex2, front_face_vertex3, color)
    draw_line(front_face_vertex3, front_face_vertex4, color)
    draw_line(front_face_vertex4, front_face_vertex1, color)

    -- Back face
    draw_line(back_face_vertex1, back_face_vertex2, color)
    draw_line(back_face_vertex2, back_face_vertex3, color)
    draw_line(back_face_vertex3, back_face_vertex4, color)
    draw_line(back_face_vertex4, back_face_vertex1, color)

    -- Connecting lines
    draw_line(front_face_vertex1, back_face_vertex1, color)
    draw_line(front_face_vertex2, back_face_vertex2, color)
    draw_line(front_face_vertex3, back_face_vertex3, color)
    draw_line(front_face_vertex4, back_face_vertex4, color)

end

---comment
---@param obb any
---@param color number
local function draw_obb(obb, color)
    if not obb then
        return
    end

    local pos = obb:call("get_Position")
    local extent = obb:call("get_Extent")
    local rotation = obb:call("get_RotateAngle")

    rotation = euler_to_quat(rotation.x, rotation.y, rotation.z)

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

    draw_line(corners[1], corners[2], color)
    draw_line(corners[1], corners[3], color)
    draw_line(corners[1], corners[5], color)
    draw_line(corners[2], corners[4], color)
    draw_line(corners[2], corners[6], color)
    draw_line(corners[3], corners[4], color)
    draw_line(corners[3], corners[7], color)
    draw_line(corners[4], corners[8], color)
    draw_line(corners[5], corners[6], color)
    draw_line(corners[5], corners[7], color)
    draw_line(corners[6], corners[8], color)
    draw_line(corners[7], corners[8], color)
end

-- Trigger definitions
---@type Trigger[]
local all_scene_triggers = {}

---@type Trigger[]
local previously_hit_triggers = {}

---@class Trigger
---@field name string
---@field shape any
---@field type string
---@field draw boolean
---@field instance any
---@field debug string
local Trigger = {}
Trigger.__index = Trigger

function Trigger.new(name, shape, type, instance)
    local self = setmetatable({}, Trigger)
    self.name = name
    self.shape = shape
    self.type = type
    self.draw = true
    self.instance = instance
    self.debug = ""
    return self
end

---@return Trigger?
function Trigger.from_game_interact_trigger(game_object, interact_trigger)
    if not game_object then
        return nil
    end

    local trigger_runtime_type = interact_trigger:get_type_definition():get_name()
    local trigger_display_name = interact_trigger.UniqueName .. "_" .. trigger_runtime_type

    local colliders = get_component(game_object, "via.physics.Colliders")

    local collider_count = colliders:call("get_NumColliders()")
    for i = 0, collider_count do
        local collider = colliders:call("getColliders", i)
        if collider then
            local collider_shape = collider:call("get_TransformedShape")
            local trigger_shape_name = collider_shape:get_type_definition():get_name()
            if collider_shape then
                local trigger = Trigger.new(
                    trigger_display_name .. " [" .. trigger_shape_name .. "]" .. " @ " .. game_object:call("get_Name"),
                    collider_shape,
                    trigger_runtime_type,
                    interact_trigger
                )
                return trigger
            end
        end
    end

    return nil
end

function Trigger:equals(other)
    return self.shape:call("Equals(System.Object)", other.shape)
end

---@param trigger Trigger
---@param color any
local function render_trigger(trigger, color)
    if not trigger.shape then
        return
    end

    local shape_type = trigger.shape:get_type_definition():get_name()

    local name_label = "TRIGGER (" .. trigger.name .. ")"

    if shape_type == "BoxShape" then
        local obb = trigger.shape:call("get_Box()")
        local pos = obb:call("get_Position")

        draw_obb(obb, color)

        local name_label_pos = draw.world_to_screen(pos)

        if name_label_pos and config.trigger.should_render_labels then
            draw_label(name_label, name_label_pos, config.trigger.label_color)

            -- draw_label(tostring(trigger.instance:call("get_Triggered")), Vector3f.new(name_label_pos.x, name_label_pos.y + 15, name_label_pos.z), COLOR_WHITE)
            draw_label(trigger.debug, Vector3f.new(name_label_pos.x, name_label_pos.y + 15, name_label_pos.z), config.trigger.label_color)
        end
    elseif shape_type == "SphereShape" then
        local camera = sdk.get_primary_camera()
        local camera_transform = get_component(camera:call("get_GameObject"), "via.Transform")

        local camera_joints = camera_transform:call("get_Joints")
        local camera_joint = camera_joints:get_element(0)

        local camera_joint_rotation = camera_joint:call("get_Rotation")

        local camera_up = camera_joint_rotation * Vector3f.new(0, 1, 0)

        local camera_forward = camera_joint_rotation * Vector3f.new(0, 0, 1) -- if z is the forward axis
        local camera_right = camera_up:cross(camera_forward) -- calculate the 'right' direction

        local center = trigger.shape:call("get_Center")
        local radius = trigger.shape:call("get_Radius")

        local screen_pos_center = draw.world_to_screen(center)

        local top_pos = center + (camera_up:normalized() * radius)
        local screen_top_pos = draw.world_to_screen(top_pos)

        local right_pos = center + (camera_right:normalized() * radius)
        local screen_right_pos = draw.world_to_screen(right_pos)

        local game_object = trigger.instance:call("get_Owner")

        if not game_object then
            return
        end

        local game_object_transform = get_component(game_object, "via.Transform")

        if screen_top_pos and game_object_transform then
            local radius_2d = (screen_top_pos - screen_pos_center):length()
            d2d.outline_ellipse(screen_pos_center.x, screen_pos_center.y, radius_2d, radius_2d, color)

            local name_label_pos = screen_pos_center
    
            if name_label_pos and config.trigger.should_render_labels then
                draw_label(name_label, name_label_pos, config.trigger.label_color)
            end

            -- local radius_2d_horizontal = (screen_right_pos - screen_pos_center):length()

            -- local axis_x = game_object_transform:call("get_AxisX"):normalized()
            -- local axis_y = game_object_transform:call("get_AxisY"):normalized()
            -- local axis_z = game_object_transform:call("get_AxisZ"):normalized()

            -- local x_axis_end_pos = center + (axis_x * radius)
            -- local y_axis_end_pos = center + (axis_y * radius)
            -- local z_axis_end_pos = center + (axis_z * radius)

            -- local x_line_end_2d = draw.world_to_screen(x_axis_end_pos)
            -- local y_line_end_2d = draw.world_to_screen(y_axis_end_pos)
            -- local z_line_end_2d = draw.world_to_screen(z_axis_end_pos)

            -- draw_line(screen_pos_center, x_line_end_2d, color)
            -- draw_line(screen_pos_center, y_line_end_2d, color)
            -- draw_line(screen_pos_center, z_line_end_2d, color)

            -- local radius_2d_x = (x_line_end_2d - screen_pos_center):length()
            -- local radius_2d_y = (y_line_end_2d - screen_pos_center):length()

            -- if screen_pos_center then
            --     d2d.outline_ellipse(screen_pos_center.x, screen_pos_center.y, radius_2d_x, radius_2d_y, color)
            -- end
        end
    end
end

-- Additional functions
local function config_allows_trigger_type(type)
    return trigger_type_filter_map[type] ~= nil and trigger_type_filter_map[type]
end

local function get_scene_triggers()
    clear_table(all_scene_triggers)

    local scene_manager = sdk.get_native_singleton("via.SceneManager")
    if not scene_manager then
        return
    end

    local scene = sdk.call_native_func(scene_manager, sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
    if not scene then
        return
    end

    local transform = scene:call("get_FirstTransform")
    while transform do
        local game_object = transform:call("get_GameObject")
        if game_object then
            local interact_holder = get_component(game_object, "chainsaw.InteractHolder")
            local colliders = get_component(game_object, "via.physics.Colliders")
            if interact_holder and colliders then
                local trigger_containers = interact_holder:call("get_Triggers")

                if trigger_containers then
                    for _,t in pairs(trigger_containers) do
                        local interact_trigger = t:call("get_Trigger")
                        if interact_trigger then
                            local trigger = Trigger.from_game_interact_trigger(game_object, interact_trigger)
                            if trigger then
                                table.insert(all_scene_triggers, trigger)

                                sdk.hook_vtable(
                                    interact_trigger,
                                    sdk.find_type_definition("chainsaw.InteractTrigger"):get_method("checkEnableType(via.GameObject, chainsaw.CharacterContext, chainsaw.collision.GimmickSensorUserData, System.Boolean)"),
                                    function (args)
                                        local game_object = sdk.to_managed_object(args[3])
                                        local character_context = sdk.to_managed_object(args[4])
                                        local gimmick_sensor_userdata = sdk.to_managed_object(args[5])
                                        local unk = args[6]

                                        local type_name = character_context:get_type_definition():get_full_name()

                                        -- addresses
                                        trigger.debug = tostring(args[3]) .. " | " .. tostring(args[4]) .. " | " .. tostring(args[5])
                                    end,
                                    function (retval)
                                        -- trigger.debug = tostring(retval)
                                        return retval
                                    end
                                )
                            end
                        end
                    end
                end
            end
        end
        transform = transform:call("get_Next")
    end
end

-- Hooks
local function on_pre_trigger_generate_work(args)
    if not config.should_render_activated_triggers then
        return
    end

    local current_trigger_activated = sdk.to_managed_object(args[2])
    local trigger_runtime_type = current_trigger_activated:get_type_definition():get_name()

    local trigger_display_name = current_trigger_activated.UniqueName .. "_" .. trigger_runtime_type

    local owner_game_object = sdk.to_managed_object(current_trigger_activated:call("get_Owner()"))

    local game_object_colliders = get_component(owner_game_object, "via.physics.Colliders")
    if not game_object_colliders then
        error("Failed to get via.physics.Colliders component for Game Object")
    end

    local game_object_interact_holder = get_component(owner_game_object, "chainsaw.InteractHolder")
    if not game_object_interact_holder then
        error("Failed to get chainsaw.InteractHolder component for Game Object")
    end

    if config.is_debug then
        table.insert(debug_game_objects, owner_game_object)
    end

    local colliders_count = game_object_colliders:call("get_NumColliders()")

    contact_count = colliders_count

    for i = 0, colliders_count do
        local collider = game_object_colliders:call("getColliders", i)
        if collider then
            local collider_shape = collider:call("get_TransformedShape")
            if collider_shape then
                local trigger_shape_name = collider_shape:get_type_definition():get_name()
                local trigger = Trigger.new(
                    trigger_display_name .. " [" .. trigger_shape_name .. "]" .. " @ " .. owner_game_object:call("get_Name"),
                    collider_shape,
                    trigger_runtime_type,
                    current_trigger_activated
                )
                if not entry_exists(previously_hit_triggers, trigger) and config_allows_trigger_type(trigger.type) then
                    table.insert(previously_hit_triggers, trigger)
                end
            end
        end
    end
end

local function on_post_trigger_generate_work(ret)
    return ret
end

-- chainsaw.InteractTriggerActivated.generateWork(chainsaw.InteractTrigger.TargetType, chainsaw.InteractManager.WorkIndex)
sdk.hook(
    sdk.find_type_definition("chainsaw.InteractTriggerActivated"):get_method("generateWork(chainsaw.InteractTrigger.TargetType, chainsaw.InteractManager.WorkIndex)"),
    on_pre_trigger_generate_work,
    on_post_trigger_generate_work
)

-- chainsaw.CampaignManager.onStartInGame()
sdk.hook(
    sdk.find_type_definition("chainsaw.CampaignManager"):get_method("onStartInGame()"),
    function(args)
        clear_table(previously_hit_triggers)
        clear_table(all_scene_triggers)
        get_scene_triggers()
    end,
    function(ret)
        return ret
    end
)

local function on_draw()
    local screen_w, screen_h = d2d.surface_size()
    if config.should_render_scene_triggers then
        for i,t in ipairs(all_scene_triggers) do
            if config_allows_trigger_type(t.type) and t.draw then
                render_trigger(t, config.scene_trigger_color)
            end
        end
    end

    if config.should_render_activated_triggers then
        for i,t in ipairs(previously_hit_triggers) do
            if config_allows_trigger_type(t.type) and t.draw then
                render_trigger(t, config.activated_trigger_color)
            end
        end
    end
end

re.on_draw_ui(function()
    if imgui.tree_node("Trigger Trace") then
        changed, config.should_render_scene_triggers = imgui.checkbox("Scene (All)", config.should_render_scene_triggers)
        if config.should_render_scene_triggers then
            imgui.same_line()
            if imgui.button("Find all triggers") then
                get_scene_triggers()
            end
            imgui.same_line()
            if imgui.button("Clear") then
                clear_table(all_scene_triggers)
            end
        end

        changed, config.should_render_activated_triggers = imgui.checkbox("On Hit (Activated)", config.should_render_activated_triggers)

        if config.should_render_activated_triggers or config.should_render_scene_triggers then
            if imgui.tree_node("Filters") then
                changed, trigger_type_filter_map["InteractTriggerAreaHit"] = imgui.checkbox("Area Hit", trigger_type_filter_map["InteractTriggerAreaHit"])
                changed, trigger_type_filter_map["InteractTriggerKey"] = imgui.checkbox("Key", trigger_type_filter_map["InteractTriggerKey"])
                changed, trigger_type_filter_map["InteractTriggerUseItem"] = imgui.checkbox("Use Item", trigger_type_filter_map["InteractTriggerUseItem"])

                imgui.tree_pop()
            end
        end

        if imgui.begin_list_box("Scene Triggers") then
            for i,t in ipairs(all_scene_triggers) do
                changed, t.draw = imgui.checkbox(tostring(i) .. ". " .. t.name, t.draw)
                if imgui.begin_popup_context_item() then
                    if imgui.button("Copy Label") then
                        ext.set_clipboard(t.name)
                        imgui.close_current_popup()
                    end
                    imgui.end_popup()
                end
            end
            imgui.end_list_box()
        end

        if imgui.begin_list_box("Triggers hit") then
            for i,t in ipairs(previously_hit_triggers) do
                changed, t.draw = imgui.checkbox(tostring(i) .. ". " .. t.name, t.draw)
                if imgui.begin_popup_context_item() then
                    if imgui.button("Copy Label") then
                        ext.set_clipboard(t.name)
                        imgui.close_current_popup()
                    end
                    imgui.end_popup()
                end
            end
            imgui.end_list_box()
        end

        if imgui.button("Clear##1") then
            clear_table(previously_hit_triggers)
        end

        if imgui.tree_node("Visuals") then
            changed, config.trigger.should_render_labels = imgui.checkbox("Render Labels", config.trigger.should_render_labels)
            changed, config.trigger.label_color = imgui.color_edit_argb("Labels", config.trigger.label_color)
            changed, config.scene_trigger_color = imgui.color_edit_argb("Triggers", config.scene_trigger_color)
            changed, config.activated_trigger_color = imgui.color_edit_argb("Activated Triggers", config.activated_trigger_color)
            imgui.tree_pop()
        end

        imgui.spacing()

        changed, config.is_debug = imgui.checkbox("Debug Mode (development only)", config.is_debug)

        if changed and not config.is_debug then
            clear_table(debug_game_objects)
        end

        if config.is_debug then
            if imgui.tree_node("Debug") then
                imgui.text("Colliders: " .. tostring(contact_count))
                imgui.text("Debug: " .. debug_text)
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

d2d.register(
    function()
        font = d2d.Font.new("Tahoma", 16)
    end,
    on_draw
)