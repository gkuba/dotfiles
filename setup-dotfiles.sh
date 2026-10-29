#!/usr/bin/env bash
#
# Dotfiles Setup
#
# Interactive installer for gkuba's shell setup on pacman (Arch, CachyOS) and
# apt (Debian, Ubuntu) systems: shell tools, the bare dotfiles repository in
# ~/dotfiles, Zsh plugins, the Starship prompt, Fastfetch preferences, the Zsh
# login shell and the managed /etc/hosts block.
#
# Built on the Violet-Noir installer template
# (~/Projects/InstallScriptTemplate). The CUSTOMIZE sections hold this
# script's data, checks and steps; everything else is template engine code.
#
# The bare repository is only fetched and fast-forwarded, like
# `dotgit pull --ff-only`. Its Git config is written only right after this
# script clones it, to match the existing setup: status.showUntrackedFiles=no
# and the branch upstream, with no fetch refspec.
#
# Run as your normal user; sudo is used only for system changes.

set -u -o pipefail
shopt -s extglob

# ═════════════════════════════════════════════════════════════════════════════
# CUSTOMIZE 1: script identity and command-line flags
# ═════════════════════════════════════════════════════════════════════════════

APP_NAME='DOTFILES SETUP'            # shown in the header box (keep it short, uppercase)
SCRIPT_SLUG='setup-dotfiles'          # used for the log file name

DRY_RUN=${DRY_RUN:-0}
[[ "$DRY_RUN" == 1 ]] || DRY_RUN=0
PRESELECT=0
PRE_PACKAGES=0 PRE_DOTFILES=0 PRE_SYSTEM=0 PRE_UPDATE=0

usage() {
  cat <<EOF
Usage: ${0##*/} [options]

Sets up shell tools and dotfiles on pacman (Arch, CachyOS) and apt (Debian,
Ubuntu) systems. With no options the wizard starts at the welcome screen.
Selection options pre-select only those items and open the wizard at the
review screen; nothing runs until you confirm the plan and enter your password.

Selections:
  -p, --packages     Shell tools, utilities, and the Fira Code font
  -d, --dotfiles     Bare dotfiles repo (~/dotfiles), Zsh plugins, Starship prompt
  -s, --system       Zsh as the login shell and the managed /etc/hosts block
  -u, --update       Full system update before packages are installed
  -A, --all          -p, -d and -s (add -u for a system update)

Other:
  -n, --dry-run      Run the whole wizard and install screens but change nothing;
                     every command that would modify the system is shown instead.
                     (Also enabled by DRY_RUN=1.)
  -h, --help         Show this help.

Short options can be combined, e.g. ${0##*/} -pdn

The wizard also offers backing up files that block the first checkout, and
standalone Neovim and Fastfetch configs for machines without the bare repo.
Fastfetch image choices are saved in ~/.config/dotfiles-setup/fastfetch.conf
and reapplied after every dotfiles update.

The bare repo is only fetched and fast-forwarded, like 'dotgit pull --ff-only';
its Git config is written only right after this script clones it.
EOF
}

parse_args() {
  local arg flag i
  while (($#)); do
    arg=$1; shift
    case "$arg" in
      --packages) PRE_PACKAGES=1 ;;
      --dotfiles) PRE_DOTFILES=1 ;;
      --system) PRE_SYSTEM=1 ;;
      --update) PRE_UPDATE=1 ;;
      --all) PRE_PACKAGES=1 PRE_DOTFILES=1 PRE_SYSTEM=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --help) usage; exit 0 ;;
      --) (($#)) && { printf '%s: unexpected argument: %s\n' "${0##*/}" "$1" >&2; exit 2; }; break ;;
      --*) printf '%s: unknown option: %s\nTry --help.\n' "${0##*/}" "$arg" >&2; exit 2 ;;
      -?*)
        for ((i = 1; i < ${#arg}; i++)); do
          flag=${arg:i:1}
          case "$flag" in
            p) PRE_PACKAGES=1 ;;
            d) PRE_DOTFILES=1 ;;
            s) PRE_SYSTEM=1 ;;
            u) PRE_UPDATE=1 ;;
            A) PRE_PACKAGES=1 PRE_DOTFILES=1 PRE_SYSTEM=1 ;;
            n) DRY_RUN=1 ;;
            h) usage; exit 0 ;;
            *) printf '%s: unknown option: -%s\nTry --help.\n' "${0##*/}" "$flag" >&2; exit 2 ;;
          esac
        done
        ;;
      *) printf '%s: unexpected argument: %s\nTry --help.\n' "${0##*/}" "$arg" >&2; exit 2 ;;
    esac
  done
  (( PRE_PACKAGES || PRE_DOTFILES || PRE_SYSTEM || PRE_UPDATE )) && PRESELECT=1
  return 0
}

# Applied after the data section below; maps flags onto selections. Flags
# choose exactly what runs, so the wizard defaults are cleared first. The
# Fastfetch image choices keep their saved values.
apply_preselection() {
  local i
  for i in "${!SHELL_SELECTED[@]}"; do SHELL_SELECTED[i]=$PRE_PACKAGES; done
  for i in "${!UTIL_SELECTED[@]}"; do UTIL_SELECTED[i]=$PRE_PACKAGES; done
  DOTS_SELECTED[DOT_REPO]=$PRE_DOTFILES
  DOTS_SELECTED[DOT_ZSH]=$PRE_DOTFILES
  DOTS_SELECTED[DOT_STARSHIP]=$PRE_DOTFILES
  DOTS_SELECTED[DOT_BACKUP]=0
  DOTS_SELECTED[DOT_STANDALONE]=0
  SYS_SELECTED[SYS_UPDATE]=$PRE_UPDATE
  SYS_SELECTED[SYS_LOGIN]=$PRE_SYSTEM
  SYS_SELECTED[SYS_HOSTS]=$PRE_SYSTEM
  sync_groups_from_items
  log_event "Preselected from options: packages=$PRE_PACKAGES dotfiles=$PRE_DOTFILES system=$PRE_SYSTEM update=$PRE_UPDATE"
}

parse_args "$@"

if [[ ! -t 0 || ! -t 1 ]]; then
  printf 'Run this installer in a terminal.\n' >&2
  exit 2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Glyphs and colors
# ─────────────────────────────────────────────────────────────────────────────

case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) UTF8=1 ;;
  *) UTF8=0 ;;
esac

if (( UTF8 )); then
  G_TL='╭' G_TR='╮' G_BL='╰' G_BR='╯' G_H='─' G_V='│' G_HEAVY='━'
  G_ON='●' G_OFF='○' G_CUR='▸' G_OK='✓' G_FAIL='✗' G_SKIP='–' G_WARN='!'
  G_INFO='•' G_RUN='→' G_DIAMOND='◆' G_SEP='·' G_MASK='•' G_REBOOT='↻'
  G_SUB='↳' G_THUMB='┃' G_TRACK='│' G_ELLIPSIS='…' G_UPDOWN='↑↓' G_ARROWS='↑↓←→'
  SPINNER=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
else
  G_TL='+' G_TR='+' G_BL='+' G_BR='+' G_H='-' G_V='|' G_HEAVY='='
  G_ON='x' G_OFF='.' G_CUR='>' G_OK='v' G_FAIL='x' G_SKIP='-' G_WARN='!'
  G_INFO='*' G_RUN='>' G_DIAMOND='*' G_SEP='-' G_MASK='*' G_REBOOT='!'
  G_SUB='-' G_THUMB='#' G_TRACK='|' G_ELLIPSIS='...' G_UPDOWN='Up/Dn' G_ARROWS='Arrows'
  SPINNER=( '|' '/' '-' '\' )
fi

# Violet-Noir palette.
PURPLE=$'\e[38;2;128;80;212m'
LAVENDER=$'\e[38;2;235;230;248m'
PINK=$'\e[38;2;255;121;198m'
BLUE=$'\e[38;2;139;180;255m'
CYAN=$'\e[38;2;65;220;205m'
GREEN=$'\e[38;2;95;210;145m'
YELLOW=$'\e[38;2;241;214;125m'
RED=$'\e[38;2;255;85;85m'
DIM=$'\e[38;2;150;144;170m'
BOLD=$'\e[1m'
RESET=$'\e[0m'
if [[ -n "${NO_COLOR:-}" || "${TERM:-dumb}" == dumb ]]; then
  PURPLE='' LAVENDER='' PINK='' BLUE='' CYAN='' GREEN='' YELLOW='' RED='' DIM='' BOLD='' RESET=''
fi

repeat_glyph() { # glyph count -> REPEAT_OUT
  local g=$1 n=$2 s=''
  (( n < 1 )) && { REPEAT_OUT=''; return; }
  while (( ${#s} < n )); do s+="$g$g$g$g$g$g$g$g"; done
  REPEAT_OUT=${s:0:n}
}
repeat_glyph "$G_H" 200; HBAR=$REPEAT_OUT
repeat_glyph "$G_HEAVY" 200; HEAVYBAR=$REPEAT_OUT


# ═════════════════════════════════════════════════════════════════════════════
# CUSTOMIZE 2: items, groups, and install steps
# ═════════════════════════════════════════════════════════════════════════════

# ── Configuration ───────────────────────────────────────────────────────────
DOTFILES_REPO='https://github.com/gkuba/dotfiles.git'
DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_BACKUP_DIR="$HOME/.dotfiles-backup"
DOTFILES_RAW='https://raw.githubusercontent.com/gkuba/dotfiles/refs/heads/master'
STARSHIP_CONFIG_REPO='https://raw.githubusercontent.com/gkuba/Starship-Configs/main'
HOSTS_GIST_URL='https://gist.githubusercontent.com/gkuba/328f47706216baaf6cdc6c5519bf84c2/raw/73b9f6d7bd6cff4cb44d0da872747a1cbce66e0d/gistfile1.txt'
HOSTS_BLOCK_START='# >>> gkuba custom hosts >>>'
HOSTS_BLOCK_END='# <<< gkuba custom hosts <<<'
ZSH_PLUGIN_REPOS=( zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting zsh-users/zsh-history-substring-search )
FASTFETCH_CONFIG="$HOME/.config/fastfetch/config.jsonc"
FASTFETCH_PREFS="$HOME/.config/dotfiles-setup/fastfetch.conf"
BACKUP_STAMP=$(date +%Y%m%d-%H%M%S)   # one backup folder per run
HOST_NAME=$(uname -n)

# Install steps have no keyboard, so Git must fail instead of asking for a
# password or an SSH passphrase (ssh reads those from the terminal directly).
export GIT_TERMINAL_PROMPT=0
[[ -n "${GIT_SSH_COMMAND:-}" ]] || export GIT_SSH_COMMAND='ssh -o BatchMode=yes'

# Downloads land here; restore_terminal removes it on exit.
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/$SCRIPT_SLUG.XXXXXXXX") || exit 1

detect_package_manager() { # -> PKG_MANAGER (pacman, apt or empty), OS_ID, OS_LIKE
  local key value
  PKG_MANAGER='' OS_ID='' OS_LIKE=''
  if [[ -r /etc/os-release ]]; then
    while IFS='=' read -r key value; do
      value=${value%\"}; value=${value#\"}; value=${value%\'}; value=${value#\'}
      case "$key" in ID) OS_ID=$value ;; ID_LIKE) OS_LIKE=$value ;; esac
    done < /etc/os-release
  fi
  if [[ "$OS_ID" == arch || "$OS_ID" == cachyos || " $OS_LIKE " == *' arch '* ]]; then
    command -v pacman >/dev/null 2>&1 && PKG_MANAGER=pacman
  elif [[ "$OS_ID" == debian || "$OS_ID" == ubuntu || " $OS_LIKE " == *' debian '* || " $OS_LIKE " == *' ubuntu '* ]]; then
    command -v apt-get >/dev/null 2>&1 && PKG_MANAGER=apt
  fi
  return 0
}
detect_package_manager

starship_config_for_host() { # hostname -> config file name in Starship-Configs
  case "$1" in
    pixel) printf 'pixel-starship.toml' ;;
    pi|pi-*|raspberrypi*|pixelshed) printf 'pi-starship.toml' ;;
    *) printf 'starship.toml' ;;
  esac
}
STARSHIP_FILE=$(starship_config_for_host "$HOST_NAME")

FONT_PKG=ttf-fira-code
[[ "$PKG_MANAGER" == apt ]] && FONT_PKG=fonts-firacode

# Saved Fastfetch choices (same file and format as the old setup-dotfiles.sh).
FF_SAVED_IMAGES=1 FF_SAVED_ASCII=0
if [[ -r "$FASTFETCH_PREFS" ]]; then
  while IFS='=' read -r __key __value; do
    case "$__key:$__value" in
      KEEP_IMAGES:true) FF_SAVED_IMAGES=1 ;;
      KEEP_IMAGES:false) FF_SAVED_IMAGES=0 ;;
      USE_ASCII:true) FF_SAVED_ASCII=1 ;;
      USE_ASCII:false) FF_SAVED_ASCII=0 ;;
    esac
  done < "$FASTFETCH_PREFS"
  unset __key __value
fi

# ── Items ───────────────────────────────────────────────────────────────────
# Package groups (kind "package") show installed status on the review screen;
# action groups (kind "action") show apply/skip. Review labels fit 17 columns.
SHELL_ITEMS=( zsh starship fzf eza fastfetch neovim )
UTIL_ITEMS=( git curl 7zip unzip iproute2 "$FONT_PKG" )
DOTS_ITEMS=( 'Dotfiles repo' 'Zsh plugins' 'Starship prompt' 'Back up conflicts' 'App configs only' )
SYS_ITEMS=( 'System update' 'Zsh login shell' 'Hosts block' 'Fastfetch images' 'Fastfetch ASCII' )

