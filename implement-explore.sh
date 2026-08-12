#!/bin/bash
set -euo pipefail
cd ~/FreeTube

echo "===== STEP 1: Creating new files ====="

# --- Explore view directory ---
mkdir -p src/renderer/views/Explore

# --- Explore.vue ---
cat > src/renderer/views/Explore/Explore.vue << 'VUEEOF'
<template>
  <div>
    <FtCard class="card">
      <h2>
        <FontAwesomeIcon
          :icon="['fas', 'compass']"
          class="headingIcon"
        />
        {{ $t("Explore.Explore") }}
      </h2>
      <FtFlexBox class="exploreControls">
        <button
          class="exploreShuffleButton"
          :disabled="isLoading || exploreCache.length === 0"
          @click="shuffleExplore"
        >
          <FontAwesomeIcon :icon="['fas', 'shuffle']" />
          {{ $t("Explore.Shuffle") }}
        </button>
        <label class="exploreHideWatchedLabel">
          <input
            type="checkbox"
            :checked="hideWatchedExplore"
            @change="toggleHideWatched"
          >
          {{ $t("Explore.Hide Watched") }}
        </label>
      </FtFlexBox>
      <FtLoader v-if="isLoading" />
      <div
        v-else-if="shownResults.length === 0"
        class="exploreEmpty"
      >
        <p>{{ $t("Explore.No Videos") }}</p>
      </div>
      <FtElementList
        v-else
        :data="shownResults"
      />
    </FtCard>
  </div>
</template>

<script setup>
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'
import { computed, onMounted, ref, shallowRef } from 'vue'
import { useI18n } from 'vue-i18n'

import FtCard from '../../components/ft-card/ft-card.vue'
import FtLoader from '../../components/FtLoader/FtLoader.vue'
import FtElementList from '../../components/FtElementList/FtElementList.vue'
import FtFlexBox from '../../components/ft-flex-box/ft-flex-box.vue'

import store from '../../store/index'

const { t } = useI18n()

const isLoading = ref(true)
const shuffledResults = shallowRef([])

const exploreCache = computed(() => {
  return store.getters.getExploreCache
})

const hideWatchedExplore = computed(() => {
  return store.getters.getHideWatchedExplore
})

const historyCacheById = computed(() => {
  return store.getters.getHistoryCacheById
})

const shownResults = computed(() => {
  let results = shuffledResults.value

  if (hideWatchedExplore.value) {
    results = results.filter(video => {
      return !Object.hasOwn(historyCacheById.value, video.videoId)
    })
  }

  return results
})

