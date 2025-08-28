# res://entities/components/tag_component.gd
extends Node
class_name TagComponent

# 使用一个 Dictionary 来存储标签，值可以是true或任何元数据
# 但为了简单起见，我们先用 PackedStringArray
@export var tags: PackedStringArray = []

func has_tag(tag_name: String) -> bool:
    return tags.has(tag_name)

func add_tag(tag_name: String):
    if not has_tag(tag_name):
        tags.append(tag_name)
        print("Entity now has tag: ", tag_name)

func remove_tag(tag_name: String):
    if has_tag(tag_name):
        var index = tags.find(tag_name)
        if index != -1:
            tags.remove_at(index)
            print("Entity lost tag: ", tag_name)

func get_tags() -> PackedStringArray:
    return tags