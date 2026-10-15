# shellcheck shell=bash
do_uninstall() {
  header "Unleash — Full Uninstall"

  if ! is_root && ! is_dry_run; then
    error_exit "Uninstall needs sudo: sudo ./unleash uninstall"
  fi

  if skip_if_dry_run "remove every unleash LaunchDaemon, pf anchor, hosts entry and backup"; then
    return 0
  fi

  begin "Removing heal LaunchDaemon"
  local plist="/Library/LaunchDaemons/com.unleash.heal.plist"
  if [ -f "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"
    end_ok
  else
    end_fail; echo "     Not installed"
  fi

  begin "Removing monitor LaunchDaemon"
  plist="/Library/LaunchDaemons/com.unleash.monitor.plist"
  if [ -f "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"
    end_ok
  else
    end_fail; echo "     Not installed"
  fi

  begin "Cleaning pf anchors"
  local anchors=("/etc/pf.anchors/com.unleash/mdm" "/etc/pf.anchors/com.unleash.selective")
  for a in "${anchors[@]}"; do
    [ -f "$a" ] && rm -f "$a"
  done
  for anchor_name in "com.unleash/mdm" "com.unleash.selective"; do
    pfctl -a "$anchor_name" -F all 2>/dev/null || true
  done
  local pf_conf="/etc/pf.conf"
  if [ -f "$pf_conf" ]; then
    sed -i '' '/# Added by unleash/d' "$pf_conf" 2>/dev/null || true
    sed -i '' '/com\.unleash/d' "$pf_conf" 2>/dev/null || true
  fi
  pfctl -f /etc/pf.conf 2>/dev/null || true
  end_ok

  begin "Cleaning hosts entries"
  local hosts="/private/etc/hosts"
  if [ -f "$hosts" ]; then
    # Removes every domain the tool added, not just the first three.
    strip_hosts_block "$hosts"
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Restoring launchd overrides"
  local ldp="/private/var/db/com.apple.xpc.launchd/disabled.plist"
  if [ -f "$ldp" ]; then
    for label in com.apple.ManagedClient.enroll com.apple.ManagedClient.cloudConfiguration \
      com.apple.mdmclient.daemon.runatboot com.apple.activationd; do
      /usr/libexec/PlistBuddy -c "Delete :$label" "$ldp" 2>/dev/null || true
    done
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Removing backup directory"
  if [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Removing config file"
  # The invoking user's home, not root's: the tool is normally run with sudo,
  # where $HOME is /var/root and the real config was never touched.
  local cfgfile
  cfgfile="$(unleash_user_home)/.unleash.conf"
  if [ -f "$cfgfile" ]; then
    rm -f "$cfgfile"
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Stopping monitor if running"
  local pidfile="/tmp/unleash-monitor.pid"
  if [ -f "$pidfile" ]; then
    kill "$(cat "$pidfile")" 2>/dev/null || true
    rm -f "$pidfile"
    end_ok
  else
    end_fail; echo "     Not running"
  fi

  echo ""
  success "Uninstall complete"
  info "Your system is back to its original state."
  info "The unleash script itself was not removed."
}
