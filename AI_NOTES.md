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
cd ~/Desktop/FreeTube && pnpm run pack && node _scripts/build-appimage.mjs
Output: build/FreeTube Discover-*.AppImage
Config: ~/.config/freetube-discover/ (separate from system FreeTube)
Note: `pnpm run lint` crashes on Node 20 (Set.prototype.union in
eslint-plugin-unicorn). Upstream CI uses Node 24. Build (webpack) is unaffected.

## Git
- Branch: feature/explore-page
- Base: upstream v0.25.3-beta (merged 2026-08-28)
- Custom: name=freetube-discover, productName="FreeTube Discover"
- Custom commits sit on top of the upstream v0.25.3 merge commit.

## Scripts (project root)
implement-explore.sh, finish-explore.sh, enhance-discover.sh, add-pagesize.sh, build-appimage.sh

Update these notes when necesary
