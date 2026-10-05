class_name AreaRegistry
extends RefCounted
## The area modules the builder runs, in the order they build (a later one may attach to an earlier one's rooms).

static func modules() -> Array:
	return [ForestArea.new(), SwampArea.new(), VillageArea.new(), CemeteryArea.new(), CathedralArea.new(), CryptArea.new(), VolcanoArea.new()]
