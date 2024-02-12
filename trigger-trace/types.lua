---@class Draw
---@field world_to_screen fun(world_pos: Vector3f): Vector3f
---@field world_text fun(text: string, world_pos: Vector3f, color: number)
---@field text fun(text: string, x: number, y: number, color: number)
---@field filled_rect fun(x: number, y: number, w: number, h: number, color: number)
---@field outline_rect fun(x: number, y: number, w: number, h: number, color: number)
---@field line fun(x1: number, y1: number, x2: number, y2: number, color: number)
---@field outline_circle fun(x: number, y: number, radius: number, color: number, num_segments: number)
---@field filled_circle fun(x: number, y: number, radius: number, color: number, num_segments: number)
---@field outline_quad fun(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, x4: number, y4: number, color: number)
---@field filled_quad fun(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, x4: number, y4: number, color: number)
---@field sphere fun(world_pos: Vector3f, radius: number, color: number, outline: number)
---@field capsule fun(world_start_pos: Vector3f, world_end_pos: Vector3f, radius: number, color: number, outline: number)
---@field gizmo fun(unique_id: integer, matrix, operation, mode)
---@field cube fun(matrix)
---@field grid fun(matrix, size)

---@class Vector3f
---@field x number
---@field y number
---@field z number
---@field new fun(x: number, y: number, z: number): Vector3f
---@field dot fun(other: Vector3f)
---@field cross fun(other: Vector3f)
---@field length fun(): number
---@field normalize fun()
---@field normalized fun(): Vector3f
---@field reflect fun(normal: Vector3f): Vector3f
---@field refract fun(normal: Vector3f, eta: number): Vector3f
---@field lerp fun(other: Vector3f, t: number): Vector3f

---@class Quaternion
---@field w number
---@field x number
---@field y number
---@field z number
---@field new fun(w: number, x: number, y: number, z: number): Quaternion

---@class Imgui
---@field text fun(text: string): string
---@field checkbox fun(text: string, value: boolean): boolean
---@field same_line fun()
---@field button fun(text: string)
---@field tree_node fun(text:string): boolean
---@field tree_pop fun()
---@field spacing fun()
---@field begin_list_box fun(text: string): boolean
---@field begin_popup_context_item fun()
---@field close_current_popup fun()
---@field end_popup fun()
---@field end_list_box fun()
---@field color_edit_argb fun(text: string, color: number)

---@class Direct2D
---@field register fun(init_fn: function, draw_fn: function)
---@field line fun(x1: number, y1: number, x2: number, y2: number, thickness: number, color: number)
---@field surface_size fun()
---@field outline_ellipse fun(x: number, y: number, radius1: number, radius2: number, color: number)

---@class Extensions
---@field set_clipboard fun(text: string)

local TT = {
    REF = {
        ---@type Draw
        draw = draw,

        ---@type Vector3f
        Vector3f = Vector3f,

        ---@type Quaternion
        Quaternion = Quaternion,

        ---@type Imgui
        imgui = imgui,

        ---@type Direct2D
        d2d = d2d
    },
    ---@type Extensions
    ext = ext
}

return TT