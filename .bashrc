#curllocationslist Don't merge
set -o vi
export EDITOR=nvim
alias vim=nvim

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac

PERSISTENT_HISTORY_FILE="$HOME/dot-files/.persistent_history"
HISTTIMEFORMAT="%F %T "
log_bash_persistent_history()
{
  [[
  $(history 1) =~ ^\ *[0-9]+\ +([^\ ]+\ [^\ ]+)\ +(.*)$
  ]]
  local date_part="${BASH_REMATCH[1]}"
  # Replace newlines with blank space and trim trailing spaces
  local command_part=$(echo "${BASH_REMATCH[2]}" | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
  if [ "$command_part" != "$PERSISTENT_HISTORY_LAST" ] && \
    [[ $command_part != "phgrep "* ]]
  then
    if [[ $command_part == "ph "* ]]
    then
      parsed_command=$(echo $command_part | awk '{print $2}')
      command_part=$(_ph_get_command $parsed_command)
    fi
    echo $date_part "|" $HOSTNAME "|" $PWD "|" "$command_part" >> $PERSISTENT_HISTORY_FILE
    export PERSISTENT_HISTORY_LAST="$command_part"
  fi
}

# Stuff to do on PROMPT_COMMAND
run_on_prompt_command()
{
  log_bash_persistent_history
}

_ph_get_command()
{
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    if ! [[ $1 =~ ^-?[0-9]+$ ]]; then
      echo "Illegal non-integer argument."
    else
      command=`sed "$1!d" $PERSISTENT_HISTORY_FILE | awk -F "|" '{print $4}'`
      echo $command
    fi
  fi
}

ph()
{
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    command=$(_ph_get_command $1)
    echo $command
    eval $command
  fi
}

phe()
{
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    command=$(_ph_get_command $1)
    echo $command
  fi
}

mov_to_webm() {
  local width=800
  local speed_filter=""
  local input=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--small)
        width=400
        ;;
      -f|--fast)
        speed_filter=",setpts=PTS/1.5"
        ;;
      -h|--help)
        echo "Usage: mov_to_webm [--small] [--fast] <input.mov>"
        echo "  -s, --small  Scale to 400px wide (default: 800px)"
        echo "  -f, --fast   Speed video up to 1.5x (default: normal speed)"
        return 0
        ;;
      -*)
        echo "Unknown option: $1" >&2
        return 2
        ;;
      *)
        if [ -n "$input" ]; then
          echo "Only one input file is supported" >&2
          return 2
        fi
        input="$1"
        ;;
    esac
    shift
  done

  if [ -z "$input" ]; then
    echo "Usage: mov_to_webm [--small] [--fast] <input.mov>" >&2
    return 2
  fi

  ffmpeg -nostats -i "$input" -an \
    -filter:v "scale=${width}:-1,pad=ceil(iw/2)*2:ceil(ih/2)*2${speed_filter}" \
    -c:v libvpx-vp9 -crf 23 "$input.webm"
}

mov_to_webm_and_upload() {
  local -a conversion_options=()
  local -a inputs=()
  local verbose=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s|--small|-f|--fast)
        conversion_options+=("$1")
        ;;
      -v|--verbose)
        verbose=true
        ;;
      -h|--help)
        echo "Usage: mov_to_webm_and_upload [--small] [--fast] [--verbose] <input.mov> [input.mov ...]"
        echo "  -s, --small    Scale to 400px wide (default: 800px)"
        echo "  -f, --fast     Speed videos up to 1.5x (default: normal speed)"
        echo "  -v, --verbose  Show GitHub attachment upload details"
        return 0
        ;;
      --)
        shift
        inputs+=("$@")
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        return 2
        ;;
      *)
        inputs+=("$1")
        ;;
    esac
    shift
  done

  if [ "${#inputs[@]}" -eq 0 ]; then
    echo "Usage: mov_to_webm_and_upload [--small] [--fast] [--verbose] <input.mov> [input.mov ...]" >&2
    return 2
  fi

  local input output
  local -a webm_files=()
  for input in "${inputs[@]}"; do
    if [ ! -f "$input" ]; then
      echo "mov_to_webm_and_upload: file not found: $input" >&2
      return 1
    fi
  done

  for input in "${inputs[@]}"; do
    output="$input.webm"
    printf 'Converting %s to %s\n' "$input" "$output" >&2
    if ! mov_to_webm "${conversion_options[@]}" "$input"; then
      echo "mov_to_webm_and_upload: conversion failed for $input" >&2
      return 1
    fi
    webm_files+=("$output")
  done

  if [ "$verbose" = true ]; then
    gh_image_upload --verbose -- "${webm_files[@]}"
  else
    gh_image_upload -- "${webm_files[@]}"
  fi
}

mov_to_small() {
  ffmpeg -i "$1" -an -filter:v "scale=800:-1,pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -crf 23 "$1.mp4"
}

mov_to_1_5x_mov() {
  ffmpeg -i "$1" -an -filter:v "setpts=0.6666666*PTS" -c:v libx264 -crf 23 "$1.mp4"
}

mov_to_gif_same_speed() {
  scale="960"
  if [ "$#" -eq 2 ]; then
    scale="$2"
  fi
  ffmpeg -i "$1" -pix_fmt rgb24 -filter:v "fps=10,scale=$scale:-1:flags=lanczos" "$1.gif"
}

mov_to_gif() {
  ffmpeg -i "$1" -pix_fmt rgb24 -filter:v "fps=10,scale=960:-1:flags=lanczos,setpts=PTS/1.5" "$1.gif"
}

mov_to_gif_small() {
  ffmpeg -i "$1" -pix_fmt rgb24 -filter:v "fps=10,scale=480:-1:flags=lanczos,setpts=PTS/1.5" "$1.gif"
}

__fzf_persistent_history__() {
  local selection
  selection=$(tac $PERSISTENT_HISTORY_FILE | \
    fzf --tiebreak=index -d '\|' -n '4..' \
    --bind 'ctrl-v:execute(echo {} | awk -F "|" '"'"'{print $4}'"'"' > /tmp/fzf_cmd_edit.txt; nvim </dev/tty >/dev/tty 2>&1 /tmp/fzf_cmd_edit.txt; echo $? > /tmp/fzf_nvim_exit_code)+accept')

  if [[ -f /tmp/fzf_nvim_exit_code ]]; then
    local exit_code=$(cat /tmp/fzf_nvim_exit_code)
    rm /tmp/fzf_nvim_exit_code
    if [[ $exit_code -eq 0 ]]; then
      cat /tmp/fzf_cmd_edit.txt
      rm /tmp/fzf_cmd_edit.txt
    else
      rm -f /tmp/fzf_cmd_edit.txt
      echo ""
    fi
  else
    echo "$selection" | sed "s/[^|]*|[^|]*|[^|]*|[[:space:]]*//";
  fi
}
# Heavily inspired from ~/.fzf/shell/key-bindings.bash
bind '"\C-x\C-a": vi-movement-mode'
bind '"\C-x\C-e": shell-expand-line'
bind '"\C-x\C-r": redraw-current-line'
bind '"\C-x^": history-expand-line'
bind '"\C-p": "\C-x\C-addi`__fzf_persistent_history__`\C-x\C-e\C-x\C-r\C-x^\C-x\C-a$a\C-m"'

sed_command() {
  if [[ $machine == 'Mac' ]]; then
    echo "gsed"
  else
    echo "sed"
  fi
}

explode_aar() {
  TMP_DIR=$(mktemp -d)
  unzip $1 -d $TMP_DIR || return 1
  unzip $TMP_DIR/classes.jar -d $TMP_DIR/classes || return 1
  echo $TMP_DIR/classes
}

alias pbapply='pbpaste | git apply -p0 --reject'
alias pbapplyghdiff='pbpaste | awk 1 | git apply --reject'

pbcopycommit() {
  if [ "$#" -gt 1 ]; then
    echo "Usage: pbcopycommit [commit]"
    return 1
  fi

  local commit="${1:-HEAD}"
  git show --format=email --binary "$commit" | pbcopy
}

pbam() {
  pbpaste | git am --3way "$@"
}

alias kmpcisend='./scripts/kmp/ci_send.sh'
alias scrcpys10='scrcpy -s $S10_ADB_DEVICE_ID'

alias readerforceuninstall='python3 ./scripts/device-owner/force-uninstall.py'
alias readerbypassappinstallenabled='./scripts/device-owner/reader-control.sh bypassAppInstall true && echo success'
alias readerbypassappinstalldisabled='./scripts/device-owner/reader-control.sh bypassAppInstall false && echo success'
alias readersetupdatesdisabled='./scripts/device-owner/reader-control-check.sh setUpdatesEnabled false && echo SUCCESS'
alias readersetupdatesenabled='./scripts/device-owner/reader-control-check.sh setUpdatesEnabled true && echo SUCCESS'
alias readergenerateregistrationcode='./scripts/device-owner/reader-control.sh generateRegistrationCode && adb logcat -s DebugUpdaterControlReceiver -v raw'
alias clauded='claude --dangerously-skip-permissions'
alias cl='claude --dangerously-skip-permissions'
alias cod='codex --approve-for-me'


create_devbox() {
    local branch_suffix=''
    local workspace='pay-server'  # Default value
    local prompt=''

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch-suffix)
                branch_suffix="$2"
                shift 2
                ;;
            --workspace)
                workspace="$2"
                shift 2
                ;;
            --prompt)
                prompt="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Validate required inputs
    if [[ -z "$branch_suffix" ]]; then
        echo "Error: --branch-suffix is required."
        return 1
    fi

    # Set up variables
    local DATE=$(date +%Y%m%d)
    local branch="$USER/$DATE-$branch_suffix"
    local devboxname="$USER-$DATE-$branch_suffix"

    # Construct the command as an array to preserve argument boundaries
    local cmd=(pay remote new "$devboxname" --repo "stripe-internal/mint:$branch" --workspace "$workspace" --ide none --notify-on-ready --skip-confirm)

    if [[ -n "$prompt" ]]; then
      cmd+=(--prompt "$prompt")
    fi

    echo "${cmd[@]}"
    "${cmd[@]}"
}

# Completion function for create_devbox
_create_devbox_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--branch-suffix --workspace --prompt"

    # Function to check if an option has already been used
    option_used() {
        local opt="$1"
        for ((i=1; i < COMP_CWORD; i++)); do
            if [[ "${COMP_WORDS[i]}" == "$opt" ]]; then
                return 0
            fi
        done
        return 1
    }

    # Filter out already used options
    local available_opts=()
    for opt in $opts; do
        if ! option_used "$opt"; then
            available_opts+=("$opt")
        fi
    done

    if [[ ${cur} == --* ]] ; then
        COMPREPLY=( $(compgen -W "${available_opts[*]}" -- ${cur}) )
        return 0
    fi

    case "${prev}" in
        --branch-suffix|--workspace|--prompt)
            # You can add specific completions for these options if needed
            COMPREPLY=()
            ;;
        *)
            COMPREPLY=( $(compgen -W "${available_opts[*]}" -- ${cur}) )
            ;;
    esac
}

complete -F _create_devbox_completions create_devbox

alias remotessh='pay remote ssh'

payremotenewnewbranch() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  branch_suffix="$1"
  DATE=$(date +%Y%m%d)
  devboxname="$USER-$DATE-$branch_suffix"
  branch="$USER/$DATE-$branch_suffix"
  echo "Dev box name: $devboxname ; Branch $branch"
  pay remote new "$devboxname" -r "pay-server:$branch" -o -n --skip-confirm
}

remotenew() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  DATE=$(date +%Y%m%d)
  if git rev-parse --verify "$1" >/dev/null 2>&1; then
    raw_branch_name=$(echo "$1" | sed 's/.*[0-9]\{8\}-//')
    devboxname="$USER-$DATE-$raw_branch_name"
    branch=$1
  else
    devboxname="$USER-$DATE-$1"
    branch="$USER/$DATE-$1"
  fi
  echo "Dev box name: $devboxname ; Branch $branch"
  pay remote new "$devboxname" -r "pay-server:$branch" -o -n --skip-confirm
}

gitbrowse () {
  logfmt='%h %C(magenta)%aL%C(cyan)%d%C(white) %s %Creset- %ar'
  git log --color=always --pretty="format:$logfmt" "$@" | fzf --ansi --no-sort --reverse --tiebreak=index --bind "enter:execute(git show -m {1})"
}

# https://polothy.github.io/post/2019-08-19-fzf-git-checkout/
fzf-git-branch() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    git branch --all --color=always --sort=-committerdate |
        grep -v HEAD |
        fzf --height 50% --ansi --no-multi --preview-window right:65% \
            --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' \
            --tiebreak begin |
        sed "s/.* //"
}

fzf-git-checkout() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    local branch

    branch=$(fzf-git-branch)
    if [[ "$branch" = "" ]]; then
        echo "No branch selected."
        return
    fi

    # If branch name starts with 'remotes/' then it is a remote branch. By
    # using --track and a remote branch name, it is the same as:
    # git checkout -b branchName --track origin/branchName
    if [[ "$branch" = 'remotes/'* ]]; then
        git checkout --track $branch
    else
        git checkout $branch;
    fi
}
alias sqlite='rlwrap sqlite3'
alias cf='clang-format -i'
alias gb='fzf-git-branch'
alias gco='fzf-git-checkout'
alias ktfmt='java -jar ~/bin/ktfmt-0.54-jar-with-dependencies.jar --kotlinlang-style'

s()
{
  GIT_BASE_DIR=$(basename `git rev-parse --show-toplevel`)
  if [ "$GIT_BASE_DIR" = "zoolander" ] || [ "$GIT_BASE_DIR" = "pay-server" ]; then
    CMD="git status -uno"
  else
    CMD="git status"
  fi
  echo $CMD
  $CMD
}
l()
{
  GIT_BASE_DIR=$(basename "$(git rev-parse --show-toplevel)")
  if [ "$GIT_BASE_DIR" = "zoolander" ] || [ "$GIT_BASE_DIR" = "pay-server" ]; then
    CMD="git log --max-count=10"
  else
    CMD="git log"
  fi
  echo "$CMD"
  $CMD
}
rebasei()
{
  git rebase -i "$1^"
}
# alias hpr='hub pull-request'

default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
}

_set_android_serial() {
  export ANDROID_SERIAL="$1"
  echo "ANDROID_SERIAL=${ANDROID_SERIAL} (${2})"
}

setandroidserials710() {
  _set_android_serial "f4c941aa" "S710"
}

setandroidserials700() {
  _set_android_serial "4f64d47b" "S700"
}

setandroidserials700devkit() {
  _set_android_serial "1234567" "S700 devkit"
}

setandroidserialwpe() {
  _set_android_serial "f85e6a55" "WPE"
}

setandroidserialv660pA13() {
  _set_android_serial "713-363-464" "V660P A13"
}

setandroidserialv660pA10() {
  _set_android_serial "452-406-077" "V660P A10"
}

setandroidserialpixel10() {
  _set_android_serial "57260DLCR000FJ" "Pixel 10"
}

