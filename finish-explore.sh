#!/bin/bash
set -euo pipefail
cd ~/FreeTube

echo "===== STEP 1: Fix datastores/index.js — add explore to loadDatastores/compactAllDatastores ====="
# The loadDatastores and compactAllDatastores functions are in handlers/base.js, not datastores/index.js
# But we already added `export const explore = createDatastore('explore')` to datastores/index.js
# Now we need to update the functions in base.js to load/compact the explore datastore

cat > /tmp/finish-explore.mjs << 'NODEEOF'
import fs from 'fs'
import path from 'path'

const root = process.cwd()

function modifyFile(filePath, findString, replaceString) {
  const fullPath = path.join(root, filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`File not found: ${filePath}`)
  }
  const content = fs.readFileSync(fullPath, 'utf8')
  if (!content.includes(findString)) {
    // Check if already done
    if (content.includes(replaceString)) {
      console.log(`  ⊙ Already done: ${filePath}`)
      return
    }
    throw new Error(`Could not find expected string in ${filePath}`)
  }
  const newContent = content.replace(findString, replaceString)
  fs.writeFileSync(fullPath, newContent)
  console.log(`  ✓ Modified ${filePath}`)
}

// === 1. handlers/base.js — Add Explore class + update loadDatastores/compactAllDatastores ===
modifyFile(
  'src/datastores/handlers/base.js',
  'function loadDatastores() {',
  `class Explore {
  static find() {
    return db.explore.findAsync({}).sort({ archivedAt: -1 })
  }

  static upsert(record) {
    return db.explore.updateAsync({ videoId: record.videoId }, record, { upsert: true })
  }

  static delete(videoId) {
    return db.explore.removeAsync({ videoId })
  }

  static deleteAll() {
    return db.explore.removeAsync({}, { multi: true })
  }
}

function loadDatastores() {`
)

modifyFile(
  'src/datastores/handlers/base.js',
  '    db.subscriptionCache.loadDatabaseAsync(),\n  ])',
  '    db.subscriptionCache.loadDatabaseAsync(),\n    db.explore.loadDatabaseAsync(),\n  ])'
)

modifyFile(
  'src/datastores/handlers/base.js',
  '    db.subscriptionCache.compactDatafileAsync(),\n  ])',
  '    db.subscriptionCache.compactDatafileAsync(),\n    db.explore.compactDatafileAsync(),\n  ])'
)

modifyFile(
  'src/datastores/handlers/base.js',
  '  SubscriptionCache as subscriptionCache,\n\n  loadDatastores,',
  '  SubscriptionCache as subscriptionCache,\n  Explore as explore,\n\n  loadDatastores,'
)

// === 2. datastores/handlers/electron.js — Add Explore handler class ===
modifyFile(
  'src/datastores/handlers/electron.js',
  `  static deleteAll() {
    return window.ftElectron.dbSubscriptionCache(DBActions.GENERAL.DELETE_ALL)
  }
}

export {
  Settings as settings,
  History as history,
  Profiles as profiles,
  Playlists as playlists,
  SearchHistory as searchHistory,
  SubscriptionCache as subscriptionCache,
}`,
  `  static deleteAll() {
    return window.ftElectron.dbSubscriptionCache(DBActions.GENERAL.DELETE_ALL)
  }
}

class Explore {
  static find() {
    return window.ftElectron.dbExplore(DBActions.GENERAL.FIND)
  }

  static upsert(record) {
    return window.ftElectron.dbExplore(DBActions.GENERAL.UPSERT, record)
  }

  static delete(videoId) {
    return window.ftElectron.dbExplore(DBActions.GENERAL.DELETE, videoId)
  }

  static deleteAll() {
    return window.ftElectron.dbExplore(DBActions.GENERAL.DELETE_ALL)
  }
}

export {
  Settings as settings,
  History as history,
  Profiles as profiles,
  Playlists as playlists,
  SearchHistory as searchHistory,
  SubscriptionCache as subscriptionCache,
  Explore as explore,
}`
)

// === 3. datastores/handlers/web.js — Re-export explore ===
modifyFile(
  'src/datastores/handlers/web.js',
  "export { history, profiles, playlists, searchHistory, subscriptionCache } from './base'",
  "export { history, profiles, playlists, searchHistory, subscriptionCache, explore } from './base'"
)

// === 4. datastores/handlers/index.js — Export DBExploreHandlers ===
modifyFile(
  'src/datastores/handlers/index.js',
  `  subscriptionCache as DBSubscriptionCacheHandlers,
} from 'DB_HANDLERS_ELECTRON_RENDERER_OR_WEB'`,
  `  subscriptionCache as DBSubscriptionCacheHandlers,
  explore as DBExploreHandlers,
} from 'DB_HANDLERS_ELECTRON_RENDERER_OR_WEB'`
)

