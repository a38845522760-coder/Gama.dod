extends ScrollContainer
class_name TouchScroll

## ScrollContainer that scrolls with a finger drag even when the drag starts on a button.
## Buttons normally swallow the touch; here every button inside passes it on to the scroller.

func _ready() -> void:
    scroll_deadzone = 14
    follow_focus = false
    get_tree().node_added.connect(_on_node_added)
    _fix_children(self)

func _exit_tree() -> void:
    if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)

func _on_node_added(node: Node) -> void:
    if is_ancestor_of(node):
        _fix_node(node)
        _fix_children(node)

func _fix_children(root: Node) -> void:
    for child in root.get_children():
        _fix_node(child)
        _fix_children(child)

func _fix_node(node: Node) -> void:
    if node is BaseButton:
        (node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
