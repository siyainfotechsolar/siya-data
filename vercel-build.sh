#!/bin/bash
set -e

git config --global --add safe.directory '*'

cd admin_panel

if [ ! -f flutter/bin/flutter ]; then
  rm -rf flutter
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

./flutter/bin/flutter config --no-analytics
./flutter/bin/flutter build web --release --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
