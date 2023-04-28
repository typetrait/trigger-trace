-- Author: alchemistis

-- Singletons
local interact_manager = sdk.get_managed_singleton("chainsaw.InteractManager")

-- Variables
local area_hit_count = 0
local last_trigger_target_type = 0

local trigger_count = 0

local trigger_activate_type = 0

local trigger_display_name = 0

local dummy_transform_origin = nil

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
        draw.world_text("TRIGGER", dummy_transform_origin, 0xffffffff)
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Trigger Trace") then
        imgui.text("Area Hit count: " .. area_hit_count)
        imgui.text("Trigger Target Type: " .. last_trigger_target_type)
        imgui.text("Display name: " .. trigger_display_name)
    end
end)