extends VBoxContainer
class_name ItemInspectPanel

## Shared, deliberately small item-inspection presentation component.
## It only renders an item's name and short description. Decision rules remain
## in the owning interaction (LockerCleanup or DeskCleanup).

@onready var item_name: Label = $ItemName
@onready var description: Label = $Description


func present_item(item: Dictionary) -> void:
	item_name.text = str(item.get("display_name", "物品"))
	description.text = str(item.get("description", ""))
