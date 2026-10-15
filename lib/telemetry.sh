
TELEMETRY_FILE="$(unleash_user_home)/.unleash-telemetry"

telemetry_opt_in() {
	local val="${1:-}"
	case "$val" in
		on|yes|true|1)
			printf 'enabled\n' > "$TELEMETRY_FILE"
			success "Telemetry enabled"
			;;
		off|no|false|0)
			rm -f "$TELEMETRY_FILE"
			success "Telemetry disabled"
			;;
		*)
			local current="disabled"
			[ -f "$TELEMETRY_FILE" ] && current="enabled"
			info "Telemetry: $current"
			info "Usage: ./unleash telemetry on|off"
			info "No events are sent in this release; the flag only records your choice."
			;;
	esac
}

telemetry_is_enabled() {
	[ -f "$TELEMETRY_FILE" ] && return 0
	return 1
}

# Reserved for a future release; nothing calls it yet, so no data leaves the
# machine today.
telemetry_send() {
	telemetry_is_enabled || return 0
	local event="$1"
	local data="${2:-{\}}"
	local url="https://unleash-telemetry.mateussiqueira.workers.dev/event"
	local payload
	payload=$(printf '{"event":"%s","version":"%s","arch":"%s","os":"%s","data":%s}' \
		"$event" "$VERSION" "$(uname -m)" "$(uname -s)" "$data")
	curl -s -o /dev/null -H "Content-Type: application/json" \
		-d "$payload" "$url" 2>/dev/null || true
}
