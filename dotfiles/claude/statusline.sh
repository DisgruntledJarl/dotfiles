#!/usr/bin/env bash
# Claude Code statusline: model · effort · 5h usage bar · reset time

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
print(lvl.capitalize() if lvl else '')
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

# Progress bar (10 chars wide)
filled = round(used_pct / 10)
bar = '█' * filled + '░' * (10 - filled)

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

print(f'{bar} {used_pct:.0f}% | resets in {reset_str}')
" 2>/dev/null)

# Build output
parts=()
[[ -n "$model" ]] && parts+=("$model")
[[ -n "$effort" ]] && parts+=("$effort")

header=$(IFS=' · '; echo "${parts[*]}")

if [[ "$rate_info" == "NO_RATE" || -z "$rate_info" ]]; then
    echo "$header"
else
    echo "$header  |  5h: $rate_info"
fi
