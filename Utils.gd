class_name Utils

static func format_currency(amount, limit: float = 1000.0) -> String:
	if abs(amount) < limit:
		return Utils.with_commas(amount)
	
	var is_negative = amount < 0
	var value = abs(float(amount))
	var suffixes = ["", "k", "m", "b", "t", "q", "Q"]
	var suffix_index = 0
	
	while value >= limit:
		value /= 1000.0
		suffix_index += 1
	
	# Standard Suffixes
	var suffix = ""
	
	# If we are within standard suffixes
	if suffix_index < suffixes.size():
		suffix = suffixes[suffix_index]
	else:
		# Dynamic Suffix Generation (aa, ab, ac...)
		# effective index starts at 0 for 'aa' when suffix_index is 7 (size of standard)
		var idx = suffix_index - suffixes.size()
		
		# alphabet size 26.
		# 0 -> aa, 25 -> az, 26 -> ba...
		var first_char = char(97 + (idx / 26)) # 'a' is 97
		var second_char = char(97 + (idx % 26))
		suffix = first_char + second_char
	
	var text = ""
	
	# We want max 4 chars total including suffix.
	# value is now between 1.0 and 999.9...
	
	if limit > 1000.0:
		text = Utils.with_commas(value)
	else:
		# Truncate to 1 decimal place to prevent rounding up (4.99k -> 5k is misleading if limit is 5k)
		value = floor(value * 10.0) / 10.0
		if value >= 100.0:
			text = "%d" % int(value)
		else:
			text = "%.1f" % value
			if text.ends_with(".0"): text = text.trim_suffix(".0")

	
	return ("-" if is_negative else "") + text + suffix

static func with_commas(number) -> String:
	var string = str(int(number))
	var mod = string.length() % 3
	var res = ""
	for i in range(0, string.length()):
		if i != 0 && (i % 3) == mod:
			res += ","
		res += string[i]
	return res
