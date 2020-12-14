#!/usr/bin/env bash
# requirements: xdotool

# Interface interaction cofiguration values
EQUIP_RING_ROH_KEY='n'
EQUIP_RING_LR_KEY='u'
EAT_FOOD_KEY='h'
DRINK_POTION_KEY='m'
CAST_RUNE_SPELL_KEY='y'
EQUIP_SOFT_BOOTS_KEY='j'
MANA_POTION_CENTER_X=1707
MANA_POTION_CENTER_Y=292
CHAR_CENTER_X=958
CHAR_CENTER_Y=372
SCREEN_NO=0
REGEN_RING_CENTER_X=1772
REGEN_RING_CENTER_Y=498
RING_SLOT_CENTER_X=1768
RING_SLOT_CENTER_Y=336



function debug() {
  [[ "${DEBUG}" ]] && echo "$@" >&2
}

function random() {
  local min=$1
  local max=$2
  local delta=$((max - min))
  echo $((min + (RANDOM % (delta + 1))))
}

# Playable area set at Y: 696 with 2 cols on left and 2 cols on right
# To get the realtime mouse location use:
#   watch -t -n 0.0001 xdotool getmouselocation
function click_mana_potion() {
  local tibia_wid=$1
  local minX=$((MANA_POTION_CENTER_X-12))
  local maxX=$((MANA_POTION_CENTER_X+12))
  # with full depot box
  local minY=$((MANA_POTION_CENTER_Y-12))
  local maxY=$((MANA_POTION_CENTER_Y+12))
  # with 1500 manas
  #local minY=169
  #local maxY=195
  local X=$(random ${minX} ${maxX})
  local Y=$(random ${minY} ${maxY})

  local wait_time="0.$(random 250 390)s"
  echo "Pausing ${wait_time}" &
  sleep ${wait_time}

  echo "Clicking mana potion (${X},${Y})" &
  xdotool mousemove --screen "${SCREEN_NO}" "${X}" "${Y}"
  xdotool click --window ${tibia_wid} --delay $(random 125 250) 1
}

function click_char() {
  local tibia_wid=$1
  local minY=$((CHAR_CENTER_Y-12))
  local maxY=$((CHAR_CENTER_Y+12))
  local minX=$((CHAR_CENTER_X-12))
  local maxX=$((CHAR_CENTER_X+12))
  local X=$(random ${minX} ${maxX})
  local Y=$(random ${minY} ${maxY})

  local wait_time="0.$(random 250 390)s"
  echo "Pausing ${wait_time}" &
  sleep ${wait_time}

  echo "Clicking char (${X},${Y})" &
  xdotool mousemove --screen "${SCREEN_NO}" --window "${tibia_wid}" "${X}" "${Y}"
  xdotool click --window "${tibia_wid}" --delay "$(random 125 250)" 1
}

function send_keystroke() {
  local tibia_wid="$1"
  local keystroke="$2"
  local min="$3"
  [[ -z "${min}" ]] && min=2
  local max="$4"
  [[ -z "${max}" ]] && max=2
  local reps=$(random ${min} ${max})
  for i in $(seq 1 ${reps}); do
    local delay="$(random 123 257)"
    echo "Sending ${keystroke} with delay 0.${delay}s"
    xdotool key --delay "${delay}" --window "${tibia_wid}" "${keystroke}"
    local wait_time="0.$(random 110 350)s"
    echo "Pausing ${wait_time}"
    sleep "${wait_time}"
  done
}

function sec_per_rune() {
  echo $((mana_per_rune / mana_per_sec))
}

function mana_potion_count() {
  echo $(((mana_per_rune / 100) - 1))
}

function get_current_window_id() {
  echo $(xdotool getactivewindow)
}

function get_tibia_wid() {
  if [[ "${tibia_pid}" ]]; then
    echo $(xdotool search --pid ${tibia_pid})
  else
    echo $(xdotool search --class Tibia)
  fi
}

function focus_window() {
  local window_id=$1
  xdotool windowactivate --sync "${window_id}"
}

function timestamp_ms() {
  date "+%s%N" | cut -b1-13
}

