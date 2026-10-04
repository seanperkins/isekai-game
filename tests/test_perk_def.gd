extends GutTest
## A perk is bought several times at a rising price: base plus the step for each earlier purchase.

func test_price_rises_by_the_step() -> void:
	var perk := PerkDef.new()
	perk.price_base = 5
	perk.price_step = 3
	assert_eq([perk.price_of(0), perk.price_of(1), perk.price_of(2)], [5, 8, 11])