DOT_REPO=0 DOT_ZSH=1 DOT_STARSHIP=2 DOT_BACKUP=3 DOT_STANDALONE=4
SYS_UPDATE=0 SYS_LOGIN=1 SYS_HOSTS=2 SYS_FF_IMAGES=3 SYS_FF_ASCII=4

# Defaults match a plain run of the old script: every package, the repo,
# plugins, Starship and the Zsh login shell; hosts block off.
SHELL_SELECTED=(1 1 1 1 1 1) SHELL_INSTALLED=(0 0 0 0 0 0)
UTIL_SELECTED=(1 1 1 1 1 1)  UTIL_INSTALLED=(0 0 0 0 0 0)
DOTS_SELECTED=(1 1 1 0 0)
SYS_SELECTED=(0 1 0 "$FF_SAVED_IMAGES" "$FF_SAVED_ASCII")

# Groups, in review-screen order. Each entry names the arrays above.
GROUP_TITLES=( 'Shell tools' 'Utilities and font' 'Dotfiles' 'System and Fastfetch' )
GROUP_ITEMS=( SHELL_ITEMS UTIL_ITEMS DOTS_ITEMS SYS_ITEMS )
GROUP_SELECTED=( SHELL_SELECTED UTIL_SELECTED DOTS_SELECTED SYS_SELECTED )
GROUP_INSTALLED=( SHELL_INSTALLED UTIL_INSTALLED '' '' )
GROUP_KIND=( package package action action )
GROUP_COLUMN=( 0 0 1 1 )              # review screen: 0 = left column, 1 = right
GROUP_SUMMARY=(                       # one line each on the welcome screen
  'zsh, starship, fzf, eza, fastfetch, neovim'
  'git, curl, 7zip, unzip, iproute2, Fira Code'
  'bare repo in ~/dotfiles, Zsh plugins, Starship'
  'login shell, hosts block, Fastfetch images'
)

# Wizard page 1 shows package groups as checkboxes (one per package group);
# the review screen fine-tunes single items.
PACKAGE_LABELS=( 'Shell tools' 'Utilities and font' )
PACKAGE_DETAILS=(
  "zsh $G_SEP starship $G_SEP fzf $G_SEP eza $G_SEP fastfetch $G_SEP neovim"
  "git $G_SEP curl $G_SEP 7zip $G_SEP unzip $G_SEP iproute2 $G_SEP $FONT_PKG"
)
PACKAGE_GROUPS=( 0 1 )                # GROUP_* index behind each page-1 checkbox
PACKAGE_SELECTED=(0 0)
PACKAGE_PREVIOUS=(0 0)

# Wizard pages 2 and 3 select action items directly (at most five per page
# so each fits 80x24).
DOTS_DETAILS=(
  "Clone or fast-forward ~/dotfiles and check out its files into ~"
  'Clone or update the three Zsh plugins in ~/.zsh'
  "The Starship config for this host ($STARSHIP_FILE)"
  'Move files that would block the checkout into ~/.dotfiles-backup first'
  'Only the Neovim and Fastfetch configs, for machines without ~/dotfiles'
)
if [[ "$PKG_MANAGER" == apt ]]; then __update_detail='apt-get update and upgrade before installing packages'
else __update_detail='pacman -Syu before installing packages'
fi
SYS_DETAILS=(
  "$__update_detail"
  'Change your login shell to Zsh; log out and back in afterwards'
  'Refresh the gkuba block in /etc/hosts from the Gist; backs up first'
  'Keep the custom logo images (off removes them from ~, not the repo)'
  "Use Fastfetch's built-in logo instead of an image"
)
unset __update_detail
PAGE2_TITLE='Dotfiles'             PAGE2_INTRO='Choose what to set up from the dotfiles repos.'
PAGE3_TITLE='System and Fastfetch' PAGE3_INTRO='Choose system changes and Fastfetch preferences.'

# Install steps, in run order. PHASE_FATAL=1 ends the run when that step
# fails; other failures offer Continue or Stop. phase_enabled (below) decides
# which steps run for the current selections.
PHASE_TITLES=( 'System update' 'Install packages' 'Login shell' 'Dotfiles repo' 'Zsh plugins'
               'Starship prompt' 'App configs' 'Fastfetch preferences' 'Hosts file' )
PHASE_FUNCS=( update_system install_selected_packages set_login_shell sync_dotfiles_repo sync_zsh_plugins
              install_starship_config install_app_configs apply_fastfetch_preferences update_hosts_block )
PHASE_DONE_TEXT=( 'System updated.' 'Packages installed.' 'Login shell set.' 'Dotfiles repo is current.'
                  'Zsh plugins are current.' 'Starship prompt configured.' 'App configs installed.'
                  'Fastfetch preferences applied.' 'Hosts file updated.' )
PHASE_FATAL=( 1 1 0 0 0 0 0 0 0 )

fastfetch_choices_changed() {
  (( SYS_SELECTED[SYS_FF_IMAGES] != FF_SAVED_IMAGES || SYS_SELECTED[SYS_FF_ASCII] != FF_SAVED_ASCII ))
}

phase_enabled() { # step number (1-based) -> success when it should run
  case "$1" in
    1) (( SYS_SELECTED[SYS_UPDATE] )) ;;
    2) any_selected "${SHELL_SELECTED[@]}" "${UTIL_SELECTED[@]}" ;;
    3) (( SYS_SELECTED[SYS_LOGIN] )) ;;
    4) (( DOTS_SELECTED[DOT_REPO] )) ;;
    5) (( DOTS_SELECTED[DOT_ZSH] )) ;;
    6) (( DOTS_SELECTED[DOT_STARSHIP] )) ;;
    7) (( DOTS_SELECTED[DOT_STANDALONE] )) ;;
    # Reapplied after every repo update, since the update restores the
    # tracked Fastfetch files first.
    8) (( DOTS_SELECTED[DOT_REPO] || DOTS_SELECTED[DOT_STANDALONE] )) || fastfetch_choices_changed ;;
    9) (( SYS_SELECTED[SYS_HOSTS] )) ;;
    *) return 1 ;;
  esac
}

