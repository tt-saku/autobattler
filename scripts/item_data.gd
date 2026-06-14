# item_data.gd
extends Resource
class_name ItemData

# 让它可在 Inspector 编辑
@export var id: String = ""
@export var name: String = ""
@export var size: int = 1   # 1 = 小, 2 = 中, 3 = 大
@export var cd_a: float = 1.0
@export var cd_b: float = 1.0

# 图片资源
@export var icon_a: Texture
@export var icon_b: Texture

# 文本描述
@export var effect_a: String
@export var effect_b: String
@export var flip_effect: String

# 其他扩展属性
# heroes : common , dooley , karnok , vanessa , pygmalien , mak , stelle , jules
@export var heroes: String = "common"
# tags : friend , core , food , loot , weapon , tool , toy , trap , apprael , aquatic...
@export var tags: Array = []
#rarity : bronze , silver , gold , diamond , legondary
@export var rarity: String = "bronze"