whichandroidserial() {
  case "$ANDROID_SERIAL" in
    "")
      echo "ANDROID_SERIAL is not set"
      ;;
    "f4c941aa")
      echo "S710: $ANDROID_SERIAL"
      ;;
    "4f64d47b")
      echo "S700: $ANDROID_SERIAL"
      ;;
    "1234567")
      echo "S700 devkit: $ANDROID_SERIAL"
      ;;
    "f85e6a55")
      echo "WPE: $ANDROID_SERIAL"
      ;;
    "713-363-464")
      echo "V660P A13: $ANDROID_SERIAL"
      ;;
    "452-406-077")
      echo "V660P A10: $ANDROID_SERIAL"
      ;;
    "57260DLCR000FJ")
      echo "Pixel 10: $ANDROID_SERIAL"
      ;;
    "$S10_ADB_DEVICE_ID")
      echo "S10: $ANDROID_SERIAL"
      ;;
    *)
      echo "$ANDROID_SERIAL"
      ;;
  esac
}

_adbreaderpid() {
  adb shell ps | grep com.stripe.reader | tr -s "[:space:]" ' ' | cut -d' ' -f2
}

_adbtestapppid() {
  adb shell ps | grep com.stripe.terminal.testapp | tr -s "[:space:]" ' ' | cut -d' ' -f2
}

_adbupdaterpid() {
  adb shell ps | grep com.stripe.updater | tr -s "[:space:]" ' ' | cut -d' ' -f2
}

_adbstandalonepid() {
  adb shell ps | grep com.stripe.standalone.app | tr -s "[:space:]" ' ' | cut -d' ' -f2
}

_adbdonationstestapppid() {
  adb shell ps | grep com.stripe.donationstestapp | tr -s "[:space:]" ' ' | cut -d' ' -f2
}

