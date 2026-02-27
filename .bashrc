# Don't merge
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

mov_to_webm_normal_speed() {
  ffmpeg -i "$1" -an -filter:v "scale=800:-1,pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libvpx-vp9 -crf 23 "$1.webm"
}

mov_to_webm_small() {
  ffmpeg -i "$1" -an -filter:v "scale=400:-1,pad=ceil(iw/2)*2:ceil(ih/2)*2,setpts=PTS/1.5" -c:v libvpx-vp9 -crf 23 "$1.webm"
}

mov_to_webm() {
  ffmpeg -nostats -i "$1" -an -filter:v "scale=800:-1,pad=ceil(iw/2)*2:ceil(ih/2)*2,setpts=PTS/1.5" -c:v libvpx-vp9 -crf 23 "$1.webm"
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
alias kmpcisend='./scripts/kmp/ci_send.sh'
alias scrcpyreader='scrcpy -s $(reader_device)'
alias scrcpys10='scrcpy -s $S10_ADB_DEVICE_ID'
alias scrcpypixel10='scrcpy -s $PIXEL_10_ADB_DEVICE_ID'

alias readerforceuninstall='export ANDROID_SERIAL=$(reader_device); python3 ./scripts/device-owner/force-uninstall.py'
alias readerbypassappinstallenabled='export ANDROID_SERIAL=$(reader_device); ./scripts/device-owner/reader-control.sh bypassAppInstall true && echo success'
alias readerbypassappinstalldisabled='export ANDROID_SERIAL=$(reader_device); ./scripts/device-owner/reader-control.sh bypassAppInstall false && echo success'
alias readersetupdatesdisabled='export ANDROID_SERIAL=$(reader_device); ./scripts/device-owner/reader-control-check.sh setUpdatesEnabled false && echo SUCCESS'
alias readersetupdatesenabled='export ANDROID_SERIAL=$(reader_device); ./scripts/device-owner/reader-control-check.sh setUpdatesEnabled true && echo SUCCESS'


create_devbox() {
    local branch_suffix=''
    local repo='pay-server'  # Default value
    local prompt=''

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch-suffix)
                branch_suffix="$2"
                shift 2
                ;;
            --repo)
                repo="$2"
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
        echo "Error: branch-suffix and prompt are required."
        return 1
    fi

    if [[ -n "$prompt" ]]; then
      prompt_cli="--prompt \"$prompt\""
    else
      prompt_cli=''
    fi

    # Set up variables
    local DATE=$(date +%Y%m%d)
    local branch="$USER/$DATE-$branch_suffix"
    local devboxname="$USER-$DATE-$branch_suffix"

    # Construct the command as an array to preserve argument boundaries
    local cmd=(pay remote new "$devboxname" --repo "$repo:$branch" --no-open-code --notify-on-ready --skip-confirm)

    if [[ -n "$prompt" ]]; then
      cmd+=(--prompt "$prompt")
    fi

    echo "${cmd[@]}"
    "${cmd[@]}"
    # # Construct and execute command
    # cmd="pay remote new $devboxname --repo $repo:$branch --no-open-code --notify-on-ready --skip-confirm $prompt_cli"
    # echo $cmd
    # $cmd
}

# Completion function for create_devbox
_create_devbox_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--branch-suffix --repo --prompt"

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
        --branch-suffix|--repo|--prompt)
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

alias adbreader='adb -s $(reader_device)'

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

setreaders710() {
  export PREFERRED_READER="f4c941aa"
  _current_reader=$(reader_device)
  export ANDROID_SERIAL=$_current_reader
}

setreaders700() {
  export PREFERRED_READER="4f64d47b"
  _current_reader=$(reader_device)
  export ANDROID_SERIAL=$_current_reader
}

setreaders700devkit() {
  export PREFERRED_READER="1234567"
  _current_reader=$(reader_device)
  export ANDROID_SERIAL=$_current_reader
}

setreaderwpe() {
  export PREFERRED_READER="f85e6a55"
  _current_reader=$(reader_device)
  export ANDROID_SERIAL=$_current_reader
}

setreaderv660pA13() {
  export PREFERRED_READER="713-363-464"
  _current_reader=$(reader_device)
  export ANDROID_SERIAL=$_current_reader
}

setreaderv660pA10() {
  export PREFERRED_READER="452-406-077"
  _current_reader=$(reader_device)
  export ANDROID_SERIAL=$_current_reader
}

