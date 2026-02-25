class_name ViewModelBase
extends Node

signal property_changed(property_name: String, value: Variant)

func _notify_property_change(prop: String, value: Variant):
	property_changed.emit(prop, value)
