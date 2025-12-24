class_name Utils

static func format_currency(amount: int) -> String:
	if amount < 1000:
		return str(amount)
	
	var value = float(amount)
	var suffixes = ["", "k", "m", "b", "t"]
	var suffix_index = 0
	
	while value >= 1000.0 and suffix_index < suffixes.size() - 1:
		value /= 1000.0
		suffix_index += 1
	
	var suffix = suffixes[suffix_index]
	var text = ""
	
	# We want max 4 chars total including suffix.
	# value is now between 1.0 and 999.9...
	
	if value >= 100.0:
		# e.g., 100 to 999 -> "100k" (4 chars).
		# "999k" is 4 chars.
		# "100.1k" is 6 chars. So definitely just int here.
		text = "%d" % int(value)
	elif value >= 10.0:
		# e.g., 10.0 to 99.9. 
		# "10.1k" is 5 chars. User said "10.1k seems fine".
		# So we allow 1 decimal place here now.
		if is_equal_approx(value, floor(value)):
			text = "%d" % int(value)
		else:
			text = "%.1f" % value
			if text.ends_with(".0"): text = text.trim_suffix(".0")
	else:
		# e.g. 1.0 to 9.99...
		# "1.5k" -> 4 chars. Perfect.
		# "9.9k" -> 4 chars. Perfect.
		# "1.0k" -> "1k"? prefer "1k" likely.
		# Check if clean integer
		if is_equal_approx(value, floor(value)):
			text = "%d" % int(value)
		else:
			text = "%.1f" % value
			# remove .0 if it crept in? (Standard %.1f shouldn't round wildly)
			# But Wait, "1.0" with %.1f is "1.0".
			if text.ends_with(".0"):
				text = text.trim_suffix(".0")
	
	return text + suffix
