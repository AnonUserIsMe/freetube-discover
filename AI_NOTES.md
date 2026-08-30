# AI Project Notes — FreeTube Discover

Fork of FreeTube with custom Discover feature. User is not a professional
developer (codes casually with the pi coding harness); all recent changes
were made by AI assistants via shell scripts.

## Feature
Captures "Up Next" recommendations when watching videos -> discover.db.
Discover page: shuffle, filters (date/length), page size, hide watched, clear.
Search "Hide Watched" filter (off by default): shown as the last checkbox in the
Features list of the search filters prompt (client-side filter, kept out of
searchSettings.features). Hides search results present in history (historyCacheById).
Not persisted (like other search filters). Files: FtSearchFilters.vue, SearchPage.vue,
TopNav.vue, store/modules/utils.js (searchSettings.hideWatched + setSearchHideWatched),
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
