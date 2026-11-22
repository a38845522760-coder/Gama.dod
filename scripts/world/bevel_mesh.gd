extends RefCounted
class_name BevelMesh

## Builds boxes with chamfered (bevelled) edges. A plain BoxMesh has razor-sharp edges that
## look flat and "blocky"; a small chamfer catches the light on every edge and makes crates,
## containers, walls and machinery read as real, manufactured objects.
## Meshes are cached by size + bevel so thousands of boxes share a handful of meshes.

static var _cache: Dictionary = {}

static func box(size: Vector3, bevel: float) -> ArrayMesh:
    var key := "%.3f_%.3f_%.3f_%.3f" % [size.x, size.y, size.z, bevel]
    if _cache.has(key):
        return _cache[key]
    var mesh := _build(size, bevel)
    _cache[key] = mesh
    return mesh

static func _axis(index: int) -> Vector3:
    match index:
        0:
            return Vector3.RIGHT
        1:
            return Vector3.UP
        _:
            return Vector3.BACK

static func _build(size: Vector3, bevel_request: float) -> ArrayMesh:
    var half := size * 0.5
    var bevel := clampf(bevel_request, 0.001, minf(half.x, minf(half.y, half.z)) * 0.9)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    # ---- six main faces -------------------------------------------------------------
    for axis_index in range(3):
        for sign_value in [-1.0, 1.0]:
            var sgn: float = sign_value
            var n: Vector3 = _axis(axis_index) * sgn
            var t1: Vector3 = _axis((axis_index + 1) % 3)
            var t2: Vector3 = _axis((axis_index + 2) % 3)
            var h_n: float = half[axis_index]
            var h1: float = half[(axis_index + 1) % 3] - bevel
            var h2: float = half[(axis_index + 2) % 3] - bevel
            var center: Vector3 = n * h_n
            var a: Vector3 = center - t1 * h1 - t2 * h2
            var b: Vector3 = center + t1 * h1 - t2 * h2
            var c: Vector3 = center + t1 * h1 + t2 * h2
            var d: Vector3 = center - t1 * h1 + t2 * h2
            _tri(st, a, b, c, n)
            _tri(st, a, c, d, n)

    # ---- twelve chamfer strips ----------------------------------------------------------
    for axis_a in range(3):
        for axis_b in range(axis_a + 1, 3):
            var axis_c: int = 3 - axis_a - axis_b
            for sa in [-1.0, 1.0]:
                for sb in [-1.0, 1.0]:
                    var sgn_a: float = sa
                    var sgn_b: float = sb
                    var ea: Vector3 = _axis(axis_a)
                    var eb: Vector3 = _axis(axis_b)
                    var ec: Vector3 = _axis(axis_c)
                    var ha: float = half[axis_a]
                    var hb: float = half[axis_b]
                    var run_c: float = half[axis_c] - bevel
                    var edge_normal: Vector3 = (ea * sgn_a + eb * sgn_b).normalized()
                    var p1_low: Vector3 = ea * sgn_a * ha + eb * sgn_b * (hb - bevel) - ec * run_c
                    var p1_high: Vector3 = ea * sgn_a * ha + eb * sgn_b * (hb - bevel) + ec * run_c
                    var p2_low: Vector3 = ea * sgn_a * (ha - bevel) + eb * sgn_b * hb - ec * run_c
                    var p2_high: Vector3 = ea * sgn_a * (ha - bevel) + eb * sgn_b * hb + ec * run_c
                    _tri(st, p1_low, p1_high, p2_high, edge_normal)
                    _tri(st, p1_low, p2_high, p2_low, edge_normal)

    # ---- eight corner triangles ---------------------------------------------------------
    for sx in [-1.0, 1.0]:
        for sy in [-1.0, 1.0]:
            for sz in [-1.0, 1.0]:
                var fx: float = sx
                var fy: float = sy
                var fz: float = sz
                var corner_normal := Vector3(fx, fy, fz).normalized()
                var v1 := Vector3(fx * half.x, fy * (half.y - bevel), fz * (half.z - bevel))
                var v2 := Vector3(fx * (half.x - bevel), fy * half.y, fz * (half.z - bevel))
                var v3 := Vector3(fx * (half.x - bevel), fy * (half.y - bevel), fz * half.z)
                _tri(st, v1, v2, v3, corner_normal)

    return st.commit()

## Adds one triangle facing `outward`. Godot treats clockwise triangles as front faces, so the
## order is flipped when the geometric normal would otherwise point the wrong way.
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, outward: Vector3) -> void:
    var geometric: Vector3 = (p1 - p0).cross(p2 - p0)
    var first: Vector3 = p1
    var second: Vector3 = p2
    if geometric.dot(outward) > 0.0:
        first = p2
        second = p1
    st.set_normal(outward)
    st.add_vertex(p0)
    st.set_normal(outward)
    st.add_vertex(first)
    st.set_normal(outward)
    st.add_vertex(second)
