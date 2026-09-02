# AI Project Notes — FreeTube Discover

Fork of FreeTube with custom Discover feature. User is not a professional
developer (codes casually with the pi coding harness); all recent changes
were made by AI assistants via shell scripts.

## Feature
Captures "Up Next" recommendations when watching videos -> discover.db.
Discover page: infinite scroll (IntersectionObserver sentinel at window level;
24 shown initially, +12 per intersection), Shuffle re-deals the feed, filters
(date added / upload date / length), hide watched, clear.
Feed ordering = "deal" blend: 80% of slots follow most-recently-recommended
order (archivedAt desc = last time recommended anywhere), 20% random from any
point of the catalog (no repeats; seeded per deal so it stays stable until the
user shuffles). Shuffle button re-deals + scrolls to top.
The old page-size setting and sort dropdown were removed (commit history has
them; persisted discoverPageSize/discoverSortMode DB rows are now inert and
harmlessly ignored by the settings loader).
Search "Hide Watched" filter (off by default): shown as the last checkbox in the
Features list of the search filters prompt (client-side filter, kept out of
searchSettings.features). Hides search results present in history (historyCacheById).
Not persisted (like other search filters). Files: FtSearchFilters.vue, SearchPage.vue,
TopNav.vue, store/modules/utils.js (searchSettings.hideWatched + setSearchHideWatched),
helpers/utils.js (searchFiltersMatch), locales/en-US.yaml.

Discover icon (binoculars): faCompass was used in the code but NEVER registered, so
FontAwesome rendered a blank icon. Fixed by registering faBinoculars in
src/renderer/main.js (import list + library.add()) and pointing BOTH the SideNav
entry (SideNav.vue) and the Discover page heading (views/Discover/Discover.vue) at
['fas','binoculars']. faBinoculars exists in @fortawesome/free-solid-svg-icons.

## Build
cd ~/Desktop/FreeTube && pnpm run pack && node _scripts/build-appimage.mjs
Output: build/FreeTube Discover-*.AppImage
Config: ~/.config/freetube-discover/ (separate from system FreeTube)
Note: `pnpm run lint` crashes on Node 20 (Set.prototype.union in
eslint-plugin-unicorn). Upstream CI uses Node 24. Build (webpack) is unaffected.

### FontAwesome icons
An icon only renders if it's registered in src/renderer/main.js (import it from
'@fortawesome/free-solid-svg-icons' AND add it to library.add()). FontAwesome fails
silently for unregistered icons — it just renders blank, no error. Always check a
new icon is in that file. (This is how the blank Discover compass icon went unnoticed.)

## Git
- Branch: feature/explore-page
- Base: upstream v0.25.3-beta (merged 2026-08-28)
- Custom: name=freetube-discover, productName="FreeTube Discover"
- Custom commits sit on top of the upstream v0.25.3 merge commit.

### Updating from upstream (when a new FreeTube release comes out)
1. `git fetch origin --tags`
2. `git merge v0.25.X-beta` (the release tag) from the feature branch.
3. Fix any conflicts in the custom files (see list above).
4. Rebuild with the Build section's commands; test the AppImage.
5. Commit the merge. Never rewrite or rebase the custom commit stack.

### Custom footprint (where merge conflicts will happen)
AI_NOTES.md; the files listed per feature above; _scripts/build-appimage.mjs and
ebuilder.config.mjs; root *.sh build scripts; package.json (product name);
pnpm-lock.yaml; static/locales/en-US.yaml. Upstream-only changes (other
locales, .github/, etc.) should not conflict — if they do, inspect first.

## Scripts (project root)
implement-explore.sh, finish-explore.sh, enhance-discover.sh, add-pagesize.sh, build-appimage.sh

Update these notes when necessary.