# ── Engine state (no changes needed) ────────────────────────────────────────
PHASE_COUNT=${#PHASE_TITLES[@]}
PHASE_STATE=() PHASE_TIME=() PHASE_RC=()
for ((__i = 0; __i < PHASE_COUNT; __i++)); do PHASE_STATE+=(pending); PHASE_TIME+=(''); PHASE_RC+=(0); done
unset __i
PACKAGE_STATUS_READY=0
STOP_REQUESTED=0
COMPLETION_NOTES=()                   # extra lines for the completion screen
SUDO_KEEPALIVE_PID=''

# ─────────────────────────────────────────────────────────────────────────────
# Terminal and logging
# ─────────────────────────────────────────────────────────────────────────────

LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/$SCRIPT_SLUG-$(date +%Y%m%d-%H%M%S)-XXXXXX.log") || exit 1
exec {LOG_FD}>>"$LOG_FILE"
SAVED_STTY=$(stty -g 2>/dev/null || true)

log_event() { printf '[%(%H:%M:%S)T] %s\n' -1 "$*" >&"$LOG_FD"; }

enter_screen() {
  printf '\e[?1049h\e[?25l'
  [[ -z "$SAVED_STTY" ]] || stty -echo -icanon min 1 time 0 2>/dev/null || true
}
restore_terminal() {
  [[ -z "$SUDO_KEEPALIVE_PID" ]] || kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  [[ -z "$SAVED_STTY" ]] || stty "$SAVED_STTY" 2>/dev/null || true
  [[ -z "${TEMP_DIR:-}" || ! -d "$TEMP_DIR" ]] || rm -rf -- "$TEMP_DIR"
  printf '\e[?25h\e[?1049l'
}
trap restore_terminal EXIT
trap 'exit 130' INT TERM

# Ctrl+C during installation must not interrupt a package manager mid-
# transaction, so the terminal stops generating SIGINT and the frame reads
# Ctrl+C as a key instead.
disable_interrupt_key() { [[ -z "$SAVED_STTY" ]] || stty -isig 2>/dev/null || true; }

# ─────────────────────────────────────────────────────────────────────────────
# Layout helpers (everything fits 80x24; uses up to 100 columns when present)
# ─────────────────────────────────────────────────────────────────────────────

TERM_ROWS=24 TERM_COLS=80 W=76 BODY_LAST=21 FOOT_RULE=22 FOOT_KEYS=23

ui_metrics() {
  local size c
  size=$(stty size 2>/dev/null) || size=''
  if [[ "$size" =~ ^([0-9]+)\ ([0-9]+)$ ]]; then
    TERM_ROWS=${BASH_REMATCH[1]} TERM_COLS=${BASH_REMATCH[2]}
  else
    TERM_ROWS=24 TERM_COLS=80
  fi
  (( TERM_ROWS < 16 )) && TERM_ROWS=16
  c=$TERM_COLS
  (( c > 100 )) && c=100
  (( c < 64 )) && c=64
  W=$((c - 4))
  BODY_LAST=$((TERM_ROWS - 3))
  FOOT_RULE=$((TERM_ROWS - 2))
  FOOT_KEYS=$((TERM_ROWS - 1))
}

at() { printf '\e[%d;%dH' "$1" "$2"; }
put() { printf '\e[%d;1H\e[2K  %s' "$1" "$2"; }          # row, text at column 3

vis_len() { # text -> VIS_LEN (ANSI color codes excluded)
  local s=${1//$'\e'\[*([0-9;])m/}
  VIS_LEN=${#s}
}
pad() { # text width -> text padded with spaces to width
  vis_len "$1"
  local n=$(( $2 - VIS_LEN ))
  (( n < 0 )) && n=0
  printf '%s%*s' "$1" "$n" ''
}
pad_v() { # VAR text width -> VAR=text padded to width (no subshell)
  vis_len "$2"
  local n=$(( $3 - VIS_LEN ))
  (( n < 0 )) && n=0
  printf -v "$1" '%s%*s' "$2" "$n" ''
}
fit() { # plain-text width -> FIT_OUT truncated with an ellipsis when needed
  local text=$1 width=$2
  if (( ${#text} > width )); then
    FIT_OUT="${text:0:width-${#G_ELLIPSIS}}$G_ELLIPSIS"
  else
    FIT_OUT=$text
  fi
}

# wrap_into ARRAY WIDTH TEXT [CONTINUATION_PREFIX]
# Word-wraps plain text by character count (multibyte aware, unlike fold).
wrap_into() {
  local -n __wrap_out=$1
  local width=$2 text=$3 cont=${4-} lead rest line word avail cand
  local -a words=()
  __wrap_out=()
  (( width < 10 )) && width=10
  if (( ${#text} <= width )); then __wrap_out=("$text"); return 0; fi
  lead=${text%%[! ]*}
  rest=${text#"$lead"}
  [[ -n "$cont" ]] || cont=$lead
  read -ra words <<< "$rest"
  line=$lead
  for word in "${words[@]}"; do
    if [[ "$line" == "$lead" || "$line" == "$cont" ]]; then cand="$line$word"; else cand="$line $word"; fi
    if (( ${#cand} <= width )); then line=$cand; continue; fi
    [[ "$line" == "$lead" || "$line" == "$cont" ]] || { __wrap_out+=("$line"); line=$cont; }
    avail=$((width - ${#cont}))
    (( avail < 1 )) && avail=1
    while (( ${#line} + ${#word} > width )); do
      __wrap_out+=("$line${word:0:avail}")
      word=${word:avail}
      line=$cont
    done
    line+=$word
  done
  __wrap_out+=("$line")
}

# Header: rounded box with the app name in the top border, the screen title
# on the left and step progress on the right.
draw_header() { # title [progress-label current total]
  local title=$1 label=${2:-} cur=${3:-0} total=${4:-0}
  local name=" $G_DIAMOND $APP_NAME " tag='' fill i dots='' plain_dots='' right='' plain_right=''
  ui_metrics
  (( DRY_RUN )) && tag=' DRY RUN '
  fill=$((W - 4 - ${#name} - ${#tag}))
  printf '\e[?25l\e[H\e[2J'
  at 1 3
  printf '%s%s%s%s%s%s%s%s%s%s%s%s%s' "$PURPLE" "$G_TL$G_H" "$RESET" "$PINK$BOLD" "$name" "$RESET" \
    "$PURPLE" "${HBAR:0:fill}" "$RESET" "$YELLOW$BOLD" "$tag" "$RESET" "$PURPLE$G_H$G_TR$RESET"
  if (( total > 0 )); then
    for ((i = 1; i <= total; i++)); do
      if (( i < cur )); then dots+="$GREEN$G_ON$RESET"
      elif (( i == cur )); then dots+="$CYAN$BOLD$G_ON$RESET"
      else dots+="$DIM$G_OFF$RESET"
      fi
      plain_dots+=x
    done
    right="$dots  $DIM$label $cur/$total$RESET"
    plain_right="$plain_dots  $label $cur/$total"
  fi
  fit "$title" $((W - 5 - ${#plain_right}))
  at 2 3
  printf '%s%s%s %s%s' "$PURPLE" "$G_V" "$RESET" "$BLUE$BOLD" "$FIT_OUT"
  printf '%s' "$RESET"
  at 2 $((3 + W - 2 - ${#plain_right}))
  printf '%s %s%s%s' "$right" "$PURPLE" "$G_V" "$RESET"
  at 3 3
  printf '%s%s%s%s%s' "$PURPLE" "$G_BL" "${HBAR:0:W-2}" "$G_BR" "$RESET"
}

# Footer: heavy rule plus key hints. Pass key/label pairs.
draw_footer() {
  local -a parts=()
  local key label sep text plain spacing
  while (($# >= 2)); do parts+=("$1" "$2"); shift 2; done
  for spacing in 3 2 1; do
    printf -v sep '%*s' "$spacing" ''
    text='' plain=''
    local i
    for ((i = 0; i < ${#parts[@]}; i += 2)); do
      key=${parts[i]} label=${parts[i+1]}
      [[ -z "$plain" ]] || { text+=$sep; plain+=$sep; }
      text+="$CYAN$BOLD$key$RESET $DIM$label$RESET"
      plain+="$key $label"
    done
    (( ${#plain} <= W )) && break
  done
  printf '\e[%d;1H\e[2K  %s%s%s' "$FOOT_RULE" "$PURPLE" "${HEAVYBAR:0:W}" "$RESET"
  printf '\e[%d;1H\e[2K  %s' "$FOOT_KEYS" "$text"
}

# read_key -> KEY: UP DOWN LEFT RIGHT PGUP PGDN HOME END ENTER ESC SPACE
#                  BACKSPACE CTRL_C CTRL_D IGNORE EOF, or the character typed.
read_key() {
  local k='' k2='' k3='' k4='' seq
  KEY=''
  IFS= read -rsn1 k || { KEY=EOF; return 1; }
  case "$k" in
    $'\e')
      if IFS= read -rsn1 -t 0.08 k2; then
        if [[ "$k2" == '[' || "$k2" == O ]]; then
          IFS= read -rsn1 -t 0.08 k3 || k3=''
          case "$k3" in
            A) KEY=UP ;; B) KEY=DOWN ;; C) KEY=RIGHT ;; D) KEY=LEFT ;;
            H) KEY=HOME ;; F) KEY=END ;;
            [0-9])
              seq=$k3
              while IFS= read -rsn1 -t 0.08 k4; do [[ "$k4" == '~' ]] && break; seq+=$k4; done
              case "$seq" in 5) KEY=PGUP ;; 6) KEY=PGDN ;; 1|7) KEY=HOME ;; 4|8) KEY=END ;; *) KEY=IGNORE ;; esac
              ;;
            *) KEY=IGNORE ;;
          esac
        else
          KEY=ESC
        fi
      else
        KEY=ESC
      fi
      ;;
    $'\r'|$'\n'|'') KEY=ENTER ;;
    ' ') KEY=SPACE ;;
    $'\x7f'|$'\b') KEY=BACKSPACE ;;
    $'\x03') KEY=CTRL_C ;;
    $'\x04') KEY=CTRL_D ;;
    *) KEY=$k ;;
  esac
  return 0
}

# Scrollable list: pager_draw ARRAY FIRST_ROW LAST_ROW. PAGER_START=-1 means
# "show the end". pager_scroll KEY handles scrolling keys.
PAGER_START=0 PAGER_MAX=0 PAGER_VISIBLE=1
pager_draw() {
  local -n __pager_lines=$1
  local first=$2 last=$3 total i row thumb_size thumb_start text_w=$((W - 2)) glyph color line
  PAGER_VISIBLE=$((last - first + 1))
  (( PAGER_VISIBLE < 1 )) && PAGER_VISIBLE=1
  total=${#__pager_lines[@]}
  PAGER_MAX=$((total - PAGER_VISIBLE))
  (( PAGER_MAX < 0 )) && PAGER_MAX=0
  (( PAGER_START < 0 || PAGER_START > PAGER_MAX )) && PAGER_START=$PAGER_MAX
  thumb_size=$((PAGER_VISIBLE * PAGER_VISIBLE / (total > 0 ? total : 1)))
  (( thumb_size < 1 )) && thumb_size=1
  thumb_start=$((PAGER_START * (PAGER_VISIBLE - thumb_size) / (PAGER_MAX > 0 ? PAGER_MAX : 1)))
  for ((i = 0; i < PAGER_VISIBLE; i++)); do
    row=$((first + i))
    line=${__pager_lines[PAGER_START + i]:-}
    pad_v PADDED "$line" "$text_w"
    printf '\e[%d;1H\e[2K  %s' "$row" "$PADDED"
    if (( total > PAGER_VISIBLE )); then
      if (( i >= thumb_start && i < thumb_start + thumb_size )); then glyph=$G_THUMB color=$CYAN$BOLD; else glyph=$G_TRACK color=$DIM; fi
      at "$row" $((W + 2))
      printf '%s%s%s' "$color" "$glyph" "$RESET"
    fi
  done
}
pager_scroll() {
  case "$1" in
    UP|k) (( PAGER_START > 0 )) && ((PAGER_START -= 1)) ;;
    DOWN|j) (( PAGER_START < PAGER_MAX )) && ((PAGER_START += 1)) ;;
    PGUP) PAGER_START=$((PAGER_START - PAGER_VISIBLE)); (( PAGER_START < 0 )) && PAGER_START=0 ;;
    PGDN) PAGER_START=$((PAGER_START + PAGER_VISIBLE)); (( PAGER_START > PAGER_MAX )) && PAGER_START=$PAGER_MAX ;;
    HOME) PAGER_START=0 ;;
    END) PAGER_START=$PAGER_MAX ;;
    *) return 1 ;;
  esac
  return 0
}


# ─────────────────────────────────────────────────────────────────────────────
# Output helpers (used inside install steps; the frame colors them by prefix)
# ─────────────────────────────────────────────────────────────────────────────

info() { printf '%s %s\n' "$G_INFO" "$*"; }
success() { printf '%s %s\n' "$G_OK" "$*"; }
warn() { printf '%s %s\n' "$G_WARN" "$*"; }
error() { printf '%s %s\n' "$G_FAIL" "$*" >&2; }

quote_cmd() {
  local out='' a
  for a in "$@"; do
    if [[ "$a" =~ ^[A-Za-z0-9_./:=@%+,~-]+$ ]]; then out+="$a "; else out+="$(printf '%q' "$a") "; fi
  done
  printf '%s' "${out% }"
}

# Every command that changes the system goes through run(). In a dry run it
# is printed instead of executed.
run() {
  if (( DRY_RUN )); then
    printf '%s would run: %s\n' "$G_RUN" "$(quote_cmd "$@")"
    return 0
  fi
  "$@"
}
as_root() { run sudo -n "$@"; }
pacman_install() { # packages... (Arch helper; remove if unused)
  if command -v stdbuf >/dev/null 2>&1; then
    as_root stdbuf -oL -eL pacman -S --needed --noconfirm --color never "$@"
  else
    as_root pacman -S --needed --noconfirm --color never "$@"
  fi
}
dry_note() { (( DRY_RUN )) && printf '%s dry run: %s\n' "$G_RUN" "$*"; return 0; }

need_cmd() { # command message -> fails, or only warns in a dry run
  command -v "$1" >/dev/null 2>&1 && return 0
  if (( DRY_RUN )); then warn "$2 (dry run continues)"; return 0; fi
  error "$2"
  return 1
}


# ═════════════════════════════════════════════════════════════════════════════
# CUSTOMIZE 3: checks
# ═════════════════════════════════════════════════════════════════════════════

prerequisite_problem() { # prints a reason, or nothing when the script can start
  if (( EUID == 0 )); then printf 'Run this installer as your normal user; sudo is requested only when needed.'; return; fi
  command -v sudo >/dev/null 2>&1 || { printf 'sudo is required.'; return; }
  if [[ -z "$PKG_MANAGER" ]]; then
    printf 'Unsupported system (ID=%s, ID_LIKE=%s). This installer supports pacman (Arch, CachyOS) and apt (Debian, Ubuntu).' \
      "${OS_ID:-unknown}" "${OS_LIKE:-none}"
    return
  fi
}

package_command() { # package -> the command it provides (empty for the font)
  case "$1" in
    neovim) printf 'nvim' ;;
    7zip) printf '7z' ;;
    iproute2) printf 'ip' ;;
    "$FONT_PKG") ;;
    *) printf '%s' "$1" ;;
  esac
}

package_installed() { # name -> success when installed by the package manager or on PATH
  local cmd
  if [[ "$PKG_MANAGER" == pacman ]]; then
    pacman -Qq -- "$1" >/dev/null 2>&1 && return 0
  else
    [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == *'install ok installed'* ]] && return 0
  fi
  # A tool installed another way (for example starship in /usr/local/bin)
  # counts too, so the package manager does not add a second copy.
  cmd=$(package_command "$1")
  [[ -n "$cmd" ]] && command -v "$cmd" >/dev/null 2>&1
}

# Read-only state gathered once, on the "Checking this system" screen.
APT_UNAVAILABLE=() LOGIN_SHELL_NOW='' HOSTS_MARKERS_OK=1
DOT_STATE=missing DOT_BRANCH='' DOT_HEAD='' DOT_REMOTE_SHA='' DOT_INDEX_EMPTY=0 DOT_BEHIND=''
DOT_CHANGES=() CONFLICTS=()

check_package_status() { # fills every package group's *_INSTALLED array, then inspects the rest
  local g i
  for g in "${!GROUP_TITLES[@]}"; do
    [[ "${GROUP_KIND[g]}" == package ]] || continue
    local -n __items=${GROUP_ITEMS[g]} __installed=${GROUP_INSTALLED[g]}
    for i in "${!__items[@]}"; do
      if package_installed "${__items[i]}"; then __installed[i]=1; else __installed[i]=0; fi
    done
    unset -n __items __installed
  done
  APT_UNAVAILABLE=()
  if [[ "$PKG_MANAGER" == apt ]]; then
    for i in "${!SHELL_ITEMS[@]}"; do
      (( SHELL_INSTALLED[i] )) || apt-cache show "${SHELL_ITEMS[i]}" >/dev/null 2>&1 || APT_UNAVAILABLE+=("${SHELL_ITEMS[i]}")
    done
    for i in "${!UTIL_ITEMS[@]}"; do
      (( UTIL_INSTALLED[i] )) || apt-cache show "${UTIL_ITEMS[i]}" >/dev/null 2>&1 || APT_UNAVAILABLE+=("${UTIL_ITEMS[i]}")
    done
  fi
  LOGIN_SHELL_NOW=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
  HOSTS_MARKERS_OK=1
  hosts_markers_valid /etc/hosts || HOSTS_MARKERS_OK=0
  inspect_dotfiles
  PACKAGE_STATUS_READY=1
  log_event "Package status ($PKG_MANAGER): shell=${SHELL_INSTALLED[*]} utilities=${UTIL_INSTALLED[*]} apt-unavailable=${APT_UNAVAILABLE[*]:-none}"
  log_event "Dotfiles repo: state=$DOT_STATE branch=${DOT_BRANCH:-none} head=${DOT_HEAD:0:7} remote=${DOT_REMOTE_SHA:0:7} first-checkout=$DOT_INDEX_EMPTY changes=${#DOT_CHANGES[@]} conflicts=${#CONFLICTS[@]}"
}

# Looks at ~/dotfiles without changing it: no fetch, no config writes. The
# remote commit comes from ls-remote, which only reads.
inspect_dotfiles() {
  DOT_STATE=missing DOT_BRANCH='' DOT_HEAD='' DOT_REMOTE_SHA='' DOT_INDEX_EMPTY=0 DOT_BEHIND=''
  DOT_CHANGES=() CONFLICTS=()
  [[ -e "$DOTFILES_DIR" ]] || return 0
  if ! is_bare_repo; then DOT_STATE=invalid; return 0; fi
  DOT_STATE=bare
  DOT_BRANCH=$(dotgit symbolic-ref --quiet --short HEAD 2>/dev/null) || DOT_BRANCH=''
  DOT_HEAD=$(dotgit rev-parse -q --verify HEAD 2>/dev/null) || DOT_HEAD=''
  [[ -n "$(dotgit ls-files 2>/dev/null | sed -n 1p)" ]] || DOT_INDEX_EMPTY=1
  if (( ! DOT_INDEX_EMPTY )); then
    mapfile -t DOT_CHANGES < <(dotgit status --porcelain=v1 --untracked-files=no 2>/dev/null)
  fi
  if [[ -n "$DOT_BRANCH" ]] && command -v timeout >/dev/null 2>&1; then
    DOT_REMOTE_SHA=$(timeout 15 /usr/bin/git --git-dir="$DOTFILES_DIR" ls-remote origin "refs/heads/$DOT_BRANCH" 2>/dev/null | cut -f1)
  fi
  if (( DOT_INDEX_EMPTY )); then
    [[ -n "$DOT_HEAD" ]] && collect_conflicts HEAD
  elif [[ -n "$DOT_REMOTE_SHA" && "$DOT_REMOTE_SHA" != "$DOT_HEAD" ]] && dotgit cat-file -e "$DOT_REMOTE_SHA^{commit}" 2>/dev/null; then
    # The new commits are already here from an earlier fetch, so the plan can
    # name what they add.
    DOT_BEHIND=$(dotgit rev-list --count "HEAD..$DOT_REMOTE_SHA" 2>/dev/null)
    collect_conflicts "$DOT_REMOTE_SHA"
  fi
  return 0
}

packages_to_install() { # success when a selected package is not installed yet
  local i
  for i in "${!SHELL_ITEMS[@]}"; do (( SHELL_SELECTED[i] && ! SHELL_INSTALLED[i] )) && return 0; done
  for i in "${!UTIL_ITEMS[@]}"; do (( UTIL_SELECTED[i] && ! UTIL_INSTALLED[i] )) && return 0; done
  return 1
}

pkg_selected() { # package name -> success when selected on the review screen
  local i
  for i in "${!SHELL_ITEMS[@]}"; do [[ "${SHELL_ITEMS[i]}" == "$1" ]] && (( SHELL_SELECTED[i] )) && return 0; done
  for i in "${!UTIL_ITEMS[@]}"; do [[ "${UTIL_ITEMS[i]}" == "$1" ]] && (( UTIL_SELECTED[i] )) && return 0; done
  return 1
}

require_tool() { # command reason -> blocker unless installed or selected
  command -v "$1" >/dev/null 2>&1 && return 0
  pkg_selected "$1" && return 0
  PLAN_BLOCKERS+=("$2 needs $1, which is not installed. Select it on the review screen (B goes back).")
}

short_list() { # max items... -> SHORT_LIST like "a, b, c and 2 more"
  local max=$1 n
  shift
  n=$#
  if (( n > max )); then SHORT_LIST="$(join_by ', ' "${@:1:max}") and $((n - max)) more"
  else SHORT_LIST=$(join_by ', ' "$@")
  fi
}

# Problems that must block the run, shown on the plan screen. Add one line
# per problem to PLAN_BLOCKERS; Enter stays disabled while any exist.
collect_plan_blockers() {
  local name
  local -a unavailable=() changed=()
  (( DOTS_SELECTED[DOT_REPO] || DOTS_SELECTED[DOT_ZSH] )) && require_tool git 'The dotfiles repo and Zsh plugins'
  (( DOTS_SELECTED[DOT_STARSHIP] )) && require_tool starship 'The Starship prompt'
  (( DOTS_SELECTED[DOT_STARSHIP] || DOTS_SELECTED[DOT_STANDALONE] || SYS_SELECTED[SYS_HOSTS] )) \
    && require_tool curl 'Config downloads and the hosts update'
  (( SYS_SELECTED[SYS_LOGIN] )) && require_tool zsh 'Zsh as the login shell'

  if (( DOTS_SELECTED[DOT_REPO] )); then
    case "$DOT_STATE" in
      invalid) PLAN_BLOCKERS+=("$DOTFILES_DIR exists but is not a bare Git repository. Move or rename it, then run again.") ;;
      bare)
        [[ -n "$DOT_BRANCH" ]] || PLAN_BLOCKERS+=("$DOTFILES_DIR is not on a branch (detached HEAD). Switch back with: dotgit switch master")
        if ((${#DOT_CHANGES[@]})); then
          for name in "${DOT_CHANGES[@]}"; do changed+=("${name:3}"); done
          short_list 4 "${changed[@]}"
          PLAN_BLOCKERS+=("Tracked dotfiles have local changes: $SHORT_LIST. Commit, stash or restore them (dotgit status, dotgit diff), then run again.")
        fi
        ;;
    esac
    if ((${#CONFLICTS[@]})) && (( ! DOTS_SELECTED[DOT_BACKUP] )); then
      short_list 4 "${CONFLICTS[@]}"
      PLAN_BLOCKERS+=("${#CONFLICTS[@]} existing path(s) would be overwritten by the checkout: $SHORT_LIST. Select 'Back up conflicts' or move them.")
    fi
  fi
  if (( DOTS_SELECTED[DOT_STANDALONE] )) && { (( DOTS_SELECTED[DOT_REPO] )) || [[ "$DOT_STATE" == bare ]]; }; then
    PLAN_BLOCKERS+=("'App configs only' would overwrite Neovim and Fastfetch files tracked by the bare repo. Use it only on machines without $DOTFILES_DIR.")
  fi
  if (( SYS_SELECTED[SYS_HOSTS] && ! HOSTS_MARKERS_OK )); then
    PLAN_BLOCKERS+=('The managed block markers in /etc/hosts are nested, repeated or out of order. Fix them by hand first.')
  fi
  for name in "${APT_UNAVAILABLE[@]}"; do pkg_selected "$name" && unavailable+=("$name"); done
  if ((${#unavailable[@]})); then
    PLAN_BLOCKERS+=("Not in the enabled apt repositories: ${unavailable[*]}. Deselect them, or enable the repository components that have them.")
  fi
  return 0
}

# Optional extra lines per group on the plan screen (shown under the group).
plan_group_notes() { # group index -> PLAN_NOTES array
  local i new=0 have=0 shell
  PLAN_NOTES=()
  case "$1" in
    0|1)
      local -n __sel=${GROUP_SELECTED[$1]} __inst=${GROUP_INSTALLED[$1]}
      for i in "${!__sel[@]}"; do (( __sel[i] )) || continue; if (( __inst[i] )); then ((have++)); else ((new++)); fi; done
      unset -n __sel __inst
      if (( new )); then PLAN_NOTES+=("$new to install with $PKG_MANAGER, $have already installed")
      else PLAN_NOTES+=("all already installed; $PKG_MANAGER skips them")
      fi
      # Say once, under the first package group, that installing syncs first.
      if { (( $1 == 0 )) || ! any_selected "${SHELL_SELECTED[@]}"; } && packages_to_install; then
        if [[ "$PKG_MANAGER" == apt ]]; then PLAN_NOTES+=('apt-get update runs first')
        elif (( ! SYS_SELECTED[SYS_UPDATE] )); then PLAN_NOTES+=("pacman -Syu: syncs and fully upgrades the system first (sync alone is unsafe on Arch)")
        fi
      fi
      ;;
    2)
      if (( DOTS_SELECTED[DOT_REPO] )); then
        if [[ "$DOT_STATE" == missing ]]; then
          PLAN_NOTES+=("clone $DOTFILES_REPO into ~/dotfiles, then check it out into ~")
        elif [[ "$DOT_STATE" == invalid ]]; then
          :  # the blocker explains it
        elif (( DOT_INDEX_EMPTY )); then
          PLAN_NOTES+=("first checkout of ${DOT_BRANCH:-HEAD} into ~")
        elif [[ -z "$DOT_REMOTE_SHA" ]]; then
          PLAN_NOTES+=("${DOT_BRANCH:-HEAD}: origin is not reachable right now; the step tries again")
        elif [[ "$DOT_REMOTE_SHA" == "$DOT_HEAD" ]]; then
          PLAN_NOTES+=("$DOT_BRANCH is up to date with origin (${DOT_HEAD:0:7})")
        else
          PLAN_NOTES+=("fetch and fast-forward $DOT_BRANCH to ${DOT_REMOTE_SHA:0:7}${DOT_BEHIND:+ ($DOT_BEHIND new commit(s))}")
        fi
        [[ "$DOT_STATE" == bare ]] && PLAN_NOTES+=('no Git config changes; works like dotgit pull --ff-only')
        if ((${#CONFLICTS[@]})) && (( DOTS_SELECTED[DOT_BACKUP] )); then
          PLAN_NOTES+=("move ${#CONFLICTS[@]} conflicting path(s) to ~/.dotfiles-backup/$BACKUP_STAMP/")
        fi
      fi
      (( DOTS_SELECTED[DOT_ZSH] )) && PLAN_NOTES+=('plugins in ~/.zsh: autosuggestions, syntax-highlighting, history-substring-search')
      (( DOTS_SELECTED[DOT_STARSHIP] )) && PLAN_NOTES+=("Starship: $STARSHIP_FILE for host $HOST_NAME")
      (( DOTS_SELECTED[DOT_STANDALONE] )) && PLAN_NOTES+=('download nvim/init.lua and fastfetch/config.jsonc; existing files are backed up')
      ;;
    3)
      if (( SYS_SELECTED[SYS_UPDATE] )); then
        if [[ "$PKG_MANAGER" == apt ]]; then PLAN_NOTES+=('apt-get update and upgrade'); else PLAN_NOTES+=('pacman -Syu'); fi
      fi
      if (( SYS_SELECTED[SYS_LOGIN] )); then
        shell=$(command -v zsh 2>/dev/null || printf 'zsh')
        if [[ "$LOGIN_SHELL_NOW" == "$shell" ]]; then PLAN_NOTES+=("login shell is already $shell (no change)")
        else PLAN_NOTES+=("login shell ${LOGIN_SHELL_NOW:-unknown} $G_RUN $shell; log out and back in afterwards")
        fi
      fi
      (( SYS_SELECTED[SYS_HOSTS] )) && PLAN_NOTES+=("replace the managed block from the Gist; backup /etc/hosts.bak.$BACKUP_STAMP")
      if phase_enabled 8; then
        local images='keep custom images' logo='image logo'
        (( SYS_SELECTED[SYS_FF_IMAGES] )) || images='remove custom images'
        (( SYS_SELECTED[SYS_FF_ASCII] )) && logo='built-in logo'
        PLAN_NOTES+=("Fastfetch: $images, $logo")
      fi
      ;;
  esac
  return 0
}

add_completion_note() { # text, added once
  local note
  for note in "${COMPLETION_NOTES[@]}"; do [[ "$note" == "$1" ]] && return 0; done
  COMPLETION_NOTES+=("$1")
}

# Runs after each successful step; add completion notes here, for example a
# reboot hint after a kernel update.
after_step_hook() { # step number
  local shell
  (( DRY_RUN )) && return 0
  case "$1" in
    1|2) [[ -d "/usr/lib/modules/$(uname -r)" ]] || add_completion_note 'A new kernel was installed. Reboot to start using it.' ;;
    3)
      shell=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
      [[ "$shell" != "$LOGIN_SHELL_NOW" ]] && add_completion_note 'Log out and back in to start using Zsh as your login shell.'
      ;;
  esac
  return 0
}

# ── Engine helpers for groups (no changes needed) ───────────────────────────

any_selected() { local v; for v in "$@"; do (( v )) && return 0; done; return 1; }

group_size() { local -n __a=${GROUP_ITEMS[$1]}; GROUP_SIZE=${#__a[@]}; }
item_label() { local -n __a=${GROUP_ITEMS[$1]}; ITEM_LABEL=${__a[$2]}; }
item_selected() { local -n __s=${GROUP_SELECTED[$1]}; (( __s[$2] )); }
set_item() { local -n __s=${GROUP_SELECTED[$1]}; __s[$2]=$3; }
item_installed() {
  [[ -n "${GROUP_INSTALLED[$1]}" ]] || return 1
  local -n __i=${GROUP_INSTALLED[$1]}
  (( __i[$2] ))
}
group_selected_count() { # group -> GROUP_COUNT
  local -n __s=${GROUP_SELECTED[$1]}
  local v
  GROUP_COUNT=0
  for v in "${__s[@]}"; do ((GROUP_COUNT += v)); done
}
set_group() { # group value
  local -n __s=${GROUP_SELECTED[$1]}
  local i
  for i in "${!__s[@]}"; do __s[i]=$2; done
}
selected_labels() { # group -> SELECTED_LABELS array
  local -n __a=${GROUP_ITEMS[$1]} __s=${GROUP_SELECTED[$1]}
  local i
  SELECTED_LABELS=()
  for i in "${!__a[@]}"; do (( __s[i] )) && SELECTED_LABELS+=("${__a[i]}"); done
  return 0
}

sync_groups_from_items() {
  local p g
  for p in "${!PACKAGE_GROUPS[@]}"; do
    g=${PACKAGE_GROUPS[p]}
    group_selected_count "$g"
    if (( GROUP_COUNT )); then PACKAGE_SELECTED[p]=1; else PACKAGE_SELECTED[p]=0; fi
  done
  PACKAGE_PREVIOUS=("${PACKAGE_SELECTED[@]}")
}
apply_group_changes() {
  local p
  # Only a group whose checkbox changed resets its items, so choices made on
  # the review screen survive going back.
  for p in "${!PACKAGE_GROUPS[@]}"; do
    (( PACKAGE_SELECTED[p] != PACKAGE_PREVIOUS[p] )) && set_group "${PACKAGE_GROUPS[p]}" "${PACKAGE_SELECTED[p]}"
  done
  PACKAGE_PREVIOUS=("${PACKAGE_SELECTED[@]}")
}


# ─────────────────────────────────────────────────────────────────────────────
# Wizard screens (no changes needed)
# ─────────────────────────────────────────────────────────────────────────────

show_message_screen() { # title color lines...
  local title=$1 color=$2 row=5 line
  shift 2
  local -a wrapped=()
  draw_header "$title"
  local text
  for text in "$@"; do
    wrap_into wrapped $((W - 2)) "$text"
    for line in "${wrapped[@]}"; do put "$row" "$color$line$RESET"; ((row++)); done
  done
  put $((row + 1)) "${DIM}Log: $LOG_FILE$RESET"
  draw_footer 'Enter' 'Exit'
  while read_key; do [[ "$KEY" == ENTER || "$KEY" == ESC || "$KEY" == q ]] && return 0; done
}


show_welcome() {
  local os user host session size_note row g
  os=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release 2>/dev/null | sed 's/^"//;s/"$//')
  [[ -n "$os" ]] || os=Linux
  user=$(id -un 2>/dev/null || printf 'unknown')
  host=$(hostname -s 2>/dev/null || cat /etc/hostname 2>/dev/null || printf 'unknown')
  session="${XDG_CURRENT_DESKTOP:-no desktop}${XDG_SESSION_TYPE:+ ($XDG_SESSION_TYPE)}"
  log_event 'Welcome screen.'
  while :; do
    draw_header 'Welcome'
    put 5 "$DIM$G_INFO$RESET $LAVENDER$os$RESET $DIM$G_SEP$RESET $LAVENDER$user@$host$RESET $DIM$G_SEP$RESET $LAVENDER$session$RESET"
    put 7 "$BLUE${BOLD}What this installer can set up$RESET"
    row=8
    for g in "${!GROUP_TITLES[@]}"; do
      put "$row" "  $PINK$G_DIAMOND$RESET $(pad "${LAVENDER}${BOLD}${GROUP_TITLES[g]}$RESET" 24)${DIM}${GROUP_SUMMARY[g]}$RESET"
      ((row++))
    done
    ((row++))
    put "$row" "$BLUE${BOLD}How it works$RESET"; ((row++))
    put "$row" "  ${CYAN}1$RESET Choose  $DIM$G_RUN$RESET  ${CYAN}2$RESET Review  $DIM$G_RUN$RESET  ${CYAN}3$RESET Authenticate  $DIM$G_RUN$RESET  ${CYAN}4$RESET Install"; ((row++))
    put "$row" "  ${DIM}Nothing changes until you confirm the plan and enter your password.$RESET"; ((row += 2))
    if (( DRY_RUN )); then
      put "$row" "$YELLOW$BOLD$G_WARN Dry run:$RESET$YELLOW commands are shown, nothing is changed.$RESET"; ((row++))
    fi
    if (( TERM_COLS < 80 || TERM_ROWS < 24 )); then
      size_note="Terminal is ${TERM_COLS}x${TERM_ROWS}; resize to at least 80x24 for the best layout."
      put "$row" "$YELLOW$G_WARN $size_note$RESET"
    fi
    draw_footer 'Enter' 'Start' 'Esc' 'Quit'
    read_key || return 1
    case "$KEY" in
      ENTER) log_event 'Welcome accepted.'; return 0 ;;
      ESC|q|Q) return 1 ;;
    esac
  done
}

# Status text and color for one review row -> ST_TEXT ST_COLOR SEL
item_status() { # group index
  local g=$1 i=$2
  ST_TEXT='' ST_COLOR=$DIM SEL=0
  item_selected "$g" "$i" && SEL=1
  if [[ "${GROUP_KIND[g]}" == package ]]; then
    if item_installed "$g" "$i"; then ST_TEXT="$G_OK installed" ST_COLOR=$DIM$GREEN
    elif (( SEL )); then ST_TEXT='+ install' ST_COLOR=$GREEN
    else ST_TEXT="$G_SKIP skip"
    fi
  else
    if (( SEL )); then ST_TEXT='+ apply' ST_COLOR=$GREEN; else ST_TEXT="$G_SKIP skip"; fi
  fi
}

show_selection_review() {
  local -a rg=() ri=() rl=() rcol=() rr=() hg=() hc=() hr=() col_row=(7 7)
  local i g r c cw lw x cursor=${REVIEW_CURSOR:-0} mark label_color notes_row target best dist
  # Lay out groups into two columns once; rows are fixed for the screen.
  for g in "${!GROUP_TITLES[@]}"; do
    c=${GROUP_COLUMN[g]}; r=${col_row[c]}
    hg+=("$g"); hc+=("$c"); hr+=("$r"); ((r++))
    group_size "$g"
    for ((i = 0; i < GROUP_SIZE; i++)); do
      item_label "$g" "$i"
      rg+=("$g"); ri+=("$i"); rl+=("$ITEM_LABEL"); rcol+=("$c"); rr+=("$r"); ((r++))
    done
    ((r++))
    col_row[c]=$r
  done
  notes_row=${col_row[0]}
  (( col_row[1] > notes_row )) && notes_row=${col_row[1]}
  (( cursor >= ${#rg[@]} )) && cursor=0
  log_event 'Step 04/06: Review selections.'
  while :; do
    draw_header 'Review selections' Step 4 6
    cw=$(((W - 4) / 2)); lw=$((cw - 19))
    put 5 "${LAVENDER}Fine-tune individual items. Status shows what is already on this system.$RESET"
    for i in "${!hg[@]}"; do
      g=${hg[i]}
      group_selected_count "$g"; group_size "$g"
      at "${hr[i]}" $((3 + hc[i] * (cw + 4)))
      printf '%s%s%s %s%d/%d%s' "$BLUE$BOLD" "${GROUP_TITLES[g]}" "$RESET" "$DIM" "$GROUP_COUNT" "$GROUP_SIZE" "$RESET"
    done
    for i in "${!rg[@]}"; do
      item_status "${rg[i]}" "${ri[i]}"
      if (( i == cursor )); then mark="$CYAN$BOLD$G_CUR$RESET" label_color=$CYAN$BOLD
      elif (( SEL )); then mark=' ' label_color=$LAVENDER
      else mark=' ' label_color=$DIM
      fi
      at "${rr[i]}" $((3 + rcol[i] * (cw + 4)))
      fit "${rl[i]}" "$lw"
      pad_v PADDED "$label_color$FIT_OUT$RESET" "$lw"
      if (( SEL )); then
        printf '%s %s%s%s %s %s%s%s' "$mark" "$GREEN" "$G_ON" "$RESET" "$PADDED" "$ST_COLOR" "$ST_TEXT" "$RESET"
      else
        printf '%s %s%s%s %s %s%s%s' "$mark" "$DIM" "$G_OFF" "$RESET" "$PADDED" "$ST_COLOR" "$ST_TEXT" "$RESET"
      fi
    done
    # Optional notes under the columns go here (row "$notes_row" onward).
    : "$notes_row"
    draw_footer "$G_ARROWS" 'Move' 'Space' 'Toggle' 'G' 'Group' 'A/N' 'All/None' 'Enter' 'Next' 'B' 'Back' 'Esc' 'Quit'
    read_key || return 1
    case "$KEY" in
      UP|k|K) (( cursor > 0 )) && ((cursor--)) ;;
      DOWN|j|J) (( cursor + 1 < ${#rg[@]} )) && ((cursor++)) ;;
      LEFT|RIGHT|h|l)
        if [[ "$KEY" == LEFT || "$KEY" == h ]]; then target=0; else target=1; fi
        if (( rcol[cursor] != target )); then
          best=-1 x=$cursor
          for i in "${!rg[@]}"; do
            (( rcol[i] == target )) || continue
            dist=$((rr[i] - rr[cursor])); (( dist < 0 )) && dist=$((-dist))
            if (( best < 0 )) || (( dist < best )); then best=$dist; x=$i; fi
          done
          cursor=$x
        fi
        ;;
      SPACE)
        g=${rg[cursor]} i=${ri[cursor]}
        if item_selected "$g" "$i"; then set_item "$g" "$i" 0; else set_item "$g" "$i" 1; fi
        log_event "Review toggle: ${rl[cursor]}."
        ;;
      g|G)
        g=${rg[cursor]}
        group_selected_count "$g"
        if (( GROUP_COUNT )); then set_group "$g" 0; else set_group "$g" 1; fi
        ;;
      a|A) for g in "${!GROUP_TITLES[@]}"; do set_group "$g" 1; done ;;
      n|N) for g in "${!GROUP_TITLES[@]}"; do set_group "$g" 0; done ;;
      ENTER) REVIEW_CURSOR=$cursor; log_event 'Selection review confirmed.'; return 0 ;;
      b|B|BACKSPACE) REVIEW_CURSOR=$cursor; return 2 ;;
      ESC|q|Q) return 1 ;;
    esac
  done
}

draw_menu() {
  local step=$1 title=$2 intro=$3
  local -n labels_ref=$4 details_ref=$5 selected_ref=$6
  local cursor=0 i row line mark box label_color
  local -a wrapped=()
  while :; do
    draw_header "$title" Step "$step" 6
    put 5 "$LAVENDER$intro$RESET"
    row=7
    for i in "${!labels_ref[@]}"; do
      if (( i == cursor )); then mark="$CYAN$BOLD$G_CUR$RESET" label_color=$CYAN$BOLD; else mark=' ' label_color=$LAVENDER; fi
      if (( selected_ref[i] )); then box="$GREEN$G_ON$RESET"; else box="$DIM$G_OFF$RESET"; fi
      (( selected_ref[i] )) && (( i != cursor )) && label_color=$LAVENDER$BOLD
      put "$row" "$mark $box $label_color${labels_ref[i]}$RESET"; ((row++))
      wrap_into wrapped $((W - 6)) "${details_ref[i]}"
      for line in "${wrapped[@]}"; do put "$row" "    $DIM$line$RESET"; ((row++)); done
      ((row++))
    done
    draw_footer "$G_UPDOWN" 'Move' 'Space' 'Toggle' 'A' 'All' 'N' 'None' 'Enter' 'Next' 'B' 'Back' 'Esc' 'Quit'
    read_key || return 1
    case "$KEY" in
      UP|k|K) (( cursor > 0 )) && ((cursor--)) ;;
      DOWN|j|J) (( cursor + 1 < ${#labels_ref[@]} )) && ((cursor++)) ;;
      SPACE) selected_ref[cursor]=$((1 - selected_ref[cursor])); log_event "Toggled ${labels_ref[cursor]} to ${selected_ref[cursor]}." ;;
      a|A) for i in "${!selected_ref[@]}"; do selected_ref[i]=1; done ;;
      n|N) for i in "${!selected_ref[@]}"; do selected_ref[i]=0; done ;;
      ENTER) log_event "Completed page: $title (${selected_ref[*]})."; return 0 ;;
      b|B|BACKSPACE) return 2 ;;
      ESC|q|Q) return 1 ;;
    esac
  done
}