whichreader() {
  current_reader_device=$(reader_device)
  s710_string="f4c941aa"
  s700_string="4f64d47b"
  wpe_string="f85e6a55"
  if [ "$current_reader_device" = "$s700_string" ]; then
    echo "S700: $s700_string"
  elif [ "$current_reader_device" = "$wpe_string" ]; then
    echo "WPE: $wpe_string"
  elif [ "$current_reader_device" = "$s710_string" ]; then
    echo "S710: $s710_string"
  else
    echo "$current_reader_device"
  fi
}

reader_device() {
  if [ -n "${PREFERRED_READER}" ]; then
      echo "${PREFERRED_READER}"
      return 0
  fi
  s710_string="f4c941aa"
  s700_string="4f64d47b"
  wpe_string="f85e6a55"
  verifone_string="452-406-077"
  adb_devices=$(adb devices | grep -v 'List of devices attached')
  if [[ $adb_devices == *"$s700_string"* ]]; then
    s700=true
  else
    s700=false
  fi
  if [[ $adb_devices == *"$wpe_string"* ]]; then
    wpe=true
  else
    wpe=false
  fi
  if [[ $adb_devices == *"$verifone_string"* ]]; then
    verifone=true
  else
    verifone=false
  fi
  if [[ $adb_devices == *"$s710_string"* ]]; then
    s710=true
  else
    s710=false
  fi

  readers_found=0
  [ "$s700" = "true" ] && ((readers_found++))
  [ "$wpe" = "true" ] && ((readers_found++))
  [ "$verifone" = "true" ] && ((readers_found++))
  [ "$s710" = "true" ] && ((readers_found++))

  if [ $readers_found -gt 1 ]; then
    echo "multiple_readers_found"
  elif [ $readers_found -eq 0 ]; then
    echo "no_readers_found"
  elif [ "$s700" = "true" ]; then
    echo $s700_string
  elif [ "$wpe" = "true" ]; then
    echo $wpe_string
  elif [ "$s710" = "true" ]; then
    echo $s710_string
  else
    echo $verifone_string
  fi
}
# reader_device() {
#   if [ -n "${PREFERRED_READER}" ]; then
#       echo "${PREFERRED_READER}"
#       return 0
#   fi
#   s700_string="4f64d47b"
#   wpe_string="f85e6a55"
#   adb_devices=$(adb devices | grep -v 'List of devices attached')
#   if [[ $adb_devices == *"$s700_string"* ]]; then
#     s700=true
#   else
#     s700=false
#   fi
#   if [[ $adb_devices == *"$wpe_string"* ]]; then
#     wpe=true
#   else
#     wpe=false
#   fi
#   if [ "$s700" = "true" ] && [ "$wpe" = "true" ]; then
#     echo "two_readers_found"
#   elif [ "$s700" = "false" ] && [ "$wpe" = "false" ]; then
#     echo "no_readers_found"
#   elif [ "$s700" = "true" ]; then
#     echo $s700_string;
#   else
#     echo $wpe_string;
#   fi
# }

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