function wait_timer() {
  local wait_time_secs="$1"
  local tibia_wid="$2"
  local wait_time_ms=$((wait_time_secs * 1000))
  local start_timestamp_ms=$(timestamp_ms)
  sleep "${wait_time_secs}s" &
  local wait_pid=$!

  echo
  local prev_msg_len=0
  while kill -0 ${wait_pid} 2>/dev/null; do
    local current_timestamp_ms=$(timestamp_ms)
    local elapsed_time_ms=$((current_timestamp_ms - start_timestamp_ms))
    local remaining_time_ms=$((wait_time_ms - elapsed_time_ms))
    if [[ ${remaining_time_ms} -gt 0 ]]; then
      local remaining_time_sec=$((remaining_time_ms / 1000))
      local msg="Waiting ${remaining_time_sec}s  "
      local overwrite=$(printf '\\b%0.s' $(seq 1 ${prev_msg_len}))
      local prev_msg_len=${#msg}
      printf "${overwrite}${msg}"
      local elapsed_time_s=$((elapsed_time_ms/1000))
      # check ring slot every 5 seconds
      # only enable this if you're not playing the game, because each check
      # freezes BOTH client's rendering.
      if [[ ${check_empty_slots} ]] && \
        [[ $((elapsed_time_s%5)) -eq 0 ]] && \
        is_ring_slot_empty "${tibia_wid}"; then
        equip_regen_ring "${tibia_wid}"
      fi
      if [[ ${use_char_reader} -eq 1 ]]; then
        make_rune "${tibia_wid}"
      fi
      sleep "0.250s"
    fi
  done
  echo
  echo

}

function is_out_of_souls_or_mana() {
    if [[ ${use_char_reader} -eq 1 ]]; then
      if [[ "${tibia_pid}" ]]; then
        eval "$(sudo ./char_reader.py --pid ${tibia_pid})"
      else
        eval "$(sudo ./char_reader.py)"
      fi
      echo "mana: ${MANA}, soul points: ${SOUL_POINTS}"
    else
      MANA=0
      SOUL_POINTS=200
    fi

    # do not drink mana if we're at /maximum char mana
    # do not drink mana if we're running out of soul points.
    [[ ${MANA} -gt ${max_mana_threshold} ]] || [[ ${SOUL_POINTS} -lt 6 ]]
}

function is_ring_slot_empty() {
  local tibia_wid="$1"
  ./equipment_reader.py --check_slot_empty 'ring' "${tibia_wid}"
}

potions_seq_counter=0
function get_potion_count() {
  local mana_potions_seq_len=${#mana_potions_seq[@]}
  if [[ ${mana_potions_seq_len} -gt 0 ]]; then
    debug "mana_potions_seq_len=${mana_potions_seq_len}"
    debug "potions_seq_counter=${potions_seq_counter}"
    local seq_idx=$((potions_seq_counter % mana_potions_seq_len))
    debug "seq_idx=${seq_idx}"
    echo ${mana_potions_seq[seq_idx]}
  else
    echo $(random ${min_mana_potions_per_turn} ${max_mana_potions_per_turn})
  fi
}

function drink_mana_potion() {
  local tibia_wid=$1
  if is_out_of_souls_or_mana; then
    return 1
  fi

  if [[ ${use_mouse_for_mana_potion} ]]; then
    click_mana_potion ${tibia_wid}
    click_char ${tibia_wid}
  else
    send_keystroke "${tibia_wid}" "${DRINK_POTION_KEY}" 1 1
  fi
}

function drink_mana_potions() {
  local tibia_wid=$1
  if is_out_of_souls_or_mana; then
    return 1
  fi

  local potion_count=$(get_potion_count)
  if [[ ${potion_count} -eq 0 ]]; then
    return 1
  fi
  potions_seq_counter=$((potions_seq_counter + 1))

  echo '-----------------------'
  echo "Drinking ${potion_count} mana potions"
  echo '-----------------------'
  for i in $(seq 1 ${potion_count}); do
    drink_mana_potion ${tibia_wid}
    local wait_time="0.$(random 310 560)s"
    echo "Pausing ${wait_time}"
    sleep "${wait_time}"

    # cast rune spell in case we have enough mana to use it again
    if [[ "${cast_rune_spell_after_drinking_potion}" ]]; then
      make_rune "${tibia_wid}" 1 2
    fi
  done
}

function cast_rune_spell() {
  # call the rune spell a random number of times between 2 and 5
  local tibia_wid="$1"
  local min=$2
  [[ -z "${min}" ]] && min=2
  local max=$3
  [[ -z "${min}" ]] && max=5

  echo '------------------'
  echo 'Calling rune spell'
  echo '------------------'
  send_keystroke "${tibia_wid}" "${CAST_RUNE_SPELL_KEY}" ${min} ${max}
}

function hold_regen_ring() {
  local tibia_wid=$1
  local minX=$((REGEN_RING_CENTER_X-12))
  local maxX=$((REGEN_RING_CENTER_X+12))
  local minY=$((REGEN_RING_CENTER_Y-12))
  local maxY=$((REGEN_RING_CENTER_Y+12))

  local X=$(random ${minX} ${maxX})
  local Y=$(random ${minY} ${maxY})

  local wait_time="0.$(random 250 390)s"
  sleep ${wait_time}
  xdotool mousemove --sync --screen 0 ${X} ${Y}
  wait_time="0.$(random 250 390)s"
  sleep ${wait_time}
  #xdotool keydown --window "${tibia_wid}" Pointer_Button1
  xdotool mousedown --window "${tibia_wid}" 1
}

function drop_regen_ring() {
  local tibia_wid=$1
  local minX=$((RING_SLOT_CENTER_X-12))
  local maxX=$((RING_SLOT_CENTER_X+12))
  local minY=$((RING_SLOT_CENTER_Y-12))
  local maxY=$((RING_SLOT_CENTER_Y+12))

  local X=$(random ${minX} ${maxX})
  local Y=$(random ${minY} ${maxY})

  local wait_time="0.$(random 250 390)s"
  sleep "${wait_time}"
  for i in $(seq 1 160); do
    xdotool mousemove_relative --sync 0 -1
  done
  # xdotool mousemove --screen 0 ${X} ${Y}
  wait_time="0.$(random 250 390)s"
  sleep "${wait_time}"
  xdotool keyup --window "${tibia_wid}" Pointer_Button1
  # xdotool mouseup --window "${tibia_wid}" 1
}

function smart_equip_regen_ring() {
  local tibia_wid="$1"
  if is_out_of_souls_or_mana; then
    return 1
  fi

  echo '-------------------'
  echo 'Equipping life ring'
  echo '-------------------'
  send_keystroke "${tibia_wid}}" "${EQUIP_RING_LR_KEY}" 1
  if [[ "${tibia_pid}" ]]; then
    eval "$(sudo ./char_reader.py --pid ${tibia_pid})"
  else
    eval "$(sudo ./char_reader.py)"
  fi
  if [[ ${SOUL_POINTS} -gt 10 ]]; then
    echo '-------------------------'
    echo 'Equipping ring of healing'
    echo '-------------------------'
    wait_time="0.$(random 250 390)s"
    sleep "${wait_time}"
    # equip ring of healing
    send_keystroke "${tibia_wid}}" "${EQUIP_RING_ROH_KEY}" 1
  fi
}

function dumb_equip_regen_ring() {
  local tibia_wid="$1"
  echo '-------------------'
  echo 'Equipping life ring'
  echo '-------------------'
  # equip life ring
  send_keystroke "${tibia_wid}}" "${EQUIP_RING_LR_KEY}" 1
  # small wait to make sure primary gets equipped
  wait_time="0.$(random 250 390)s"
  sleep "${wait_time}"
  # equip ring of healing
  send_keystroke "${tibia_wid}}" "${EQUIP_RING_ROH_KEY}" 1
}

function equip_regen_ring() {
  local tibia_wid="$1"
  if [[ "${use_mouse_for_regen_ring}" ]]; then
    #hold_regen_ring "${tibia_wid}"
    #drop_regen_ring "${tibia_wid}"
    drag_drop_ring ${tibia_wid}
  else
    if [[ ${use_char_reader} -eq 1 ]]; then
      smart_equip_regen_ring "${tibia_wid}"
    else
      dumb_equip_regen_ring "${tibia_wid}"
    fi
  fi
}

function equip_soft_boots() {
  local tibia_wid="$1"
  if is_out_of_souls_or_mana; then
    return 1
  fi
  # equip soft boots
  echo '-------------------'
  echo 'Equipping soft boots'
  echo '-------------------'
  send_keystroke "${tibia_wid}}" "${EQUIP_SOFT_BOOTS_KEY}" 1
}

function eat_food() {
  local tibia_wid="$1"
  if is_out_of_souls_or_mana; then
    return 1
  fi
  # call the eat command a random number between 0 and 3
  # we don't want to always issue the eat command
  echo '-----------'
  echo 'Eating food'
  echo '-----------'
  send_keystroke "${tibia_wid}" "${EAT_FOOD_KEY}" 0 3
}

function make_rune() {
  local tibia_wid="$1"
  local min_wait="$2"
  local max_wait="$3"
  if [[ ${use_char_reader} -eq 1 ]]; then
    if [[ "${tibia_pid}" ]]; then
      eval "$(sudo ./char_reader.py --pid ${tibia_pid})"
    else
      eval "$(sudo ./char_reader.py)"
    fi
    if [[ ${MANA} -gt ${mana_per_rune} ]]; then
      cast_rune_spell "${tibia_wid}" "${min_wait}" "${max_wait}"
    fi
  else
    cast_rune_spell "${tibia_wid}" "${min_wait}" "${max_wait}"
  fi
}

function wait_for_mana() {
  local tibia_wid=$1
  local total_sit_seconds=$(random ${min_wait_per_turn} ${max_wait_per_turn})
  # only if using mana potions
  echo
  echo '------------------------'
  echo "| Waiting for mana ${total_sit_seconds}s |"
  echo '------------------------'
  echo

  if [[ ${use_char_reader} -eq 1 ]]; then
    wait_timer "${total_sit_seconds}" "${tibia_wid}"
  else
    local third_sit_seconds=$((total_sit_seconds / 3))
    wait_timer "${third_sit_seconds}" "${tibia_wid}"
    # cast rune spell half way through wait to make sure we don't get full mana
    # and waste
    make_rune "${tibia_wid}"
    wait_timer "${third_sit_seconds}" "${tibia_wid}"
    make_rune "${tibia_wid}"
    wait_timer "${third_sit_seconds}" "${tibia_wid}"
  fi
}

function is_logged_out {
  ! ./tibia_reconnector.py --check_if_ingame "${tibia_pid}"
}

function login {
 ./tibia_reconnector.py --login \
    --credentials_profile "${credentials_profile}" \
    "${tibia_pid}"

  if [[ $? -ne 0 ]]; then
    echo "Failed log back into the game." >&2
    echo "Runemaker is quitting." >&2
    exit 1
  fi
}

function manasit() {
  local tibia_wid=$(get_tibia_wid)
  while true; do
    if [[ "${credentials_profile}" ]] && is_logged_out; then
      echo "We were disconnected. We will attempt login after 3-5 minutes."
      # Sleep 4-6 minutes before attempting to log back in, otherwise we may get
      # an exceptional disconnection message from which we can't recover (yet)
      # in the Tibia client.
      sleep "$(random 180 300)s"
      login
    fi
    # get current focused window
    eval "$(xdotool getmouselocation --shell)"
    local curr_x=${X}
    local curr_y=${Y}
    local curr_screen=${SCREEN}
    local curr_window=${WINDOW}
    debug "curr_x,y: ${curr_x}, ${curr_y}"
    debug "curr_screen=${curr_screen}"
    debug "curr_window=${curr_window}"

    # focus tibia window
    if [[ "${refocus_tibia_to_make_rune}" ]]; then
      focus_window ${tibia_wid}
    fi

    sleep "0.$(random 210 550)s"

    make_rune "${tibia_wid}"
    equip_regen_ring "${tibia_wid}"
    equip_soft_boots "${tibia_wid}"
    drink_mana_potions "${tibia_wid}"
    eat_food "${tibia_wid}"

    # return to prev window
    sleep "$(random 1 2).$(random 1 9)$(random 1 9)s"
    if [[ "${refocus_tibia_to_make_rune}" ]]; then
      xdotool mousemove --screen ${curr_screen} \
        ${curr_x} ${curr_y}
      focus_window ${curr_window}
    fi

    if [[ "${credentials_profile}" ]] && is_logged_out; then
      echo "We were disconnected. We will attempt login after 3-5 minutes."
      sleep "$(random 180 300)s"
      login
    fi
    # sit until next rune spell with randomization
    wait_for_mana "${tibia_wid}"
  done
}

tibia_pid=
credentials_profile=
check_empty_slots=
mana_per_rune=
mana_per_sec=5
half_mana_potions=
cast_rune_spell_after_drinking_potion=
refocus_tibia_to_make_rune=
min_mana_potions_per_turn=
max_mana_potions_per_turn=
max_wait_per_turn=
min_wait_per_turn=
mana_potions_seq=()
use_mouse_for_mana_potion=
use_char_reader=0
max_char_mana=99999
max_mana_threshold=99999
function parse_args() {
  while [[ $# -gt 0 ]]; do
    arg=$1
    case $arg in
    --mana-per-rune)
      mana_per_rune=$2
      shift
      ;;
    --mana-per-sec)
      mana_per_sec=$2
      shift
      ;;
    --rune-spell-after-potion)
      cast_rune_spell_after_drinking_potion=1
      ;;
    --half-mana-potions)
      half_mana_potions=1
      ;;
    --refocus-tibia-to-make-rune)
      refocus_tibia_to_make_rune=1
      ;;
    --min-mana-potions-per-turn)
      min_mana_potions_per_turn=$2
      shift
      ;;
    --max-mana-potions-per-turn)
      max_mana_potions_per_turn=$2
      shift
      ;;
    --min-wait-per-turn)
      min_wait_per_turn=$2
      shift
      ;;
    --max-wait-per-turn)
      max_wait_per_turn=$2
      shift
      ;;
    --mana-potions-seq)
      # split space or comma separated sequence of elements as an array
      IFS=', ' read -r -a mana_potions_seq <<<"$2"
      shift
      ;;
    --use-mouse-for-mana-potion)
      use_mouse_for_mana_potion=1
      ;;
    --use-char-reader)
      use_char_reader=1
      ;;
    --max-char-mana)
      max_char_mana=$2
      max_mana_threshold=$((${max_char_mana} - 200))
      shift
      ;;
    --tibia-pid)
      tibia_pid=$2
      shift
      ;;
    --credentials-profile)
      credentials_profile=$2
      shift
      ;;
    --check_empty_slots)
      check_empty_slots=1
      ;;
    *)
      break
      ;;
    esac
    shift
  done

  if [[ -z "${max_wait_per_turn}" ]]; then
    max_wait_per_turn=$(sec_per_rune)
  fi

  if [[ -z "${min_wait_per_turn}" ]]; then
    local tmp=$(sec_per_rune)
    min_wait_per_turn=$((tmp / 2))
  fi

  if [[ ${min_mana_potions_per_turn} -gt ${max_mana_potions_per_turn} ]]; then
    echo "min-mana-potions-per-turn ${min_mana_potions_per_turn} is greater than \
max-mana-potions-per turn ${max_mana_potions_per_turn}" >&2
    exit 1
  fi

  if [[ ${min_wait_per_turn} -gt ${max_wait_per_turn} ]]; then
    echo "min-wait-per-turn ${min_wait_per_turn} is greater than\
max-wait-per turn ${max_wait_per_turn}" >&2
    exit 1
  fi

  if [[ "${half_mana_potions}" ]]; then
    echo "Using half the mana potions"
  fi

  if [[ -z "${mana_per_rune}" ]]; then
    echo "You need to provide the mana cost per rune. (--mana-per-rune <amount>)" >&2
    exit 1
  fi

  local mana_potions_seq_len=${#mana_potions_seq[@]}
  if [[ ${mana_potions_seq_len} -gt 0 ]]; then
    debug "Mana potion sequence length: ${mana_potions_seq_len}"

    max_mana_potions_per_turn=0
    min_mana_potions_per_turn=0
  else
    if [[ -z "${max_mana_potions_per_turn}" ]]; then
      max_mana_potions_per_turn=$(mana_potion_count)
    fi

    if [[ -z "${min_mana_potions_per_turn}" ]]; then
      min_mana_potions_per_turn=0
    fi
  fi

  if [[ "${cast_rune_spell_after_drinking_potion}}" ]]; then
    echo "We will cast the rune spell right after drinking potions."
  fi

  if [[ "${refocus_tibia_to_make_rune}" ]]; then
    echo "We will refocus the Tibia window to make a rune (and then return focus to the original window)."
  fi
  echo "Mana per rune spell: ${mana_per_rune}"
  echo "Mana regen per sec: ${mana_per_sec}"
  echo "Minimum wait per turn: ${min_wait_per_turn}"
  echo "Maximum wait per turn: ${max_wait_per_turn}"
  if [[ ${mana_potions_seq_len} -gt 0 ]]; then
    echo "Mana potion sequence: ${mana_potions_seq[@]}"
  else
    echo "Min mana potions per turn: ${min_mana_potions_per_turn}"
    echo "Max mana potions per turn: ${max_mana_potions_per_turn}"
  fi

  if [[ "${use_mouse_for_mana_potion}" ]]; then
    echo "Using mouse for drinking mana potions"
  fi

  if [[ ${use_char_reader} -eq 1 ]]; then
    echo "Using char_reader.py to determine whether to equip life ring or ring of healing."
    if [[ ${max_char_mana} -lt 99999 ]]; then
      echo "Using a maximum character mana pool of ${max_char_mana}."
    fi
  fi

}

function main() {
  parse_args "$@"
  if [[ "${credentials_profile}" ]] && is_logged_out; then
    login
  fi
  manasit
}

main "$@"
