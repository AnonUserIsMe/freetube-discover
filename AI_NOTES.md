# AI Project Notes — FreeTube Discover

Fork of FreeTube with custom Discover feature. User is NOT a developer.
All changes made by AI assistants via shell scripts.

## Feature
Captures "Up Next" recommendations when watching videos -> discover.db.
Discover page: shuffle, filters (date/length), page size, hide watched, clear.

## Build
cd ~/FreeTube && pnpm run pack && node _scripts/build-appimage.mjs
Output: build/FreeTube Discover-*.AppImage
Config: ~/.config/freetube-discover/ (separate from system FreeTube)

## Git
- Branch: feature/explore-page
- Merged: v0.25.2-beta
- Custom: name=freetube-discover, productName="FreeTube Discover"

## Scripts (project root)
implement-explore.sh, finish-explore.sh, enhance-discover.sh, add-pagesize.sh, build-appimage.sh

Update these notes when necesary