# ── Plan ────────────────────────────────────────────────────────────────────

PLAN_LINES=() PLAN_BLOCKERS=()
PLAN_LABEL_W=22
plan_row() { # kind label value [more values...]
  local kind=$1 label=$2 icon color value first=1 line
  shift 2
  local -a wrapped=()
  case "$kind" in
    ok) icon=$G_OK color=$GREEN ;;
    skip) icon=$G_SKIP color=$DIM ;;
    warn) icon=$G_WARN color=$YELLOW ;;
    block) icon=$G_FAIL color=$RED ;;
  esac
  local value_w=$((W - 4 - 2 - PLAN_LABEL_W))
  for value in "$@"; do
    if (( first )); then
      wrap_into wrapped "$value_w" "$value"
      PLAN_LINES+=("$color$icon$RESET $(pad "$LAVENDER$BOLD$label$RESET" "$PLAN_LABEL_W")$LAVENDER${wrapped[0]}$RESET")
    else
      wrap_into wrapped "$value_w" "$G_SUB $value" '  '
      PLAN_LINES+=("  $(pad '' "$PLAN_LABEL_W")$DIM${wrapped[0]}$RESET")
    fi
    for line in "${wrapped[@]:1}"; do
      PLAN_LINES+=("  $(pad '' "$PLAN_LABEL_W")$( ((first)) && printf '%s' "$LAVENDER" || printf '%s' "$DIM")$line$RESET")
    done
    first=0
  done
}

