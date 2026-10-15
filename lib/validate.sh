
# Messages go to stdout so callers can capture them; the exit status carries
# the verdict. (They used to go to stderr, so `msg=$(validate_username ...)`
# was always empty and the warning line rendered with no text.)
validate_username() {
	local u="$1"
	[ -n "$u" ] || { echo "Username cannot be empty"; return 1; }
	[ ${#u} -le 31 ] || { echo "Username too long (max 31 chars)"; return 1; }
	case "$u" in
		*[!a-zA-Z0-9_-]*) echo "Use only letters, numbers, underscore, hyphen"; return 1 ;;
		[!a-zA-Z_]*) echo "Must start with a letter or underscore"; return 1 ;;
	esac
	return 0
}

validate_password() {
	[ -n "$1" ] || { echo "Password cannot be empty"; return 1; }
	[ ${#1} -ge 4 ] || { echo "Minimum 4 characters"; return 1; }
	return 0
}

prompt_username() {
	local var_name="$1"
	local value="" msg=""
	while true; do
		read -r -p "Username (default 'Apple'): " value || value=""
		[ -n "$value" ] || value="Apple"
		if msg=$(validate_username "$value"); then
			printf -v "$var_name" '%s' "$value"
			return 0
		fi
		warn "$msg"
	done
}

prompt_password() {
	local var_name="$1"
	local value="" msg=""
	while true; do
		read -r -s -p "Password (default '1234'): " value || value=""
		echo ""
		[ -n "$value" ] || value="1234"
		if msg=$(validate_password "$value"); then
			printf -v "$var_name" '%s' "$value"
			return 0
		fi
		warn "$msg"
	done
}
