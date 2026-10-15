# shellcheck shell=bash

# Count matching lines, returning 0 rather than an empty value when the file
# is missing or has no matches. `grep -c` prints 0 and exits 1 when it finds
# nothing, so `|| echo 0` yields "0\n0" and breaks every [ -gt ] test.
count_lines() {
	local matches=0
	matches=$(grep -c "$1" "$2" 2>/dev/null || true)
	printf '%s' "${matches:-0}"
}

# Number of installed configuration profiles (0 when none/detection fails).
count_profiles() {
	local profiles=0
	if command -v profiles >/dev/null 2>&1; then
		# -output xml writes files into the CWD; stdout-xml prints to stdout.
		profiles=$(sudo profiles -C -output stdout-xml 2>/dev/null | grep -c "ProfileDisplayName" || true)
		profiles="${profiles:-0}"
	fi
	printf '%s' "$profiles"
}

check_mdm_status() {
	local data_mount="$1"
	local hosts="$data_mount/private/etc/hosts"
	local cfg="$data_mount/private/var/db/ConfigurationProfiles/Settings"
	local ldp="$data_mount/private/var/db/com.apple.xpc.launchd/disabled.plist"
	local expected=13

	header "MDM Status Report"

	step "DEP markers ($cfg)"
	if [ -d "$cfg" ]; then
		for f in \
			.cloudConfigHasActivationRecord \
			.cloudConfigRecordFound \
			.cloudConfigRecordNotFound \
			.cloudConfigProfileInstalled \
			.cloudConfigTimerCheck; do
			if [ -f "$cfg/$f" ]; then
				echo -e "  ${GRN}$f${NC} — present"
			else
				echo -e "  ${YEL}$f${NC} — absent"
			fi
		done
	else
		warn "Settings directory not found"
	fi
	echo ""

	step "Blocked domains in hosts"
	if [ -f "$hosts" ]; then
		local matches
		matches=$(grep -iE 'iprofiles|enrollment|mdm|acmdm|albert|gdmf|configuration|xp\.apple|gs\.apple|tb\.apple' "$hosts" 2>/dev/null || true)
		if [ -n "$matches" ]; then
			echo "$matches" | while IFS= read -r line; do
				echo -e "  ${GRN}$line${NC}"
			done
		else
			echo -e "  ${YEL}(none)${NC}"
		fi
		local count
		count=$(count_lines '^0\.0\.0\.0 ' "$hosts")
		if [ "${#MDM_DOMAINS[@]}" -gt 0 ]; then
			expected="${#MDM_DOMAINS[@]}"
		fi
		echo -e "  ${CYAN}Total: $count of $expected expected domains blocked${NC}"
	else
		echo -e "  ${YEL}(hosts not found)${NC}"
	fi
	echo ""

	step "Enrollment daemon status"
	if [ -f "$ldp" ]; then
		$PB -c "Print" "$ldp" 2>/dev/null || echo -e "  ${YEL}(empty/corrupt)${NC}"
	else
		echo -e "  ${YEL}(no override)${NC}"
	fi
	echo ""

	step "Profiles enrollment status"
	if command -v profiles >/dev/null 2>&1; then
		profiles status -type enrollment 2>/dev/null \
			|| echo -e "  ${YEL}Cannot check (expected in Recovery)${NC}"
	else
		echo -e "  ${YEL}'profiles' not available${NC}"
	fi
	echo ""

	step "Backup status"
	if has_backup; then
		echo -e "  ${GRN}Backup exists:${NC} $(cat "$BACKUP_DIR/timestamp")"
	else
		echo -e "  ${YEL}No backup${NC}"
	fi
	echo ""

	if [ -f "$cfg/.cloudConfigRecordFound" ]; then
		local org
		org=$(plutil -convert xml1 -o - "$cfg/.cloudConfigRecordFound" 2>/dev/null \
			| grep -iA1 OrganizationName | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
		[ -n "$org" ] && echo -e "${YEL}Active DEP record found — device assigned to: $org${NC}"
	else
		echo -e "${GRN}No active DEP record.${NC}"
	fi
}

# deep_status [--json] [data_mount]
deep_status() {
	local data_mount="${1:-}"
	local cfg="${data_mount}/private/var/db/ConfigurationProfiles/Settings"

	if [ "$data_mount" = "--json" ]; then
		deep_status_json ""
		return
	fi
	header "Deep MDM Audit"

	step "Installed Configuration Profiles"
	local profile_count
	profile_count=$(count_profiles)
	if command -v profiles >/dev/null 2>&1; then
		if [ "$profile_count" -gt 0 ]; then
			warn "$profile_count profile(s) installed:"
			sudo profiles -C -output stdout-xml 2>/dev/null | grep -A1 "ProfileDisplayName" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/  - \1/'
		else
			info "No configuration profiles installed"
		fi
	else
		warn "profiles command not available"
	fi
	echo ""

	step "MDM Enrollment State"
	if command -v profiles >/dev/null 2>&1; then
		sudo profiles status -type enrollment 2>/dev/null || echo "  Cannot determine"
	fi
	echo ""

	step "MDM Identity Certificates (Keychain)"
	if command -v security >/dev/null 2>&1; then
		local mdm_certs
		mdm_certs=$(sudo security find-identity -p basic 2>/dev/null | grep -ci "mdm\|MDM\|Apple.*Push" || true)
		mdm_certs="${mdm_certs:-0}"
		if [ "$mdm_certs" -gt 0 ]; then
			warn "$mdm_certs MDM-related certificate(s) found"
			sudo security find-identity -p basic 2>/dev/null | grep -i "mdm\|Apple.*Push"
		else
			info "No MDM certificates found in keychain"
		fi
	else
		warn "security command not available"
	fi
	echo ""

	step "MDM LaunchAgents (User)"
	local found=0
	for home in /Users/*/; do
		[ -d "$home/Library/LaunchAgents" ] || continue
		local user_agents=""
		local _agent _name _lower
		for _agent in "$home/Library/LaunchAgents/"*; do
			[ -f "$_agent" ] || continue
			_name=${_agent##*/}
			_lower=$(printf '%s' "$_name" | tr '[:upper:]' '[:lower:]')
			case "$_lower" in
				*mdm*|*enrollment*|*managed*) user_agents="$user_agents $_name" ;;
			esac
		done
		if [ -n "$user_agents" ]; then
			local who="${home%/}"
			who="${who##*/}"
			echo -e "  ${YEL}${who}:${NC}"
			echo "$user_agents" | sed 's/^/    /'
			found=$((found + 1))
		fi
	done
	if [ "$found" -eq 0 ]; then
		info "No MDM LaunchAgents found in any user"
	fi
	echo ""

	step "MDM LaunchDaemons (System)"
	local sys_agents=""
	local _daemon _dname _dlower
	for _daemon in /Library/LaunchDaemons/*; do
		[ -f "$_daemon" ] || continue
		_dname=${_daemon##*/}
		_dlower=$(printf '%s' "$_dname" | tr '[:upper:]' '[:lower:]')
		case "$_dlower" in
			*mdm*|*enrollment*|*managed*) sys_agents="$sys_agents $_dname" ;;
		esac
	done
	if [ -n "$sys_agents" ]; then
		echo "$sys_agents" | sed 's/^/  /'
	else
		info "No MDM LaunchDaemons found"
	fi
	echo ""

	step "Running MDM Processes"
	local procs
	procs=$(ps aux 2>/dev/null | grep -iE "mdm|managedclient|activation" | grep -v grep || true)
	if [ -n "$procs" ]; then
		echo "$procs" | awk '{print "  " $11 " (PID " $2 ")"}'
	else
		info "No MDM processes running"
	fi
	echo ""

	step "MDM Agent Binaries"
	for agent_bin in /usr/local/bin/jamf /usr/local/bin/jamfagent /opt/jamf/bin/jamf \
		/usr/local/bin/intune /usr/local/bin/microsoft-intune \
		/Applications/Jamf* /Applications/Microsoft\ Intune* /Applications/VMware\ Workspace*; do
		if [ -e "$agent_bin" ]; then
			warn "Agent binary found: $agent_bin"
		fi
	done
	info "Scan complete"
	echo ""

	step "Firewall Status"
	pf_status 2>/dev/null || info "pf firewall check skipped"

	step "Overall Assessment"
	local risk="LOW"
	[ "$profile_count" -gt 0 ] && risk="MEDIUM"
	ps aux 2>/dev/null | grep -qiE "mdm|managedclient" && risk="HIGH"
	[ -f "$cfg/.cloudConfigRecordFound" ] && risk="CRITICAL"

	case "$risk" in
		LOW) echo -e "  ${GRN}Risk: $risk — Device appears clean${NC}" ;;
		MEDIUM) echo -e "  ${YEL}Risk: $risk — Residual profiles detected${NC}" ;;
		HIGH) echo -e "  ${RED}Risk: $risk — MDM processes still running${NC}" ;;
		CRITICAL) echo -e "  ${RED}Risk: $risk — Active DEP record found${NC}" ;;
	esac
}