join_by() { local sep=$1 out='' x; shift; for x in "$@"; do out+="${out:+$sep}$x"; done; printf '%s' "$out"; }


build_plan() {
  local g problem any=0
  PLAN_LINES=() PLAN_BLOCKERS=()
  for g in "${!GROUP_TITLES[@]}"; do
    selected_labels "$g"
    ((${#SELECTED_LABELS[@]})) || continue
    any=1
    plan_group_notes "$g"
    plan_row ok "${GROUP_TITLES[g]}" "$(join_by ', ' "${SELECTED_LABELS[@]}")" "${PLAN_NOTES[@]}"
  done
  (( any )) || PLAN_BLOCKERS+=('Nothing is selected. Go back and choose at least one item.')
  collect_plan_blockers
  for problem in "${PLAN_BLOCKERS[@]}"; do plan_row block 'Cannot continue' "$problem"; done
  return 0
}

show_plan() {
  log_event 'Step 05/06: Review the plan.'
  build_plan
  PAGER_START=0
  while :; do
    draw_header 'Review the plan' Step 5 6
    put 5 "${LAVENDER}This run will:$RESET"
    pager_draw PLAN_LINES 7 $((BODY_LAST - 1))
    if ((${#PLAN_BLOCKERS[@]})); then
      put "$BODY_LAST" "$RED$G_FAIL Resolve the ${#PLAN_BLOCKERS[@]} problem(s) marked $G_FAIL to continue. B goes back.$RESET"
      draw_footer "$G_UPDOWN" 'Scroll' 'B' 'Back' 'Esc' 'Quit'
    else
      put "$BODY_LAST" "${CYAN}Next: enter your password, then installation starts.$RESET"
      draw_footer "$G_UPDOWN" 'Scroll' 'Enter' 'Continue' 'B' 'Back' 'Esc' 'Quit'
    fi
    read_key || return 1
    pager_scroll "$KEY" && continue
    case "$KEY" in
      ENTER) ((${#PLAN_BLOCKERS[@]})) && continue; log_event 'Plan confirmed.'; return 0 ;;
      b|B|BACKSPACE) return 2 ;;
      ESC|q|Q) return 1 ;;
    esac
  done
}

# ── Authentication ──────────────────────────────────────────────────────────

draw_auth_page() { # masked-length message message-color
  local length=$1 message=$2 mcolor=${3:-$CYAN} bw shown label=' sudo password '
  draw_header 'Authenticate' Step 6 6
  bw=$((W < 52 ? W : 52))
  if (( DRY_RUN )); then
    put 5 "${YELLOW}Dry run: nothing is installed, so the password is not checked.$RESET"
    put 6 "${DIM}Press Enter to continue.$RESET"
  else
    put 5 "${LAVENDER}Installation needs administrator rights.$RESET"
    put 6 "${DIM}Your password is passed only to sudo and is never logged or stored.$RESET"
  fi
  put 8 "$PURPLE$G_TL$G_H$RESET$DIM$label$RESET$PURPLE${HBAR:0:bw-3-${#label}}$G_TR$RESET"
  if (( length > 0 )); then
    shown=$length; (( shown > bw - 4 )) && shown=$((bw - 4))
    repeat_glyph "$G_MASK" "$shown"
    put 9 "$PURPLE$G_V$RESET $(pad "$LAVENDER$REPEAT_OUT$RESET" $((bw - 4))) $PURPLE$G_V$RESET"
  else
    put 9 "$PURPLE$G_V$RESET $(pad "${DIM}type your password$RESET" $((bw - 4))) $PURPLE$G_V$RESET"
  fi
  put 10 "$PURPLE$G_BL${HBAR:0:bw-2}$G_BR$RESET"
  [[ -z "$message" ]] || put 12 "$mcolor$message$RESET"
  draw_footer 'Enter' 'Authenticate' 'Esc' 'Back' 'Ctrl+C' 'Quit'
}

show_authentication() {
  local password='' message='' mcolor=$CYAN auth_pid auth_rc spin=0
  log_event 'Step 06/06: Authentication.'
  while :; do
    draw_auth_page "${#password}" "$message" "$mcolor"
    read_key || return 1
    case "$KEY" in
      ENTER)
        if (( DRY_RUN )); then password=''; log_event 'Dry run: authentication skipped.'; return 0; fi
        if [[ -z "$password" ]]; then message='Enter your sudo password to continue.' mcolor=$YELLOW; continue; fi
        log_event 'Validating sudo credentials.'
        # Validate in the background so the spinner keeps moving. The password
        # travels through a pipe: never argv, the environment, or the log.
        { printf '%s\n' "$password" | sudo -S -p '' -v >/dev/null 2>&1; } &
        auth_pid=$!
        password=''
        while kill -0 "$auth_pid" 2>/dev/null; do
          put 12 "$CYAN${SPINNER[spin % ${#SPINNER[@]}]} Checking with sudo$G_ELLIPSIS$RESET"
          ((spin++))
          sleep 0.08
        done
        auth_rc=0
        wait "$auth_pid" || auth_rc=$?
        if (( auth_rc == 0 )); then log_event 'Sudo authentication succeeded.'; return 0; fi
        log_event "Sudo authentication failed (status $auth_rc)."
        message="$G_FAIL Sudo did not accept that password. Try again." mcolor=$RED
        ;;
      ESC) password=''; return 2 ;;
      BACKSPACE) password=${password%?}; message='' ;;
      SPACE) password+=' '; message='' ;;
      CTRL_D|UP|DOWN|LEFT|RIGHT|PGUP|PGDN|HOME|END|IGNORE|CTRL_C) : ;;
      *) [[ ${#KEY} == 1 && "$KEY" == [[:print:]] ]] && { password+=$KEY; message=''; } ;;
    esac
  done
}

start_sudo_keepalive() {
  (( DRY_RUN )) && return 0
  local parent=$$
  # Refresh the sudo timestamp while installation runs; Arch's default sudo
  # timeout is 5 minutes, shorter than many updates or AUR builds.
  ( while sleep 45; do
      kill -0 "$parent" 2>/dev/null || exit 0
      sudo -n -v 2>/dev/null || exit 0
    done ) </dev/null >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
  log_event "Sudo keepalive started (pid $SUDO_KEEPALIVE_PID)."
}

# ── Log viewer and completion ──────────────────────────────────────────────

LOG_VIEW=()
load_log_view() {
  local line
  local -a raw=() wrapped=()
  LOG_VIEW=()
  mapfile -t raw < "$LOG_FILE"
  for line in "${raw[@]}"; do
    wrap_into wrapped $((W - 2)) "$line" '           '
    LOG_VIEW+=("${wrapped[@]}")
  done
  ((${#LOG_VIEW[@]})) || LOG_VIEW=('No log entries yet.')
}

show_log_viewer() {
  local saved=$PAGER_START
  load_log_view
  PAGER_START=-1
  while :; do
    draw_header 'Full log'
    pager_draw LOG_VIEW 5 $((BODY_LAST - 1))
    put "$BODY_LAST" "${DIM}File: $LOG_FILE$RESET"
    draw_footer "$G_UPDOWN" 'Scroll' 'PgUp/PgDn' 'Page' 'Home/End' 'Jump' 'Esc' 'Back'
    read_key || break
    pager_scroll "$KEY" && continue
    case "$KEY" in ESC|CTRL_D|q|Q|ENTER|b|B) break ;; esac
  done
  PAGER_START=$saved
}


show_completion() {
  local i icon color status title outcome=ok note
  local -a lines=()
  for i in "${!PHASE_TITLES[@]}"; do
    case "${PHASE_STATE[i]}" in
      ok) icon=$G_OK color=$GREEN status="done in ${PHASE_TIME[i]}" ;;
      fail) icon=$G_FAIL color=$RED status="failed (exit ${PHASE_RC[i]}) after ${PHASE_TIME[i]}"; outcome=fail ;;
      skip) icon=$G_SKIP color=$DIM status='not selected' ;;
      stopped) icon=$G_SKIP color=$YELLOW status='not run'; [[ "$outcome" == ok ]] && outcome=stopped ;;
      *) icon=$G_SKIP color=$DIM status='not run' ;;
    esac
    lines+=("$color$icon$RESET $(pad "$LAVENDER${PHASE_TITLES[i]}$RESET" 28)$color$status$RESET")
  done
  lines+=('')
  for note in "${COMPLETION_NOTES[@]}"; do lines+=("$YELLOW$G_REBOOT $note$RESET"); done
  (( DRY_RUN )) && lines+=("$YELLOW$G_WARN Dry run: nothing was changed.$RESET")
  case "$outcome" in
    ok) title='Finished' ;;
    fail) title='Finished with errors' ;;
    stopped) title='Stopped' ;;
  esac
  log_event "Run finished: $outcome."
  PAGER_START=0
  while :; do
    draw_header "$title"
    case "$outcome" in
      ok) put 5 "$GREEN$BOLD$G_OK Selected setup actions completed.$RESET" ;;
      fail) put 5 "$RED$BOLD$G_FAIL Some steps failed. Open the full log for details.$RESET" ;;
      stopped) put 5 "$YELLOW$BOLD$G_WARN Stopped at your request. Remaining steps were not run.$RESET" ;;
    esac
    pager_draw lines 7 $((BODY_LAST - 1))
    put "$BODY_LAST" "${DIM}Log: $LOG_FILE$RESET"
    draw_footer 'Ctrl+D' 'Full log' 'Enter' 'Exit'
    read_key || return 0
    case "$KEY" in
      CTRL_D|l|L) show_log_viewer ;;
      ENTER|ESC|q|Q|CTRL_C) return 0 ;;
    esac
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Install step frame
# ─────────────────────────────────────────────────────────────────────────────