alias adblogcatclear='adbreader logcat -c'
adblogcattransaction() {
  READER_PID=$(_adbreaderpid)
  UPDATER_PID=$(_adbupdaterpid)
  type adblogcattransaction
  # adbreader shell "logcat | grep --line-buffered -E ' $READER_PID|$UPDATER_PID ' | grep --line-buffered -E 'BbposControllerListener|CancelHandler|HardwareService|BbposDeviceControllerImpl|PaymentCollectionCoordinator|PaymentCollectionStateMachine|BbposPaymentCollectionListener|FormNavigationFragment|BbposPaymentCollector|EndPreviousTransactionPrerequisiteFactory|PollingCommandLogger' | grep --line-buffered -E -v 'PaymentCollectionData\('" | sed -u "s/ $READER_PID / com.stripe.reader /; s/ $UPDATER_PID / com.stripe.updater /" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"
  adbreader shell "logcat | grep --line-buffered -E ' $READER_PID|$UPDATER_PID ' | grep --line-buffered -E 'class=|asdf' | grep --line-buffered -E 'CollectReusableCardOp|CollectPaymentMethodOp|ResumeCollectPaymentMethodOp|SetReaderDisplayOp|TransactionCoordinator|TransactionViewModel.*onTransactionStateSummaryUpdate|DefaultScreenDurationLogger|BbposControllerListener|HardwareService.*BbposSdkService|BbposDeviceControllerImpl|PaymentCollectionCoordinator|PaymentCollectionStateMachine|BbposPaymentCollectionListener|FormNavigationFragment|BbposPaymentCollector|EndPreviousTransactionPrerequisiteFactory|PollingCommandLogger|SetReaderDisplayComponentHealthLogger|asdf'" | sed -u "s/ $READER_PID / com.stripe.reader /; s/ $UPDATER_PID / com.stripe.updater /" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"
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

  declare -a pids=()
  declare -a labels=()

  [[ -n $READER_PID ]]     && { pids+=("$READER_PID");     labels+=("<reader PID>"); }
  [[ -n $UPDATER_PID ]]    && { pids+=("$UPDATER_PID");    labels+=("<updater PID>"); }
  [[ -n $STANDALONE_PID ]] && { pids+=("$STANDALONE_PID"); labels+=("<standalone PID>"); }
  [[ -n $TEST_APP_PID ]]   && { pids+=("$TEST_APP_PID");   labels+=("<test-app PID>"); }

  if [[ ${#pids[@]} -eq 0 ]]; then
    echo "No PIDs found." >&2
    return 1
  fi

  # Build grep alternation (no escaping)
  GREP_ALT=""
  for pid in "${pids[@]}"; do
    if [[ -z $GREP_ALT ]]; then
      GREP_ALT=$pid
    else
      GREP_ALT="$GREP_ALT|$pid"
    fi
  done

  # Build sed script to replace each PID when matched as a whole token.
  SED_SCRIPT=""
  for i in "${!pids[@]}"; do
    pid=${pids[i]}
    label=${labels[i]}
    # No escaping of pid or label (assumed safe)
    SED_SCRIPT="$SED_SCRIPT;s/ $pid / $label /g"
  done
  SED_SCRIPT=${SED_SCRIPT#;}

  TIMESTAMP=$(date -u +"%Y_%m_%dT%H_%M_%SZ")
  adb shell "logcat" \
    | grep --line-buffered -E "($GREP_ALT)" \
    | gsed --unbuffered -E "$SED_SCRIPT" \
    | tee "logcat_${TIMESTAMP}.txt"
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
  adbreader shell "logcat | grep --line-buffered -E '$GREP_PATTERN' | grep --line-buffered -v ' V QueueFileCollector: ' | grep --line-buffered -v ' D DebugLoggingHttpInterceptor: ' | grep --line-buffered -v ' V BatchDispatcher: ' | grep --line-buffered -v ' I DebugConfigCerthorse: '" | sed -u "s/ $READER_PID / reader     /; s/ $UPDATER_PID / updater    /; $( [[ -n $STANDALONE_PID ]] && echo "s/ $STANDALONE_PID / standalone /" )" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"

  #adbreader shell "logcat | grep --line-buffered -E ' $READER_PID|$UPDATER_PID|$STANDALONE_PID ' | grep --line-buffered -v ' V QueueFileCollector: ' | grep --line-buffered -v ' D DebugLoggingHttpInterceptor: ' | grep --line-buffered -v ' V BatchDispatcher: ' | grep --line-buffered -v ' I DebugConfigCerthorse: '" | sed -u "s/ $READER_PID / reader     /; s/ $UPDATER_PID / updater    /; s/ $STANDALONE_PID / standalone /" | tee "logcat_$(date -u +"%Y-%m-%dT%H:%M:%SZ").txt"
}

taillatestlogcat() {
  latest_logcat=$(ls -1 logcat_* | tail -n 1)
  tail -f $latest_logcat
}
lesslatestlogcat() {
  latest_logcat=$(ls -1 logcat_* | tail -n 1)
  less $latest_logcat
  # if [ -n "$1" ]; then
  #   stdbuf -oL tail -f "$latest_logcat" | grep --line-buffered "$1" | less +F -X
  #   #grep --line-buffered "$1" "$latest_logcat" | less -K -R +F
  # else
  #   stdbuf -oL tail -f "$latest_logcat" | less +F -X
  #   #less -K -R +F "$latest_logcat"
  # fi
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
  git diff "$baseBranch"...HEAD
}

gfbandopenpr() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  gfb "$1"
  # shellcheck disable=SC2119
  openpr
}

ghprcreate() {
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

  hostname=$(git remote get-url origin | sed -e 's/^.*@//' -e 's/:.*//' -e 's/^https:\/\///')
  GH_HOST="$hostname" gh pr create --body-file "$filename" --title "$title" -B "$baseBranch"
}

openpr() {
  if [ "$#" -gt 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  if [ "$#" -gt 0 ]; then
    baseBranch=$1
  else
    baseBranch=$(default_branch)
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

  # Push branch, if required
  diffUpstream=$(git diff --quiet @{u}..HEAD)
  diffExitCode=$?
  if ! [[ $diffExitCode -eq 0 ]]; then
    git push --no-verify -u origin HEAD
    if ! [[ $? -eq 0 ]]; then
      cat "$tmpFile"
      return 1
    fi
  fi

  $sed_cmd -i "/$delimiter/Q" "$tmpFile"
  # Remove last blank line
  $sed_cmd -i '${/^$/d};' "$tmpFile"

  ghprcreate $tmpFile $baseBranch
}

disableautomerge()
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
automerge()
{
  branchName=$(git rev-parse --abbrev-ref HEAD)
  remoteUrl=$(git config --get remote.origin.url)
  # e.g., git@git.corp.stripe.com:stripe-internal/android.git
  orgAndRepo=$(echo "$remoteUrl" | cut -d':' -f 2 | cut -d'.' -f 1)
  url="cibot.corp.stripe.com/api/git.corp.stripe.com/$orgAndRepo/branches/$branchName/auto_merge"
  echo $url
  sc-curl -d '{"auto_merge":true, "auto_merge_working_hours":true}' -H "Content-Type: application/json" -H "X-Requested-With: curl" -X POST "$url"
  echo
}

alias ghcreateissue='gh issue create --web'
alias viewpr='gh pr view --web'
alias mergepr='gh pr merge -m -d'
alias ghimageupload='gh pr view 19498 --web'

alias ghassignbricandjil='gh pr edit --add-assignee bric-stripe,jil-stripe'

gcob()
{
  echo "deprecated; use b"
  git checkout -b $USER/$1
}

b()
{
  git checkout -b $USER/$1
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
alias wpc='work pr create --with-edit'
alias wr='work review $(cat ~/dot-files/.stripe-android-usernames.txt | fzf)'

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

curlaccountget() {
  curl_output=$(curl -s "https://api.stripe.com/v1/account" -u "$SECRET_KEY":)
  echo "$curl_output"
  echo "$curl_output" | jq .id
}
alias stripelistenwebhooks='stripe listen --forward-to localhost:8000/webhook'
alias curllocationslist='type curllocationslist; curl -s "https://api.stripe.com/v1/terminal/locations" -u "$SECRET_KEY": | jq -r -c '"'"'.data[] | [.display_name, .id]'"'"''
alias curllocationslisttest='type curllocationslisttest; curl -s "https://api.stripe.com/v1/terminal/locations" -u "$SECRET_KEY": | jq -r -c '"'"'.data[] | select((.display_name | contains("test")) or (.display_name | contains("Home"))) | [.display_name, .id]'"'"''

curlwebhooklist() {
  curl -s -H "Stripe-Version: 2025-05-28.basil;" "https://api.stripe.com/v1/webhook_endpoints" -u "$SECRET_KEY":
}

curlwebhookdelete() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl -s -H "Stripe-Version: 2025-05-28.basil;" -X DELETE "https://api.stripe.com/v1/webhook_endpoints/$1" -u "$SECRET_KEY":
}

curlwebhookcreate() {
  type curlwebhookcreate
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl -s -H "Stripe-Version: 2025-05-28.basil;" "https://api.stripe.com/v1/webhook_endpoints" -u "$SECRET_KEY": -d "enabled_events[]"="terminal.reader.action_succeeded" -d "enabled_events[]"="terminal.reader.action_failed" --data-urlencode "api_version"="2025-05-28.basil;" --data-urlencode url="$1")
  echo "$curl_output"
}

curlfileget() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl -s "https://api.stripe.com/v1/files/$1" -u "$SECRET_KEY":)
  echo "$curl_output"
  CONTENT_URL=$(echo "$curl_output" | jq -r -c .url)
  curl_output=$(curl -s "$CONTENT_URL" -u "$SECRET_KEY":)
  echo "$curl_output" | tee file.svg
}

curllocationsget() {
  curl -s "https://api.stripe.com/v1/terminal/locations/$LOCATION_ID" -u "$SECRET_KEY":
}

curllocationssetconfigoverride() {
  curl -s "https://api.stripe.com/v1/terminal/locations/$LOCATION_ID" -u "$SECRET_KEY": -d configuration_overrides="$1"
}

curlreadercreatesimulated() {
  output=$(curl -s "https://api.stripe.com/v1/terminal/readers" -u "$SECRET_KEY": -d "location=$LOCATION_ID" -d registration_code=simulated-wpe)
  echo "$output"
  READER_ID=$(echo "$output" | jq -r -c .id)
  export READER_ID
}

curlreaderdelete() {
  curl -s -X DELETE "https://api.stripe.com/v1/terminal/readers/$1" -u "$SECRET_KEY":
}

curlreadergetwithconnectiontoken() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  CONNECTION_TOKEN=$(curl -s -X POST https://api.stripe.com/v1/terminal/connection_tokens -u "$SECRET_KEY": | jq .secret | sed -e 's/"//g')
  curl "https://api.stripe.com/v1/terminal/readers?serial_number=$1" -u $CONNECTION_TOKEN:
}

curlreaderlist() {
  if [ "$#" -eq 1 ]; then
    output=$(curl -H "Stripe-Version: 2025-05-28.basil;" -s "https://api.stripe.com/v1/terminal/readers?serial_number=$1" -u "$SECRET_KEY":)
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
    curl -H "Stripe-Version: 2025-05-28.basil;" -s "https://api.stripe.com/v1/terminal/readers?limit=100" -u "$SECRET_KEY":
  fi
}

curlreaderget() {
  curl -H "Stripe-Version: 2025-05-28.basil;" -s "https://api.stripe.com/v1/terminal/readers/$READER_ID" -u "$SECRET_KEY":
}

curlreaderregister() {
  type curlreaderregister
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    output=$(curl -s https://api.stripe.com/v1/terminal/readers -u "$SECRET_KEY:" -d location="$LOCATION_ID" -d registration_code="$1" -d label='billfinn')
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
  fi
}

curllocationscreate() {
  curl_output=$(curl -s https://api.stripe.com/v1/terminal/locations -u "$SECRET_KEY": -d display_name="$(date +%Y%m%d) test location" -d "address[line1]"="354 Oyster Point Blvd" -d "address[city]"="South San Francisco" -d "address[state]"="CA" -d "address[country]"="US" -d "address[postal_code]"="94080")
  echo "$curl_output"
  LOCATION_ID=$(echo "$curl_output" | jq -r -c .id)
  export LOCATION_ID
  echo "Setting location ID: $LOCATION_ID"
}
curllocationsdelete() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
  else
    curl -s -X DELETE "https://api.stripe.com/v1/terminal/locations/$1" -u "$SECRET_KEY":
  fi
}

alias curllocationsclearconfigoverride='curl -s https://api.stripe.com/v1/terminal/locations/$LOCATION_ID -u "$SECRET_KEY": -d configuration_overrides='
alias curlconfigurationslist='curl -s "https://api.stripe.com/v1/terminal/configurations" -u "$SECRET_KEY":'
alias curlconfigurationsget='curl -s "https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID" -u "$SECRET_KEY":'
alias curlconfigurationsgetdefault='curl -s "https://api.stripe.com/v1/terminal/configurations?is_account_default=true" -u "$SECRET_KEY":'
alias curlconfigurationscreate='curl -s -X POST "https://api.stripe.com/v1/terminal/configurations" -u "$SECRET_KEY":'
alias curlconfigurationsofflineenable='curl -s https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "offline[enabled]"=true'
alias curlconfigurationsofflinedisable='curl -s https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "offline[enabled]"=false'
alias curlconfigurationstippingclear='curl -s https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "tipping"='
alias curlconfigurationstippingset='curl -s https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "tipping[usd][fixed_amounts][]"=100   -d "tipping[usd][fixed_amounts][]"=200   -d "tipping[usd][fixed_amounts][]"=300'
alias curlconfigurationstippingsetsmart='curl -s https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "tipping[usd][percentages][]"=15   -d "tipping[usd][percentages][]"=20   -d "tipping[usd][percentages][]"=25   -d "tipping[usd][fixed_amounts][]"=100   -d "tipping[usd][fixed_amounts][]"=200   -d "tipping[usd][fixed_amounts][]"=300   -d "tipping[usd][smart_tip_threshold]"=1000 -d "tipping[gbp][percentages][]"=15   -d "tipping[gbp][percentages][]"=20   -d "tipping[gbp][percentages][]"=25   -d "tipping[gbp][fixed_amounts][]"=100   -d "tipping[gbp][fixed_amounts][]"=200   -d "tipping[gbp][fixed_amounts][]"=300   -d "tipping[gbp][smart_tip_threshold]"=1000'
alias curlconfigurationsstandaloneenable='curl -s https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "standalone[enabled]"=true -d "standalone[payment_settings][currency]"=usd -d "standalone[payment_settings][payment_method_types][0]"=card_present'
alias curlconfigurationsstandalonedisable='curl -s https://api.stripe.com/v1/terminal/configurations/$CONFIGURATION_ID -u "$SECRET_KEY": -d "standalone[enabled]"=false'
alias curlpaymentintentlist='curl -s https://api.stripe.com/v1/payment_intents -u "$SECRET_KEY":'
alias curlpaymentintentlistrecent='curl -s -X GET https://api.stripe.com/v1/payment_intents -u "$SECRET_KEY": -d created[gt]=$(date -v-15M +%s)'
alias curlpaymentintentcancel='curl -s -X POST https://api.stripe.com/v1/payment_intents/$PAYMENT_INTENT_ID/cancel -u "$SECRET_KEY":'
alias curlrefundcreate='curl -s https://api.stripe.com/v1/refunds -u "$SECRET_KEY": -d payment_intent=$PAYMENT_INTENT_ID'

waitforactionsucceeded() {
  while true; do
    sleep 0.5
    collect_inputs_output=$(curl -s "https://api.stripe.com/v1/terminal/readers/$READER_ID" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;")
    status=$(echo "$collect_inputs_output" | jq -r .action.status)
    if [ "$status" = "succeeded" ]; then
      break
    fi
  done
}

# Make this a function, so it's easier to use within bash scripts
curlreadercancelaction() {
  curl -s -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/cancel_action" -u "$SECRET_KEY":
}

curlreadercollectinputstimeout() {
  type curlreadercollectinputstimeout
  curl -X POST "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/timeout_input_collection" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;"
}

curlreadercollectinputssucceed() {
  type curlreadercollectinputssucceed
  curl -X POST "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/succeed_input_collection" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;"
}

curlreadercollectinputssucceedskip() {
  type curlreadercollectinputssucceed
  curl -X POST "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/succeed_input_collection" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "skip_non_required_inputs"="all"
}

# Make this a function, so it's easier to use within bash scripts
curlreadercollectinputs() {
  title="Receipt"
  if [ "$#" -eq 1 ]; then
    title="$1"
  fi
  type curlreadercollectinputs
  curl -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=selection -d "inputs[0][selection][choices][0][style]"=primary -d "inputs[0][selection][choices][0][text]"=Email -d "inputs[0][selection][choices][0][id]"=email_id -d "inputs[0][selection][choices][1][style]"=primary -d "inputs[0][selection][choices][1][text]"=Printed -d "inputs[0][selection][choices][1][id]"=printed_id -d "inputs[0][selection][choices][2][style]"=secondary -d "inputs[0][selection][choices][2][text]"="No thanks" -d "inputs[0][selection][choices][2][id]"="no_thanks_id" -d "inputs[0][custom_text][title]"="$title" -d "inputs[0][custom_text][description]"="How would you like your receipt?" -d "inputs[0][required]"=true -d "metadata[order_number]"=12345
}

curlreadercollectinputsx2() {
  type curlreadercollectinputsx2
  curl -X POST -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" \
    -u "$SECRET_KEY:" \
    -H "Stripe-Version: 2025-05-28.basil;" \
    -d "inputs[0][type]"=text \
    -d "inputs[0[custom_text][title]"="Title 1" \
    -d "inputs[1][type]"=text \
    -d "inputs[1[custom_text][title]"="Title 2"
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
  curl -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=signature -d "inputs[0][custom_text][title]"="Please sign" -d "inputs[0][custom_text][description]"="Please sign if you agree to the terms and conditions."
}

curlreadercollectinputstext() {
  type curlreadercollectinputstext
  curl -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=text -d "inputs[0][custom_text][title]"="Enter your name" -d "inputs[0][custom_text][description]"="We'll need your name to look up your account."
}

curlreadercollectinputsnumeric() {
  type curlreadercollectinputsnumeric
  curl -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=numeric -d "inputs[0][custom_text][title]"="Enter your zip code"
}

curlreadercollectinputsemail() {
  type curlreadercollectinputsemail
  curl -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=email -d "inputs[0][custom_text][title]"="Enter your email address" -d "inputs[0][custom_text][description]"="We'll send updates to your order and occasional deals."
}

curlreadercollectinputsphone() {
  type curlreadercollectinputsphone
  curl -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_inputs" -u "$SECRET_KEY": -H "Stripe-Version: 2025-05-28.basil;" -d "inputs[0][type]"=phone -d "inputs[0][custom_text][title]"="Enter your phone number" -d "inputs[0][custom_text][description]"="We'll text you when your order is ready."
}

curlpaymentintentget() {
  curl_output=$(curl -X GET -s "https://api.stripe.com/v1/payment_intents/$PAYMENT_INTENT_ID" -u "$SECRET_KEY:")
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
  curl_output=$(curl -X POST -s "https://api.stripe.com/v1/payment_intents/$pi_id/capture" -u "$SECRET_KEY:"  ${extra_args:+"$extra_args"})
  echo "$curl_output"
}

curlpaymentintentcreate() {
  currency="usd"
  amount="5200"
  extra_args=""
  if [ "$#" -eq 3 ]; then
    amount="$1"
    currency="$2"
    extra_args="$3"
  fi
  if [ "$#" -eq 2 ]; then
    amount="$1"
    currency="$2"
  fi
  if [ "$#" -eq 1 ]; then
    amount="$1"
  fi
  echo "before"
  pi_output=$(curl -s https://api.stripe.com/v1/payment_intents -u "$SECRET_KEY:" -d amount="$amount" -d currency="$currency" -d "payment_method_types[]"=card_present -d capture_method=manual ${extra_args:+"$extra_args"})
  echo "$pi_output"
  PAYMENT_INTENT_ID=$(echo "$pi_output" | jq -r -c .id)
  export PAYMENT_INTENT_ID
}

curlreadercollectwithsurchargenotice() {
  if [ "$#" -eq 1 ]; then
    PI_ID="$1"
  else
    curlpaymentintentcreate
    PI_ID="$PAYMENT_INTENT_ID"
  fi
  echo "$PI_ID"
  curl_output=$(curl -H "Stripe-Version: 2024-12-18.acacia;" -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_payment_method" -u "$SECRET_KEY:" -d payment_intent="$PI_ID" --data-urlencode "collect_config[surcharge_notice]"="\$22.66 amount above incl. \$0.66 credit card surcharge. Debit cards pay a total of \$22.00")
  echo "$curl_output"
}

curlreadercollect() {
  if [ "$#" -eq 1 ]; then
    PI_ID="$1"
  else
    curlpaymentintentcreate
    PI_ID="$PAYMENT_INTENT_ID"
  fi
  echo "$PI_ID"
  curl_output=$(curl -H "Stripe-Version: 2024-12-18.acacia;" -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/collect_payment_method" -u "$SECRET_KEY:" -d payment_intent="$PI_ID")
  echo "$curl_output"
}

curlreaderconfirm() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/confirm_payment_intent" -u "$SECRET_KEY:" -d payment_intent="$1")
  echo "$curl_output"
}

curlreaderconfirmwithsurcharge() {
  if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    return 1
  fi
  curl_output=$(curl -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/confirm_payment_intent" -u "$SECRET_KEY:" -d payment_intent="$1" -d "confirm_config[amount_surcharge]"=21)
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

  curl_output=$(curl -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/process_payment_intent" \
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
  curl_output=$(curl -X POST -s "https://api.stripe.com/v1/test_helpers/terminal/readers/$READER_ID/present_payment_method" -u "$SECRET_KEY: $ARGS")
  echo "$curl_output"
}

curlreadersimplepaymentmoto() {
  curlpaymentintentcreate 5200 usd '-d  payment_method_types[]=card'
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
  curl -X POST "https://api.stripe.com/v1/terminal/readers/$READER_ID/set_reader_display" -u "$SECRET_KEY": -d type=cart  -d "cart[line_items][0][description]"="Caramel latte"  -d "cart[line_items][0][amount]"=600  -d "cart[line_items][0][quantity]"=1  -d "cart[line_items][1][description]"="Discount"  -d "cart[line_items][1][amount]"=-100  -d "cart[line_items][1][quantity]"=1  -d "cart[currency]"="$currency"  -d "cart[tax]"=100  -d "cart[total]"=600
}

curlreadersetupintent() {
  si_output=$(curl -s https://api.stripe.com/v1/setup_intents -u "$SECRET_KEY:" -d "payment_method_types[]"=card_present)
  echo "$si_output"
  SIMPLE_SI_ID=$(echo "$si_output" | jq -r -c .id)
  export SIMPLE_SI_ID
  process_output=$(curl -s "https://api.stripe.com/v1/terminal/readers/$READER_ID/process_setup_intent" -u "$SECRET_KEY:" -d setup_intent="$SIMPLE_SI_ID" -d customer_consent_collected=true)
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
export PIXEL_10_ADB_DEVICE_ID="57260DLCR000FJ"

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
alias adbpixel10='adb -s $PIXEL_10_ADB_DEVICE_ID'

alias adbreinstallapp='type adbreinstallapp; adbinstallhandoff && adb shell am start -n com.stripe.terminal.testapp/.MainActivity'
# alias adbbuildapp='type adbbuildapp; ./gradlew :terminalapp:application:assembleDebug && adbreinstallapp'


alias readerreinstalllatest='type readerreinstalllatest; APK_ROOT_DIR=$(find /Users/billfinn/stripe/reader-apks/ -maxdepth 1 -type d | grep "2\.[0-9][0-9]" | sort | tail -n 1); echo $APK_ROOT_DIR; adbreader install -t $APK_ROOT_DIR/com.stripe.updater-bbpos-debug.apk && adbreader install -t $APK_ROOT_DIR/com.stripe.reader-bbpos-debug.apk'
alias readerreinstallapp='type readerreinstallapp; adbreader install -t ./terminalapp/application/build/outputs/apk/debug/application-debug.apk && adbreader shell am start -n com.stripe.terminal.testapp/.MainActivity; saydone installing_app'
alias readerreinstallreader='type readerreinstallreader; adbreader install ./reader/application/build/outputs/apk/bbpos/debug/com.stripe.reader-bbpos-debug.apk; saydone installing_reader'
alias readerreinstallupdater='type readerreinstallupdater; adbreader install ./updater/application/build/outputs/apk/bbpos/debug/com.stripe.updater-bbpos-debug.apk; saydone installing_updater'
alias readerreinstallupdaterandreader='readerreinstallupdater && readerreinstallreader'

alias readerreinstallverifonereader='type readerreinstallverifonereader; adbreader install ./reader/application/build/outputs/apk/verifone/debug/com.stripe.reader-verifone-debug.apk; saydone installing_verifone_reader'
alias readerreinstallverifoneupdater='type readerreinstallverifoneupdater; adbreader install ./updater/application/build/outputs/apk/verifone/debug/com.stripe.updater-verifone-debug.apk; saydone installing_verifone_updater'
alias readerreinstallverifoneupdaterandreader='readerreinstallverifoneupdater && readerreinstallverifonereader'

alias standaloneassemble='type standaloneassemble; ./gradlew --configuration-cache :standalonepos:application:assembleDebug ; saydone'
alias standaloneinstallDebug='type standaloneinstallDebug; ./gradlew --configuration-cache :standalonepos:application:installDebug ; saydone'
alias standalonereinstall='type standalonereinstall; adbreader install ./standalonepos/application/build/outputs/apk/debug/application-debug.apk; saydone'

alias readerbuildapp='type readerbuildapp; ./gradlew --configuration-cache :terminalapp:application:installHandoff; adbreader shell am start -n com.stripe.terminal.testapp/.MainActivity; saydone installing app'
alias readerstartupdater='type readerstartupdater; adbreader shell am start -n com.stripe.updater/.MainActivity'

alias readerbuildupdater='type readerbuildupdater; readerassembledebugupdater && readerreinstallupdater; saydone building_updater'
alias readerbuildreader='type readerbuildreader; readerassembledebugreader && readerreinstallreader; saydone building_reader'
alias readerbuildupdaterandreader='type readerbuildupdaterandreader; readerbuildupdater && readerbuildreader'

alias readerbuildupdaterandreaderrelease='type readerbuildupdaterandreaderrelease; ./gradlew :updater:application:assembleRelease && apksigner sign --ks $HOME/stripe/android/debug.keystore --ks-pass pass:android ./updater/application/build/outputs/apk/bbpos/release/com.stripe.updater-bbpos-release-unsigned.apk && adbreader install ./updater/application/build/outputs/apk/bbpos/release/com.stripe.updater-bbpos-release-unsigned.apk ; saydone building_updater && ./gradlew :reader:application:assembleRelease && apksigner sign --ks $HOME/stripe/android/debug.keystore --ks-pass pass:android ./reader/application/build/outputs/apk/bbpos/release/com.stripe.reader-bbpos-release-unsigned.apk && adbreader install ./reader/application/build/outputs/apk/bbpos/release/com.stripe.reader-bbpos-release-unsigned.apk; saydone building_reader'

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
alias d='git diff'
alias glm='git log -p $(default_branch)..HEAD'
alias glbf='git log -p --author=billfinn'
alias glp='git log -p --follow'
# alias gg='git grep --break --heading --line-number'
alias gg='git grep --line-number'
alias gpush='git push -u origin HEAD'
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
