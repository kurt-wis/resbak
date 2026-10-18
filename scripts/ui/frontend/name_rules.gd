class_name NameRules
extends RefCounted

## Player-name rules (docs/RESBAK.md § 6 Setup, § 10): 3 to 16 characters after trim, letters
## (including Ñ ñ), digits and spaces, a local Filipino + English blocklist matched
## case-insensitively. The dice picks from DICE_NAMES (>= 20; every one passes validate()).

const MIN_LEN := 3
const MAX_LEN := 16

const DICE_NAMES := [
	"Batang Ulan", "Siga ng Kanto", "Kuya Tricycle", "Ate Sarisari", "Tsinelas Ninja",
	"Mang Tonyo Jr", "Bilis ng Hangin", "Tambay Prince", "Palengke Queen", "Taya Master",
	"Lakad Pogi", "Sipa Champion", "Batang Kalye", "Ginoong Tsinelas", "Hari ng Tumbang",
	"Kidlat sa Eskina", "Bida ng Purok", "Kapitan Piko", "Ninong Tambay", "Aling Nena",
	"Dyip Driver", "Pandesal Boy", "Taho Warrior", "Isaw Master", "Bantay Base",
	"Sakay Lang", "Tuko sa Poste", "Bilis ng Pagong", "Ñoño Runner", "Lola Bantay",
]

const BLOCKLIST := [
	"fuck", "shit", "bitch", "bastard", "asshole", "dick", "cock", "pussy", "slut", "whore",
	"nigger", "nigga", "faggot", "retard", "cunt", "rape", "nazi", "hitler",
	"putang", "puta", "gago", "tangina", "tanga", "bobo", "ulol", "tarantado", "pakyu",
	"leche", "kantot", "burat", "pekpek", "titi", "puki", "inutil", "siraulo",
]

## Returns {ok, name, reason}. `name` is the trimmed, space-collapsed name.
static func validate(raw: String) -> Dictionary:
	var n := raw.strip_edges()
	while "  " in n:
		n = n.replace("  ", " ")
	if n.length() < MIN_LEN:
		return {"ok": false, "name": n, "reason": "Masyadong maikli (3 hanggang 16). Too short."}
	if n.length() > MAX_LEN:
		return {"ok": false, "name": n, "reason": "Masyadong mahaba (3 hanggang 16). Too long."}
	for i in range(n.length()):
		var ch := n.unicode_at(i)
		var okc := (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 32 or ch == 0xD1 or ch == 0xF1
		if not okc:
			return {"ok": false, "name": n, "reason": "Letra, numero at espasyo lang. Letters, digits, spaces only."}
	var squashed := n.to_lower().replace(" ", "").replace("ñ", "n")
	for bad in BLOCKLIST:
		if squashed.contains(String(bad)):
			return {"ok": false, "name": n, "reason": "Hindi pwede ang pangalang ito. That name is not allowed."}
	return {"ok": true, "name": n, "reason": ""}

static func dice(rng: RandomNumberGenerator = null, avoid := "") -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var n: String = DICE_NAMES[rng.randi() % DICE_NAMES.size()]
	if n == avoid:
		n = DICE_NAMES[(DICE_NAMES.find(n) + 1) % DICE_NAMES.size()]
	return n
