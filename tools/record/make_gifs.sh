#!/bin/sh
# Records the README's GIFs (tools/record/record.gd) into docs/media/.
#
#   tools/record/make_gifs.sh            # every clip
#   tools/record/make_gifs.sh invasion     # just one
#
# Needs ffmpeg. Opens a game window while each clip plays; movie mode runs
# at a fixed framerate, so a slow machine still makes a smooth clip.
set -e
cd "$(dirname "$0")/../.."

GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
FPS=30           # recorded framerate
GIF_FPS=15
GIF_WIDTH=720
OUT=docs/media
TMP=build/record
mkdir -p "$OUT" "$TMP"

clips=${*:-"invasion lift crowd"}
for clip in $clips; do
	echo "== $clip"
	log="$TMP/$clip.log"
	"$GODOT" --path . --resolution 1280x720 --fixed-fps $FPS \
		--write-movie "$TMP/$clip.avi" \
		-s tools/record/record.gd -- --no-hot-reload --clip="$clip" | tee "$log"
	grep -q "^TRIM " "$log" || { echo "$clip failed"; exit 1; }
	trim=$(grep '^TRIM ' "$log" | tail -1 | cut -d' ' -f2)
	start=$(echo "scale=3; ${trim:-0} / $FPS" | bc)
	ffmpeg -loglevel error -y -ss "$start" -i "$TMP/$clip.avi" \
		-vf "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
		-loop 0 "$OUT/$clip.gif"
	ls -lh "$OUT/$clip.gif"
done