FRAME_LINES=() FRAME_NUM=0 FRAME_TITLE='' FRAME_STATUS='' FRAME_STATUS_COLOR=''

frame_line_color() {
  case "$1" in
    "$G_OK "*) FRAME_COLOR=$GREEN ;;
    "$G_FAIL "*) FRAME_COLOR=$RED ;;
    "$G_WARN "*|warning:*|*' warning: '*) FRAME_COLOR=$YELLOW ;;
    "$G_RUN "*) FRAME_COLOR=$CYAN ;;
    "$G_INFO "*|'::'*) FRAME_COLOR=$BLUE ;;
    *) case "${1,,}" in
         *error*|*failed*|*failure*|*denied*|*'not found'*) FRAME_COLOR=$RED ;;
         *) FRAME_COLOR=$LAVENDER ;;
       esac ;;
  esac
}

draw_frame_box() {
  local visible=$1 label=' Output '
  put 5 "$PURPLE$G_TL$G_H$RESET$DIM$label$RESET$PURPLE${HBAR:0:W-3-${#label}}$G_TR$RESET"
  local i
  for ((i = 1; i <= visible; i++)); do
    printf '\e[%d;1H\e[2K  %s%s%s\e[%d;%dH%s%s%s' $((5 + i)) "$PURPLE" "$G_V" "$RESET" $((5 + i)) $((W + 2)) "$PURPLE" "$G_V" "$RESET"
  done
  put $((6 + visible)) "$PURPLE$G_BL${HBAR:0:W-2}$G_BR$RESET"
}