deep_status_json() {
	local data_mount="${1:-}"
	local cfg="${data_mount}/private/var/db/ConfigurationProfiles/Settings"

	local json=""
	json="${json}{\n"
	json="${json}  \"version\": \"$VERSION\",\n"
	json="${json}  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",\n"

	local profile_count=0
	profile_count=$(count_profiles)
	json="${json}  \"profile_count\": $profile_count,\n"

	local enroll_state="unknown"
	if command -v profiles >/dev/null 2>&1; then
		enroll_state=$(sudo profiles status -type enrollment 2>/dev/null | head -1 | xargs || echo "unknown")
	fi
	enroll_state="${enroll_state:-unknown}"
	enroll_state="${enroll_state//\"/\\\"}"
	json="${json}  \"enrollment_state\": \"${enroll_state}\",\n"

	local mdm_certs=0
	if command -v security >/dev/null 2>&1; then
		mdm_certs=$(sudo security find-identity -p basic 2>/dev/null | grep -ci "mdm\|MDM\|Apple.*Push" || true)
		mdm_certs="${mdm_certs:-0}"
	fi
	json="${json}  \"mdm_certificates\": $mdm_certs,\n"

	local running_procs=0
	running_procs=$(ps aux 2>/dev/null | grep -ciE "mdm|managedclient|activation" || true)
	running_procs="${running_procs:-0}"
	running_procs=$((running_procs - 1))
	[ "$running_procs" -lt 0 ] && running_procs=0
	json="${json}  \"running_mdm_processes\": $running_procs,\n"

	local risk="LOW"
	[ "$profile_count" -gt 0 ] && risk="MEDIUM"
	[ "$running_procs" -gt 0 ] && risk="HIGH"
	[ -f "$cfg/.cloudConfigRecordFound" ] && risk="CRITICAL"
	json="${json}  \"risk_score\": \"${risk}\"\n"

	json="${json}}"
	echo -e "$json"
}
