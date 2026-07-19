class_name Big
extends RefCounted

# Idle-scale number: value = m * 10^e, mantissa normalized to 1 <= |m| < 10
# (or m == 0). ~15 significant digits, range 10^±9e15. All ops are O(1);
# formatting is exponent arithmetic, so no divide loops and nothing to
# overflow — non-finite inputs saturate to the exponent cap instead of inf.

const EXP_CAP: int = 9_000_000_000_000_000

const SUFFIXES = ["", "k", "m", "b", "t", "q", "Q"]

var m: float = 0.0
var e: int = 0

static func zero() -> Big:
	return Big.new()

static func of(x: float) -> Big:
	if is_nan(x): return Big.new()
	if is_inf(x): return parts(1.0 if x > 0 else -1.0, EXP_CAP)
	return parts(x, 0)

static func parts(mantissa: float, exponent: int) -> Big:
	var b = Big.new()
	b.m = mantissa
	b.e = exponent
	return b._norm()

static func from_log10(l: float) -> Big:
	# Positive value from its base-10 log; -inf gives zero.
	if is_nan(l) or l == -INF: return Big.new()
	if l == INF or l >= EXP_CAP: return parts(1.0, EXP_CAP)
	var ex = floor(l)
	var mant = pow(10.0, l - ex)
	# Snap log round-trip wobble (10^log10(5000) = 4.9999...) so displays
	# don't floor a clean 5k down to 4.9k
	if abs(mant - round(mant)) < 1e-9: mant = round(mant)
	return parts(mant, int(ex))

func _norm() -> Big:
	if is_nan(m): m = 0.0
	if m == 0.0:
		e = 0
		return self
	if is_inf(m):
		m = 1.0 if m > 0 else -1.0
		e = EXP_CAP
		return self
	var ae = floor(log10_f(abs(m)))
	if ae != 0.0:
		m = m / pow(10.0, ae)
		e += int(ae)
	# Guard float rounding at the bucket edges
	if abs(m) >= 10.0:
		m /= 10.0
		e += 1
	elif abs(m) < 1.0:
		m *= 10.0
		e -= 1
	if e >= EXP_CAP:
		e = EXP_CAP
	elif e <= -EXP_CAP: # Underflow to zero
		m = 0.0
		e = 0
	return self

func copy() -> Big:
	var b = Big.new()
	b.m = m
	b.e = e
	return b

func is_zero() -> bool:
	return m == 0.0

func signum() -> int:
	return 0 if m == 0.0 else (1 if m > 0.0 else -1)

func neg() -> Big:
	var b = copy()
	b.m = -b.m
	return b

func add(o: Big) -> Big:
	if is_zero(): return o.copy()
	if o.is_zero(): return copy()
	var d = e - o.e
	# Beyond ~17 digits apart the smaller operand is below the mantissa's
	# precision and contributes nothing.
	if d > 17: return copy()
	if d < -17: return o.copy()
	return Big.parts(m + o.m * pow(10.0, -d), e)

func sub(o: Big) -> Big:
	return add(o.neg())

func mul(o: Big) -> Big:
	if is_zero() or o.is_zero(): return Big.new()
	return Big.parts(m * o.m, e + o.e)

func mul_f(f: float) -> Big:
	return mul(Big.of(f))

func div(o: Big) -> Big:
	if o.is_zero(): return Big.parts(1.0 * signum(), EXP_CAP) # Saturate, no inf
	if is_zero(): return Big.new()
	return Big.parts(m / o.m, e - o.e)

func cmp(o: Big) -> int:
	var s = signum()
	var so = o.signum()
	if s != so: return -1 if s < so else 1
	if s == 0: return 0
	# Same nonzero sign: larger exponent wins (inverted for negatives)
	if e != o.e:
		var by_exp = 1 if e > o.e else -1
		return by_exp * s
	if m == o.m: return 0
	return (1 if m > o.m else -1)

func gt(o: Big) -> bool: return cmp(o) > 0
func gte(o: Big) -> bool: return cmp(o) >= 0
func lt(o: Big) -> bool: return cmp(o) < 0
func lte(o: Big) -> bool: return cmp(o) <= 0

func to_float() -> float:
	# Saturates instead of returning inf.
	if e > 307: return 1.7976e308 * signum()
	if e < -307: return 0.0
	return m * pow(10.0, e)

func lg() -> float:
	# Base-10 log of the magnitude; -inf for zero.
	if is_zero(): return -INF
	return log10_f(abs(m)) + float(e)

static func log10_f(x: float) -> float:
	return log(x) / log(10.0)

func ratio(denom: Big) -> float:
	# Clamped 0..1 — for progress bars.
	if denom.is_zero() or signum() <= 0: return 0.0
	return clamp(div(denom).to_float(), 0.0, 1.0)

func format(plain_limit: float = 1000.0) -> String:
	var s = signum()
	if s == 0: return "0"
	if e >= EXP_CAP: return ("-" if s < 0 else "") + "∞"
	var sign_str = "-" if s < 0 else ""
	if e < 15:
		var f = abs(to_float())
		if f < plain_limit:
			return sign_str + Utils.with_commas(f)
	var g = e / 3
	var lead = abs(m) * pow(10.0, e % 3)
	# Floor to 1 decimal so 4.99k never displays as 5k
	lead = floor(lead * 10.0) / 10.0
	var lead_txt: String
	if lead >= 100.0:
		lead_txt = "%d" % int(lead)
	else:
		lead_txt = ("%.1f" % lead).trim_suffix(".0")
	var suffix: String
	if g < SUFFIXES.size():
		suffix = SUFFIXES[g]
	else:
		var idx = g - SUFFIXES.size()
		if idx < 676: # aa..zz
			suffix = char(97 + idx / 26) + char(97 + idx % 26)
		else:
			return sign_str + "%.2fe%d" % [abs(m), e]
	return sign_str + lead_txt + suffix

func to_save():
	return {"m": m, "e": e}

static func from_save(v) -> Big:
	# Accepts the {m, e} dict, or a plain number from pre-Big saves.
	if v is Dictionary:
		return parts(float(v.get("m", 0.0)), int(v.get("e", 0)))
	if v is float or v is int:
		return of(float(v))
	return Big.new()
