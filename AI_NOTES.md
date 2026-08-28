# AI Project Notes — FreeTube Discover

Fork of FreeTube with custom Discover feature. User is NOT a developer.
All changes made by AI assistants via shell scripts.

## Feature
Captures "Up Next" recommendations when watching videos -> discover.db.
Discover page: shuffle, filters (date/length), page size, hide watched, clear.
Search "Hide Watched" filter (off by default): checkbox in search filters prompt;
hides search results present in history (historyCacheById). Not persisted (like
other search filters). Files: FtSearchFilters.vue, SearchPage.vue, TopNav.vue,
store/modules/utils.js (searchSettings.hideWatched + setSearchHideWatched),
helpers/utils.js (searchFiltersMatch), locales/en-US.yaml.

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