function shuffleArray(array) {
  const arr = [...array]
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

function shuffleExplore() {
  shuffledResults.value = shuffleArray(exploreCache.value)
}

function toggleHideWatched() {
  store.dispatch('updateHideWatchedExplore', !hideWatchedExplore.value)
}

onMounted(async () => {
  await store.dispatch('grabExplore')
  shuffleExplore()
  isLoading.value = false
})
</script>

<style scoped src="./Explore.css" />
VUEEOF

# --- Explore.css ---
cat > src/renderer/views/Explore/Explore.css << 'CSSEOF'
.card {
  padding: 20px;
}

.headingIcon {
  margin-inline-end: 8px;
}

.exploreControls {
  margin-block: 16px;
  gap: 16px;
  align-items: center;
}

.exploreShuffleButton {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  background: var(--primary-color);
  color: var(--text-with-main-color);
}

.exploreShuffleButton:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.exploreHideWatchedLabel {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-size: 14px;
}

.exploreEmpty {
  text-align: center;
  padding: 40px 20px;
  color: var(--secondary-text-color);
}
CSSEOF

# --- Vuex store module: explore.js ---
cat > src/renderer/store/modules/explore.js << 'JSEOF'
import { DBExploreHandlers } from '../../../datastores/handlers/index'

const state = {
  exploreCache: [],
  exploreCacheById: {}
}

const getters = {
  getExploreCache(state) {
    return state.exploreCache
  },

  getExploreCacheById(state) {
    return state.exploreCacheById
  }
}

const actions = {
  async grabExplore({ commit }) {
    try {
      const results = await DBExploreHandlers.find()

      const resultsById = {}
      results.forEach(video => {
        resultsById[video.videoId] = video
      })

      commit('setExploreCache', results)
      commit('setExploreCacheById', resultsById)
    } catch (errMessage) {
      console.error(errMessage)
    }
  },

  async addToExplore({ commit }, record) {
    try {
      await DBExploreHandlers.upsert(record)
      commit('upsertToExploreCache', record)
    } catch (errMessage) {
      console.error(errMessage)
    }
  },

  async removeFromExplore({ commit }, videoId) {
    try {
      await DBExploreHandlers.delete(videoId)
      commit('removeFromExploreCacheById', videoId)
    } catch (errMessage) {
      console.error(errMessage)
    }
  },

  async removeAllExplore({ commit }) {
    try {
      await DBExploreHandlers.deleteAll()
      commit('setExploreCache', [])
      commit('setExploreCacheById', {})
    } catch (errMessage) {
      console.error(errMessage)
    }
  }
}

const mutations = {
  setExploreCache(state, exploreCache) {
    state.exploreCache = exploreCache
  },

  setExploreCacheById(state, exploreCacheById) {
    state.exploreCacheById = exploreCacheById
  },

  upsertToExploreCache(state, record) {
    const i = state.exploreCache.findIndex((currentRecord) => {
      return record.videoId === currentRecord.videoId
    })

    if (i !== -1) {
      state.exploreCache[i] = record
    } else {
      state.exploreCache.unshift(record)
    }

    state.exploreCacheById[record.videoId] = record
  },

  removeFromExploreCacheById(state, videoId) {
    for (let i = 0; i < state.exploreCache.length; i++) {
      if (state.exploreCache[i].videoId === videoId) {
        state.exploreCache.splice(i, 1)
        break
      }
    }

    delete state.exploreCacheById[videoId]
  }
}

export default {
  state,
  getters,
  actions,
  mutations
}
JSEOF

echo "  ✓ Created Explore.vue, Explore.css, explore.js"

echo ""
echo "===== STEP 2: Modifying existing files ====="

# Use Node.js for reliable string manipulation
cat > /tmp/modify-explore.mjs << 'NODEEOF'
import fs from 'fs'
import path from 'path'
import { execSync } from 'child_process'

const root = process.cwd()

function modifyFile(filePath, findString, replaceString) {
  const fullPath = path.join(root, filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`File not found: ${filePath}`)
  }
  const content = fs.readFileSync(fullPath, 'utf8')
  if (!content.includes(findString)) {
    throw new Error(`Could not find expected string in ${filePath}`)
  }
  const newContent = content.replace(findString, replaceString)
  fs.writeFileSync(fullPath, newContent)
  console.log(`  ✓ Modified ${filePath}`)
}

// === 1. constants.js — Add IPC channels ===
modifyFile(
  'src/constants.js',
  "  DB_SUBSCRIPTION_CACHE: 'db-subscription-cache',",
  "  DB_SUBSCRIPTION_CACHE: 'db-subscription-cache',\n  DB_EXPLORE: 'db-explore',"
)
modifyFile(
  'src/constants.js',
  "  SYNC_SUBSCRIPTION_CACHE: 'sync-subscription-cache',",
  "  SYNC_SUBSCRIPTION_CACHE: 'sync-subscription-cache',\n  SYNC_EXPLORE: 'sync-explore',"
)

// === 2. datastores/index.js — Add explore datastore ===
modifyFile(
  'src/datastores/index.js',
  "export const subscriptionCache = createDatastore('subscription-cache')",
  "export const subscriptionCache = createDatastore('subscription-cache')\nexport const explore = createDatastore('explore')"
)
modifyFile(
  'src/datastores/index.js',
  '    db.subscriptionCache.loadDatabaseAsync(),\n  ])',
  '    db.subscriptionCache.loadDatabaseAsync(),\n    db.explore.loadDatabaseAsync(),\n  ])'
)
modifyFile(
  'src/datastores/index.js',
  '    db.subscriptionCache.compactDatafileAsync(),\n  ])',
  '    db.subscriptionCache.compactDatafileAsync(),\n    db.explore.compactDatafileAsync(),\n  ])'
)

// === 3. datastores/handlers/base.js — Add Explore class ===
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
  '  SubscriptionCache as subscriptionCache,\n\n  loadDatastores,',
  '  SubscriptionCache as subscriptionCache,\n  Explore as explore,\n\n  loadDatastores,'
)

