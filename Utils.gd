class_name Utils

static func format_currency(amount, limit: float = 1000.0) -> String:
	# Delegates to Big so floats share the same O(1), overflow-safe
	# formatting (inf saturates to ∞ instead of hanging).
	return Big.of(float(amount)).format(limit)

static func with_commas(number) -> String:
	var f = float(number)
	var neg = f < 0.0
	f = abs(f)
	if f >= 1e15: # Past exact-int range; callers should be using suffixes
		return ("-" if neg else "") + "%.0f" % f
	var string = str(int(f))
	var mod = string.length() % 3
	var res = ""
	for i in range(0, string.length()):
		if i != 0 && (i % 3) == mod:
			res += ","
		res += string[i]
	return ("-" if neg else "") + res
