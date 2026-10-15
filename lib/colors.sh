RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
MAG='\033[1;35m'
NC='\033[0m'

LOG_FILE=""
VERBOSE=false
DRY_RUN=false

# Diagnostics go to stderr. Callers capture the stdout of helper functions
# (data_mount=$(resolve_data_volume), backup paths, ...) and a log line on
# stdout would be captured as part of the returned value.
log() {
  local level="$1"
  local msg="$2"
  local color=""
  local label=""

  case "$level" in
    ERROR)   color="$RED";   label="ERR"  ;;
    WARN)    color="$YEL";   label="WRN"  ;;
    OK)      color="$GRN";   label=" OK"  ;;
    INFO)    color="$BLU";   label="INF"  ;;
    STEP)    color="$CYAN";  label="STP"  ;;
    DEBUG)   color="$MAG";   label="DBG"  ;;
    *)       color="$NC";    label="LOG"  ;;
  esac

  if [ "$level" = "DEBUG" ] && [ "$VERBOSE" = false ]; then
    return
  fi

  local ts
  ts=$(date '+%H:%M:%S')
  echo -e "${color}[${label}]${NC} ${msg}" >&2

  if [ -n "$LOG_FILE" ]; then
    echo "[${ts}] [${label}] ${msg}" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

error_exit() {
  log "ERROR" "$1"
  exit 1
}

warn() {
  log "WARN" "$1"
}

success() {
  log "OK" "$1"
}

info() {
  log "INFO" "$1"
}

step() {
  log "STEP" "$1"
}

debug() {
  log "DEBUG" "$1"
}

# True while a --dry-run / `unleash test` simulation is in progress.
is_dry_run() {
  [ "${DRY_RUN:-false}" = true ]
}

# Usage: skip_if_dry_run "do the thing" && return 0
# Returns 0 (and prints the notice) while simulating, 1 for a real run.
skip_if_dry_run() {
  if is_dry_run; then
    info "[DRY RUN] Would $1"
    return 0
  fi
  return 1
}

header() {
  local title="$1"
  local width=$(( ${#title} + 4 ))
  local bar=""
  local i=0
  # Built in pure bash: `tr ' ' '═'` is not multibyte-safe with the BSD tr
  # shipped on macOS.
  while [ "$i" -lt "$width" ]; do
    bar="${bar}═"
    i=$((i + 1))
  done
  echo ""
  echo -e "${CYAN}╔${bar}╗${NC}"
  echo -e "${CYAN}║  ${title}  ║${NC}"
  echo -e "${CYAN}╚${bar}╝${NC}"
  echo ""
}

begin() {
  local label="$1"
  echo -ne "${CYAN}  ${label} ... ${NC}"
}

spinner() {
  local pid=$1
  local msg="${2:-Working}"
  local spin='-\|/'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    echo -ne "\r${CYAN}  ${msg} ... ${spin:$i:1}${NC}"
    sleep 0.2
  done
  echo -ne "\r${CYAN}  ${msg} ... ${NC}"
}

end_ok() {
  echo -e "${GRN}✓${NC}"
}

end_fail() {
  echo -e "${RED}✗${NC}"
}

# Prompt for a line and assign it to the variable named by $1.
# printf -v is used instead of eval, so quotes, $ and backslashes in the
# answer are taken literally.
prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default="$3"
  local value=""
  read -r -p "${CYAN}${prompt_text}${NC} (default '${default}'): " value || value=""
  [ -n "$value" ] || value="$default"
  printf -v "$var_name" '%s' "$value"
}

# Notify the user logged into the console, if there is one. A LaunchDaemon
# has no GUI session, where osascript would silently fail.
notify_user() {
  local title="$1"
  local message="$2"
  command -v osascript >/dev/null 2>&1 || return 0
  local console_user=""
  console_user=$(stat -f %Su /dev/console 2>/dev/null || echo "")
  [ -n "$console_user" ] || return 0
  [ "$console_user" = "root" ] && return 0
  osascript -e "display notification \"$message\" with title \"$title\"" >/dev/null 2>&1 || true
}

confirm() {
  local prompt="$1"
  local response=""
  read -r -p "${prompt} (y/N): " response || response=""
  case "$response" in
    [Yy]) return 0 ;;
    *)    return 1 ;;
  esac
}