// === 4. datastores/handlers/electron.js — Add Explore handler ===
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

// === 5. datastores/handlers/web.js — Add explore to re-export ===
modifyFile(
  'src/datastores/handlers/web.js',
  "export { history, profiles, playlists, searchHistory, subscriptionCache } from './base'",
  "export { history, profiles, playlists, searchHistory, subscriptionCache, explore } from './base'"
)

// === 6. datastores/handlers/index.js — Add explore to exports ===
modifyFile(
  'src/datastores/handlers/index.js',
  `  subscriptionCache as DBSubscriptionCacheHandlers,
} from 'DB_HANDLERS_ELECTRON_RENDERER_OR_WEB'`,
  `  subscriptionCache as DBSubscriptionCacheHandlers,
  explore as DBExploreHandlers,
} from 'DB_HANDLERS_ELECTRON_RENDERER_OR_WEB'`
)

// === 7. preload/interface.js — Add dbExplore and handleSyncExplore ===
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

// === 8. main/index.js — Add IPC handler for DB_EXPLORE ===
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

// === 9. store/index.js — Register explore module ===
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

// === 10. settings.js — Add hideWatchedExplore setting ===
modifyFile(
  'src/renderer/store/modules/settings.js',
  '  hideWatchedSubs: false,',
  '  hideWatchedSubs: false,\n  hideWatchedExplore: true,'
)

// === 10b. settings.js — Add explore sync listener ===
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

// === 11. router/index.js — Add Explore route ===
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

// === 12. SideNav.vue — Add Explore nav entry ===
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

// === 13. Watch.js — Add capture hook ===
// 13a. Call after local API recommendedVideos
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

// 13b. Call after invidious API recommendedVideos
modifyFile(
  'src/renderer/views/Watch/Watch.js',
  `          // place watched recommended videos last
          this.recommendedVideos = recommendedVideos.sort(this.sortWatchedVideosLast)`,
  `          // place watched recommended videos last
          this.recommendedVideos = recommendedVideos.sort(this.sortWatchedVideosLast)

          this.archiveRecommendedVideos()`
)

// 13c. Add archiveRecommendedVideos method
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

// 13d. Add addToExplore to mapActions
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

// === 14. en-US.yaml — Add Explore locale strings ===
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

// === 15. Find grabHistory dispatch and add grabExplore ===
try {
  const grepResult = execSync(
    'grep -rn "grabHistory" src/renderer/ --include="*.vue" --include="*.js" 2>/dev/null || true',
    { encoding: 'utf8' }
  )
  if (grepResult.trim()) {
    console.log('  Found grabHistory dispatches:')
    grepResult.trim().split('\n').forEach(line => {
      console.log('    ' + line)
    })

    // Try to add grabExplore alongside grabHistory in each file
    const files = new Set()
    grepResult.trim().split('\n').forEach(line => {
      const match = line.match(/^([^:]+):/)
      if (match) files.add(match[1])
    })

    for (const file of files) {
      const fullPath = path.join(root, file)
      if (!fs.existsSync(fullPath)) continue

      const content = fs.readFileSync(fullPath, 'utf8')

      // Look for patterns like: dispatch('grabHistory') or store.dispatch('grabHistory')
      // and add grabExplore alongside
      if (content.includes("dispatch('grabHistory')")) {
        const newContent = content.replace(
          /dispatch\('grabHistory'\)/g,
          "dispatch('grabHistory')\n      await store.dispatch('grabExplore')"
        )
        // Only write if the replacement actually changed something and grabExplore isn't already there
        if (newContent !== content && !newContent.includes("dispatch('grabExplore')\n      await store.dispatch('grabExplore')\n      await store.dispatch('grabExplore')")) {
          fs.writeFileSync(fullPath, newContent)
          console.log(`  ✓ Added grabExplore to ${file}`)
        }
      }
    }
  } else {
    console.log('  ℹ grabHistory not found — Explore page will load data on mount')
  }
} catch (e) {
  console.log('  ℹ Could not search for grabHistory — Explore page will load data on mount')
}

console.log('\nAll modifications complete!')
NODEEOF

node /tmp/modify-explore.mjs

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
