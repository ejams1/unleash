# shellcheck shell=bash

VPN_RULES_ANCHOR="com.unleash/vpn-kill"
VPN_RULES_FILE="/etc/pf.anchors/com.unleash/vpn-kill"

# vpn_kill_install [--interface utunX]
vpn_kill_install() {
	header "VPN Kill-Switch — MDM Leak Protection"

	if ! is_root && ! is_dry_run; then
		error_exit "VPN kill-switch needs sudo: sudo ./unleash vpn-kill"
	fi

	# Parse --interface/-i explicitly: the flag itself used to be taken as the
	# interface name because the argument was read positionally.
	local user_if=""
	while [ $# -gt 0 ]; do
		case "$1" in
			--interface|-i)
				[ $# -ge 2 ] || error_exit "$1 requires an interface name (e.g. --interface utun4)"
				user_if="$2"
				shift 2
				;;
			*) shift ;;
		esac
	done

	if is_dry_run; then
		if [ -n "$user_if" ]; then
			info "[DRY RUN] Would install the VPN kill-switch for $user_if"
		else
			info "[DRY RUN] Would detect the VPN interface and install the kill-switch"
		fi
		return 0
	fi

	local vpn_if="$user_if"
	if [ -z "$vpn_if" ]; then
		step "Detecting active VPN interfaces..."
		local interfaces iface addr
		interfaces=$(ifconfig 2>/dev/null | grep -E "^utun[0-9]+:" | sed 's/:.*//' || true)
		# utun0-3 exist on a stock macOS without any VPN, so take the last
		# interface that actually has an address and say which one was used.
		for iface in $interfaces; do
			addr=$(ifconfig "$iface" 2>/dev/null | awk '/inet /{print $2}')
			if [ -n "$addr" ]; then
				echo "   $iface: $addr"
				vpn_if="$iface"
			fi
		done
		if [ -z "$vpn_if" ]; then
			warn "No VPN interface with an address found."
			info "Re-run with an explicit interface: sudo ./unleash vpn-kill --interface utun4"
			return 1
		fi
		info "Using $vpn_if (override with --interface)"
	fi

	if skip_if_dry_run "install the VPN kill-switch for $vpn_if"; then
		return 0
	fi

	step "Installing pf rules for VPN kill-switch..."
	local anchor_dir="/etc/pf.anchors/com.unleash"
	mkdir -p "$anchor_dir"

	# pf stops at the first matching rule, so the VPN pass has to be written
	# before the block; with the block first the pass rules never matched and
	# Apple traffic was dropped on every interface, VPN or not.
	cat > "$VPN_RULES_FILE" << RULES
# Unleash VPN kill-switch
# Apple MDM ranges are allowed only through $vpn_if.
# If the tunnel drops, the traffic falls through to the block below.
pass out on $vpn_if
block drop out proto {tcp,udp} to {17.0.0.0/8, 17.128.0.0/10}
RULES
	chmod 644 "$VPN_RULES_FILE"
	success "VPN kill-switch rules installed for $vpn_if"

	local pf_conf="/etc/pf.conf"
	local anchor_line="anchor \"${VPN_RULES_ANCHOR}\""
	local load_line="load anchor \"${VPN_RULES_ANCHOR}\" from \"${VPN_RULES_FILE}\""

	if [ -f "$pf_conf" ]; then
		if grep -q "vpn-kill" "$pf_conf" 2>/dev/null; then
			info "pf.conf already has VPN kill-switch anchor"
		else
			echo "" >> "$pf_conf"
			echo "# Added by unleash — VPN kill-switch (prevents MDM leaks)" >> "$pf_conf"
			echo "$anchor_line" >> "$pf_conf"
			echo "$load_line" >> "$pf_conf"
		fi
	fi

	pfctl -e -f "$pf_conf" 2>/dev/null && success "VPN kill-switch active" \
		|| warn "pfctl failed"

	echo ""
	info "What this does:"
	info "  - Allows MDM traffic out through $vpn_if"
	info "  - Blocks MDM Apple IP ranges (17.0.0.0/8) everywhere else"
	info "  - If the VPN drops, MDM traffic is blocked — no leaks"
	echo ""
	warn "This does NOT affect your regular internet traffic."
	warn "Only MDM-related IPs are affected by the kill-switch."
}

vpn_kill_remove() {
	header "Remove VPN Kill-Switch"

	if ! is_root && ! is_dry_run; then
		error_exit "Needs sudo: sudo ./unleash vpn-kill-remove"
	fi

	if skip_if_dry_run "remove the VPN kill-switch"; then
		return 0
	fi

	if [ -f "$VPN_RULES_FILE" ]; then
		rm -f "$VPN_RULES_FILE"
		success "VPN kill-switch rules removed"
	fi

	local pf_conf="/etc/pf.conf"
	if [ -f "$pf_conf" ]; then
		sed -i '' '/# Added by unleash — VPN kill-switch/d' "$pf_conf" 2>/dev/null || true
		sed -i '' '/vpn-kill/d' "$pf_conf" 2>/dev/null || true
		success "pf.conf cleaned"
	fi

	pfctl -a "$VPN_RULES_ANCHOR" -F all 2>/dev/null || true
	success "pf anchor flushed"
}

vpn_kill_status() {
	step "VPN kill-switch status"
	if [ -f "$VPN_RULES_FILE" ]; then
		echo "  Rules file: $VPN_RULES_FILE"
		cat "$VPN_RULES_FILE" | sed 's/^/    /'
	else
		echo "  No VPN kill-switch installed"
	fi
	if command -v pfctl >/dev/null 2>&1; then
		echo ""
		pfctl -a "$VPN_RULES_ANCHOR" -s rules 2>/dev/null \
			&& echo "  Anchor loaded" \
			|| echo "  Anchor not loaded"
	fi
}