draw_frame_rows() {
  local visible=$1 start i line inner=$((W - 4)) out=''
  start=$((${#FRAME_LINES[@]} - visible))
  (( start < 0 )) && start=0
  for ((i = 0; i < visible; i++)); do
    line=${FRAME_LINES[start + i]:-}
    frame_line_color "$line"
    pad_v PADDED "$FRAME_COLOR$line$RESET" "$inner"
    out+=$'\e['"$((6 + i));5H$PADDED"
  done
  # One write per redraw so the terminal never shows a half-updated frame.
  printf '%s' "$out"
}

draw_frame_status() { # visible text color
  put $((7 + $1)) "$3$2$RESET"
}

redraw_frame() {
  local visible=$((TERM_ROWS - 11))
  (( visible < 3 )) && visible=3
  draw_header "${FRAME_TITLE}" Install "$FRAME_NUM" "$PHASE_COUNT"
  draw_frame_box "$visible"
  draw_frame_rows "$visible"
  draw_frame_status "$visible" "$FRAME_STATUS" "$FRAME_STATUS_COLOR"
}

format_elapsed() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }

clean_output_line() { # text -> CLEAN_LINE without terminal control sequences
  local s=${1%$'\r'}
  s=${s##*$'\r'}
  s=${s//$'\e'\[*([0-9;?])[A-Za-z]/}
  s=${s//$'\e'\]*([^$'\a'])$'\a'/}
  s=${s//$'\t'/    }
  s=${s//[$'\001'-$'\037'$'\177']/}
  CLEAN_LINE=$s
}

# run_step NUMBER TITLE FUNCTION -> exit status of FUNCTION
run_step() {
  local num=$1 title=$2 fn=$3
  local visible fd pid rc=0 read_rc line pending='' started=$SECONDS spin=0 dirty=1 burst key
  local -a wrapped=()
  ui_metrics
  visible=$((TERM_ROWS - 11))
  (( visible < 3 )) && visible=3
  FRAME_LINES=() FRAME_NUM=$num FRAME_TITLE=$title
  FRAME_STATUS='' FRAME_STATUS_COLOR=$CYAN
  log_event "Install step $num/$PHASE_COUNT started: $title."
  draw_header "$title" Install "$num" "$PHASE_COUNT"
  draw_frame_box "$visible"
  draw_footer 'Ctrl+C' 'Stop after this step'

  # stdin is /dev/null so a prompt fails immediately instead of hanging.
  coproc STEP_CMD { step_entry "$fn" </dev/null 2>&1; }
  exec {fd}<&"${STEP_CMD[0]}"
  pid=$STEP_CMD_PID

  while :; do
    burst=0
    while :; do
      if IFS= read -r -t 0.12 -u "$fd" line; then read_rc=0; else read_rc=$?; fi
      if (( read_rc > 128 )); then pending+=$line; break; fi
      line="$pending$line" pending=''
      if (( read_rc == 0 )) || [[ -n "$line" ]]; then
        log_event "  $line"
        clean_output_line "$line"
        if [[ -n "${CLEAN_LINE//[[:space:]]/}" ]]; then
          wrap_into wrapped $((W - 4)) "$CLEAN_LINE" '  '
          FRAME_LINES+=("${wrapped[@]}")
          dirty=1
        fi
      fi
      (( read_rc != 0 )) && break
      (( ++burst >= 300 )) && break
      read -t 0 -u "$fd" || break
    done
    if (( ${#FRAME_LINES[@]} > 4000 )); then FRAME_LINES=("${FRAME_LINES[@]: -2000}"); fi
    if read -t 0 -u 0 2>/dev/null && IFS= read -rsn1 -u 0 key; then
      if [[ "$key" == $'\x03' ]] && (( ! STOP_REQUESTED )); then
        STOP_REQUESTED=1
        log_event 'Stop requested; finishing the current step.'
      fi
    fi
    (( dirty )) && { draw_frame_rows "$visible"; dirty=0; }
    if (( STOP_REQUESTED )); then
      FRAME_STATUS="${SPINNER[spin % ${#SPINNER[@]}]} $title $G_SEP $(format_elapsed $((SECONDS - started))) $G_SEP stopping after this step$G_ELLIPSIS"
      FRAME_STATUS_COLOR=$YELLOW
    else
      FRAME_STATUS="${SPINNER[spin % ${#SPINNER[@]}]} $title $G_SEP $(format_elapsed $((SECONDS - started)))"
    fi
    draw_frame_status "$visible" "$FRAME_STATUS" "$FRAME_STATUS_COLOR"
    ((spin++))
    (( read_rc == 1 )) && break
  done
  exec {fd}<&-
  wait "$pid" || rc=$?

  PHASE_TIME[num-1]=$(format_elapsed $((SECONDS - started)))
  PHASE_RC[num-1]=$rc
  if ((${#FRAME_LINES[@]} == 0)); then FRAME_LINES=('(no output)'); draw_frame_rows "$visible"; fi
  if (( rc == 0 )); then
    PHASE_STATE[num-1]=ok
    FRAME_STATUS="$G_OK ${PHASE_DONE_TEXT[num-1]} (${PHASE_TIME[num-1]})" FRAME_STATUS_COLOR=$GREEN
    log_event "Install step $num/$PHASE_COUNT completed: $title (${PHASE_TIME[num-1]})."
  else
    PHASE_STATE[num-1]=fail
    FRAME_STATUS="$G_FAIL $title failed (exit $rc) after ${PHASE_TIME[num-1]}" FRAME_STATUS_COLOR=$RED
    log_event "ERROR: install step $num/$PHASE_COUNT failed: $title (exit $rc)."
  fi
  draw_frame_status "$visible" "$FRAME_STATUS" "$FRAME_STATUS_COLOR"
  return "$rc"
}

step_entry() {
  if (( ! DRY_RUN )); then
    sudo -n -v 2>/dev/null || { error 'Sudo authorization expired; nothing was run.'; return 1; }
  fi
  "$@"
}

# After a step: brief pause on success, explicit choice on failure.
# Returns 0 to continue, 1 to stop the run.
after_step() {
  local num=$1 rc=$2 key
  if (( rc == 0 )); then
    (( STOP_REQUESTED )) && return 1
    draw_footer 'Ctrl+C' 'Stop' 'Any key' 'Skip pause'
    if IFS= read -rsn1 -t 1.2 key && [[ "$key" == $'\x03' ]]; then STOP_REQUESTED=1; return 1; fi
    return 0
  fi
  while :; do
    if (( PHASE_FATAL[num-1] )); then
      draw_footer 'Ctrl+D' 'Full log' 'Enter' 'Finish'
    else
      draw_footer 'Ctrl+D' 'Full log' 'Enter' 'Continue with remaining steps' 'Esc' 'Stop here'
    fi
    read_key || return 1
    case "$KEY" in
      CTRL_D|l|L) show_log_viewer; redraw_frame ;;
      ENTER) (( PHASE_FATAL[num-1] )) && return 1; (( STOP_REQUESTED )) && return 1; return 0 ;;
      ESC|CTRL_C|q|Q) STOP_REQUESTED=1; return 1 ;;
    esac
  done
}


run_installation_phases() {
  local num rc stop=0
  disable_interrupt_key
  start_sudo_keepalive
  for ((num = 1; num <= PHASE_COUNT; num++)); do
    if ! phase_enabled "$num"; then PHASE_STATE[num-1]=skip; continue; fi
    if (( stop )); then PHASE_STATE[num-1]=stopped; continue; fi
    rc=0
    run_step "$num" "${PHASE_TITLES[num-1]}" "${PHASE_FUNCS[num-1]}" || rc=$?
    (( rc == 0 )) && after_step_hook "$num"
    after_step "$num" "$rc" || stop=1
  done
}

# ═════════════════════════════════════════════════════════════════════════════
# CUSTOMIZE 4: install step functions
#
# Each runs inside the output frame with no keyboard input. Print progress with
# info / success / warn / error, send every system change through run or
# as_root (so --dry-run shows it instead), and return nonzero on failure.
# ═════════════════════════════════════════════════════════════════════════════

# ── Shared helpers ──────────────────────────────────────────────────────────

# Same command as the dotgit function in ~/.shell_functions.
dotgit() { /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }
# Without --work-tree: with it, Git reports every repository as not bare.
is_bare_repo() { [[ -d "$DOTFILES_DIR" && "$(/usr/bin/git --git-dir="$DOTFILES_DIR" rev-parse --is-bare-repository 2>/dev/null)" == true ]]; }

tilde() { TILDE=${1/#"$HOME"/\~}; } # path -> TILDE with $HOME shown as ~

download_to() { # url file (downloads only into TEMP_DIR, so dry runs fetch too)
  curl --fail --location --silent --show-error --connect-timeout 15 "$1" --output "$2"
}

pacman_upgrade() {
  if command -v stdbuf >/dev/null 2>&1; then
    as_root stdbuf -oL -eL pacman -Syu --noconfirm --color never
  else
    as_root pacman -Syu --noconfirm --color never
  fi
}
pacman_sync_install() { # packages... -> sync, full upgrade and install in one transaction
  if command -v stdbuf >/dev/null 2>&1; then
    as_root stdbuf -oL -eL pacman -Syu --needed --noconfirm --color never "$@"
  else
    as_root pacman -Syu --needed --noconfirm --color never "$@"
  fi
}
apt_get() { as_root env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

backup_user_path() { # path under ~ -> copied into this run's backup folder
  local path=$1 dest
  [[ -e "$path" || -L "$path" ]] || return 0
  dest="$DOTFILES_BACKUP_DIR/$BACKUP_STAMP/${path#"$HOME"/}"
  run mkdir -p -- "${dest%/*}" || return 1
  run cp -a -- "$path" "$dest" || return 1
  tilde "$dest"
  info "Backed up to $TILDE"
}

install_downloaded_config() { # url destination
  local url=$1 dest=$2 tmp="$TEMP_DIR/${2##*/}.download"
  tilde "$dest"
  if ! command -v curl >/dev/null 2>&1; then
    (( DRY_RUN )) || { error 'curl is not installed.'; return 1; }
    warn "curl is not installed (dry run continues); $TILDE would be downloaded from $url"
    return 0
  fi
  info "Downloading $url"
  download_to "$url" "$tmp" || { error "Download failed; $TILDE was not changed."; return 1; }
  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then success "$TILDE is already current."; return 0; fi
  backup_user_path "$dest" || return 1
  run mkdir -p -- "${dest%/*}" || return 1
  run install -m 0644 -- "$tmp" "$dest" || return 1
  success "Installed $TILDE"
}

# ── 1. System update ────────────────────────────────────────────────────────

update_system() {
  if [[ "$PKG_MANAGER" == pacman ]]; then
    info 'Updating the system with pacman -Syu'
    pacman_upgrade || { error 'The system update failed.'; return 1; }
  else
    info 'Refreshing apt package lists'
    apt_get update || return 1
    info 'Upgrading installed packages'
    apt_get upgrade -y || { error 'The system upgrade failed.'; return 1; }
  fi
  success 'The system is up to date.'
}

# ── 2. Packages ─────────────────────────────────────────────────────────────

install_selected_packages() {
  local g i font=0
  local -a packages=() present=()
  for g in "${!GROUP_TITLES[@]}"; do
    [[ "${GROUP_KIND[g]}" == package ]] || continue
    group_size "$g"
    for ((i = 0; i < GROUP_SIZE; i++)); do
      item_selected "$g" "$i" || continue
      item_label "$g" "$i"
      if item_installed "$g" "$i"; then present+=("$ITEM_LABEL"); else packages+=("$ITEM_LABEL"); fi
    done
  done
  ((${#present[@]})) && info "Already installed: ${present[*]}"
  if ((${#packages[@]} == 0)); then success 'All selected packages are already installed.'; return 0; fi
  [[ " ${packages[*]} " == *" $FONT_PKG "* ]] && font=1
  info "Installing with $PKG_MANAGER: ${packages[*]}"
  if [[ "$PKG_MANAGER" == pacman ]]; then
    if (( SYS_SELECTED[SYS_UPDATE] )); then
      # The System update step has just synced and upgraded.
      pacman_install "${packages[@]}" || { error 'pacman could not install the packages.'; return 1; }
    else
      # Always sync before installing. On Arch a sync is only safe together
      # with a full upgrade (-Sy alone is a partial upgrade), so this is one
      # -Syu transaction.
      info 'Syncing the package databases and upgrading the system first (pacman -Syu)'
      pacman_sync_install "${packages[@]}" || { error 'pacman could not sync, upgrade and install the packages.'; return 1; }
    fi
  else
    info 'Refreshing apt package lists'
    apt_get update || return 1
    if ! command -v nala >/dev/null 2>&1; then
      info 'Installing Nala with apt'
      apt_get install -y nala || { error 'Could not install Nala; no other packages were installed.'; return 1; }
    fi
    as_root env DEBIAN_FRONTEND=noninteractive nala install -y "${packages[@]}" || return 1
  fi
  if (( font )) && command -v fc-cache >/dev/null 2>&1; then
    info 'Refreshing the font cache'
    run fc-cache -f || { error 'The packages were installed, but refreshing the font cache failed.'; return 1; }
  fi
  success "Installed ${#packages[@]} package(s)."
}

# ── 3. Login shell ──────────────────────────────────────────────────────────

set_login_shell() {
  local user zsh_path current
  user=$(id -un) || return 1
  zsh_path=$(command -v zsh 2>/dev/null) || zsh_path=''
  if [[ -z "$zsh_path" ]]; then
    (( DRY_RUN )) || { error 'Zsh is not installed; install the shell packages first.'; return 1; }
    warn 'Zsh is not installed yet (dry run continues); it would come from the package step.'
    zsh_path=/usr/bin/zsh
  fi
  current=$(getent passwd "$user" | cut -d: -f7) || { error "Could not look up the account $user."; return 1; }
  if [[ "$current" == "$zsh_path" ]]; then success "Zsh ($zsh_path) is already the login shell."; return 0; fi
  if ! grep -Fxq -- "$zsh_path" /etc/shells; then
    (( DRY_RUN )) || { error "$zsh_path is not listed in /etc/shells."; return 1; }
    warn "$zsh_path is not listed in /etc/shells yet (dry run continues)."
  fi
  info "Changing the login shell for $user: $current $G_RUN $zsh_path"
  as_root usermod --shell "$zsh_path" "$user" || { error 'Could not change the login shell.'; return 1; }
  if (( ! DRY_RUN )); then
    [[ "$(getent passwd "$user" | cut -d: -f7)" == "$zsh_path" ]] \
      || { error 'The account database does not show the new shell.'; return 1; }
  fi
  success 'Zsh is now the login shell. Log out and back in for it to take effect.'
}

# ── 4. Dotfiles repo ────────────────────────────────────────────────────────

# Paths in REF that are not tracked yet but exist in ~ (or have a file where
# a folder must go) and would block the checkout -> CONFLICTS array.
collect_conflicts() { # ref
  local ref=$1 relative target prefix
  local -A seen=()
  CONFLICTS=()
  while IFS= read -r -d '' relative; do
    dotgit ls-files --error-unmatch -- "$relative" >/dev/null 2>&1 && continue
    target="$HOME/$relative"
    if [[ -e "$target" || -L "$target" ]]; then seen[$relative]=1; continue; fi
    prefix=$relative
    while [[ "$prefix" == */* ]]; do
      prefix=${prefix%/*}
      target="$HOME/$prefix"
      if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then seen[$prefix]=1; break; fi
    done
  done < <(dotgit ls-tree -r -z --name-only "$ref" 2>/dev/null)
  ((${#seen[@]})) && mapfile -t CONFLICTS < <(printf '%s\n' "${!seen[@]}" | sort)
  return 0
}

move_conflicts() {
  local relative dest root="$DOTFILES_BACKUP_DIR/$BACKUP_STAMP"
  ((${#CONFLICTS[@]})) || return 0
  if (( ! DOTS_SELECTED[DOT_BACKUP] )); then
    error 'These paths would be overwritten by the checkout:'
    for relative in "${CONFLICTS[@]}"; do error "  ~/$relative"; done
    error "Select 'Back up conflicts' or move them, then run again. Nothing was changed."
    return 1
  fi
  tilde "$root"
  info "Moving ${#CONFLICTS[@]} conflicting path(s) to $TILDE"
  for relative in "${CONFLICTS[@]}"; do
    dest="$root/$relative"
    run mkdir -p -- "${dest%/*}" || return 1
    run mv -- "$HOME/$relative" "$dest" || return 1
  done
  success 'Conflicting paths backed up.'
}

# Fastfetch preference edits are hidden from Git with skip-worktree. Before a
# fast-forward they are undone so Git can update those files; the Fastfetch
# step reapplies the saved preferences afterwards.
restore_fastfetch_overrides() {
  local entry
  local -a paths=()
  while IFS= read -r -d '' entry; do
    [[ "${entry:0:1}" == S ]] || continue
    case "${entry:2}" in
      .config/fastfetch/config.jsonc|.config/fastfetch/images/*) paths+=("${entry:2}") ;;
    esac
  done < <(dotgit ls-files -v -z -- .config/fastfetch)
  ((${#paths[@]})) || return 0
  info "Restoring ${#paths[@]} Fastfetch file(s) before the update"
  run dotgit update-index --no-skip-worktree -- "${paths[@]}" || return 1
  run dotgit checkout -- "${paths[@]}" || return 1
}

first_checkout() { # branch
  info 'Checking for files that would block the first checkout'
  collect_conflicts HEAD
  move_conflicts || return 1
  run dotgit checkout || { error 'The checkout failed; see the output above.'; return 1; }
  success "Checked out $1 into ~."
}

clone_dotfiles_repo() {
  local branch
  info "Cloning $DOTFILES_REPO into $DOTFILES_DIR"
  run /usr/bin/git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR" || { error 'The clone failed.'; return 1; }
  if (( DRY_RUN )); then
    dry_note 'after the clone: set status.showUntrackedFiles=no and the branch upstream, back up conflicts if selected, then check out into ~'
    return 0
  fi
  branch=$(dotgit symbolic-ref --quiet --short HEAD) || { error 'The new clone is not on a branch.'; return 1; }
  # The same config the existing setup has: untracked files hidden and an
  # upstream for dotgit pull, with no fetch refspec.
  run dotgit config --local status.showUntrackedFiles no || return 1
  run dotgit config --local "branch.$branch.remote" origin || return 1
  run dotgit config --local "branch.$branch.merge" "refs/heads/$branch" || return 1
  first_checkout "$branch"
}

sync_dotfiles_repo() {
  local branch head target count
  need_cmd git 'git is not installed.' || return 1
  command -v git >/dev/null 2>&1 || { dry_note 'git would come from the package step'; return 0; }
  [[ -e "$DOTFILES_DIR" ]] || { clone_dotfiles_repo; return; }
  is_bare_repo || { error "$DOTFILES_DIR exists but is not a bare Git repository. Nothing was changed."; return 1; }
  branch=$(dotgit symbolic-ref --quiet --short HEAD) \
    || { error "$DOTFILES_DIR is not on a branch (detached HEAD). Nothing was changed."; return 1; }
  if [[ -z "$(dotgit ls-files | sed -n 1p)" ]]; then first_checkout "$branch"; return; fi
  if [[ -n "$(dotgit status --porcelain=v1 --untracked-files=no)" ]]; then
    error 'Tracked dotfiles have local changes. Nothing was changed:'
    dotgit status --short --untracked-files=no
    error 'Commit, stash or restore them (dotgit status, dotgit diff), then run again.'
    return 1
  fi
  head=$(dotgit rev-parse HEAD) || return 1

  # Fetching a branch by name only writes FETCH_HEAD: no remote-tracking refs
  # and no config, exactly like dotgit pull.
  info "Fetching $branch from origin ($(dotgit remote get-url origin 2>/dev/null))"
  run dotgit fetch origin "$branch" || { error 'The fetch failed. Nothing was changed.'; return 1; }
  if (( DRY_RUN )); then
    target=$DOT_REMOTE_SHA
    if [[ -z "$target" ]] || ! dotgit cat-file -e "$target^{commit}" 2>/dev/null; then
      dry_note 'the new commits are not downloaded yet, so the fast-forward cannot be previewed'
      run dotgit merge --ff-only FETCH_HEAD
      return 0
    fi
  else
    target=$(dotgit rev-parse FETCH_HEAD) || return 1
  fi

  if [[ "$target" == "$head" ]]; then success "$branch is already up to date with origin (${head:0:7})."; return 0; fi
  if ! dotgit merge-base --is-ancestor "$head" "$target"; then
    error "$branch has commits that are not on origin, so it cannot fast-forward. Nothing was changed."
    error 'Push or rebase them by hand with dotgit, then run again.'
    return 1
  fi
  count=$(dotgit rev-list --count "$head..$target")
  info "$count new commit(s):"
  dotgit log --oneline --no-decorate "$head..$target" | sed -n 1,20p
  collect_conflicts "$target"
  move_conflicts || return 1
  restore_fastfetch_overrides || return 1
  run dotgit merge --ff-only "$target" || { error 'The fast-forward failed; see the output above.'; return 1; }
  success "Fast-forwarded $branch to ${target:0:7}."
}

# ── 5. Zsh plugins ──────────────────────────────────────────────────────────

sync_zsh_plugins() {
  local repository name target
  need_cmd git 'git is not installed.' || return 1
  run mkdir -p -- "$HOME/.zsh" || return 1
  for repository in "${ZSH_PLUGIN_REPOS[@]}"; do
    name=${repository##*/}
    target="$HOME/.zsh/$name"
    if [[ ! -d "$target" ]]; then
      info "Cloning $name"
      run git clone --depth=1 "https://github.com/$repository.git" "$target" || return 1
    elif [[ -d "$target/.git" ]]; then
      info "Updating $name"
      run git -C "$target" pull --ff-only || return 1
    else
      error "$target is not a Git checkout; left it untouched."
      return 1
    fi
  done
  success 'Zsh plugins are current.'
}

# ── 6. Starship prompt ──────────────────────────────────────────────────────

install_starship_config() {
  need_cmd starship 'starship is not installed.' || return 1
  info "Host $HOST_NAME uses $STARSHIP_FILE"
  install_downloaded_config "$STARSHIP_CONFIG_REPO/$STARSHIP_FILE" "$HOME/.config/starship.toml"
}

# ── 7. Standalone app configs ───────────────────────────────────────────────

install_app_configs() {
  install_downloaded_config "$DOTFILES_RAW/.config/nvim/init.lua" "$HOME/.config/nvim/init.lua" || return 1
  install_downloaded_config "$DOTFILES_RAW/.config/fastfetch/config.jsonc" "$FASTFETCH_CONFIG"
}

# ── 8. Fastfetch preferences ────────────────────────────────────────────────

is_kde_plasma_session() {
  local desktop="${XDG_CURRENT_DESKTOP:-} ${XDG_SESSION_DESKTOP:-} ${DESKTOP_SESSION:-}"
  desktop=${desktop^^}
  [[ "$desktop" =~ (^|[[:space:]:/-])(KDE|PLASMA)([[:space:]:/-]|$) ]]
}

mark_fastfetch_override() { # path relative to ~ -> hidden from git status when tracked
  is_bare_repo || return 0
  dotgit ls-files --error-unmatch -- "$1" >/dev/null 2>&1 || return 0
  run dotgit update-index --skip-worktree -- "$1"
}

set_fastfetch_top_padding_zero() {
  run sed -i '/"padding":[[:space:]]*{/,/}/ s/"top":[[:space:]]*[0-9][0-9]*/"top": 0/' "$FASTFETCH_CONFIG"
}

write_fastfetch_prefs() { # keep-images use-ascii (true/false)
  mkdir -p -- "${FASTFETCH_PREFS%/*}" || return 1
  ( umask 077; printf 'KEEP_IMAGES=%s\nUSE_ASCII=%s\n' "$1" "$2" > "$FASTFETCH_PREFS" )
}

apply_fastfetch_preferences() {
  local keep=true ascii=false relative
  local -a images=()
  (( SYS_SELECTED[SYS_FF_IMAGES] )) || keep=false
  (( SYS_SELECTED[SYS_FF_ASCII] )) && ascii=true
  if [[ ! -f "$FASTFETCH_CONFIG" ]]; then
    if (( DRY_RUN )); then dry_note 'the Fastfetch config would come from the steps above'
    else warn 'The Fastfetch config was not found; only the preferences are saved.'
    fi
  else
    if [[ "$keep" == false ]]; then
      if is_bare_repo; then
        mapfile -d '' -t images < <(dotgit ls-files -z -- .config/fastfetch/images 2>/dev/null)
      fi
      for relative in "${images[@]}"; do
        mark_fastfetch_override "$relative" || return 1
        [[ -e "$HOME/$relative" ]] && { run rm -f -- "$HOME/$relative" || return 1; }
      done
      if [[ -d "$HOME/.config/fastfetch/images" ]]; then
        run find "$HOME/.config/fastfetch/images" -depth -type d -empty -delete || return 1
      fi
      info "Removed ${#images[@]} custom image(s) from ~ (they stay in the repo)."
    fi
    if [[ "$ascii" == true ]]; then
      run sed -i \
        -e 's/"type": "kitty-direct"/"type": "builtin"/' \
        -e 's|"source": "~/.config/fastfetch/images/\*\.png"|"source": ""|' \
        "$FASTFETCH_CONFIG" || { error 'Could not switch Fastfetch to the built-in logo.'; return 1; }
      set_fastfetch_top_padding_zero || return 1
      mark_fastfetch_override .config/fastfetch/config.jsonc || return 1
      info 'Fastfetch now uses the built-in system logo.'
    elif ! is_kde_plasma_session; then
      # Non-KDE desktop sessions use no top padding for the Fastfetch logo.
      set_fastfetch_top_padding_zero || return 1
      mark_fastfetch_override .config/fastfetch/config.jsonc || return 1
      info 'Set the logo top padding to 0 for this non-KDE session.'
    fi
  fi
  run write_fastfetch_prefs "$keep" "$ascii" || { error "Could not save $FASTFETCH_PREFS."; return 1; }
  tilde "$FASTFETCH_PREFS"
  success "Fastfetch preferences saved in $TILDE (images: $keep, built-in logo: $ascii)."
}

# ── 9. Hosts file ───────────────────────────────────────────────────────────

hosts_markers_valid() { # file -> success when the managed markers are absent or well formed
  awk -v start="$HOSTS_BLOCK_START" -v end="$HOSTS_BLOCK_END" '
    $0 == start { if (inside || starts++) bad=1; inside=1; next }
    $0 == end { if (!inside || ends++) bad=1; inside=0; next }
    END { if (inside || starts != ends || bad) exit 1 }
  ' "$1"
}

update_hosts_block() {
  local downloaded="$TEMP_DIR/hosts.gist" base="$TEMP_DIR/hosts.base" candidate="$TEMP_DIR/hosts.new" backup entries
  if ! command -v curl >/dev/null 2>&1; then
    (( DRY_RUN )) || { error 'curl is not installed.'; return 1; }
    warn 'curl is not installed (dry run continues); the hosts list would be downloaded from the Gist.'
    return 0
  fi
  info 'Downloading the hosts list from the Gist'
  download_to "$HOSTS_GIST_URL" "$downloaded" || { error 'The download failed; /etc/hosts was not changed.'; return 1; }
  hosts_markers_valid /etc/hosts \
    || { error 'The managed markers in /etc/hosts are nested, repeated or out of order; /etc/hosts was not changed.'; return 1; }
  awk -v start="$HOSTS_BLOCK_START" -v end="$HOSTS_BLOCK_END" '
    $0 == start { inside=1; next }
    $0 == end { inside=0; next }
    !inside { if (NF == 0) { blanks++; next } while (blanks-- > 0) print ""; blanks=0; print }
  ' /etc/hosts > "$base" || return 1
  awk 'NF && $1 !~ /^#/ && $1 != "127.0.0.1" && $1 != "::1" && $1 != "localhost" { print }' "$downloaded" > "$TEMP_DIR/hosts.entries" || return 1
  entries=$(wc -l < "$TEMP_DIR/hosts.entries")
  { cat "$base"; printf '\n%s\n' "$HOSTS_BLOCK_START"; cat "$TEMP_DIR/hosts.entries"; printf '%s\n' "$HOSTS_BLOCK_END"; } > "$candidate" || return 1
  if cmp -s "$candidate" /etc/hosts; then success "The managed hosts block is already current ($entries entries)."; return 0; fi
  backup="/etc/hosts.bak.$BACKUP_STAMP"
  info "Backing up /etc/hosts to $backup"
  as_root cp -a /etc/hosts "$backup" || return 1
  as_root install -m 0644 "$candidate" /etc/hosts || return 1
  success "Managed hosts block updated ($entries entries)."
}

# ─────────────────────────────────────────────────────────────────────────────
# Main flow (no changes needed)
# ─────────────────────────────────────────────────────────────────────────────

main() {
  local result stage=0 problem
  enter_screen
  log_event "$APP_NAME started (dry run: $DRY_RUN)."

  problem=$(prerequisite_problem)
  if [[ -n "$problem" ]]; then
    log_event "Prerequisite failed: $problem"
    show_message_screen 'Cannot start' "$RED" "$G_FAIL $problem"
    return 1
  fi

  if (( PRESELECT )); then apply_preselection; stage=4; fi

  while :; do
    case "$stage" in
      0) show_welcome || return 0; stage=1 ;;
      1)
        sync_groups_from_items
        result=0
        draw_menu 1 'Optional package groups' 'Choose package groups. You can fine-tune single packages on the review screen.' \
          PACKAGE_LABELS PACKAGE_DETAILS PACKAGE_SELECTED || result=$?
        (( result == 1 )) && return 0
        (( result == 2 )) && { stage=0; continue; }
        apply_group_changes
        stage=2
        ;;
      2)
        result=0
        draw_menu 2 "$PAGE2_TITLE" "$PAGE2_INTRO" DOTS_ITEMS DOTS_DETAILS DOTS_SELECTED || result=$?
        (( result == 1 )) && return 0
        (( result == 2 )) && { stage=1; continue; }
        stage=3
        ;;
      3)
        result=0
        draw_menu 3 "$PAGE3_TITLE" "$PAGE3_INTRO" SYS_ITEMS SYS_DETAILS SYS_SELECTED || result=$?
        (( result == 1 )) && return 0
        (( result == 2 )) && { stage=2; continue; }
        stage=4
        ;;
      4)
        if (( ! PACKAGE_STATUS_READY )); then
          draw_header 'Checking this system' Step 4 6
          put 5 "$CYAN${SPINNER[0]} Checking installed packages$G_ELLIPSIS$RESET"
          check_package_status
        fi
        result=0
        show_selection_review || result=$?
        (( result == 1 )) && return 0
        (( result == 2 )) && { stage=3; continue; }
        stage=5
        ;;
      5)
        result=0
        show_plan || result=$?
        (( result == 1 )) && return 0
        (( result == 2 )) && { stage=4; continue; }
        stage=6
        ;;
      6)
        result=0
        show_authentication || result=$?
        (( result == 1 )) && return 0
        (( result == 2 )) && { stage=5; continue; }
        break
        ;;
    esac
  done

  log_event 'Plan confirmed and authenticated; starting installation.'
  run_installation_phases
  show_completion
  [[ " ${PHASE_STATE[*]} " == *' fail '* ]] && return 1
  return 0
}

main
