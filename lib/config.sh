
# Home directory of the user who invoked the tool. It normally runs under
# sudo, where $HOME is /var/root, and the settings would land in the wrong
# place (and be invisible to the user).
unleash_user_home() {
	local u="${SUDO_USER:-}"
	case "$u" in
		""|root) printf '%s' "${HOME:-/var/root}" ;;
		*) if [ -d "/Users/$u" ]; then
			printf '%s' "/Users/$u"
		else
			printf '%s' "${HOME:-/var/root}"
		fi ;;
	esac
}

CONFIG_FILE="$(unleash_user_home)/.unleash.conf"

load_config() {
	[ -f "$CONFIG_FILE" ] || return 0

	local line key value
	# `read` alone would silently drop a final line with no trailing newline.
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
			""|\#*) continue ;;
		esac
		key="${line%%=*}"
		[ "$key" = "$line" ] && continue
		value="${line#*=}"
		key="${key% }"
		key="${key# }"
		case "$key" in
			WEBHOOK) DISCORD_WEBHOOK="$value" ;;
			LOG_LEVEL) [ "$value" = "verbose" ] && VERBOSE=true ;;
			LOG_FILE) LOG_FILE="$value" ;;
		esac
	done < "$CONFIG_FILE"
}

valid_config_key() {
	case "$1" in
		WEBHOOK|LOG_LEVEL|LOG_FILE) return 0 ;;
		*) return 1 ;;
	esac
}

# The file is rewritten with grep+mv rather than sed: a value containing "/"
# or "&" used to break the sed replacement expression, and `set -e` then
# killed the whole script on `unleash config set WEBHOOK https://...`.
save_config() {
	local key="$1"
	local value="$2"
	local tmp="$CONFIG_FILE.tmp.$$"

	valid_config_key "$key" || error_exit "Unknown setting: $key (expected WEBHOOK, LOG_LEVEL or LOG_FILE)"
	case "$value" in
		*$'\n'*) error_exit "The value must be a single line" ;;
	esac

	touch "$CONFIG_FILE"
	grep -v "^${key}=" "$CONFIG_FILE" > "$tmp" 2>/dev/null || true
	printf '%s=%s\n' "$key" "$value" >> "$tmp"
	mv "$tmp" "$CONFIG_FILE"
	chmod 600 "$CONFIG_FILE" 2>/dev/null || true
	success "Saved $key to $CONFIG_FILE"
}

remove_config_key() {
	local key="$1"
	local tmp="$CONFIG_FILE.tmp.$$"
	[ -f "$CONFIG_FILE" ] || return 0
	grep -v "^${key}=" "$CONFIG_FILE" > "$tmp" 2>/dev/null || true
	mv "$tmp" "$CONFIG_FILE"
}

cmd_config() {
	header "Configuration"

	case "${2:-show}" in
		show)
			step "Config file: $CONFIG_FILE"
			if [ ! -f "$CONFIG_FILE" ]; then
				info "No config file yet."
				info "Create one with: ./unleash config set KEY VALUE"
				return 0
			fi
			sed 's/^/  /' "$CONFIG_FILE"
			;;
		set)
			local key="${3:-}"
			local value="${4:-}"
			[ -z "$key" ] || [ -z "$value" ] && {
				info "Usage: ./unleash config set KEY VALUE"
				info "Keys: WEBHOOK, LOG_LEVEL (verbose), LOG_FILE"
				return 1
			}
			save_config "$key" "$value"
			;;
		unset)
			local key="${3:-}"
			[ -z "$key" ] && { info "Usage: ./unleash config unset KEY"; return 1; }
			if [ -f "$CONFIG_FILE" ]; then
				remove_config_key "$key"
				success "Removed $key from config"
			fi
			;;
		*)
			info "Usage: ./unleash config {show|set KEY VALUE|unset KEY}"
			;;
	esac
}
