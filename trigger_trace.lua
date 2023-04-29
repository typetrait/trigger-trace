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

-- activateHitArea(via.GameObject, chainsaw.collision.GimmickSensorUserData, chainsaw.InteractManager.WorkIndex, chainsaw.InteractTrigger.TargetType, System.Collections.Generic.IEnumerable`1<chainsaw.InteractTriggerActivated>)
local function on_pre_interact_trigger_set_activate(args)
    -- args[5] should be of type "chainsaw.InteractTrigger.TargetType"
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

        -- trigger_bounding_box_lower_corner_point = trigger_bounding_box:call("getCenter()")
        -- trigger_bounding_box_upper_corner_point = trigger_bounding_box:call("getCenter()")

        trigger_bounding_box_lower_corner_point = trigger_bounding_box.minpos -- + dummy_transform_origin
        trigger_bounding_box_upper_corner_point = trigger_bounding_box.maxpos -- + dummy_transform_origin

        if trigger_bounding_box_lower_corner_point == nil or trigger_bounding_box_upper_corner_point == nil then
            error("Failed to get trigger_bounding_box_lower_corner_point or trigger_bounding_box_upper_corner_point")
        end
    end

    if last_trigger_target_type == 0 then
        area_hit_count = area_hit_count + 1
    end
end

local function on_post_interact_trigger_set_activate(ret)
    -- last_trigger_target_type = sdk.to_int64(ret)
    
    -- if (last_trigger_target_type == 1) then
    --     area_hit_count = area_hit_count + 1
    -- end

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