<p align="center">
 <img alt="" src="/_icons/logoColor.svg" width=500 align="center">
</p>

# FreeTube Discover

A [FreeTube](https://github.com/FreeTubeApp/FreeTube) fork that turns YouTube's
"Up Next" recommendations into a feed you can actually browse. Watch something,
and the videos YouTube recommended next are saved locally, so you have a
Discover page to scroll through later.

FreeTube is an open source desktop YouTube player built with privacy in mind.
Use YouTube without advertisements and prevent Google from tracking you with
their cookies and JavaScript. Available for Windows (10 and later), Mac (macOS
12 and later) & Linux thanks to Electron.

## What's different

### The Discover page

While you watch, every "Up Next" recommendation is recorded into a local
database. The Discover page shows them all, as an infinite-scroll feed:

- Fresh videos come first. The feed is split into buckets by how recently a
  video was last recommended: last 24 hours, then 1-7 days, then 7-30 days,
  then everything older.
- Each bucket keeps roughly 80% of its videos in most-recently-recommended
  order, and draws the remaining ~20% at random from the whole catalog. Older
  videos resurface this way, and no video appears twice in one feed.
- Opening Discover deals the feed fresh, so the mix changes between visits.
- Watched videos are always hidden, and you can filter by video length.

The feed is only as good as the videos you've actually watched, so it grows
as you use the app. The database lives in your FreeTube Discover config
directory, and you can clear it from Data Settings.

### Hide Watched in search

An extra search filter, "Hide Watched", removes videos from your search results
if they're already in your history. It's off by default and only applied
locally, so it doesn't change what Invidious returns.

## Building

This is an Electron app, so the normal Node.js toolchain applies.

```sh
pnpm install
pnpm run pack          # webpack build
```

For a Linux AppImage:

```sh
node _scripts/build-appimage.mjs
```

Output lands in `build/`.

> [!NOTE]
> `pnpm run lint` needs Node 24 (upstream CI runs that version). On Node 20 it
> crashes in `eslint-plugin-unicorn` before checking anything. The webpack
> build itself is unaffected by the Node version.

## Contributing

Pull requests are welcome. A few house rules:

- Base changes on the default branch, not on an upstream commit.
- When a new FreeTube release comes out, merge the release tag into this
  branch and resolve conflicts in the custom files, rather than rebasing.
- The Discover feature lives in `src/renderer/views/Discover/`,
  `src/renderer/store/modules/discover.js`, and the discover datastores in
  `src/datastores/`. If you touch one of those, keep the page self-contained.
- FontAwesome icons only render if they're registered in
  `src/renderer/main.js`. An unregistered icon renders as a blank box with no
  error, which is easy to miss.

Open an issue before working on anything non-trivial, so we don't duplicate
each other.

## Upstream

This fork tracks [FreeTubeApp/FreeTube](https://github.com/FreeTubeApp/FreeTube).
Everything not listed above is upstream's. See the upstream
[README](https://github.com/FreeTubeApp/FreeTube) for the full feature list,
Invidious setup, browser extensions, and donation information.

## License

FreeTube is Free Software: You can use, study, share and improve it at your
will. Specifically you can redistribute and/or modify it under the terms of the
[GNU Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.html)
as published by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.
