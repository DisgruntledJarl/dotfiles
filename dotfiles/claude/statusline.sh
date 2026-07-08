#!/usr/bin/env bash
# Claude Code statusline: model · effort · tokens · folder · session · 5h usage bar · reset time

payload=$(cat)

model=$(echo "$payload" | python3 -c "
import json, sys
d = json.load(sys.stdin)
name = d.get('model', {}).get('display_name') or d.get('model', {}).get('id', '?')
print(name)
" 2>/dev/null)

effort=$(echo "$payload" | python3 -c "
import json, sys
d = json.load(sys.stdin)
lvl = d.get('effort', {}).get('level', '')
if not lvl:
    print('')
    sys.exit()
color = {
    'low': '1;92',      # bold bright green
    'medium': '1;93',   # bold bright yellow
    'high': '1;91',     # bold bright red
    'xhigh': '1;95',     # bold bright magenta
    'max': '1;95',       # bold bright magenta
}.get(lvl.lower(), '1;96')
print(f'\033[{color}m{lvl.capitalize()}\033[0m')
" 2>/dev/null)

folder=$(echo "$payload" | python3 -c "
import json, sys, os
d = json.load(sys.stdin)
cwd = d.get('workspace', {}).get('current_dir') or d.get('cwd') or ''
print(os.path.basename(cwd))
" 2>/dev/null)

session_name=$(echo "$payload" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('session_name') or '')
" 2>/dev/null)

session_id=$(echo "$payload" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('session_id') or '')
" 2>/dev/null)

# Token count: the payload has no single "cumulative session total" field.
# context_window.total_input_tokens = input tokens currently in the context
# window (incl. cache reads/writes); total_output_tokens = output tokens from
# the most recent API response only. We sum them as the best available proxy
# for "tokens in play" right now, not a true running total across the session.
tokens_fmt=$(echo "$payload" | python3 -c "
import json, sys
d = json.load(sys.stdin)
cw = d.get('context_window', {})
total = (cw.get('total_input_tokens') or 0) + (cw.get('total_output_tokens') or 0)
fmt = f'{total / 1000:.1f}k' if total >= 1000 else str(total)
color = '1;91' if total >= 100000 else '1;93' if total >= 40000 else '1;92'
print(f'\033[{color}m{fmt} tokens\033[0m')
" 2>/dev/null)

rate_info=$(echo "$payload" | python3 -c "
import json, sys, time, datetime

d = json.load(sys.stdin)
rl = d.get('rate_limits', {}).get('five_hour', {})
used_pct = rl.get('used_percentage')
resets_at = rl.get('resets_at')

if used_pct is None or resets_at is None:
    print('NO_RATE')
    sys.exit()

# Progress bar (10 chars wide), colored by usage
filled = round(used_pct / 10)
bar_color = '1;91' if used_pct >= 80 else '1;93' if used_pct >= 50 else '1;92'
bar = f'\033[{bar_color}m' + '█' * filled + '\033[2m' + '░' * (10 - filled) + '\033[0m'

# Time until reset
now = time.time()
secs_left = max(0, resets_at - now)
mins_left = int(secs_left // 60)
hrs = mins_left // 60
mins = mins_left % 60

if hrs > 0:
    reset_str = f'{hrs}h{mins:02d}m'
else:
    reset_str = f'{mins}m'

print(f'{bar} \033[{bar_color}m{used_pct:.0f}%\033[0m | resets in \033[1;94m{reset_str}\033[0m')
" 2>/dev/null)

# Build output
parts=()
[[ -n "$model" ]] && parts+=("\033[1;38;5;51m${model}\033[0m")
[[ -n "$effort" ]] && parts+=("$effort")

header=$(IFS=' · '; echo "${parts[*]}")

[[ -n "$tokens_fmt" ]] && header="${header} \033[2m|\033[0m ${tokens_fmt}"
[[ -n "$folder" ]] && header="${header} \033[2m|\033[0m \033[1;93m${folder}\033[0m"

if [[ -n "$session_name" ]]; then
    header="${header} \033[2m|\033[0m \033[1;38;5;213m${session_name}\033[0m"
elif [[ -n "$session_id" ]]; then
    header="${header} \033[2m|\033[0m \033[2msession ${session_id:0:8}\033[0m"
fi

if [[ "$rate_info" == "NO_RATE" || -z "$rate_info" ]]; then
    printf "%b\n" "$header"
else
    printf "%b\n" "$header  \033[2m|\033[0m  \033[1;94m5h:\033[0m $rate_info"
fi