// === 5. preload/interface.js — Add dbExplore and handleSyncExplore ===
modifyFile(
  'src/preload/interface.js',
  `  dbSubscriptionCache: (action, data) => {
    return ipcRenderer.invoke(IpcChannels.DB_SUBSCRIPTION_CACHE, data ? { action, data } : { action })
  },`,
  `  dbSubscriptionCache: (action, data) => {
    return ipcRenderer.invoke(IpcChannels.DB_SUBSCRIPTION_CACHE, data ? { action, data } : { action })
  },

  /**
   * @param {number} action
   * @param {any} [data]
   */
  dbExplore: (action, data) => {
    return ipcRenderer.invoke(IpcChannels.DB_EXPLORE, data ? { action, data } : { action })
  },`
)

modifyFile(
  'src/preload/interface.js',
  `  handleSyncSubscriptionCache: (handler) => {
    ipcRenderer.on(IpcChannels.SYNC_SUBSCRIPTION_CACHE, (_, { event, data }) => {
      handler(event, data)
    })
  }
}`,
  `  handleSyncSubscriptionCache: (handler) => {
    ipcRenderer.on(IpcChannels.SYNC_SUBSCRIPTION_CACHE, (_, { event, data }) => {
      handler(event, data)
    })
  },

  /**
   * @param {(event: number, data: any) => void} handler
   */
  handleSyncExplore: (handler) => {
    ipcRenderer.on(IpcChannels.SYNC_EXPLORE, (_, { event, data }) => {
      handler(event, data)
    })
  }
}`
)

// === 6. main/index.js — Add DB_EXPLORE IPC handler ===
modifyFile(
  'src/main/index.js',
  `  // *********** //
  // Profiles
  ipcMain.handle(IpcChannels.DB_PROFILES, async (event, { action, data }) => {`,
  `  // *********** //
  // Explore
  ipcMain.handle(IpcChannels.DB_EXPLORE, async (event, { action, data }) => {
    if (!isFreeTubeUrl(event.senderFrame.url)) {
      return
    }

    try {
      switch (action) {
        case DBActions.GENERAL.FIND:
          return await baseHandlers.explore.find()

        case DBActions.GENERAL.UPSERT:
          await baseHandlers.explore.upsert(data)
          syncOtherWindows(
            IpcChannels.SYNC_EXPLORE,
            event,
            { event: SyncEvents.GENERAL.UPSERT, data }
          )
          return null

        case DBActions.GENERAL.DELETE:
          await baseHandlers.explore.delete(data)
          syncOtherWindows(
            IpcChannels.SYNC_EXPLORE,
            event,
            { event: SyncEvents.GENERAL.DELETE, data }
          )
          return null

        case DBActions.GENERAL.DELETE_ALL:
          await baseHandlers.explore.deleteAll()
          syncOtherWindows(
            IpcChannels.SYNC_EXPLORE,
            event,
            { event: SyncEvents.GENERAL.DELETE_ALL }
          )
          return null

        default:
          // eslint-disable-next-line no-throw-literal
          throw 'invalid explore db action'
      }
    } catch (err) {
      if (typeof err === 'string') throw err
      else throw err.toString()
    }
  })

  // *********** //
  // Profiles
  ipcMain.handle(IpcChannels.DB_PROFILES, async (event, { action, data }) => {`
)

// === 7. store/index.js — Register explore module ===
modifyFile(
  'src/renderer/store/index.js',
  "import history from './modules/history'",
  "import history from './modules/history'\nimport explore from './modules/explore'"
)

modifyFile(
  'src/renderer/store/index.js',
  '  modules: {\n    history,',
  '  modules: {\n    history,\n    explore,'
)

// === 8. settings.js — Add hideWatchedExplore setting ===
modifyFile(
  'src/renderer/store/modules/settings.js',
  '  hideWatchedSubs: false,',
  '  hideWatchedSubs: false,\n  hideWatchedExplore: true,'
)

// === 8b. settings.js — Add explore sync listener ===
modifyFile(
  'src/renderer/store/modules/settings.js',
  `          default:
            console.error('subscription-cache: invalid sync event received')
        }
      })
    }
  }`,
  `          default:
            console.error('subscription-cache: invalid sync event received')
        }
      })

      window.ftElectron.handleSyncExplore((event, data) => {
        switch (event) {
          case SyncEvents.GENERAL.UPSERT:
            commit('upsertToExploreCache', data)
            break

          case SyncEvents.GENERAL.DELETE:
            commit('removeFromExploreCacheById', data)
            break

          case SyncEvents.GENERAL.DELETE_ALL:
            commit('setExploreCache', [])
            commit('setExploreCacheById', {})
            break

          default:
            console.error('explore: invalid sync event received')
        }
      })
    }
  }`
)

// === 9. router/index.js — Add Explore route ===
modifyFile(
  'src/renderer/router/index.js',
  "import Popular from '../views/Popular/Popular.vue'",
  "import Popular from '../views/Popular/Popular.vue'\nimport Explore from '../views/Explore/Explore.vue'"
)

