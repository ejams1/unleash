# shellcheck shell=bash

MDM_BLOCKLIST="mdmenrollment.apple.com deviceenrollment.apple.com iprofiles.apple.com"

install_selective_block() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"

  step "Installing selective pf rules (block MDM only, allow Apple services)..."

  if skip_if_dry_run "resolve the MDM hostnames and install the selective pf block"; then
    return 0
  fi

  local anchor_dir="${root}/etc/pf.anchors"
  local anchor_file="${anchor_dir}/com.unleash.selective"
  mkdir -p "$anchor_dir"

  : > "$anchor_file"

  local rules=0 d ip
  for d in $MDM_BLOCKLIST; do
    for ip in $(host -t a "$d" 2>/dev/null | awk '/has address/{print $NF}'); do
      echo "block drop out proto {tcp,udp} to {$ip}" >> "$anchor_file"
      rules=$((rules + 1))
    done
    for ip in $(host -t aaaa "$d" 2>/dev/null | awk '/has IPv6 addr/{print $NF}'); do
      echo "block drop out proto {tcp,udp} to {$ip}" >> "$anchor_file"
      rules=$((rules + 1))
    done
  done

  # Without DNS there is nothing to block. Loading an empty anchor used to be
  # reported as a success, which made the "iCloud-safe block" look installed
  # while it blocked nothing (Recovery has no resolver).
  if [ "$rules" -eq 0 ]; then
    rm -f "$anchor_file"
    error_exit "Could not resolve $MDM_BLOCKLIST — no rules to install. Run this from the booted system, or use 'firewall' for the IP-range block."
  fi

  chmod 644 "$anchor_file"
  success "Selective anchor written: $anchor_file ($rules rules)"

  local pf_conf="${root}/etc/pf.conf"
  local anchor_line="anchor \"com.unleash.selective\""
  # pf reads this path at boot, after the Recovery mount has gone away, so it
  # must not contain the Recovery prefix.
  local anchor_boot_path="/etc/pf.anchors/com.unleash.selective"
  local load_line="load anchor \"com.unleash.selective\" from \"${anchor_boot_path}\""

  if [ -f "$pf_conf" ]; then
    if grep -q "com.unleash.selective" "$pf_conf" 2>/dev/null; then
      info "pf.conf already has selective anchor"
    else
      echo "" >> "$pf_conf"
      echo "# Added by unleash — selective MDM block (iCloud-safe)" >> "$pf_conf"
      echo "$anchor_line" >> "$pf_conf"
      echo "$load_line" >> "$pf_conf"
      success "pf.conf updated with selective rules"
    fi
  else
    cat > "$pf_conf" <<- EOF
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
dummynet-anchor "com.apple/*"
fwd-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"
# Added by unleash — selective MDM block (iCloud-safe)
${anchor_line}
${load_line}
EOF
    success "pf.conf created"
  fi

  if command -v pfctl >/dev/null 2>&1; then
    pfctl -e -f "$pf_conf" 2>/dev/null && success "pf rules loaded (iCloud should work)" \
      || warn "pfctl failed"
  fi
}

restore_hosts_based_block() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"
  local hosts="${root}/private/etc/hosts"

  if [ -f "$hosts" ] && grep -q "Added by unleash" "$hosts" 2>/dev/null; then
    info "unleash hosts entries intact"
  fi
}
