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
local should_render_debug_info = false

-- Variables
local trigger_color = COLOR_RED

local area_hit_count = 0
local last_trigger_target_type = 0
local trigger_activate_type = 0

-- Trigger definitions
local previously_hit_triggers = {}

local Trigger = {}
Trigger.__index = Trigger

function Trigger.new(name, aabb)
    local self = setmetatable({}, Trigger)
    self.name = name
    self.aabb = aabb
    return self
end

function Trigger:equals(other)
    return self.name == other.name and self.aabb.minpos == other.aabb.minpos and self.aabb.maxpos == other.aabb.maxpos
end

--

local function entry_exists(table, entry)
    for _, e in ipairs(table) do
        if e:equals(entry) then
            return true
        end
    end
    return false
end

local function get_component(game_object, type_name)
    local t = sdk.typeof(type_name)

    if t == nil then 
        return nil
    end

    return game_object:call("getComponent(System.Type)", t)
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

local function render_trigger(trigger, color)
    if trigger.aabb.minpos ~= nil and trigger.aabb.maxpos ~= nil then    
        local v1 = draw.world_to_screen(trigger.aabb.minpos)
        local v2 = draw.world_to_screen(trigger.aabb.maxpos)

        if v1 ~= nil and v2 ~= nil then
            draw.line(v1.x, v1.y, v2.x, v2.y, COLOR_WHITE)
            draw_wireframe_box(trigger.aabb.minpos, trigger.aabb.maxpos, color)
        end

        aabb_center = trigger.aabb:call("getCenter()")

        if aabb_center ~= nil then
            local name_label = "TRIGGER (" .. trigger.name .. ")"
    
            local name_label_pos = draw.world_to_screen(aabb_center)
            local name_label_bounds = imgui.calc_text_size(name_label)
    
            if (name_label_pos ~= nil) then
                draw.text(name_label, name_label_pos.x - (name_label_bounds.x / 2), name_label_pos.y, COLOR_WHITE)
            end
    
            draw.world_text("+", trigger.aabb.minpos, COLOR_WHITE)
            draw.world_text("+", trigger.aabb.maxpos, COLOR_WHITE)
        end
    end
end

-- activateHitArea(via.GameObject, chainsaw.collision.GimmickSensorUserData, chainsaw.InteractManager.WorkIndex, chainsaw.InteractTrigger.TargetType, System.Collections.Generic.IEnumerable`1<chainsaw.InteractTriggerActivated>)
local function on_pre_interact_trigger_set_activate(args)
    -- args[6] should be of type "chainsaw.InteractTrigger.TargetType"
    -- 0 means TargetType.Pl00, probably player character?
    last_trigger_target_type = sdk.to_int64(args[6])

    local triggers = sdk.to_managed_object(args[7]) -- IEnumerable<chainsaw.InteractTriggerActivated>
    local enumerator = sdk.to_managed_object(triggers:call("GetEnumerator()"))

    while enumerator:call("MoveNext()") do
        local current_trigger_activated = sdk.to_managed_object(enumerator:call("get_Current()"))
        local trigger_activate_type = sdk.to_int64(current_trigger_activated:call("get_Activate()"))

        local trigger_display_name = current_trigger_activated:call("get_DisplayName()")

        local owner_game_object = sdk.to_managed_object(current_trigger_activated:call("get_Owner()"))
        local owner_game_object_transform = get_component(owner_game_object, "via.Transform")

        local owner_game_object_collider = get_component(owner_game_object, "via.physics.Colliders")
        if owner_game_object_collider == nil then
            error("Failed to get via.physics.Colliders component for Game Object")
        end

        local trigger_bounding_box = owner_game_object_collider:call("get_BoundingAabb()")
        if trigger_bounding_box.minpos == nil or trigger_bounding_box.maxpos == nil then
            error("Failed to get trigger_bounding_box.minpos or trigger_bounding_box.maxpos")
        end

        local trigger = Trigger.new(trigger_display_name, trigger_bounding_box)

        if not entry_exists(previously_hit_triggers, trigger) then
            table.insert(previously_hit_triggers, trigger)
        end
    end

    if last_trigger_target_type == 0 then
        area_hit_count = area_hit_count + 1
    end
end

local function on_post_interact_trigger_set_activate(ret)
    return ret
end

-- sdk.hook(sdk.find_type_definition("chainsaw.InteractTriggerActivated"):get_method("set_Activate(chainsaw.InteractTriggerActivated.ActivateType)"),
-- sdk.hook(sdk.find_type_definition("chainsaw.InteractTriggerAreaHit"):get_method("get_Type()"),
sdk.hook(sdk.find_type_definition("chainsaw.InteractManager"):get_method("activateHitArea(via.GameObject, chainsaw.collision.GimmickSensorUserData, chainsaw.InteractManager.WorkIndex, chainsaw.InteractTrigger.TargetType, System.Collections.Generic.IEnumerable`1<chainsaw.InteractTriggerActivated>)"),
    on_pre_interact_trigger_set_activate,
    on_post_interact_trigger_set_activate)

re.on_frame(function()
    if not should_render_triggers then
        return
    end

    for i,t in ipairs(previously_hit_triggers) do
        render_trigger(t, trigger_color)
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Trigger Trace") then
        changed, should_render_triggers = imgui.checkbox("Render Triggers", should_render_triggers)

        changed, trigger_color = imgui.color_picker("Trigger color", trigger_color)

        if imgui.tree_node("Debug") then
            changed, should_render_debug_info = imgui.checkbox("Display Debug Info", should_render_debug_info)
            imgui.tree_pop()
        end

        imgui.tree_pop()
    end

    imgui.spacing()
end)