modifyFile(
  'src/renderer/router/index.js',
  `    {
      path: '/popular',
      name: 'popular',
      meta: {
        title: 'Most Popular'
      },
      component: Popular
    },`,
  `    {
      path: '/popular',
      name: 'popular',
      meta: {
        title: 'Most Popular'
      },
      component: Popular
    },
    {
      path: '/explore',
      name: 'explore',
      meta: {
        title: 'Explore'
      },
      component: Explore
    },`
)

// === 10. SideNav.vue — Add Explore nav entry ===
modifyFile(
  'src/renderer/components/SideNav/SideNav.vue',
  `      <router-link
        v-if="!hidePlaylists"
        class="navOption mobileShow"
        role="button"
        to="/userplaylists"`,
  `      <router-link
        class="navOption mobileShow"
        role="button"
        to="/explore"
        :title="$t('Explore.Explore')"
      >
        <div
          class="thumbnailContainer"
        >
          <FontAwesomeIcon
            :icon="['fas', 'compass']"
            class="navIcon"
            :class="applyNavIconExpand"
          />
        </div>
        <p
          class="navLabel"
        >
          {{ $t("Explore.Explore") }}
        </p>
      </router-link>
      <router-link
        v-if="!hidePlaylists"
        class="navOption mobileShow"
        role="button"
        to="/userplaylists"`
)

// === 11. Watch.js — Add capture hook ===
// 11a. Call after local API recommendedVideos
modifyFile(
  'src/renderer/views/Watch/Watch.js',
  `          .map(parseLocalWatchNextVideo).filter(_ => _)
          // place watched recommended videos last
          .sort(this.sortWatchedVideosLast) ?? []`,
  `          .map(parseLocalWatchNextVideo).filter(_ => _)
          // place watched recommended videos last
          .sort(this.sortWatchedVideosLast) ?? []

        this.archiveRecommendedVideos()`
)

// 11b. Call after invidious API recommendedVideos
modifyFile(
  'src/renderer/views/Watch/Watch.js',
  `          // place watched recommended videos last
          this.recommendedVideos = recommendedVideos.sort(this.sortWatchedVideosLast)`,
  `          // place watched recommended videos last
          this.recommendedVideos = recommendedVideos.sort(this.sortWatchedVideosLast)

          this.archiveRecommendedVideos()`
)

// 11c. Add archiveRecommendedVideos method + addToExplore to mapActions
modifyFile(
  'src/renderer/views/Watch/Watch.js',
  `    addToHistory: function (watchProgress) {`,
  `    archiveRecommendedVideos: function () {
      if (this.recommendedVideos.length === 0) {
        return
      }

      const exploreVideos = this.recommendedVideos.map(video => ({
        videoId: video.videoId,
        title: video.title,
        author: video.author,
        authorId: video.authorId,
        viewCount: video.viewCount,
        published: video.published,
        lengthSeconds: video.lengthSeconds,
        liveNow: video.liveNow,
        isUpcoming: video.isUpcoming,
        type: 'video',
        archivedAt: Date.now(),
        sourceVideoId: this.videoId
      }))

      exploreVideos.forEach(video => {
        this.addToExplore(video)
      })
    },

    addToHistory: function (watchProgress) {`
)

modifyFile(
  'src/renderer/views/Watch/Watch.js',
  `    ...mapActions([
      'updateHistory',
      'updateWatchProgress',
      'updateLastViewedPlaylist',
      'updatePlaylistLastPlayedAt',
      'updateSubscriptionDetails',
    ]),`,
  `    ...mapActions([
      'updateHistory',
      'updateWatchProgress',
      'updateLastViewedPlaylist',
      'updatePlaylistLastPlayedAt',
      'updateSubscriptionDetails',
      'addToExplore',
    ]),`
)

// === 12. en-US.yaml — Add Explore locale strings ===
modifyFile(
  'static/locales/en-US.yaml',
  'Most Popular: Most Popular',
  `Explore:
  Explore: Explore
  Shuffle: Shuffle
  Hide Watched: Hide Watched
  No Videos: 'No videos to explore yet. Watch some videos and their "Up Next" recommendations will appear here!'
Most Popular: Most Popular`
)

console.log('\nAll modifications complete!')
NODEEOF

node /tmp/finish-explore.mjs

echo ""
echo "===== STEP 2: Verify datastores/index.js already has explore export ====="
grep -n "explore" src/datastores/index.js

echo ""
echo "===== STEP 3: Verification ====="
echo "--- New files ---"
ls -la src/renderer/views/Explore/
echo ""
ls -la src/renderer/store/modules/explore.js

echo ""
echo "--- Git diff summary ---"
git diff --stat

echo ""
echo "===== DONE ====="
echo "To test, run: cd ~/FreeTube && pnpm run dev"
