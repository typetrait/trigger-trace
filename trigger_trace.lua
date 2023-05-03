-- Author: alchemistis
-- Provides functionality for rendering in-game triggers.
-- Happy skip/glitch hunting.

-- Singletons
local interact_manager = sdk.get_managed_singleton("chainsaw.InteractManager")

-- Variables
local area_hit_count = 0
local last_trigger_target_type = 0

local trigger_count = 0

local trigger_activate_type = 0

local trigger_display_name = 0

local dummy_transform_origin = nil

local trigger_bounding_box_lower_corner_point = nil
local trigger_bounding_box_upper_corner_point = nil

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
        if back_face_vertex1 ~= nil and back_face_vertex2 ~= nil then
            draw.line(front_face_vertex1.x, front_face_vertex1.y, back_face_vertex1.x, back_face_vertex1.y, color)
        end
        if back_face_vertex2 ~= nil and back_face_vertex3 ~= nil then
            draw.line(front_face_vertex2.x, front_face_vertex2.y, back_face_vertex2.x, back_face_vertex2.y, color)
        end
        if back_face_vertex3 ~= nil and back_face_vertex4 ~= nil then
            draw.line(front_face_vertex3.x, front_face_vertex3.y, back_face_vertex3.x, back_face_vertex3.y, color)
        end
        if back_face_vertex4 ~= nil and back_face_vertex1 ~= nil then
            draw.line(front_face_vertex4.x, front_face_vertex4.y, back_face_vertex4.x, back_face_vertex4.y, color)
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

    trigger_count = 0
    while enumerator:call("MoveNext()") do
        trigger_count = trigger_count + 1

        local current_trigger_activated = sdk.to_managed_object(enumerator:call("get_Current()"))
        trigger_activate_type = sdk.to_int64(current_trigger_activated:call("get_Activate()"))

        trigger_display_name = current_trigger_activated:call("get_DisplayName()")

        local owner_game_object = sdk.to_managed_object(current_trigger_activated:call("get_Owner()"))
        local owner_game_object_transform = get_component(owner_game_object, "via.Transform")

        dummy_transform_origin = owner_game_object_transform:call("get_Position()")

        local owner_game_object_collider = get_component(owner_game_object, "via.physics.Colliders")
        if owner_game_object_collider == nil then
            error("Failed to get via.physics.Colliders component for Game Object")
        end

        local trigger_bounding_box = owner_game_object_collider:call("get_BoundingAabb()")

        -- local trigger_bounding_box_center = trigger_bounding_box:call("getCenter()")

        trigger_bounding_box_lower_corner_point = trigger_bounding_box.minpos
        trigger_bounding_box_upper_corner_point = trigger_bounding_box.maxpos

        if trigger_bounding_box_lower_corner_point == nil or trigger_bounding_box_upper_corner_point == nil then
            error("Failed to get trigger_bounding_box_lower_corner_point or trigger_bounding_box_upper_corner_point")
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
    draw.text("Area Hit count: " .. area_hit_count, 5, 5, 0xffffffff)
    draw.text("Trigger Target Type: " .. last_trigger_target_type, 5, 20, 0xffffffff)
    draw.text("IEnumerable<chainsaw.InteractTriggerActivated> count: " .. trigger_count, 5, 35, 0xffffffff)
    draw.text("chainsaw.InteractTriggerActivated.Activate: " .. trigger_activate_type, 5, 50, 0xffffffff)
    draw.text("Display name: " .. trigger_display_name, 5, 65, 0xffffffff)

    if dummy_transform_origin ~= nil then
        if trigger_bounding_box_lower_corner_point ~= nil and trigger_bounding_box_upper_corner_point ~= nil then
            draw.text("minpos: <" .. trigger_bounding_box_lower_corner_point.x .. ", " .. trigger_bounding_box_lower_corner_point.y .. ", " .. trigger_bounding_box_lower_corner_point.z .. ">", 5, 80, 0xffffffff)
            draw.text("maxpos: <" .. trigger_bounding_box_upper_corner_point.x .. ", " .. trigger_bounding_box_upper_corner_point.y .. ", " .. trigger_bounding_box_upper_corner_point.z .. ">", 5, 95, 0xffffffff)
        
            local v1 = draw.world_to_screen(trigger_bounding_box_lower_corner_point)
            local v2 = draw.world_to_screen(trigger_bounding_box_upper_corner_point)

            if v1 ~= nil and v2 ~= nil then
                draw.line(v1.x, v1.y, v2.x, v2.y, 0xffffffff)
                draw_wireframe_box(trigger_bounding_box_lower_corner_point, trigger_bounding_box_upper_corner_point, 0xff0000ff)
            end
        end
        
        draw.world_text("TRIGGER", dummy_transform_origin, 0xffffffff)
        draw.world_text("+", trigger_bounding_box_lower_corner_point, 0xffffffff)
        draw.world_text("+", trigger_bounding_box_upper_corner_point, 0xffffffff)
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Trigger Trace") then
        imgui.text("Area Hit count: " .. area_hit_count)
        imgui.text("Trigger Target Type: " .. last_trigger_target_type)
        imgui.text("Display name: " .. trigger_display_name)
    end
end)