type_slowly() {
    text="$1"
    consecutive_fast=0

    for (( i=0; i<${#text}; i++ )); do
        char="${text:$i:1}"
        if [ "$char" == " " ]; then
            adb shell input text "%s"
        else
            adb shell input text "$char"
        fi

        # Simulate typing bursts: fast typing followed by pauses
        if [ $consecutive_fast -gt 5 ]; then
            # After typing 5-8 chars quickly, take a break
            delay=$((250 + RANDOM % 350))  # 250-600ms pause
            consecutive_fast=0
        else
            # Normal typing speed with variation
            delay=$((0))   # 70-200ms
            consecutive_fast=$((consecutive_fast + 1))
        fi

        # # Occasional random longer pause (hesitation)
        # if [ $((RANDOM % 15)) -eq 0 ]; then
        #     delay=$((400 + RANDOM % 400))  # 400-800ms
        # fi

        echo $delay
        printf -v delay_sec "0.%03d" "$delay"
        #sleep "$delay_sec"
    done
}

type_in_chunks() {
    text="$1"
    chunk_size_min=1
    chunk_size_max=3

    i=0
    while [ $i -lt ${#text} ]; do
        # Random chunk size between 2-5 characters
        chunk_size=$((chunk_size_min + RANDOM % (chunk_size_max - chunk_size_min + 1)))

        # Extract chunk
        chunk="${text:$i:$chunk_size}"

        # Replace spaces with %s for adb
        chunk="${chunk// /%s}"

        # Send chunk
        adb shell input text "$chunk"

        # Random delay between chunks: 50-150ms
        delay=$((0 + RANDOM % 101))
        printf -v delay_sec "0.%03d" "$delay"
        sleep "$delay_sec"

        i=$((i + chunk_size))
    done
}

type_foo() {
  adb shell << 'EOF'
  text='billfinn@stripe.com'
  len=${#text}

  for i in $(seq 0 $((len - 1))); do
      char=$(echo "$text" | cut -c$((i+1)))

      if [ "$char" = " " ]; then
          input text '%s'
      else
          input text "$char"
      fi

      # Random delay between 100-180ms
      delay=$((RANDOM % 80 + 100))

      # Convert to seconds (e.g., 120 -> 0.120)
      #sleep 0.0${delay}
  done
EOF
}

alias adblogcatclear='adb logcat -c'
adblogcattransaction() {
  READER_PID=$(_adbreaderpid)
  UPDATER_PID=$(_adbupdaterpid)
  type adblogcattransaction
  # adb shell "logcat | grep --line-buffered -E ' $READER_PID|$UPDATER_PID ' | grep --line-buffered -E 'BbposControllerListener|CancelHandler|HardwareService|BbposDeviceControllerImpl|PaymentCollectionCoordinator|PaymentCollectionStateMachine|BbposPaymentCollectionListener|FormNavigationFragment|BbposPaymentCollector|EndPreviousTransactionPrerequisiteFactory|PollingCommandLogger' | grep --line-buffered -E -v 'PaymentCollectionData\('" | sed -u "s/ $READER_PID / com.stripe.reader /; s/ $UPDATER_PID / com.stripe.updater /" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"
  adb shell "logcat | grep --line-buffered -E ' $READER_PID|$UPDATER_PID ' | grep --line-buffered -E 'class=|asdf' | grep --line-buffered -E 'CollectReusableCardOp|CollectPaymentMethodOp|ResumeCollectPaymentMethodOp|SetReaderDisplayOp|TransactionCoordinator|TransactionViewModel.*onTransactionStateSummaryUpdate|DefaultScreenDurationLogger|BbposControllerListener|HardwareService.*BbposSdkService|BbposDeviceControllerImpl|PaymentCollectionCoordinator|PaymentCollectionStateMachine|BbposPaymentCollectionListener|FormNavigationFragment|BbposPaymentCollector|EndPreviousTransactionPrerequisiteFactory|PollingCommandLogger|SetReaderDisplayComponentHealthLogger|asdf'" | sed -u "s/ $READER_PID / com.stripe.reader /; s/ $UPDATER_PID / com.stripe.updater /" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"
}

append_pid() {
  local pid=$1
  if [[ -n $pid ]]; then
    if [[ -z $PID_LIST ]]; then
      PID_LIST=$pid
    else
      PID_LIST="$PID_LIST|$pid"
    fi
  fi
}

# adblogcat() {
#   type adblogcat
#   READER_PID=$(_adbreaderpid)
#   UPDATER_PID=$(_adbupdaterpid)
#   STANDALONE_PID=$(_adbstandalonepid)
#   TEST_APP_PID=$(_adbtestapppid)
# 
#   # Build pipe-delimited pattern from non-empty PIDs
#   PID_LIST=""
#   for pid in "$READER_PID" "$UPDATER_PID" "$STANDALONE_PID" "$TEST_APP_PID"; do
#     if [[ -n $pid ]]; then
#       if [[ -z $PID_LIST ]]; then
#         PID_LIST=$pid
#       else
#         PID_LIST="$PID_LIST|$pid"
#       fi
#     fi
#   done
# 
#   # If no PIDs found, exit or handle as desired
#   if [[ -z $PID_LIST ]]; then
#     echo "No PIDs found." >&2
#     return 1
#   fi
# 
#   # Surround with spaces so pattern matches PIDs as separate tokens in log lines
#   # Use grep -E with --line-buffered for streaming
#   adb shell "logcat | grep --line-buffered -E ' (${PID_LIST}) '" | tee "logcat_$(date -u +"%Y_%m_%dT%H_%M_%SZ").txt"
# }

adblogcat() {
  type adblogcat

  READER_PID=$(_adbreaderpid)
  UPDATER_PID=$(_adbupdaterpid)
  STANDALONE_PID=$(_adbstandalonepid)
  TEST_APP_PID=$(_adbtestapppid)
  DONATIONS_PID=$(_adbdonationstestapppid)

  echo "reader:      ${READER_PID:-not running} (com.stripe.reader)"
  echo "updater:     ${UPDATER_PID:-not running} (com.stripe.updater)"
  echo "standalone:  ${STANDALONE_PID:-not running} (com.stripe.standalone.app)"
  echo "testapp:     ${TEST_APP_PID:-not running} (com.stripe.terminal.testapp)"
  echo "donations:   ${DONATIONS_PID:-not running} (com.stripe.donationstestapp)"
  echo "---"

  # Build sed script to label known PIDs inline
  SED_SCRIPT=""
  [[ -n $READER_PID ]]     && SED_SCRIPT="$SED_SCRIPT;s/ $READER_PID / <reader> /g"
  [[ -n $UPDATER_PID ]]    && SED_SCRIPT="$SED_SCRIPT;s/ $UPDATER_PID / <updater> /g"
  [[ -n $STANDALONE_PID ]] && SED_SCRIPT="$SED_SCRIPT;s/ $STANDALONE_PID / <standalone> /g"
  [[ -n $TEST_APP_PID ]]   && SED_SCRIPT="$SED_SCRIPT;s/ $TEST_APP_PID / <testapp> /g"
  [[ -n $DONATIONS_PID ]]  && SED_SCRIPT="$SED_SCRIPT;s/ $DONATIONS_PID / <donations> /g"
  SED_SCRIPT=${SED_SCRIPT#;}

  TIMESTAMP=$(date -u +"%Y_%m_%dT%H_%M_%SZ")
  if [[ -n $SED_SCRIPT ]]; then
    adb shell logcat \
      | grep --line-buffered -vE " (chatty|ActivityManager|SystemServiceManager|SystemServer|SystemServerTiming|IzatSvc_IzatManager|LocSvc_HIDL_IzatProvider|TelecomFramework|Telecom|vold|ThermalHAL-UTIL|ThermalHAL-TARGET|wpa_supplicant|WifiService) " \
      | gsed --unbuffered -E "$SED_SCRIPT" \
      | tee "logcat_${TIMESTAMP}.txt"
  else
    adb shell logcat \
      | grep --line-buffered -vE " (chatty|ActivityManager|SystemServiceManager|SystemServer|SystemServerTiming|IzatSvc_IzatManager|LocSvc_HIDL_IzatProvider|TelecomFramework|Telecom|vold|ThermalHAL-UTIL|ThermalHAL-TARGET|wpa_supplicant|WifiService) " \
      | tee "logcat_${TIMESTAMP}.txt"
  fi
}

teedatetxtfile() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if [ $# -gt 0 ]; then
    # first arg appended to generated file base
    tee "logcat_${ts}_$1.txt"
  else
    tee "logcat_${ts}.txt"
  fi
}

adblogcatall() {
  type adblogcatall

  READER_PID=$(_adbreaderpid)
  UPDATER_PID=$(_adbupdaterpid)
  STANDALONE_PID=$(_adbstandalonepid)
  TEST_APP_PID=$(_adbtestapppid)
  DONATIONS_PID=$(_adbdonationstestapppid)

  echo "reader:      ${READER_PID:-not running} (com.stripe.reader)"
  echo "updater:     ${UPDATER_PID:-not running} (com.stripe.updater)"
  echo "standalone:  ${STANDALONE_PID:-not running} (com.stripe.standalone.app)"
  echo "testapp:     ${TEST_APP_PID:-not running} (com.stripe.terminal.testapp)"
  echo "donations:   ${DONATIONS_PID:-not running} (com.stripe.donationstestapp)"
  echo "---"

  SED_SCRIPT=""
  [[ -n $READER_PID ]]     && SED_SCRIPT="$SED_SCRIPT;s/ $READER_PID / <reader> /g"
  [[ -n $UPDATER_PID ]]    && SED_SCRIPT="$SED_SCRIPT;s/ $UPDATER_PID / <updater> /g"
  [[ -n $STANDALONE_PID ]] && SED_SCRIPT="$SED_SCRIPT;s/ $STANDALONE_PID / <standalone> /g"
  [[ -n $TEST_APP_PID ]]   && SED_SCRIPT="$SED_SCRIPT;s/ $TEST_APP_PID / <testapp> /g"
  [[ -n $DONATIONS_PID ]]  && SED_SCRIPT="$SED_SCRIPT;s/ $DONATIONS_PID / <donations> /g"
  SED_SCRIPT=${SED_SCRIPT#;}

  TIMESTAMP=$(date -u +"%Y_%m_%dT%H_%M_%SZ")
  if [[ -n $SED_SCRIPT ]]; then
    adb shell logcat \
      | grep --line-buffered -vE " (chatty|ActivityManager|SystemServiceManager|SystemServer|SystemServerTiming|IzatSvc_IzatManager|LocSvc_HIDL_IzatProvider|TelecomFramework|Telecom|vold|ThermalHAL-UTIL|ThermalHAL-TARGET|wpa_supplicant|WifiService) " \
      | grep --line-buffered -v ' V QueueFileCollector: ' \
      | grep --line-buffered -v ' D DebugLoggingHttpInterceptor: ' \
      | grep --line-buffered -v ' V BatchDispatcher: ' \
      | grep --line-buffered -v ' I DebugConfigCerthorse: ' \
      | gsed --unbuffered -E "$SED_SCRIPT" \
      | tee "logcat_${TIMESTAMP}.txt"
  else
    adb shell logcat \
      | grep --line-buffered -vE " (chatty|ActivityManager|SystemServiceManager|SystemServer|SystemServerTiming|IzatSvc_IzatManager|LocSvc_HIDL_IzatProvider|TelecomFramework|Telecom|vold|ThermalHAL-UTIL|ThermalHAL-TARGET|wpa_supplicant|WifiService) " \
      | grep --line-buffered -v ' V QueueFileCollector: ' \
      | grep --line-buffered -v ' D DebugLoggingHttpInterceptor: ' \
      | grep --line-buffered -v ' V BatchDispatcher: ' \
      | grep --line-buffered -v ' I DebugConfigCerthorse: ' \
      | tee "logcat_${TIMESTAMP}.txt"
  fi
}

adblogcatverbose() {
  READER_PID=$(_adbreaderpid)
  UPDATER_PID=$(_adbupdaterpid)
  STANDALONE_PID=$(_adbstandalonepid)
  # Build the grep pattern conditionally
  GREP_PATTERN=" $READER_PID|$UPDATER_PID"
  if [[ -n $STANDALONE_PID ]]; then
    GREP_PATTERN+="|$STANDALONE_PID"
  fi
  type adblogcatverbose
  adb shell "logcat | grep --line-buffered -E '$GREP_PATTERN' | grep --line-buffered -v ' V QueueFileCollector: ' | grep --line-buffered -v ' D DebugLoggingHttpInterceptor: ' | grep --line-buffered -v ' V BatchDispatcher: ' | grep --line-buffered -v ' I DebugConfigCerthorse: '" | sed -u "s/ $READER_PID / reader     /; s/ $UPDATER_PID / updater    /; $( [[ -n $STANDALONE_PID ]] && echo "s/ $STANDALONE_PID / standalone /" )" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"

  #adb shell "logcat | grep --line-buffered -E ' $READER_PID|$UPDATER_PID|$STANDALONE_PID ' | grep --line-buffered -v ' V QueueFileCollector: ' | grep --line-buffered -v ' D DebugLoggingHttpInterceptor: ' | grep --line-buffered -v ' V BatchDispatcher: ' | grep --line-buffered -v ' I DebugConfigCerthorse: '" | sed -u "s/ $READER_PID / reader     /; s/ $UPDATER_PID / updater    /; s/ $STANDALONE_PID / standalone /" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"
}

taillatestlogcat() {
  latest_logcat=$(ls -1 logcat_* | tail -n 1)
  tail -f $latest_logcat
}

# lesslatestlogcat() {
#   latest_logcat=$(ls -1 logcat_* | tail -n 1)
#   less $latest_logcat
#   # if [ -n "$1" ]; then
#   #   stdbuf -oL tail -f "$latest_logcat" | grep --line-buffered "$1" | less +F -X
#   #   #grep --line-buffered "$1" "$latest_logcat" | less -K -R +F
#   # else
#   #   stdbuf -oL tail -f "$latest_logcat" | less +F -X
#   #   #less -K -R +F "$latest_logcat"
#   # fi
# }

lesslatestlogcat() {
    local pattern="$1"
    latest_logcat=$(ls -1 logcat_* | tail -n 1)

    if [[ -n "$pattern" ]]; then
      # tail -f -n +1 "$latest_logcat" | grep --line-buffered --color=always -E "$pattern" | less -R +F
        # grep --color=always -E "$pattern" "$latest_logcat" | less -R +F
        # less +F +"&$pattern" "$latest_logcat"
          local temp_file=$(mktemp)

          # Start tail+grep in background, writing to temp file
          tail -f -n +1 "$latest_logcat" | grep --line-buffered --color=always -E "$pattern" > "$temp_file" &
          local tail_pid=$!

          # Give it a moment to populate
          sleep 0.5

          # Now tail the filtered output with less
          less -R +F "$temp_file"

          # Clean up when less exits
          kill $tail_pid 2>/dev/null
          rm "$temp_file"
    else
        less +F "$latest_logcat"
    fi
}

gdg() {
  local png_files
  baseBranch="origin/green-pay-server"
  png_files=$(git diff --name-only "$baseBranch"...HEAD "$@" | rg '\.png$')
  if [[ -n "$png_files" ]]; then
    echo "Ignoring PNG files:"
    echo "$png_files" | sed 's/^/  /'
    echo ""
  fi
  git diff "$baseBranch"...HEAD "$@" -- . ':(exclude)*.png'
}

gdm() {
  baseBranch=$(default_branch)
  # 2025-12-02 I don't know why I was doing this.
  # if [ "$baseBranch" = "master" ] && git ls-remote --exit-code --heads origin master-passing-tests &>/dev/null; then
  #   git fetch origin master-passing-tests
  #   comparisonBranch="origin/master-passing-tests"
  # else
  #   comparisonBranch="$baseBranch"
  # fi
  # git diff "$comparisonBranch"...HEAD
  local png_files
  png_files=$(git diff --name-only "$baseBranch"...HEAD "$@" | rg '\.png$')
  if [[ -n "$png_files" ]]; then
    echo "Ignoring PNG files:"
    echo "$png_files" | sed 's/^/  /'
    echo ""
  fi
  git diff "$baseBranch"...HEAD "$@" -- . ':(exclude)*.png'
}

gh_checkout_and_open_pr() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  gfb "$1"
  # shellcheck disable=SC2119
  gh_open_pr
}

gh_hostname() {
  git remote get-url origin | sed -e 's/^.*@//' -e 's/:.*//' -e 's/^https:\/\///'
}

gh_create_pr() {
  if [ "$#" -gt 2 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  local filename="$1"
  if [ "$#" -gt 1 ]; then
    baseBranch=$2
  else
    baseBranch=$(default_branch)
  fi

  local sed_cmd=$(sed_command)

  title=$(head -n 1 "$filename")
  echo "Title: $title"
  # Delete the title and the blank line below the title
  $sed_cmd -i '1,2d' "$filename"

  GH_HOST="$(gh_hostname)" gh pr create --body-file "$filename" --title "$title" -B "$baseBranch"
}

gh_open_pr() {
  if [ "$#" -gt 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  if [ "$#" -gt 0 ]; then
    baseBranch=$1
  else
    baseBranch=$(default_branch)
  fi

  # Close existing draft PR if one exists
  local isDraft
  isDraft=$(GH_HOST="$(gh_hostname)" gh pr view --json isDraft --jq '.isDraft' 2>/dev/null)
  if [[ "$isDraft" == "true" ]]; then
    echo "Draft PR exists, closing it first..."
    gh_close_draft_pr
  fi

  current_folder=$(basename "$PWD")
  if [[ "$current_folder" != "android" ]]; then
    echo "fetching...$baseBranch"
    git fetch origin "$baseBranch"
  fi

  # Determine the comparison branch
  comparisonBranch=$(git merge-base "origin/$baseBranch" HEAD)

  tmpFile=$(mktemp)
  echo "Temp filename: $tmpFile"
  cp .github/PULL_REQUEST_TEMPLATE.md "$tmpFile"

  local sed_cmd=$(sed_command)
  $sed_cmd -i $'1s;^;PR Title\\n\\n;' "$tmpFile"
  delimiter="<-- Lines below this will not be included in the PR description -->"

  gitCommits=$(git log --pretty=format:"Commit: %H%nAuthor:%an%nDate:%ad%n%n%s%n%n%b" $comparisonBranch..HEAD)
  printf '\n%s\n' "$delimiter" >> "$tmpFile"
  printf '%s\n' "$gitCommits" >> "$tmpFile"

  # Remove all trailing whitespace
  $sed_cmd -i 's/[ \t]*$//' "$tmpFile"
  # Disable auto-comment formatting

  sayready write_pr
  nvim -c "set formatoptions-=cro | lua require('config.functions').add_stripes()" "$tmpFile"
  vimExitCode=$?
  if ! [[ $vimExitCode -eq 0 ]]; then
    echo "error: vim exit code $vimExitCode"
    return 1
  fi

  # Push branch if local and remote differ
  local localSha remoteSha
  localSha=$(git rev-parse HEAD)
  remoteSha=$(git rev-parse @{u} 2>/dev/null)
  if [[ "$localSha" != "$remoteSha" ]]; then
    echo "Local and remote differ. Push with --force-with-lease? [y/n]"
    read -r answer
    if [[ "$answer" != "y" ]]; then
      echo "Aborting. PR template saved at: $tmpFile"
      return 1
    fi
    git push --no-verify --force-with-lease -u origin HEAD
    if ! [[ $? -eq 0 ]]; then
      cat "$tmpFile"
      return 1
    fi
  fi

  $sed_cmd -i "/$delimiter/Q" "$tmpFile"
  # Remove last blank line
  $sed_cmd -i '${/^$/d};' "$tmpFile"

  gh_create_pr $tmpFile $baseBranch
  echo "Disabling auto merge"
  gh_disable_auto_merge
}

gpush() {
  if [ "$#" -gt 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  if [ "$#" -gt 0 ]; then
    baseBranch=$1
  else
    baseBranch=$(default_branch)
  fi

  local start=$SECONDS

  # Skip push if local HEAD matches the remote tracking branch
  local localSha remoteSha
  localSha=$(git rev-parse HEAD)
  remoteSha=$(git rev-parse @{u} 2>/dev/null)
  if [[ "$localSha" == "$remoteSha" ]]; then
    echo "already up-to-date, skipping push."
  else
    # Never force push to an existing open, non-draft PR
    local pushArgs="--no-verify -u origin HEAD"
    local prJson
    prJson=$(GH_HOST="$(gh_hostname)" gh pr view --json state,isDraft 2>/dev/null)
    if [[ -n "$prJson" ]]; then
      local prState prDraft
      prState=$(echo "$prJson" | jq -r '.state')
      prDraft=$(echo "$prJson" | jq -r '.isDraft')
      if [[ "$prState" == "OPEN" && "$prDraft" == "false" ]]; then
        echo "non-draft PR is open, using regular push (no force)."
      else
        pushArgs="--force-with-lease $pushArgs"
      fi
    else
      pushArgs="--force-with-lease $pushArgs"
    fi
    git push $pushArgs
    if ! [[ $? -eq 0 ]]; then
      echo "error: failed to push branch"
      return 1
    fi
    echo "push: $((SECONDS - start))s"
  fi

  # Check if an open PR already exists for this branch
  local prcheck=$SECONDS
  local prState
  prState=$(GH_HOST="$(gh_hostname)" gh pr view --json state --jq '.state' 2>/dev/null)
  if [[ "$prState" == "OPEN" ]]; then
    echo "pr check: $((SECONDS - prcheck))s"
    echo "PR already exists, push done. (total: $((SECONDS - start))s)"
    return 0
  fi
  echo "pr check: $((SECONDS - prcheck))s"

  local branchName
  branchName=$(git rev-parse --abbrev-ref HEAD)

  local prcreate=$SECONDS
  GH_HOST="$(gh_hostname)" gh pr create --draft --title "$branchName" --body "Draft PR for CI and Gru" -B "$baseBranch"
  echo "pr create: $((SECONDS - prcreate))s"

  echo "Disabling auto merge"
  gh_disable_auto_merge
  echo "total: $((SECONDS - start))s"
}

gh_close_draft_pr() {
  local isDraft
  isDraft=$(GH_HOST="$(gh_hostname)" gh pr view --json isDraft --jq '.isDraft')
  if [[ "$isDraft" != "true" ]]; then
    echo "error: current branch does not have a draft PR (isDraft=$isDraft)"
    return 1
  fi
  GH_HOST="$(gh_hostname)" gh pr close "$(git branch --show-current)"
  echo "Draft PR closed."
}

# Recreate the current branch's draft PR as a clean, non-draft PR.
# Source this file from .bashrc, or copy the function into it directly.
gh_recreate_pr() {
    if (($# != 0)); then
        printf 'Usage: gh_recreate_pr\n' >&2
        return 2
    fi

    local dependency
    for dependency in git gh jq mktemp; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            printf 'gh_recreate_pr: required command not found: %s\n' "$dependency" >&2
            return 1
        fi
    done

    local branch expected_oid prs_json
    if ! branch=$(git symbolic-ref --quiet --short HEAD); then
        printf 'gh_recreate_pr: HEAD is detached; check out the PR branch first\n' >&2
        return 1
    fi
    if ! expected_oid=$(git rev-parse --verify HEAD); then
        printf 'gh_recreate_pr: could not resolve the current HEAD\n' >&2
        return 1
    fi

    if ! prs_json=$(gh pr list \
        --head "$branch" \
        --state all \
        --limit 100 \
        --json number,title,body,state,isDraft,baseRefName,headRefName,headRefOid,url,createdAt); then
        printf 'gh_recreate_pr: could not list PRs for branch %s\n' "$branch" >&2
        return 1
    fi

    local open_pr
    if ! open_pr=$(jq -c \
        '[.[] | select(.state == "OPEN" and .isDraft == false)] | sort_by(.createdAt) | last // empty' \
        <<<"$prs_json"); then
        printf 'gh_recreate_pr: could not parse the PR list\n' >&2
        return 1
    fi

    if [[ -n "$open_pr" ]]; then
        local open_oid open_url
        open_oid=$(jq -r '.headRefOid' <<<"$open_pr") || return 1
        open_url=$(jq -r '.url' <<<"$open_pr") || return 1
        if [[ "$open_oid" == "$expected_oid" ]]; then
            printf 'A non-draft PR already exists for this HEAD: %s\n' "$open_url"
            return 0
        fi

        printf 'gh_recreate_pr: an open non-draft PR exists, but its head (%s) does not match local HEAD (%s): %s\n' \
            "$open_oid" "$expected_oid" "$open_url" >&2
        printf 'Push the current branch or resolve the existing PR before retrying.\n' >&2
        return 1
    fi

    local source_pr
    if ! source_pr=$(jq -c --arg oid "$expected_oid" \
        '[.[] | select(.isDraft == true and .headRefOid == $oid)] | sort_by(.createdAt) | last // empty' \
        <<<"$prs_json"); then
        printf 'gh_recreate_pr: could not parse the draft PR metadata\n' >&2
        return 1
    fi

    if [[ -z "$source_pr" ]]; then
        local latest_draft
        latest_draft=$(jq -c \
            '[.[] | select(.isDraft == true)] | sort_by(.createdAt) | last // empty' \
            <<<"$prs_json") || return 1

        if [[ -n "$latest_draft" ]]; then
            printf 'gh_recreate_pr: the latest draft PR head (%s) does not match local HEAD (%s)\n' \
                "$(jq -r '.headRefOid' <<<"$latest_draft")" "$expected_oid" >&2
            printf 'Push the current branch, then retry. No PR was closed.\n' >&2
        else
            printf 'gh_recreate_pr: no draft PR was found for branch %s\n' "$branch" >&2
        fi
        return 1
    fi

    local source_number source_state source_title source_base source_head source_url
    source_number=$(jq -r '.number' <<<"$source_pr") || return 1
    source_state=$(jq -r '.state' <<<"$source_pr") || return 1
    source_title=$(jq -r '.title' <<<"$source_pr") || return 1
    source_base=$(jq -r '.baseRefName' <<<"$source_pr") || return 1
    source_head=$(jq -r '.headRefName' <<<"$source_pr") || return 1
    source_url=$(jq -r '.url' <<<"$source_pr") || return 1

    local body_file
    if ! body_file=$(mktemp "${TMPDIR:-/tmp}/recreate-pr.XXXXXX"); then
        printf 'gh_recreate_pr: could not create a temporary body file\n' >&2
        return 1
    fi
    trap 'rm -f "$body_file"' EXIT
    if ! jq -j '.body // ""' <<<"$source_pr" >"$body_file"; then
        printf 'gh_recreate_pr: could not save the draft PR body\n' >&2
        return 1
    fi

    local current_oid
    if ! current_oid=$(git rev-parse --verify HEAD) || [[ "$current_oid" != "$expected_oid" ]]; then
        printf 'gh_recreate_pr: local HEAD changed during validation; retry the command\n' >&2
        return 1
    fi

    if [[ "$source_state" == "OPEN" ]]; then
        printf 'Closing draft PR #%s: %s\n' "$source_number" "$source_url"
        if ! gh pr close "$source_number"; then
            printf 'gh_recreate_pr: failed to close draft PR #%s\n' "$source_number" >&2
            return 1
        fi
    else
        printf 'Draft PR #%s is already closed; reusing its metadata.\n' "$source_number"
    fi

    local new_url
    printf 'Creating a fresh non-draft PR from %s into %s...\n' "$source_head" "$source_base"
    if ! new_url=$(gh pr create \
        --base "$source_base" \
        --head "$source_head" \
        --title "$source_title" \
        --body-file "$body_file"); then
        printf 'gh_recreate_pr: PR creation failed; draft PR #%s remains closed\n' "$source_number" >&2
        printf 'Run gh_recreate_pr again to retry using the closed draft metadata.\n' >&2
        return 1
    fi

    local created_pr created_draft created_oid created_url
    if ! created_pr=$(gh pr view "$new_url" --json isDraft,headRefOid,url); then
        printf 'gh_recreate_pr: created %s but could not verify it\n' "$new_url" >&2
        return 1
    fi
    created_draft=$(jq -r '.isDraft' <<<"$created_pr") || return 1
    created_oid=$(jq -r '.headRefOid' <<<"$created_pr") || return 1
    created_url=$(jq -r '.url' <<<"$created_pr") || return 1

    if [[ "$created_draft" != "false" || "$created_oid" != "$expected_oid" ]]; then
        printf 'gh_recreate_pr: replacement PR was created but verification failed: %s\n' "$created_url" >&2
        printf 'Expected non-draft HEAD %s; received draft=%s HEAD=%s\n' \
            "$expected_oid" "$created_draft" "$created_oid" >&2
        return 1
    fi

    printf 'Created fresh non-draft PR: %s\n' "$created_url"
}

gh_disable_auto_merge()
{
  branchName=$(git rev-parse --abbrev-ref HEAD)
  remoteUrl=$(git config --get remote.origin.url)
  # e.g., git@git.corp.stripe.com:stripe-internal/android.git
  orgAndRepo=$(echo "$remoteUrl" | cut -d':' -f 2 | cut -d'.' -f 1)
  url="cibot.corp.stripe.com/api/git.corp.stripe.com/$orgAndRepo/branches/$branchName/auto_merge"
  echo $url
  sc-curl -d '{"auto_merge":false, "auto_merge_working_hours":false}' -H "Content-Type: application/json" -H "X-Requested-With: curl" -X POST "$url"
  echo
}

gh_enable_auto_merge()
{
  branchName=$(git rev-parse --abbrev-ref HEAD)
  remoteUrl=$(git config --get remote.origin.url)
  # e.g., git@git.corp.stripe.com:stripe-internal/android.git
  orgAndRepo=$(echo "$remoteUrl" | cut -d':' -f 2 | cut -d'.' -f 1)
  url="cibot.corp.stripe.com/api/git.corp.stripe.com/$orgAndRepo/branches/$branchName/auto_merge"
  echo $url
  sc-curl -d '{"auto_merge":true}' -H "Content-Type: application/json" -H "X-Requested-With: curl" -X POST "$url"
  echo
}

alias gh_merge_pr='gh pr merge -m -d'

gh_image_upload_cleanup() {
  if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != "--force" ]; }; then
    echo "Usage: gh_image_upload_cleanup [--force]" >&2
    return 2
  fi

  if ! command -v npx >/dev/null 2>&1; then
    echo "gh_image_upload_cleanup: npx is required." >&2
    return 1
  fi

  local session_name="stripe-ghe-attachments"
  local force=false
  local system_name
  local cache_root
  local daemon_root
  local daemon_dir
  local profile_dir
  local lock_file
  local lock_target
  local lock_pid
  local owner_info
  local attempt

  if [ "$#" -eq 1 ]; then
    force=true
  fi

  # Ask Playwright to stop the named session first. This preserves the
  # persistent profile and is enough when the daemon is still reachable.
  npx --yes @playwright/cli@0.1.17 \
    -s="$session_name" close >/dev/null 2>&1 || true

  system_name=$(uname -s 2>/dev/null || echo unknown)
  case "$system_name" in
    Darwin)
      cache_root="${HOME}/Library/Caches"
      ;;
    *)
      cache_root="${XDG_CACHE_HOME:-$HOME/.cache}"
      ;;
  esac
  daemon_root="$cache_root/ms-playwright/daemon"

  # A crashed daemon can leave Chrome alive and holding SingletonLock. Look
  # only in this session's profile, and only signal the PID encoded by that
  # profile's lock symlink after verifying it has the profile open.
  for daemon_dir in "$daemon_root"/*; do
    [ -d "$daemon_dir" ] || continue
    for profile_dir in "$daemon_dir"/ud-${session_name}-*; do
      [ -d "$profile_dir" ] || continue
      lock_file="$profile_dir/SingletonLock"
      [ -L "$lock_file" ] || continue

      lock_target=$(readlink "$lock_file" 2>/dev/null || true)
      lock_pid=$(printf '%s\n' "$lock_target" | sed -n 's/.*-\([0-9][0-9]*\)$/\1/p')
      if [ -z "$lock_pid" ] || ! kill -0 "$lock_pid" 2>/dev/null; then
        rm -f -- "$profile_dir/SingletonLock" \
          "$profile_dir/SingletonCookie" "$profile_dir/SingletonSocket"
        echo "Removed stale Playwright lock: $profile_dir" >&2
        continue
      fi

      owner_info=$(lsof -n -p "$lock_pid" 2>/dev/null | grep -F "$profile_dir" | head -1 || true)
      if [ -z "$owner_info" ]; then
        echo "gh_image_upload_cleanup: refusing to signal PID $lock_pid; it does not appear to own $profile_dir" >&2
        return 1
      fi

      echo "Stopping orphaned Playwright Chrome (PID $lock_pid) for $session_name..." >&2
      kill -TERM "$lock_pid" 2>/dev/null || true
      for attempt in 1 2 3 4 5; do
        sleep 1
        [ -L "$lock_file" ] || break
      done

      if [ -L "$lock_file" ] && [ "$force" = true ]; then
        echo "Chrome did not exit; forcing PID $lock_pid to stop." >&2
        kill -KILL "$lock_pid" 2>/dev/null || true
        sleep 1
      fi

      if [ -L "$lock_file" ]; then
        echo "gh_image_upload_cleanup: Chrome still owns $profile_dir; retry with --force." >&2
        return 1
      fi
    done
  done
}

gh_image_upload_login() {
  if [ "$#" -ne 0 ]; then
    echo "Usage: gh_image_upload_login" >&2
    return 2
  fi

  if ! command -v npx >/dev/null 2>&1; then
    echo "gh_image_upload_login: npx is required." >&2
    return 1
  fi

  # A running headless session cannot be converted to headed mode. Closing it
  # preserves its persistent profile while allowing the browser to reopen visibly.
  gh_image_upload_cleanup || return $?

  npx --yes @playwright/cli@0.1.17 \
    -s=stripe-ghe-attachments \
    open --browser chrome --persistent --headed https://git.corp.stripe.com
}

gh_image_upload() (
  if [ "$#" -eq 0 ]; then
    set -- --clipboard
  fi

  local use_clipboard=false
  local verbose=false
  local -a attachments=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -c|--clipboard)
        use_clipboard=true
        ;;
      -v|--verbose)
        verbose=true
        ;;
      --)
        shift
        attachments+=("$@")
        break
        ;;
      -*)
        echo "Usage: gh_image_upload [-c|--clipboard] [-v|--verbose] [--] [FILE ...]" >&2
        return 2
        ;;
      *)
        attachments+=("$1")
        ;;
    esac
    shift
  done

  if [ "${#attachments[@]}" -eq 0 ]; then
    use_clipboard=true
  fi

  _gh_image_upload_log() {
    if [ "$verbose" = true ]; then
      printf 'gh_image_upload: %s\n' "$*" >&2
    fi
  }

  local dependency
  for dependency in gh npx file pbcopy; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      echo "gh_image_upload: required command not found: $dependency" >&2
      return 1
    fi
  done

  local clipboard_dir=""
  local clipboard_file=""
  trap 'if [ -n "$clipboard_file" ]; then rm -f -- "$clipboard_file"; fi; if [ -n "$clipboard_dir" ]; then rmdir -- "$clipboard_dir" 2>/dev/null || true; fi' EXIT
  if [ "$use_clipboard" = true ]; then
    _gh_image_upload_log "reading PNG image from clipboard"
    if ! command -v pngpaste >/dev/null 2>&1; then
      echo "gh_image_upload: pngpaste is required to upload an image from the clipboard." >&2
      return 1
    fi
    clipboard_dir=$(mktemp -d "${TMPDIR:-/tmp}/gh-image-clipboard.XXXXXX") || return 1
    clipboard_file="$clipboard_dir/clipboard.png"
    if ! pngpaste - > "$clipboard_file"; then
      echo "gh_image_upload: the clipboard does not contain an image." >&2
      return 1
    fi
    attachments=("$clipboard_file" "${attachments[@]}")
    _gh_image_upload_log "captured clipboard image ($(wc -c < "$clipboard_file" | tr -d ' ') bytes)"
  fi

  local attachment
  for attachment in "${attachments[@]}"; do
    if [ ! -f "$attachment" ]; then
      echo "gh_image_upload: file not found: $attachment" >&2
      return 1
    fi
  done

  local uploader="$HOME/dot-files/bin/gh-attach"
  if [ ! -f "$uploader" ]; then
    echo "gh_image_upload: uploader not found: $uploader" >&2
    return 1
  fi

  local host repo issue
  _gh_image_upload_log "resolving GitHub host and repository"
  host=$(gh_hostname) || return 1
  if ! repo=$(GH_HOST="$host" gh repo view --json nameWithOwner --jq .nameWithOwner); then
    echo "gh_image_upload: could not resolve the current GitHub repository." >&2
    return 1
  fi
  _gh_image_upload_log "repository: $host/$repo"

  _gh_image_upload_log "looking up PR for the current branch"
  if ! issue=$(GH_HOST="$host" gh pr view --json number --jq .number 2>/dev/null); then
    issue=19498
    if ! GH_HOST="$host" gh pr view "$issue" --json number --jq .number >/dev/null 2>&1; then
      echo "gh_image_upload: the current branch has no PR and fallback PR #$issue was not found in $repo." >&2
      return 1
    fi
    echo "No PR found for the current branch; using $repo#$issue as the upload context." >&2
  fi
  _gh_image_upload_log "upload context: $repo#$issue"

  if [ "$verbose" = true ]; then
    _gh_image_upload_log "resetting browser session so Chrome can reopen headed"
    gh_image_upload_cleanup || return 1
  fi

  local -a markdown_lines=()
  local url mime_type filename label attachment_index=0
  for attachment in "${attachments[@]}"; do
    attachment_index=$((attachment_index + 1))
    _gh_image_upload_log "uploading $attachment_index/${#attachments[@]}: $attachment"
    local -a uploader_args=(
        --host "$host" \
        --repo "$repo" \
        --issue "$issue" \
        --session stripe-ghe-attachments \
        --keep-session \
        --browser \
        --url-only \
        --image "$attachment"
    )
    if [ "$verbose" = true ]; then
      uploader_args+=(--verbose --headed)
    fi
    if ! url=$(bash "$uploader" "${uploader_args[@]}"); then
      echo "gh_image_upload: upload failed for $attachment." >&2
      echo "Run gh_image_upload_login to establish or renew the GitHub SSO session." >&2
      return 1
    fi
    _gh_image_upload_log "uploaded $attachment_index/${#attachments[@]}: $url"

    if [[ "$url" != "https://$host/user-attachments/assets/"* ]]; then
      echo "gh_image_upload: uploader returned an unexpected URL for $attachment: $url" >&2
      return 1
    fi

    if [ -n "$clipboard_file" ] && [ "$attachment" = "$clipboard_file" ]; then
      filename="clipboard.png"
    else
      filename=$(basename "$attachment")
    fi
    label=$(printf '%s' "$filename" | sed 's/\\/\\\\/g; s/]/\\]/g')
    mime_type=$(file -b --mime-type "$attachment")
    if [[ "$mime_type" == image/* ]]; then
      markdown_lines+=("![$label]($url)")
    else
      markdown_lines+=("[$label]($url)")
    fi
  done

  _gh_image_upload_log "copying ${#markdown_lines[@]} Markdown link(s) to clipboard"
  printf '%s\n' "${markdown_lines[@]}" | pbcopy
  printf '%s\n' "${markdown_lines[@]}"
  echo "Attachment Markdown copied to the clipboard." >&2
)

gh_edit_pr_desc() {
  if [ "$#" -gt 1 ]; then
    echo "Usage: gh_edit_pr_desc [number|url|branch]" >&2
    return 2
  fi

  local pr="${1:-}"
  local edit_file body_file
  edit_file=$(mktemp "${TMPDIR:-/tmp}/gh-pr-edit.XXXXXX") || return 1
  body_file=$(mktemp "${TMPDIR:-/tmp}/gh-pr-body.XXXXXX") || {
    rm -f "$edit_file"
    return 1
  }

  if ! gh pr view ${pr:+"$pr"} --json title,body \
      --jq '.title + "\n\n" + (.body // "")' > "$edit_file"; then
    rm -f "$edit_file" "$body_file"
    return 1
  fi

  nvim -c "set formatoptions-=cro | lua require('config.functions').add_stripes()" "$edit_file" || {
    rm -f "$edit_file" "$body_file"
    echo "Editor exited unsuccessfully; PR title and description were not updated." >&2
    return 1
  }

  local title separator
  title=$(sed -n '1p' "$edit_file")
  separator=$(sed -n '2p' "$edit_file")
  if [ -z "$title" ] || [ -n "$separator" ]; then
    rm -f "$edit_file" "$body_file"
    echo "The first line must be a title followed by a blank line; PR was not updated." >&2
    return 1
  fi
  tail -n +3 "$edit_file" > "$body_file"

  if ! gh pr edit ${pr:+"$pr"} --body-file "$body_file"; then
    rm -f "$edit_file" "$body_file"
    echo "PR description was not updated; PR title was not updated." >&2
    return 1
  fi

  if ! gh pr edit ${pr:+"$pr"} --title "$title"; then
    rm -f "$edit_file" "$body_file"
    echo "PR description was updated, but PR title was not updated." >&2
    return 1
  fi

  rm -f "$edit_file" "$body_file"
  return 0
}

gh_view_pr() {
  if gh pr view --web 2>/dev/null; then
    return
  fi
  local branch
  branch=$(git branch --show-current)
  local repo_url
  repo_url=$(gh browse -n)
  open "${repo_url}/compare/${branch}?expand=1"
}

gcob()
{
  echo "deprecated; use b"
  git checkout -b $USER/$1
}

b()
{
    DATE=$(date +%Y%m%d);
    git checkout -b "$USER/$DATE-$1"
}

# git prune branch
gpb()
{
  git checkout -q master && \
    git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch; do \
    mergeBase=$(git merge-base master $branch) && \
    [[ $(git cherry master $(git commit-tree $(git rev-parse $branch\^{tree}) -p $mergeBase -m _)) == "-"* ]] &&
    git branch -D $branch; \
  done
}

gitrenamestring()
{
  if [[ $machine == 'Mac' ]]; then
    git grep -G -l -w "$1" | xargs gsed -i "s/$1/$2/g"
  else
    git grep -G -l "\b$1\b" | xargs sed -i "s/$1/$2/g"
  fi
}

gitrenameword()
{
  if [[ $machine == 'Mac' ]]; then
    git grep -G -l -w "$1" | xargs gsed -i "s/\b$1\b/$2/g"
  else
    git grep -G -l "\b$1\b" | xargs sed -i "s/\b$1\b/$2/g"
  fi
}

glb()
{
  git log -p $1...`git merge-base $1 master`
}
who_changes() {
  git log --since="1 year ago" --pretty='%al' -- "$1" | sort | uniq -c | sort -k2 -n -r | awk '{print "https://home.corp.stripe.com/people/" $2 " " $1}'
}

gdb()
{
  git diff master...$1
}

gitfixup()
{
  git commit --fixup="$1"
  # Updated to remove -i based on https://blog.gitbutler.com/how-git-core-devs-configure-git/
  #git rebase -i --autosquash $1~1
  git rebase --autosquash "$1~1"
}

gitcommitandrebase()
{
  git commit -m 'tmp'
  git rebase $@
}

gitcheckoutremotebranch()
{
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  git fetch origin "+$1:$1"
  git checkout "$1"
}


notify_failed() {
  osascript -e 'display notification "Failed"'
  say failed
}

gitreapply()
{
  # Starting at a commit in the current branch's history, cherry-pick all of
  # the commits up until HEAD on top of the `startBranch`
  if [ "$#" -ne 2 ]; then
    echo "Starting at a commit in the current branch's history, cherry-pick all of"
    echo "the commits up until HEAD on top of the \`startBranch\`"
    echo ""
    echo "Illegal number of parameters; enter a start branch and a start commit"
    return
  fi
  startBranch=$1
  startCommit=$2
  echo "branch: $startBranch"
  echo "start commit: $startCommit"
  branchName=$(git rev-parse --abbrev-ref HEAD)
  if ! [[ $branchName =~ ^billfinn.*$ ]]; then
    echo "error: not on billfinn branch"
    return 1
  fi
  if ! [[ $startBranch =~ ^billfinn.*$ ]] && ! [[ $startBranch == 'master' ]]; then
    echo "error: branch is not billfinn or master"
    return 1
  fi
  echo "currently at commit $(git rev-parse HEAD)"
  tmpBranchName=$(echo $branchName | sed 's/^billfinn/tmp-billfinn/')
  branchExists=$(git rev-parse --verify $tmpBranchName 2>/dev/null)
  if [[ -z $branchExists ]]; then
    echo "branch $tmpBranchName doesn't exist; creating"
    git branch $tmpBranchName
  fi
  echo "updating $tmpBranchName to $startBranch"
  git branch -f $tmpBranchName $startBranch
  echo "checking out $tmpBranchName"
  git checkout $tmpBranchName
  echo "cherry-picking $startCommit^..$branchName"
  if ! [[ $tmpBranchName =~ ^tmp.*$ ]]; then
    echo "error: tmp branch incorrectly formatted"
    return 1
  fi
  git cherry-pick $startCommit^..$branchName
  if ! [[ $? -eq 0 ]]; then
    echo -e "error: cherry picking failed. manually clean up and then force dev branch to HEAD\ngit branch -f $branchName HEAD"
    return 1
  fi
  oldCommit=$(git rev-parse $branchName)
  echo "branch $branchName was at $oldCommit; moving to $(git rev-parse HEAD)"
  echo -e "to move back, run:\ngit branch -f $branchName $oldCommit"
  git branch -f $branchName HEAD
  git checkout $branchName
  git branch -f $tmpBranchName $oldCommit
}

alias nt='nosetests -s --with-progressive --logging-level=INFO'

PROMPT_COMMAND="run_on_prompt_command"
#  \*(Ps = \*3\*0 \(-> Set foreground color to Black.
#  \*(Ps = \*3\*1 \(-> Set foreground color to Red.
#  \*(Ps = \*3\*2 \(-> Set foreground color to Green.
#  \*(Ps = \*3\*3 \(-> Set foreground color to Yellow.
#  \*(Ps = \*3\*4 \(-> Set foreground color to Blue.
#  \*(Ps = \*3\*5 \(-> Set foreground color to Magenta.
#  \*(Ps = \*3\*6 \(-> Set foreground color to Cyan.
#  \*(Ps = \*3\*7 \(-> Set foreground color to White.
#  \*(Ps = \*3\*9 \(-> Set foreground color to default (original).
#  \*(Ps = \*4\*0 \(-> Set background color to Black.
#  \*(Ps = \*4\*1 \(-> Set background color to Red.
#  \*(Ps = \*4\*2 \(-> Set background color to Green.
#  \*(Ps = \*4\*3 \(-> Set background color to Yellow.
#  \*(Ps = \*4\*4 \(-> Set background color to Blue.
#  \*(Ps = \*4\*5 \(-> Set background color to Magenta.
#  \*(Ps = \*4\*6 \(-> Set background color to Cyan.
#  \*(Ps = \*4\*7 \(-> Set background color to White.
#  \*(Ps = \*4\*9 \(-> Set background color to default (original).

if [[ $HOSTNAME == "vagrant"* ]]
then
  PS1="\[\033[37m\]\t\[\033[m\]-\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\]\$ "
fi
parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

rmgradlecache() {
  find ~/.gradle/caches/ -name "*stripe*$1" -exec rm -rvf {} \;
}

export PS1="\u@\h \[\033[32m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\] $ "
# alias notify'osascript -e '"'"'display notification "hello world!"'"'"'

wb() {
  if [ "$#" -eq 0 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  work begin --no-pr --title "'work-cli-$*'"
}

#alias wb='work begin --no-pr --title '
setsecretkey() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    SECRET_KEY="$1"
    export SECRET_KEY
  fi
}

setpaymentintentid() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    PAYMENT_INTENT_ID="$1"
    export PAYMENT_INTENT_ID
  fi
}

setreadercollecteddataid() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    TMRCD_ID="$1"
    export TMRCD_ID
  fi
}

setconfigurationid() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    CONFIGURATION_ID="$1"
    export CONFIGURATION_ID
  fi
}

setlocationid() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    LOCATION_ID="$1"
    export LOCATION_ID
  fi
}

setreaderid() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    READER_ID="$1"
    export READER_ID
  fi
}

setstripeaccountheader() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: setstripeaccountheader <account_id>"
    return 1
  fi
  export STRIPE_ACCOUNT_HEADER="$1"
  echo "Stripe-Account header set to: $STRIPE_ACCOUNT_HEADER"
}

clearstripeaccountheader() {
  unset STRIPE_ACCOUNT_HEADER
  echo "Stripe-Account header cleared"
}

setstripelivemode() {
  case "$1" in
    true|false)
      export STRIPE_LIVEMODE="$1"
      echo "Stripe-Livemode header set to: $STRIPE_LIVEMODE"
      ;;
    *)
      echo "Usage: setstripelivemode <true|false>"
      return 1
      ;;
  esac
}

clearstripelivemode() {
  unset STRIPE_LIVEMODE
  echo "Stripe-Livemode header cleared"
}

curlstripe() {
  local verbose=false
  case "${1:-}" in
    -v|--verbose)
      verbose=true
      shift
      ;;
  esac

  if [ "$#" -lt 1 ]; then
    echo "Usage: curlstripe [-v|--verbose] <path-or-url> [curl args...]"
    return 1
  fi
  if [ -z "$SECRET_KEY" ]; then
    echo "SECRET_KEY is not set. Use setsecretkey <secret_key>."
    return 1
  fi

  local path="$1"
  shift
  local url
  if [[ "$path" == http://* || "$path" == https://* ]]; then
    url="$path"
  elif [[ "$path" == /* ]]; then
    url="https://api.stripe.com$path"
  else
    url="https://api.stripe.com/$path"
  fi

  local livemode="${STRIPE_LIVEMODE:-}"
  if [ -z "$livemode" ]; then
    case "$SECRET_KEY" in
      *_live_*)
        livemode=true
        ;;
      *)
        livemode=false
        ;;
    esac
  fi

  local curl_args=(-s -X GET -H "Stripe-Livemode: $livemode")
  if [ "$verbose" = true ]; then
    curl_args+=(-v)
  fi
  if [ -n "$STRIPE_ACCOUNT_HEADER" ]; then
    curl_args+=(-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER")
  fi

  curl "${curl_args[@]}" "$url" -u "$SECRET_KEY:" "$@"
}

curlstripeqa() {
  local verbose=false
  case "${1:-}" in
    -v|--verbose)
      verbose=true
      shift
      ;;
  esac

  if [ "$#" -lt 1 ]; then
    echo "Usage: curlstripeqa [-v|--verbose] <path-or-url> [curl args...]"
    return 1
  fi
  if [ -z "$SECRET_KEY" ]; then
    echo "SECRET_KEY is not set. Use setsecretkey <secret_key>."
    return 1
  fi

  local path="$1"
  shift
  local url
  if [[ "$path" == http://* || "$path" == https://* ]]; then
    url="$path"
  elif [[ "$path" == /* ]]; then
    url="https://qa-api.stripe.com$path"
  else
    url="https://qa-api.stripe.com/$path"
  fi

  local livemode="${STRIPE_LIVEMODE:-}"
  if [ -z "$livemode" ]; then
    case "$SECRET_KEY" in
      *_live_*)
        livemode=true
        ;;
      *)
        livemode=false
        ;;
    esac
  fi

  local curl_args=(-s -X GET -H "Stripe-Livemode: $livemode")
  if [ "$verbose" = true ]; then
    curl_args+=(-v)
  fi
  if [ -n "$STRIPE_ACCOUNT_HEADER" ]; then
    curl_args+=(-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER")
  fi

  curl "${curl_args[@]}" "$url" -u "$SECRET_KEY:" "$@"
}

curlaccountget() {
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/account" -u "$SECRET_KEY":)
  echo "$curl_output"
  echo "$curl_output" | jq .id
}
alias stripelistenwebhooks='stripe listen --forward-to localhost:8000/webhook'
curllocationslist() {
  local output
  output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/locations" -u "$SECRET_KEY":)
  printf '%s\n' "$output"
  printf '%s\n' "$output" | jq -r -c '.data[] | [.display_name, .id]' >&2
  local count
  count=$(printf '%s\n' "$output" | jq '.data | length')
  if [ "$count" -eq 1 ]; then
    LOCATION_ID=$(printf '%s\n' "$output" | jq -r '.data[0].id')
    export LOCATION_ID
    jq -n -c --arg location_id "$LOCATION_ID" '{"message":"Only one location found. Setting LOCATION_ID","location_id":$location_id}' >&2
  fi
}

curllocationslisttest() {
  type curllocationslisttest
  local output
  output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/locations" -u "$SECRET_KEY":)
  local filtered
  filtered=$(echo "$output" | jq -r -c '.data[] | select((.display_name | contains("test")) or (.display_name | contains("Home"))) | [.display_name, .id]')
  echo "$filtered"
  local count
  count=$(echo "$filtered" | wc -l | tr -d ' ')
  if [ -n "$filtered" ] && [ "$count" -eq 1 ]; then
    LOCATION_ID=$(echo "$filtered" | jq -r '.[1]')
    export LOCATION_ID
    echo "Only one location found. Setting LOCATION_ID=$LOCATION_ID"
  fi
}

curlwebhooklist() {
  curl -s -H "Stripe-Version: 2025-05-28.basil;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/webhook_endpoints" -u "$SECRET_KEY":
}

curlwebhookdelete() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl -s -H "Stripe-Version: 2025-05-28.basil;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X DELETE "https://api.stripe.com/v1/webhook_endpoints/$1" -u "$SECRET_KEY":
}

curlwebhookcreate() {
  type curlwebhookcreate
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl -s -H "Stripe-Version: 2025-05-28.basil;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/webhook_endpoints" -u "$SECRET_KEY": -d "enabled_events[]"="terminal.reader.action_succeeded" -d "enabled_events[]"="terminal.reader.action_failed" --data-urlencode "api_version"="2025-05-28.basil;" --data-urlencode url="$1")
  echo "$curl_output"
}

curlfileget() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/files/$1" -u "$SECRET_KEY":)
  echo "$curl_output"
  CONTENT_URL=$(echo "$curl_output" | jq -r -c .url)
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "$CONTENT_URL" -u "$SECRET_KEY":)
  echo "$curl_output" | tee file.svg
}

curllocationsget() {
  curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/locations/$LOCATION_ID" -u "$SECRET_KEY":
}

curllocationssetconfigoverride() {
  curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/locations/$LOCATION_ID" -u "$SECRET_KEY": -d configuration_overrides="$1"
}

curlreadercreatesimulated() {
  output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers" -u "$SECRET_KEY": -d "location=$LOCATION_ID" -d registration_code=simulated-wpe)
  echo "$output"
  READER_ID=$(echo "$output" | jq -r -c .id)
  export READER_ID
}

curlreaderdelete() {
  curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X DELETE "https://api.stripe.com/v1/terminal/readers/$1" -u "$SECRET_KEY":
}

curlreaderaccessibilitymodeenable() {
  curl_output=$(curl -X POST -vvv -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID/accessibility_mode" \
    -H "Stripe-Version: 2026-04-22.dahlia;terminal_accessibility_mode_preview=v1" \
    -u "$SECRET_KEY:" \
    -d text_to_speech="speakers")
  echo "$curl_output"
}

curlreaderaccessibilitymodedisable() {
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID/accessibility_mode" \
    -H "Stripe-Version: 2026-04-22.dahlia;terminal_accessibility_mode_preview=v1" \
    -u "$SECRET_KEY:" \
    -d text_to_speech="off")
  echo "$curl_output"
}

curlreadergetwithconnectiontoken() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  CONNECTION_TOKEN=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST https://api.stripe.com/v1/terminal/connection_tokens -u "$SECRET_KEY": | jq .secret | sed -e 's/"//g')
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers?serial_number=$1" -u $CONNECTION_TOKEN:
}

curlreaderlist() {
  if [ "$#" -eq 1 ]; then
    output=$(curl -H "Stripe-Version: 2025-05-28.basil;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -s "https://api.stripe.com/v1/terminal/readers?serial_number=$1" -u "$SECRET_KEY":)
    echo "$output"
    READER_ID=$(echo "$output" | jq -r -c .data[].id)
    export READER_ID
    LOCATION_ID=$(echo "$output" | jq -r -c .data[].location)
    export LOCATION_ID
    echo "Setting location ID: $LOCATION_ID"
    location_output=$(curllocationsget)
    config_id=$(echo "$location_output" | jq -r -c '.configuration_overrides // empty')
    if [ -n "$config_id" ]; then
      echo "Setting config ID: $config_id"
      CONFIGURATION_ID="$config_id"
      export CONFIGURATION_ID
    fi
  else
    curl -H "Stripe-Version: 2025-05-28.basil;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -s "https://api.stripe.com/v1/terminal/readers?limit=100" -u "$SECRET_KEY":
  fi
}

curlreaderget() {
  curl -H "Stripe-Version: 2025-05-28.basil;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -s "https://api.stripe.com/v1/terminal/readers/$READER_ID" -u "$SECRET_KEY":
}

curlreaderregister() {
  type curlreaderregister
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi

  if [ -z "$LOCATION_ID" ]; then
    echo "LOCATION_ID not set. Fetching locations..."
    local loc_output
    loc_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/locations" -u "$SECRET_KEY":)
    local loc_count
    loc_count=$(echo "$loc_output" | jq '.data | length')

    if [ "$loc_count" -eq 0 ]; then
      echo "No locations found. Create one first with curllocationscreate."
      return 1
    elif [ "$loc_count" -eq 1 ]; then
      LOCATION_ID=$(echo "$loc_output" | jq -r '.data[0].id')
      export LOCATION_ID
      echo "Only one location found. Using LOCATION_ID=$LOCATION_ID"
    else
      echo "Multiple locations found. Select one:"
      local i=1
      echo "$loc_output" | jq -r -c '.data[] | [.display_name, .id]' | while IFS= read -r line; do
        echo "  $i) $line"
        i=$((i + 1))
      done
      printf "Enter number: "
      local selection
      read -r selection
      LOCATION_ID=$(echo "$loc_output" | jq -r ".data[$((selection - 1))].id")
      if [ "$LOCATION_ID" = "null" ] || [ -z "$LOCATION_ID" ]; then
        echo "Invalid selection."
        return 1
      fi
      export LOCATION_ID
      echo "Using LOCATION_ID=$LOCATION_ID"
    fi
  fi

  output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/readers -u "$SECRET_KEY:" -d location="$LOCATION_ID" -d registration_code="$1" -d label='billfinn')
  echo "$output"
  READER_ID=$(echo "$output" | jq -r -c .id)
  export READER_ID
  LOCATION_ID=$(echo "$output" | jq -r -c .location)
  export LOCATION_ID
  echo "Setting location ID: $LOCATION_ID"
  location_output=$(curllocationsget)
  config_id=$(echo "$location_output" | jq -r -c '.configuration_overrides // empty')
  if [ -n "$config_id" ]; then
    echo "Setting config ID: $config_id"
    CONFIGURATION_ID="$config_id"
    export CONFIGURATION_ID
  fi
}

curllocationscreate() {
  local date_part
  date_part=$(date +%Y%m%d)
  local unique_id
  unique_id=$(printf "%05d" $(( $(date +%s) % 100000 )))
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/locations -u "$SECRET_KEY": -d display_name="$date_part-$unique_id test location" -d "address[line1]"="354 Oyster Point Blvd" -d "address[city]"="South San Francisco" -d "address[state]"="CA" -d "address[country]"="US" -d "address[postal_code]"="94080")
  echo "$curl_output"
  LOCATION_ID=$(echo "$curl_output" | jq -r -c .id)
  export LOCATION_ID
  echo "Setting location ID: $LOCATION_ID"
}

curllocationsdelete() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X DELETE "https://api.stripe.com/v1/terminal/locations/$1" -u "$SECRET_KEY":
  fi
}

alias curllocationsclearconfigoverride='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/locations/$LOCATION_ID -u "$SECRET_KEY": -d configuration_overrides='
alias curlconfigurationslist='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/configurations" -u "$SECRET_KEY":'
alias curlreadercollecteddataget='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/reader_collected_data/$TMRCD_ID" -u "$SECRET_KEY":'
alias curlconfigurationsget='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID" -u "$SECRET_KEY":'
alias curlconfigurationsgetdefault='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/configurations?is_account_default=true" -u "$SECRET_KEY":'
alias curlconfigurationscreate='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/configurations" -u "$SECRET_KEY":'
alias curlconfigurationsofflineenable='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "offline[enabled]"=true'
alias curlconfigurationsofflinedisable='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "offline[enabled]"=false'
alias curlconfigurationstippingclear='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "tipping"='
alias curlconfigurationstippingset='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "tipping[usd][fixed_amounts][]"=100   -d "tipping[usd][fixed_amounts][]"=200   -d "tipping[usd][fixed_amounts][]"=300'
alias curlconfigurationstippingsetsmart='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "tipping[usd][percentages][]"=15   -d "tipping[usd][percentages][]"=20   -d "tipping[usd][percentages][]"=25   -d "tipping[usd][fixed_amounts][]"=100   -d "tipping[usd][fixed_amounts][]"=200   -d "tipping[usd][fixed_amounts][]"=300   -d "tipping[usd][smart_tip_threshold]"=1000 -d "tipping[gbp][percentages][]"=15   -d "tipping[gbp][percentages][]"=20   -d "tipping[gbp][percentages][]"=25   -d "tipping[gbp][fixed_amounts][]"=100   -d "tipping[gbp][fixed_amounts][]"=200   -d "tipping[gbp][fixed_amounts][]"=300   -d "tipping[gbp][smart_tip_threshold]"=1000'
alias curlconfigurationsstandaloneenable='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "standalone[enabled]"=true -d "standalone[payment_settings][currency]"=usd -d "standalone[payment_settings][payment_method_types][0]"=card_present'
alias curlconfigurationsstandalonedisable='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "standalone[enabled]"=false'
alias curlpaymentintentlist='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/payment_intents -u "$SECRET_KEY":'
alias curlpaymentintentlistrecent='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X GET https://api.stripe.com/v1/payment_intents -u "$SECRET_KEY": -d created[gt]=$(date -v-15M +%s)'
alias curlpaymentintentcancel='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST https://api.stripe.com/v1/payment_intents/$PAYMENT_INTENT_ID/cancel -u "$SECRET_KEY":'
alias curlrefundcreate='curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/refunds -u "$SECRET_KEY": -d payment_intent=$PAYMENT_INTENT_ID'

waitforactionsucceeded() {
  while true; do
    sleep 0.5
    collect_inputs_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;")
    status=$(echo "$collect_inputs_output" | jq -r .action.status)
    if [ "$status" = "succeeded" ]; then
      break
    fi
  done
}

# Make this a function, so it's easier to use within bash scripts
curlreadercancelaction() {
  curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/cancel_action" -u "$SECRET_KEY":
}

curlreadercollectinputstimeout() {
  type curlreadercollectinputstimeout
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/timeout_input_collection" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;"
}

curlreadercollectinputssucceed() {
  type curlreadercollectinputssucceed
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/succeed_input_collection" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;"
}

curlreadercollectinputssucceedskip() {
  type curlreadercollectinputssucceed
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/succeed_input_collection" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "skip_non_required_inputs"="all"
}

# Make this a function, so it's easier to use within bash scripts
curlreadercollectinputs() {
  title="Receipt"
  if [ "$#" -eq 1 ]; then
    title="$1"
  fi
  type curlreadercollectinputs
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=selection -d "inputs[0][selection][choices][0][style]"=primary -d "inputs[0][selection][choices][0][text]"=Email -d "inputs[0][selection][choices][0][id]"=email_id -d "inputs[0][selection][choices][1][style]"=primary -d "inputs[0][selection][choices][1][text]"=Printed -d "inputs[0][selection][choices][1][id]"=printed_id -d "inputs[0][selection][choices][2][style]"=secondary -d "inputs[0][selection][choices][2][text]"="No thanks" -d "inputs[0][selection][choices][2][id]"="no_thanks_id" -d "inputs[0][custom_text][title]"="$title" -d "inputs[0][custom_text][description]"="How would you like your receipt?" -d "inputs[0][required]"=true -d "metadata[order_number]"=12345
}

curlreadercollectinputsx2() {
  type curlreadercollectinputsx2
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" \
    -u "$SECRET_KEY:" \
    -H "Stripe-Version: 2025-05-28.basil;" \
    -d "inputs[0][type]"=text \
    -d "inputs[0[custom_text][title]"="Title 1" \
    -d "inputs[1][type]"=text \
    -d "inputs[1[custom_text][title]"="Title 2"
}

curlreadercollectdatamagstripe() {
  type curlreadercollectdatanfc
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_data" -u "$SECRET_KEY": -H "Stripe-Version: 2026-03-25.preview;" -d "type"=magstripe
}

curlreadercollectdatanfc() {
  type curlreadercollectdatanfc
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_data" -u "$SECRET_KEY": -H "Stripe-Version: 2026-03-25.preview;" -d "type"=nfc
}

curlreadercollectinputsbacktoback() {
  type curlreadercollectinputsbacktoback
  curlreadercollectinputs "Receipt test 1"
  waitforactionsucceeded
  # Uncomment to simulate >3s delay
  # sleep 3
  curlreadercollectinputs "Receipt test 2"
}

curlreadercollectinputssignature() {
  type curlreadercollectinputssignature
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=signature -d "inputs[0][custom_text][title]"="Please sign" -d "inputs[0][custom_text][description]"="Please sign if you agree to the terms and conditions."
}

curlreadercollectinputstext() {
  type curlreadercollectinputstext
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=text -d "inputs[0][custom_text][title]"="Enter your name" -d "inputs[0][custom_text][description]"="We'll need your name to look up your account."
}

curlreadercollectinputsnumeric() {
  type curlreadercollectinputsnumeric
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=numeric -d "inputs[0][custom_text][title]"="Enter your zip code"
}

curlreadercollectinputsemail() {
  type curlreadercollectinputsemail
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=email -d "inputs[0][custom_text][title]"="Enter your email address" -d "inputs[0][custom_text][description]"="We'll send updates to your order and occasional deals."
}

curlreadercollectinputsphone() {
  type curlreadercollectinputsphone
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=phone -d "inputs[0][custom_text][title]"="Enter your phone number" -d "inputs[0][custom_text][description]"="We'll text you when your order is ready."
}

curlpaymentintentget() {
  curl_output=$(curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X GET -s "https://api.stripe.com/v1/payment_intents/$PAYMENT_INTENT_ID" -u "$SECRET_KEY:")
  echo "$curl_output"
}

curlpaymentintentcapture() {
  extra_args=""
  if [ "$#" -eq 1 ]; then
    pi_id=$1
  elif [ "$#" -eq 2 ]; then
    pi_id=$1
    extra_args="-d amount_to_capture=$2"
  else
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST -s "https://api.stripe.com/v1/payment_intents/$pi_id/capture" -u "$SECRET_KEY:"  ${extra_args:+"$extra_args"})
  echo "$curl_output"
}

curlpaymentintentcreate() {
  local currency="usd"
  local amount="5200"
  local payment_methods="card_present"
  local capture_method="manual"
  local extra_args=()
  local payment_method_args=()
  local payment_method
  local payment_method_count=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --amount)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --amount"
          return 1
        fi
        amount="$2"
        shift 2
        ;;
      --amount=*)
        amount="${1#--amount=}"
        shift
        ;;
      --currency)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --currency"
          return 1
        fi
        currency="$2"
        shift 2
        ;;
      --currency=*)
        currency="${1#--currency=}"
        shift
        ;;
      --payment-methods)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --payment-methods"
          return 1
        fi
        payment_methods="$2"
        shift 2
        ;;
      --payment-methods=*)
        payment_methods="${1#--payment-methods=}"
        shift
        ;;
      --capture-method)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --capture-method"
          return 1
        fi
        capture_method="$2"
        shift 2
        ;;
      --capture-method=*)
        capture_method="${1#--capture-method=}"
        shift
        ;;
      --)
        shift
        extra_args+=("$@")
        break
        ;;
      -*)
        echo "Unknown option: $1"
        return 1
        ;;
      *)
        echo "Unexpected argument: $1"
        echo "Usage: curlpaymentintentcreate [--amount AMOUNT] [--currency CURRENCY] [--payment-methods METHODS] [--capture-method CAPTURE_METHOD] [-- extra curl args...]"
        return 1
        ;;
    esac
  done

  IFS=',' read -ra payment_method_args <<< "$payment_methods"
  if [ "${#payment_method_args[@]}" -eq 0 ]; then
    echo "At least one payment method is required"
    return 1
  fi

  local curl_args=(-s)
  if [ -n "$STRIPE_ACCOUNT_HEADER" ]; then
    curl_args+=(-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER")
  fi
  curl_args+=(https://api.stripe.com/v1/payment_intents -u "$SECRET_KEY:" -d amount="$amount" -d currency="$currency")

  for payment_method in "${payment_method_args[@]}"; do
    payment_method="${payment_method#"${payment_method%%[![:space:]]*}"}"
    payment_method="${payment_method%"${payment_method##*[![:space:]]}"}"
    if [ -n "$payment_method" ]; then
      curl_args+=(-d "payment_method_types[]=$payment_method")
      payment_method_count=$((payment_method_count + 1))
    fi
  done
  if [ "$payment_method_count" -eq 0 ]; then
    echo "At least one payment method is required"
    return 1
  fi

  curl_args+=(-d capture_method="$capture_method")
  curl_args+=("${extra_args[@]}")

  pi_output=$(curl "${curl_args[@]}")
  echo "$pi_output"
  PAYMENT_INTENT_ID=$(echo "$pi_output" | jq -r -c .id)
  export PAYMENT_INTENT_ID
  echo "Setting PI ID: $PAYMENT_INTENT_ID"
}

curlpaymentintentupdate() {
  amount="5100"
  currency="usd"
  if [ "$#" -ge 1 ]; then
    amount="$1"
  fi
  if [ "$#" -ge 2 ]; then
    currency="$2"
  fi
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/payment_intents/$PAYMENT_INTENT_ID" -u "$SECRET_KEY:" -d amount="$amount" -d currency="$currency")
  echo "$curl_output"
}

curlreadercollectwithsurchargenotice() {
  if [ "$#" -eq 1 ]; then
    PI_ID="$1"
  else
    curlpaymentintentcreate
    PI_ID="$PAYMENT_INTENT_ID"
  fi
  echo "$PI_ID"
  curl_output=$(curl -H "Stripe-Version: 2024-12-18.acacia;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_payment_method" -u "$SECRET_KEY:" -d payment_intent="$PI_ID" --data-urlencode "collect_config[surcharge_notice]"="\$22.66 amount above incl. \$0.66 credit card surcharge. Debit cards pay a total of \$22.00")
  echo "$curl_output"
}

curlreadercollect() {
  if [ "$#" -eq 1 ]; then
    PI_ID="$1"
  elif [ -n "$PAYMENT_INTENT_ID" ]; then
    PI_ID="$PAYMENT_INTENT_ID"
  else
    curlpaymentintentcreate
    PI_ID="$PAYMENT_INTENT_ID"
  fi
  echo "$PI_ID"
  curl_output=$(curl -H "Stripe-Version: 2024-12-18.acacia;" ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_payment_method" -u "$SECRET_KEY:" -d payment_intent="$PI_ID")
  echo "$curl_output"
}

curlreaderconfirm() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID/confirm_payment_intent" -u "$SECRET_KEY:" -d payment_intent="$1")
  echo "$curl_output"
}

curlreaderconfirmwithsurcharge() {
  if [ "$#" -eq 1 ]; then
    PI_ID="$1"
  elif [ -n "$PAYMENT_INTENT_ID" ]; then
    PI_ID="$PAYMENT_INTENT_ID"
  else
    echo "No PI ID supplied and PAYMENT_INTENT_ID is not set"
    return 1
  fi
  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID/confirm_payment_intent" -u "$SECRET_KEY:" -d payment_intent="$PI_ID" -d "confirm_config[surcharge][consent][collection]"="enabled" -d "confirm_config[surcharge][consent][notice]"="Surcharge consent" -d "confirm_config[surcharge][amount]"=21)
  # curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID/confirm_payment_intent" -u "$SECRET_KEY:" -d payment_intent="$PI_ID" -d "confirm_config[amount_surcharge]"=21)
  echo "$curl_output"
}

# curlreaderprocess() {
#   if [ "$#" -eq 1 ]; then
#     PI_ID="$1"
#   else
#     curlreadersimplepayment
#     PI_ID="$PAYMENT_INTENT_ID"
#   fi
#   echo "$PI_ID"
#   curl_output=$(curl -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/process_payment_intent" -u "$SECRET_KEY:" -d payment_intent="$1")
#   echo "$curl_output"
# }

curlreaderprocess() {
  # Usage:
  # curlreaderprocess [PI_ID] [extra curl args...]
  #
  # If PI_ID is omitted, will call curlreadersimplepayment and use $PAYMENT_INTENT_ID
  # Any additional arguments after PI_ID are passed as extra arguments to curl.

  local PI_ID
  local EXTRA_ARGS=()

  if [ "$#" -ge 1 ]; then
    PI_ID="$1"
    shift
  fi

  if [ -z "$PI_ID" ]; then
    curlreadersimplepayment
    PI_ID="$PAYMENT_INTENT_ID"
  fi

  # Remaining arguments are passed as-is to curl
  EXTRA_ARGS=("$@")

  echo "Processing payment_intent ID: $PI_ID"

  curl_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID/process_payment_intent" \
    -u "$SECRET_KEY:" \
    -d payment_intent="$PI_ID" \
    "${EXTRA_ARGS[@]}")

  echo "$curl_output"
}

curlreaderpresentpaymentmethod() {
  if [ "$#" -eq 1 ]; then
    ARGS="-d card_present[number]=$1"
  else
    ARGS=""
  fi
  type curlreaderpresentpaymentmethod
  curl_output=$(curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST -s "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/present_payment_method" -u "$SECRET_KEY: $ARGS")
  echo "$curl_output"
}

curlreadersimplepaymentmoto() {
  curlpaymentintentcreate --payment-methods card
  curlreaderprocess "$PAYMENT_INTENT_ID" -d "process_config[moto]"=true
}

curlreadersimplepayment() {
  curlpaymentintentcreate "$@"
  curlreaderprocess "$PAYMENT_INTENT_ID"
}

curlreadersimplepaymentthencollectinputs() {
  curlreadersimplepayment "$@"
  waitforactionsucceeded
  # Uncomment to simulate >3s delay
  sleep 3
  curlreadercollectinputs "Receipt collect after payment"
}

curlreadersetreaderdisplay() {
  currency="usd"
  if [ "$#" -eq 1 ]; then
    currency="$1"
  fi
  curl ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/set_reader_display" -u "$SECRET_KEY": -d type=cart  -d "cart[line_items][0][description]"="Caramel latte"  -d "cart[line_items][0][amount]"=600  -d "cart[line_items][0][quantity]"=1  -d "cart[line_items][1][description]"="Discount"  -d "cart[line_items][1][amount]"=-100  -d "cart[line_items][1][quantity]"=1  -d "cart[currency]"="$currency"  -d "cart[tax]"=100  -d "cart[total]"=600
}

curlreadersetupintent() {
  si_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} https://api.stripe.com/v1/setup_intents -u "$SECRET_KEY:" -d "payment_method_types[]"=card_present)
  echo "$si_output"
  SIMPLE_SI_ID=$(echo "$si_output" | jq -r -c .id)
  export SIMPLE_SI_ID
  process_output=$(curl -s ${STRIPE_ACCOUNT_HEADER:+-H "Stripe-Account: $STRIPE_ACCOUNT_HEADER"} "https://api.stripe.com/v1/terminal/readers/$READER_ID/process_setup_intent" -u "$SECRET_KEY:" -d setup_intent="$SIMPLE_SI_ID" -d customer_consent_collected=true)
  echo "$process_output"
}

#alias saydone="say done window \$(tmux display-message -p -F '#{window_index}' -t \"$TMUX_PANE\") exit code $?"
saydone() {
  exitCode=$?
  window=$(tmux display-message -p -F '#{window_index}' -t "$TMUX_PANE")
  say done win $window "$@" exit code $exitCode &
}

sayready() {
  window=$(tmux display-message -p -F '#{window_index}' -t "$TMUX_PANE")
  say ready win "$window" "$@" > /dev/null 2>&1 &
}

appstart() {
  if [ "$#" -gt 0 ]; then
    ADB_ARGS="-s $1"
  else
    ADB_ARGS=""
  fi
  CMD="adb $ADB_ARGS shell am start -n com.stripe.terminal.testapp/.MainActivity"
  $CMD
}
export S10_ADB_DEVICE_ID="RF8N41V8P0T"
export WILLIAM_FINN_IPHONE_UDID="AFDB9FCD-F047-52C4-A90E-7C24C40A8D4B"

gradletest() {
  # Get the title of the first Android Studio window
  window_title=$(osascript -e '
  tell application "System Events"
      set studioWindows to windows of (first process whose name is "studio")
      if (count of studioWindows) > 0 then
          return name of first item of studioWindows
      else
          return ""
      end if
  end tell
  ')

  # Check if an Android Studio window was found
  if [ -z "$window_title" ]; then
      echo "No Android Studio window found"
      exit 1
  fi


  # Extract the file name and module path from the window title
  file_name=$(echo "$window_title" | sed -n 's/.*– \(.*\) \[.*/\1/p' | sed 's/\.kt$//')
  module_path=$(echo "$window_title" | sed -n 's/.*\[\(.*\)\]/\1/p' | sed -n 's/^android\.\(.*\)/\1/p' | sed 's/\.[^\.]*Test$//' | tr '.' ':')

  echo "Window title: $window_title"
  echo "File name: $file_name"
  echo "Module path: $module_path"
  # Check if file name and module path were extracted
  if [ -z "$file_name" ] || [ -z "$module_path" ]; then
      echo "Couldn't extract file name or module path from Android Studio window title"
      exit 1
  fi

  # Generate the Gradle command
  gradle_command="./gradlew --configuration-cache $module_path:testDebugUnitTest"
  # gradle_command="./gradlew --configuration-cache $module_path:testDebugUnitTest --tests \"*$file_name\""

  # Print the command
  echo "Generated Gradle command:"
  echo "$gradle_command"
  $gradle_command
}
alias protoassemble='type protoassemble; ./gradlew --configuration-cache :proto:modules:common:assemble :proto:modules:terminal:assemble :proto:modules:source-external:assemble :proto:modules:source-internal:assemble :proto:modules:internal:assemble'
alias gradleclearconfigurationcache='type gradleclearconfigurationcache; rm -rf .gradle/configuration-cache'
alias appinstalldebug='type appinstalldebug; ./gradlew --configuration-cache :terminalapp:application:installDebug && adb shell am start -n com.stripe.terminal.testapp/.MainActivity; saydone install debug'
alias appreinstalldebug='type appreinstalldebug; adb install -t ./terminalapp/application/build/outputs/apk/debug/application-debug.apk && appstart'
alias readerassembledebugupdaterandreader='type readerassembledebugupdaterandreader; readerassembledebugupdater && readerassembledebugreader'
alias readerassembledebugupdater='type readerassembledebugupdater; ./gradlew --configuration-cache :updater:application:assembleDebug; saydone assembling updater'
alias readerassembledebugreader='type readerassembledebugreader; ./gradlew --configuration-cache :reader:application:assembleDebug; saydone assembling reader'
alias readerassembleverifoneupdaterandreader='type readerassembleverifoneupdaterandreader; readerassembleverifoneupdater && readerassembleverifonereader'
alias readerassembleverifoneupdater='type readerassembleverifoneupdater; ./gradlew --configuration-cache :updater:application:assembleVerifoneDebug; saydone assembling verifone updater'
alias readerassembleverifonereader='type readerassembleverifonereader; ./gradlew --configuration-cache :reader:application:assembleVerifoneDebug; saydone assembling verifone reader'
alias readerassemblereleasereader='type readerassemblereleasereader; ./gradlew --configuration-cache :reader:application:assembleRelease; saydone'
alias boundson='adb shell setprop debug.layout true; adb shell service call activity 1599295570 > /dev/null'
alias boundsoff='adb shell setprop debug.layout false ; adb shell service call activity 1599295570 > /dev/null'
alias appinstallhandoff='type appinstallhandoff; ./gradlew --configuration-cache :terminalapp:application:installhandoff; say done install handoff'
alias adbinstallapp='adbinstallhandoff && appstart'
alias appassemble='type appassemble; ./gradlew --configuration-cache :terminalapp:application:assembleDebug; saydone assemble_debug'
alias appinstalls10='type appinstalls10; adbs10 install -t ./terminalapp/application/build/outputs/apk/debug/application-debug.apk && appstart $S10_ADB_DEVICE_ID; saydone app_install_s10'
alias javaapprun='type javaapprun; ./gradlew --configuration-cache :terminal-java-app:application:run'
alias rmmvnlocal='rm -rvf ~/.m2/repository/com/stripe/stripeterminal*'
alias rmgradlesnapshots="find ~/.gradle/caches/ -name '*stripe*SNAPSHOT' -exec rm -rvf {} \\;"
alias adbpixel3='adb -s 8C9X1L79K'
alias adbs10='adb -s $S10_ADB_DEVICE_ID'

alias adbreinstallapp='type adbreinstallapp; adbinstallhandoff && adb shell am start -n com.stripe.terminal.testapp/.MainActivity'
# alias adbbuildapp='type adbbuildapp; ./gradlew :terminalapp:application:assembleDebug && adbreinstallapp'


alias readerreinstalllatest='type readerreinstalllatest; APK_ROOT_DIR=$(find /Users/billfinn/stripe/reader-apks/ -maxdepth 1 -type d | grep "2\.[0-9][0-9]" | sort | tail -n 1); echo $APK_ROOT_DIR; adb install -t $APK_ROOT_DIR/com.stripe.updater-bbpos-debug.apk && adb install -t $APK_ROOT_DIR/com.stripe.reader-bbpos-debug.apk'
alias readerreinstallapp='type readerreinstallapp; adb install -t ./terminalapp/application/build/outputs/apk/debug/application-debug.apk && adb shell am start -n com.stripe.terminal.testapp/.MainActivity; saydone installing_app'
alias readerreinstallreader='type readerreinstallreader; adb install ./reader/application/build/outputs/apk/bbpos/debug/com.stripe.reader-bbpos-debug.apk; saydone installing_reader'
alias readerreinstallupdater='type readerreinstallupdater; adb install ./updater/application/build/outputs/apk/bbpos/debug/com.stripe.updater-bbpos-debug.apk; saydone installing_updater'
alias readerreinstallupdaterandreader='readerreinstallupdater && readerreinstallreader'

alias readerreinstallverifonereader='type readerreinstallverifonereader; adb install -d ./reader/application/build/outputs/apk/verifone/debug/com.stripe.reader-verifone-debug.apk; saydone installing_verifone_reader'
alias readerreinstallverifoneupdater='type readerreinstallverifoneupdater; adb install -d ./updater/application/build/outputs/apk/verifone/debug/com.stripe.updater-verifone-debug.apk; saydone installing_verifone_updater'
alias readerreinstallverifoneupdaterandreader='readerreinstallverifoneupdater && readerreinstallverifonereader'

alias standaloneassemble='type standaloneassemble; ./gradlew --configuration-cache :standalonepos:application:assembleDebug ; saydone'
alias standaloneinstallDebug='type standaloneinstallDebug; ./gradlew --configuration-cache :standalonepos:application:installDebug ; saydone'
alias standalonereinstall='type standalonereinstall; adb install -d ./standalonepos/application/build/outputs/apk/debug/application-debug.apk; saydone'

alias terminalandroidassemble='type terminalandroidassemble; ./gradlew --configuration-cache :standalonepos:android:assembleDebug ; saydone'
alias terminalandroidreinstall='type terminalandroidreinstall; adb install -d ./standalonepos/android/build/outputs/apk/debug/android-debug.apk && terminalandroidappstart; saydone'
alias terminalandroidappstart='type terminalandroidappstart; adb shell am start -n com.stripe.standalonepos.android.debug/com.stripe.standalone.android.MainActivity'

alias readerbuildapp='type readerbuildapp; ./gradlew --configuration-cache :terminalapp:application:installHandoff; adb shell am start -n com.stripe.terminal.testapp/.MainActivity; saydone installing app'
alias readerstartupdater='type readerstartupdater; adb shell am start -n com.stripe.updater/.MainActivity'

alias readerbuildupdater='type readerbuildupdater; readerassembledebugupdater && readerreinstallupdater; saydone building_updater'
alias readerbuildreader='type readerbuildreader; readerassembledebugreader && readerreinstallreader; saydone building_reader'
alias readerbuildupdaterandreader='type readerbuildupdaterandreader; readerbuildupdater && readerbuildreader'

alias readerbuildupdaterandreaderrelease='type readerbuildupdaterandreaderrelease; ./gradlew :updater:application:assembleRelease && apksigner sign --ks $HOME/stripe/android/debug.keystore --ks-pass pass:android ./updater/application/build/outputs/apk/bbpos/release/com.stripe.updater-bbpos-release-unsigned.apk && adb install ./updater/application/build/outputs/apk/bbpos/release/com.stripe.updater-bbpos-release-unsigned.apk ; saydone building_updater && ./gradlew :reader:application:assembleRelease && apksigner sign --ks $HOME/stripe/android/debug.keystore --ks-pass pass:android ./reader/application/build/outputs/apk/bbpos/release/com.stripe.reader-bbpos-release-unsigned.apk && adb install ./reader/application/build/outputs/apk/bbpos/release/com.stripe.reader-bbpos-release-unsigned.apk; saydone building_reader'

alias readerbuildall='type readerbuildall; readerbuildupdater && readerbuildreaderandapp'
alias readerbuildreaderandapp='type readerbuildreaderandapp; readerbuildreader && readerbuildapp'
alias grsdkpublishlocal='find ~/.gradle/caches/ -name "*stripe*SNAPSHOT" -exec rm -rvf {} \; ; rm -rvf ~/.m2/repository/com/stripe/stripeterminal* && grsdkclean && ./gradlew terminalsdk:publishAllLocal -PVERSION_NAME=SNAPSHOT --info'
alias disablebracketedpaste='printf "\e[?2004l"'
alias phgrep='cat $PERSISTENT_HISTORY_FILE|grep --color -n -a'
alias ag='ack-grep --ignore-dir dist --ignore-file=ext:patch'
alias agt='find . -name "*.py" -type f | xargs ls -tr1 | xargs ag '
alias k='fc -s'
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous on"

alias wraplineschanged='git diff `git merge-base master HEAD` | grep "^\+" | grep -E ".{102}|^\+\+"'
alias cfchanged='cf `git diff --name-only --diff-filter=d master | grep -E "\.(m|h)$"`'

alias g='git'
alias gd='git diff --no-prefix'
d() {
  local png_files
  png_files=$(git diff --name-only "$@" | rg '\.png$')
  if [[ -n "$png_files" ]]; then
    echo "Ignoring PNG files:"
    echo "$png_files" | sed 's/^/  /'
    echo ""
  fi
  git diff "$@" -- . ':(exclude)*.png'
}
alias glm='git log -p $(default_branch)..HEAD'
alias glbf='git log -p --author=billfinn'
alias glp='git log -p --follow'
# alias gg='git grep --break --heading --line-number'
alias gg='git grep --line-number'
alias gitc='git commit'
alias r='git reset -p HEAD'
alias c='git commit'
alias cfile='gcmfile'
alias gita='git add -p'
alias a='git add -p'
alias gitu='git checkout -p --'
alias u='git checkout -p --'
alias uall='git checkout -- .'
alias co='git checkout'
alias show='git show'
alias pick='git cherry-pick'

alias glstag='git log --tags --simplify-by-decoration --pretty="format:%ci %d" | sort -r | less'
alias gamend='git commit --no-verify --amend --no-edit'
# alias gm='git checkout master'
alias gfo='git fetch origin && [ `git rev-parse --abbrev-ref HEAD` == $(default_branch) ] && gmr || git fetch . origin/$(default_branch):$(default_branch)'
gfor() {
  local branch remote merge_ref upstream_ref
  branch=$(git symbolic-ref --quiet --short HEAD) || return 1
  remote=$(git config --get "branch.$branch.remote") || return 1
  merge_ref=$(git config --get "branch.$branch.merge") || return 1
  upstream_ref=$(git rev-parse --symbolic-full-name '@{u}') || return 1

  git fetch "$remote" "+$merge_ref:$upstream_ref" && git reset --hard '@{u}'
}
alias gmr='git merge --ff-only @{u}'
alias gmain='git checkout $(default_branch) && git fetch origin && git merge --ff-only @{u}'
alias gfetchdefaultbranch='git fetch origin && git update-ref refs/heads/$(default_branch) origin/$(default_branch) && (git ls-remote --exit-code --heads origin master-passing-tests >/dev/null 2>&1 && git update-ref refs/heads/master-passing-tests origin/master-passing-tests || true)'
alias grebase='gfetchdefaultbranch && git rebase $(default_branch)'
# alias gmain='git fetch origin && git checkout origin/master'
# alias grebase='gmain && git checkout - && git rebase origin/master'
alias src='source ~/.bashrc'
alias sandboxstagingdb='export ZA_SANDBOX_STAGING_DATABASE_URI=`envdir ~/Projects/Angaza/variables.aws summon --ignore-all -f ~/Projects/Angaza/payg-backend/za/secrets.yml -e sandbox -D ENV=sandbox-staging printenv | grep "^DATABASE_URI=" | cut -d "=" -f 2`'
alias proddb='export ZA_PROD_DATABASE_URI=`cd payg-deploy > /dev/null && summon -e PRODUCTION printenv | grep "^DATABASE_URI=" | cut -d "=" -f 2`'
alias analyticsdb='export ZA_ANALYTICS_DATABASE_URL=`envdir ~/Projects/Angaza/variables.aws summon -f ~/Projects/Angaza/payg-backend/buildkite/periodic-tasks/check-follower-lag-secrets.yml printenv | grep "^ANALYTICS_FOLLOWER_DATABASE_URL=" | cut -d "=" -f 2`'
alias exportdb='export ZA_EXPORT_DATABASE_URL=`envdir ~/Projects/Angaza/variables.aws summon -f ~/Projects/Angaza/payg-backend/buildkite/periodic-tasks/check-follower-lag-secrets.yml printenv | grep "^EXPORTS_FOLLOWER_DATABASE_URL=" | cut -d "=" -f 2`'
alias followerdb='export ZA_FOLLOWER_DATABASE_URL=`cd payg-deploy > /dev/null && summon -e follower printenv | grep "^DATABASE_URI=" | cut -d "=" -f 2`'
alias heybillfinndb='export ZA_HEYBILLFINN_FORK_URL=`cd payg-deploy > /dev/null && summon -f ~/Projects/Angaza/payg-deploy/secrets.yml -e heroku_admin heroku config --app angaza-production | grep HEYBILLFINN | awk '"'"'{print $2}'"'"'`'
alias ec2instances='export ZA_EC2_INSTANCES=`ec2-host`'
alias ensure_bill='export ZA_BILL_INSTANCE=`cd payg-deploy > /dev/null && fab instance_list_all:production,deploy | grep billfinn.*i- |  tr -s " " | cut -d " " -f 4` && echo $ZA_BILL_INSTANCE'
alias ensure_batch_instance='export ZA_BATCH_INSTANCE=`cd payg-deploy > /dev/null && ec2-host $(cd payg-deploy > /dev/null && fab group_list_all:production,biz_batch | grep production__biz_batch | tail -n 1 | cut -d " " -f 1)`'
alias ensure_biz_internal_instance='export ZA_BIZ_INTERNAL_INSTANCE=`cd payg-deploy > /dev/null && ec2-host $(cd payg-deploy > /dev/null && fab group_list_all:production,biz_internal_api | grep production__biz_internal | tail -n 1 | cut -d " " -f 1)`'
# alias ensure_internal_biz_instance='export ZA_BIZ_INSTANCE=`ec2-host | grep production__biz- | sed "s/\(.*\)\s\+\(.*\)/\2/g"`'
#alias sshprod='ec2-ssh `fab group_list_all | grep production__biz | cut -d '"'"' '"'"' -f 1`'
alias sshprod='ec2-ssh `fab group_list_all:production | grep "^production__biz" | awk "{print $1}"`'
alias vssh='vagrant ssh'
alias celerydemo='celery purge -f && AWS_ACCESS_KEY_ID=`cat ~/Projects/Angaza/variables.deploy/AWS_ACCESS_KEY_ID` AWS_SECRET_ACCESS_KEY=`cat ~/Projects/Angaza/variables.deploy/AWS_SECRET_ACCESS_KEY` DATABASE_URI=postgres:///za_sandbox celery --app=za worker --loglevel=INFO --concurrency=1 -Q celery,batch 2>&1 | tee ~/celery.log'
alias celeryprodbeat='ZA_CELERY_BROKER_URL=amqp://guest@localhost:5672 DATABASE_URI=postgres:///za_prod_snapshot celery --app=za beat --loglevel=INFO'
alias zapsqlstaging='ensure_sandbox_staging && DATABASE_URI=$ZA_SANDBOX_STAGING_DATABASE_URI za-psql -u bill@angazadesign.com -p armynosegrandfather'
alias zapsqlprod='ensure_production && ZA_SQL_LOG_PATH="/tmp/za-psql-prod.log" DATABASE_URI=$ZA_PROD_DATABASE_URI za-psql -u bill@angazadesign.com -p armynosegrandfather'
# More expensive, but includes all variables
alias zapsqlprodallenv='envdir ~/Projects/Angaza/variables.aws/ summon -f ~/Projects/Angaza/payg-backend/za/secrets.yml -e production -D ENV=production za-psql -u bill@angazadesign.com'
alias zapsqlfollower='ensure_follower && ZA_SQL_LOG_PATH="/tmp/za-psql-follower.log" DATABASE_URI=$ZA_FOLLOWER_DATABASE_URL envdir ~/Projects/Angaza/variables.aws za-psql -u bill@angazadesign.com -p armynosegrandfather'
alias countries='python -c "from babel import Locale; l = Locale('"'"'en'"'"', '"'"'US'"'"'); print((u'"'"'\n'"'"'.join([u'"'"'{}:{}'"'"'.format(k, v) for (k, v) in l.territories.iteritems()])).encode('"'"'utf-8'"'"'))" | sort | less'
alias utcdate='date -u +%Y%m%dT%H%M%SZ'
alias utcclip='date -u +%Y%m%d | tr -d "\n" | xsel --clipboard'
alias isodate='date -u +%Y-%m-%dT%H:%M:%SZ'
alias justdate='date +%Y-%m-%d'
alias filenamedate='date +%Y-%m-%d_%H%M%SZ'
alias fabwheelupload='fab wheelhouse_upload:`ls -m ~/Projects/Angaza/payg-backend/*.whl | tr -d " " | tr -d "\n"`'
alias ec2host='envdir ~/Projects/Angaza/variables.aws ec2-host'
alias listgroups='cd ~/Projects/Angaza/payg-deploy && fab group_list_all:production'
alias demoserve='envdir ../variables.aws/ envdir ../variables.demo/ za-serve-gunicorn za.blueprints.admin:/raw za.blueprints.biz_api_internal:/api za.blueprints.biz_api_external:/data --workers 2'
alias zapsqldemo='ZA_CELERY_BROKER_URL=amqp://guest@localhost:5672 DATABASE_URI="postgres:///za_demo" envdir ../variables.aws/ za-psql -u system@angaza.com'
alias followerserve='ensure_follower && DATABASE_URI=$ZA_FOLLOWER_DATABASE_URL za-serve-gunicorn za.blueprints.biz_api_internal:/api --workers 2 --timeout 120'
alias grsdkclean='./gradlew terminalsdk:internal:models:clean terminalsdk:external:clean terminalsdk:internal:common:clean terminalsdk:core:clean terminalsdk:cots:clean terminalsdk:handoffclient:clean terminalsdk:default:clean terminalapp:application:clean'
# alias grsdkpublish='./gradlew terminalsdk:internal:models:publishToMavenLocal -PVERSION_NAME=SNAPSHOT && ./gradlew terminalsdk:external:publishToMavenLocal -PVERSION_NAME=SNAPSHOT && ./gradlew terminalsdk:internal:common:publishToMavenLocal -PVERSION_NAME=SNAPSHOT && ./gradlew terminalsdk:core:publishToMavenLocal -PVERSION_NAME=SNAPSHOT && ./gradlew terminalsdk:cots:publishToMavenLocal -PVERSION_NAME=SNAPSHOT && ./gradlew terminalsdk:handoffclient:publishToMavenLocal -PVERSION_NAME=SNAPSHOT && ./gradlew terminalsdk:default:publishToMavenLocal -PVERSION_NAME=SNAPSHOT'
alias grappbuild='./gradlew :terminalapp:application:assembleDebug'
# alias watchci='type watchci; ensure_sc2fa && watch -n 30 -e -c /Users/billfinn/dot-files/bin/pay_ci_passed.py $(git rev-parse HEAD)'
alias jirareportedbyme='ensure_sc2fa && jira list --query="reporter=currentUser() order by updated asc"'

alias jiramyopenreportedtickets='ensure_sc2fa && jira list --query="reporter=currentUser() AND resolution = Unresolved AND status != \"Won'\''t Fix\" ORDER BY updated ASC"'
alias jiramyopentickets='ensure_sc2fa && jira list --query="assignee=currentUser() AND resolution = Unresolved AND status != \"Won'\''t Fix\" ORDER BY updated ASC" --queryfields=status,updated,summary,customfield_10002,issuetype'
alias jiramyopenstaletickets='ensure_sc2fa && jira list --query="assignee=currentUser() AND updated <= -14d AND resolution = Unresolved AND status != \"Won'\''t Fix\" ORDER BY updated ASC" --queryfields=status,updated,summary,customfield_10002,issuetype'
alias grcc='type grcc; ./gradlew --configuration-cache'
alias grclean='type grclean; ./gradlew --no-build-cache --rerun-tasks'
alias cibuildall='pay ci:build --all'

cidownloadlogs()
{
  sc-curl "$1/plaintext_logs" > plaintext_logs.log
  echo "Logs stored at plaintext_logs.log"
}

gfb()
{
  git fetch origin "$1"
  git checkout "$1"
}

checkmerged()
{
  if [ "$#" -gt 0 ]; then
    PR_NUMBER=$1
  else
    PR_NUMBER=$(gh pr view --json number -q .number)
  fi
  ensure_sc2fa && watch -n 30 -e -c /Users/billfinn/dot-files/bin/pr_merged_passed.py $PR_NUMBER
}

watchci()
{
  #if [ "$#" -gt 0 ]; then
  #  REF=$1
  #else
  #  REF=$(git rev-parse HEAD)
  #fi
  #ensure_sc2fa && watch -n 30 -e -c /Users/billfinn/dot-files/bin/pay_ci_passed.py $REF
  #ensure_sc2fa && watch -n 30 -e -c /Users/billfinn/dot-files/bin/pay_ci_passed.py "$@"
  ensure_sc2fa && /Users/billfinn/dot-files/bin/pay_ci_passed.py "$@"
}
ensure_sc2fa()
{
  sc-2fa test
  if ! [[ $? -eq 0 ]]; then
    sc-2fa
  fi
  sc-2fa test
  if ! [[ $? -eq 0 ]]; then
    return 1
  fi
}

ktlintcheck()
{
  time (
    ./gradlew --configuration-cache --quiet ktlintCheck
  )
}

ktlintchanged()
{
  if [ "$#" -gt 0 ]; then
    BRANCH=$1
  else
    BRANCH=$(default_branch)
  fi

  CHANGED_FILES=`git --no-pager diff --name-only --diff-filter=d --no-color $BRANCH -- "*.kt" "*.kts"`
  echo -e "$CHANGED_FILES" | tr " " "\n"
  time (
    ./gradlew --configuration-cache --quiet ktlintFormat -PinternalKtlintGitFilter="$CHANGED_FILES"
  )
}
watchdb()
{
  watch $'psql -c "select pid,client_addr,client_port as port,substr(query_start::varchar, 1, 18),substr(query, 1, 50),substr(state, 1, 7),substr((now()-query_start)::varchar, 1, 8) as duration from pg_stat_activity where state != \'idle\' order by query_start;" '"$1"' '
}
watchprod()
{
  ensure_production
  watch $'psql -c "select pid,client_addr,client_port as port,substr(query_start::varchar, 1, 18),substr(query, 1, 50),substr(state, 1, 7),substr((now()-query_start)::varchar, 1, 8) as duration from pg_stat_activity where state != \'idle\' order by query_start;" $ZA_PROD_DATABASE_URI '
}
watchprodnarrow()
{
  ensure_production
  watch $'psql -c "select pid,client_addr,substr(query, 1, 50),substr((now()-query_start)::varchar, 1, 8) as duration from pg_stat_activity where state != \'idle\' order by query_start;" $ZA_PROD_DATABASE_URI '
}
stty -ixon
export VIRTUAL_ENV_DISABLE_PROMPT=1

celeryprod()
{
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    echo "rabbitmqadmin purge queue name=$1; celery purge -f && ZA_CELERY_BROKER_URL=amqp://guest@localhost:5672 DATABASE_URI=postgres:///za_prod_snapshot celery --app=za worker --hostname=$1 --loglevel=INFO --concurrency=1 --queues=$1 -Ofair 2>&1"
    rabbitmqadmin purge queue name=$1; celery purge -f && ZA_CELERY_BROKER_URL=amqp://guest@localhost:5672 DATABASE_URI=postgres:///za_prod_snapshot celery --app=za worker --hostname=$1 --loglevel=INFO --concurrency=1 --queues=$1
  fi
}

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
PATH="$PATH:~/dot-files/bin"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_BUILD_TOOLS_VERSION="$(ls $ANDROID_HOME/build-tools | tail -1)"
# Prepend a given dir to PATH if not yet in it
function pathadd() {
  if [ -d "$1" ] && [[ "$PATH" != *"$1"* ]]; then
    PATH="$1${PATH:+":$PATH"}"
    export PATH
  fi
}
pathadd $ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS_VERSION
pathadd $ANDROID_HOME/platform-tools
pathadd $ANDROID_HOME/tools
pathadd $ANDROID_HOME/tools/bin
pathadd $ANDROID_HOME/emulator
pathadd $ANDROID_HOME/cmdline-tools/latest/bin/
pathadd /Users/billfinn/stripe/android/dotnet/.dotnet
# shopt -s autocd
# export CDPATH=.:~:~/stripe

kill_gradle () {
  ./gradlew --stop
  jps | awk '/(GradleDaemon|KotlinCompileDaemon)/ { system("kill -9 "$1) }'
}

safekill()
{
  pgrep -a $1
  killall -i $1
}

gitpushtmp()
{
  if [ "$#" -gt 2 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  branchName=$(git rev-parse --abbrev-ref HEAD)
  if [[ $branchName =~ ^master$ ]] || [[ $branchName =~ ^main$ ]]; then
    echo "error: on master or main branch"
    return 1
  fi
  tmpBranchName=$(echo $branchName | sed 's/^/tmp-/')
  branchExists=$(git rev-parse --verify $tmpBranchName 2>/dev/null)
  if [[ -z $branchExists ]]; then
    echo "branch $tmpBranchName doesn't exist; creating"
    git branch $tmpBranchName
  fi

  if [ "$#" -gt 0 ]; then
    if [ "$#" -eq 2 ]; then
      # Ignore $1; we just use it as a flag to indicate "all"
      for hash in `git log --reverse --format='%H' $2^...HEAD`; do
        echo "force pushing $tmpBranchName to $hash"
        CMD="git push --no-verify -f -u origin $hash:$tmpBranchName"
      done
    else
      echo "force pushing $tmpBranchName to $1"
      CMD="git push --no-verify -f -u origin $1:$tmpBranchName"
    fi
  else
    echo "updating $tmpBranchName to $branchName"
    git branch -f $tmpBranchName $branchName
    echo "force pushing $tmpBranchName"
    if ! [[ $tmpBranchName =~ ^tmp.*$ ]]; then
      echo "error: tmp branch incorrectly formatted"
      return 1
    fi
    # Don't skip verify because we're at HEAD
    CMD="git push -u origin $tmpBranchName -f"
  fi
  echo $CMD
  $CMD || notify_failed
}
