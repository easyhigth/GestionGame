class_name CityMerchant
extends RefCounted
## Boutique d'un marchand de capitale : un stock selon son métier (voir CityPlans.TRADES), des prix calculés
## comme ceux du marchand ambulant, plus doux si l'on est en bons termes avec sa nation. Il rachète tout ce qui
## a de la valeur. En guerre, il refuse de commercer.

var stock: Array = []
var sold_count := {}
var trade_name := ""
var city_name := ""
var nation := ""
var seller_name := ""
var _trade: Trade


func _init(trade: Trade, city: Dictionary, trade_id: String, seller: String, rng: RandomNumberGenerator) -> void:
	_trade = trade
	trade_name = trade_id
	city_name = city.name
	nation = city.nation
	seller_name = seller
	for id in CityPlans.TRADES.get(trade_id, []):
		var it := Items.get_item(id) as ItemData
		if it == null:
			continue
		var p := buy_price(it)
		if p <= 0:
			continue
		var n := rng.randi_range(4, 16) if it.max_stack > 1 else rng.randi_range(1, 2)
		stock.append({"id": id, "n": n, "price": p, "cat": trade_id})


func _dip() -> Diplomacy:
	return _trade.get_tree().get_first_node_in_group("diplomacy") as Diplomacy if _trade and _trade.is_inside_tree() else null


## Remise (ou majoration) selon les relations avec la nation du marchand : de -20 % à +20 % (-25 % / +25 % dans une province).
func _rel_mult(buying: bool) -> float:
	var dip := _dip()
	if dip == null or not dip.states.has(nation):
		return 1.0
	if dip.annexed(nation):
		return 0.75 if buying else 1.25    # ta province : les meilleurs prix
	var k := clampf(dip.rel(nation) / 100.0, -1.0, 1.0) * 0.2
	return 1.0 - k if buying else 1.0 + k


## Commerce possible ? (« » si oui, sinon la raison.)
func refusal() -> String:
	var dip := _dip()
	if dip and dip.states.has(nation) and dip.at_war(nation) and not dip.annexed(nation):
		return "« Nous ne commerçons pas avec l'ennemi ! »"
	return ""


func is_here() -> bool:
	return true


func gold(p: Player) -> int:
	return _trade.gold(p)


func buy_price(it: ItemData) -> int:
	var v := _trade.value_of(it)
	if v <= 0.0:
		return 0
	return maxi(sell_price(it, 0) + 1, ceili(v * Trade.BUY_MULT * 0.9 * _rel_mult(true)))


func sell_price(it: ItemData, already := -1) -> int:
	var v := _trade.value_of(it)
	if v <= 0.0 or it.id == "piece_or":
		return 0
	var n: int = int(sold_count.get(it.id, 0)) if already < 0 else already
	var sat := maxf(Trade.SATURATION_MIN, 1.0 - Trade.SATURATION_STEP * n)
	var mult := Trade.SELL_MULT * _rel_mult(false)
	if v * mult < 0.5:
		return 0
	return maxi(1, roundi(v * mult * sat))


func buy(p: Player, entry: Dictionary, n := 1) -> String:
	var no := refusal()
	if no != "":
		return no
	n = mini(n, int(entry.n))
	if n <= 0:
		return "Plus en stock."
	var cost: int = int(entry.price) * n
	if gold(p) < cost:
		return "Pas assez d'or (%d pièces, il en faut %d)." % [gold(p), cost]
	var it := Items.get_item(entry.id)
	p.inventory.remove(Items.get_item("piece_or"), cost)
	p.inventory.add(it, n)
	entry.n = int(entry.n) - n
	if entry.n <= 0:
		stock.erase(entry)
	Sound.ui("coins")
	_trade.bought.emit(it.id, n, cost)
	return ""


func sell(p: Player, it: ItemData, n := 1) -> int:
	if refusal() != "":
		return 0
	n = mini(n, p.inventory.count(it))
	var total := 0
	var done := 0
	for i in n:
		var price := sell_price(it)
		if price <= 0 or not p.inventory.remove(it, 1):
			break
		total += price
		done += 1
		sold_count[it.id] = int(sold_count.get(it.id, 0)) + 1
	if total > 0:
		p.inventory.add(Items.get_item("piece_or"), total)
		Sound.ui("coins")
		_trade.sold.emit(it.id, done, total)
	return total
