#!/bin/bash
set -euo pipefail
cd ~/FreeTube

echo "===== STEP 1: Rename files ====="
mkdir -p src/renderer/views/Discover
mv src/renderer/views/Explore/Explore.vue src/renderer/views/Discover/Discover.vue
mv src/renderer/views/Explore/Explore.css src/renderer/views/Discover/Discover.css
rmdir src/renderer/views/Explore
mv src/renderer/store/modules/explore.js src/renderer/store/modules/discover.js
echo "  ✓ Renamed Explore/ → Discover/, explore.js → discover.js"

echo ""
echo "===== STEP 2: Global string replacements ====="
cat > /tmp/rename-to-discover.mjs << 'NODEEOF'
import fs from 'fs'
import path from 'path'

const root = process.cwd()

const files = [
  'src/constants.js',
  'src/datastores/index.js',
  'src/datastores/handlers/base.js',
  'src/datastores/handlers/electron.js',
  'src/datastores/handlers/web.js',
  'src/datastores/handlers/index.js',
  'src/preload/interface.js',
  'src/main/index.js',
  'src/renderer/store/index.js',
  'src/renderer/store/modules/settings.js',
  'src/renderer/store/modules/discover.js',
  'src/renderer/router/index.js',
  'src/renderer/components/SideNav/SideNav.vue',
  'src/renderer/views/Watch/Watch.js',
  'src/renderer/views/Discover/Discover.vue',
  'src/renderer/views/Discover/Discover.css',
  'static/locales/en-US.yaml'
]

// Order matters: uppercase first, then PascalCase, then lowercase
const replacements = [
  ['DB_EXPLORE', 'DB_DISCOVER'],
  ['SYNC_EXPLORE', 'SYNC_DISCOVER'],
  ['Explore', 'Discover'],
  ['explore', 'discover']
]

for (const file of files) {
  const fullPath = path.join(root, file)
  if (!fs.existsSync(fullPath)) {
    console.log(`  ⊙ Skipped (not found): ${file}`)
    continue
  }
  let content = fs.readFileSync(fullPath, 'utf8')
  let modified = false
  for (const [find, replace] of replacements) {
    if (content.includes(find)) {
      content = content.split(find).join(replace)
      modified = true
    }
  }
  if (modified) {
    fs.writeFileSync(fullPath, content)
    console.log(`  ✓ ${file}`)
  } else {
    console.log(`  ⊙ No changes: ${file}`)
  }
}

// Add new locale strings to en-US.yaml
const localeFile = path.join(root, 'static/locales/en-US.yaml')
let localeContent = fs.readFileSync(localeFile, 'utf8')

const noVideosLine = "  No Videos: 'No videos to discover yet. Watch some videos and their \"Up Next\" recommendations will appear here!'"
const newLocaleStrings = `  No Videos: 'No videos to discover yet. Watch some videos and their "Up Next" recommendations will appear here!'
  Clear Discover: Clear Discover
  Clear Discover Confirm: 'Are you sure you want to clear your Discover feed? This cannot be undone.'
  Cleared: Discover feed cleared
  Upload Date: Upload Date
  Video Length: Video Length
  Any Time: Any Time
  Last 24 Hours: Last 24 Hours
  Last 7 Days: Last 7 Days
  Last 30 Days: Last 30 Days
  Last 90 Days: Last 90 Days
  Any Length: Any Length
  Under 4 Minutes: Under 4 Minutes
  4-20 Minutes: 4-20 Minutes
  20-60 Minutes: 20-60 Minutes
  Over 60 Minutes: Over 60 Minutes`

if (localeContent.includes(noVideosLine)) {
  localeContent = localeContent.replace(noVideosLine, newLocaleStrings)
  fs.writeFileSync(localeFile, localeContent)
  console.log('  ✓ static/locales/en-US.yaml (new strings added)')
} else if (localeContent.includes('Clear Discover:')) {
  console.log('  ⊙ Locale strings already added')
} else {
  console.log('  ⚠ Could not find No Videos line in locale file')
}

console.log('\nString replacements complete!')
NODEEOF

node /tmp/rename-to-discover.mjs

echo ""
echo "===== STEP 3: Write enhanced Discover.vue ====="
cat > src/renderer/views/Discover/Discover.vue << 'VUEEOF'
<template>
  <div>
    <FtCard
      class="card"
    >
      <h2>
        <FontAwesomeIcon
          :icon="['fas', 'compass']"
          class="headingIcon"
        />
        {{ $t("Discover.Discover") }}
      </h2>
      <FtFlexBox
        class="discoverControls"
      >
        <button
          class="discoverShuffleButton"
          :disabled="isLoading || discoverCache.length === 0"
          @click="shuffleDiscover"
        >
          <FontAwesomeIcon :icon="['fas', 'shuffle']" />
          {{ $t("Discover.Shuffle") }}
        </button>
        <label class="discoverFilterLabel">
          {{ $t("Discover.Upload Date") }}
          <select
            v-model="uploadDateFilter"
            class="discoverFilter"
          >
            <option value="any">
              {{ $t("Discover.Any Time") }}
            </option>
            <option value="24h">
              {{ $t("Discover.Last 24 Hours") }}
            </option>
            <option value="7d">
              {{ $t("Discover.Last 7 Days") }}
            </option>
            <option value="30d">
              {{ $t("Discover.Last 30 Days") }}
            </option>
            <option value="90d">
              {{ $t("Discover.Last 90 Days") }}
            </option>
          </select>
        </label>
        <label class="discoverFilterLabel">
          {{ $t("Discover.Video Length") }}
          <select
            v-model="videoLengthFilter"
            class="discoverFilter"
          >
            <option value="any">
              {{ $t("Discover.Any Length") }}
            </option>
            <option value="short">
              {{ $t("Discover.Under 4 Minutes") }}
            </option>
            <option value="medium">
              {{ $t("Discover.4-20 Minutes") }}
            </option>
            <option value="long">
              {{ $t("Discover.20-60 Minutes") }}
            </option>
            <option value="extra">
              {{ $t("Discover.Over 60 Minutes") }}
            </option>
          </select>
        </label>
        <label class="discoverHideWatchedLabel">
          <input
            type="checkbox"
            :checked="hideWatchedDiscover"
            @change="toggleHideWatched"
          >
          {{ $t("Discover.Hide Watched") }}
        </label>
        <button
          class="discoverClearButton"
          :disabled="isLoading || discoverCache.length === 0"
          @click="clearDiscover"
        >
          <FontAwesomeIcon :icon="['fas', 'trash']" />
          {{ $t("Discover.Clear Discover") }}
        </button>
      </FtFlexBox>
      <FtLoader
        v-if="isLoading"
      />
      <div
        v-else-if="shownResults.length === 0"
        class="discoverEmpty"
      >
        <p>{{ $t("Discover.No Videos") }}</p>
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
import { showToast } from '../../helpers/utils'

const { t } = useI18n()

const isLoading = ref(true)
const shuffledResults = shallowRef([])
const uploadDateFilter = ref('any')
const videoLengthFilter = ref('any')

const discoverCache = computed(() => {
  return store.getters.getDiscoverCache
})

const hideWatchedDiscover = computed(() => {
  return store.getters.getHideWatchedDiscover
})

const historyCacheById = computed(() => {
  return store.getters.getHistoryCacheById
})

const UPLOAD_DATE_RANGES = {
  '24h': 86400000,
  '7d': 604800000,
  '30d': 2592000000,
  '90d': 7776000000
}

const LENGTH_FILTERS = {
  short: (len) => len < 240,
  medium: (len) => len >= 240 && len < 1200,
  long: (len) => len >= 1200 && len < 3600,
  extra: (len) => len >= 3600
}

const shownResults = computed(() => {
  let results = shuffledResults.value

  if (uploadDateFilter.value !== 'any') {
    const cutoff = Date.now() - UPLOAD_DATE_RANGES[uploadDateFilter.value]
    results = results.filter(video => video.published && video.published >= cutoff)
  }

  if (videoLengthFilter.value !== 'any') {
    const filterFn = LENGTH_FILTERS[videoLengthFilter.value]
    results = results.filter(video => {
      if (video.liveNow || video.isUpcoming) return false
      const len = typeof video.lengthSeconds === 'number' ? video.lengthSeconds : 0
      if (len === 0) return false
      return filterFn(len)
    })
  }

  if (hideWatchedDiscover.value) {
    results = results.filter(video => !Object.hasOwn(historyCacheById.value, video.videoId))
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

function shuffleDiscover() {
  shuffledResults.value = shuffleArray(discoverCache.value)
}

function toggleHideWatched() {
  store.dispatch('updateHideWatchedDiscover', !hideWatchedDiscover.value)
}

function clearDiscover() {
  if (confirm(t('Discover.Clear Discover Confirm'))) {
    store.dispatch('removeAllDiscover')
    shuffledResults.value = []
    showToast(t('Discover.Cleared'))
  }
}

onMounted(async () => {
  await store.dispatch('grabDiscover')
  shuffleDiscover()
  isLoading.value = false
})
</script>

<style scoped src="./Discover.css" />
VUEEOF
echo "  ✓ Wrote Discover.vue"

echo ""
echo "===== STEP 4: Write enhanced Discover.css ====="
cat > src/renderer/views/Discover/Discover.css << 'CSSEOF'
.card {
  padding: 20px;
}

.headingIcon {
  margin-inline-end: 8px;
}

.discoverControls {
  margin-block: 16px;
  gap: 16px;
  align-items: center;
  flex-wrap: wrap;
}

.discoverShuffleButton {
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

.discoverShuffleButton:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.discoverFilterLabel {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
}

.discoverFilter {
  padding: 6px 8px;
  border-radius: 4px;
  background: var(--primary-input-color);
  color: var(--primary-text-color);
  border: none;
  font-size: 14px;
  cursor: pointer;
}

.discoverHideWatchedLabel {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-size: 14px;
}

.discoverClearButton {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  background: transparent;
  color: var(--accent-color, #e53935);
  margin-inline-start: auto;
}

.discoverClearButton:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.discoverClearButton:hover:not(:disabled) {
  text-decoration: underline;
}

.discoverEmpty {
  text-align: center;
  padding: 40px 20px;
  color: var(--secondary-text-color);
}
CSSEOF
echo "  ✓ Wrote Discover.css"

echo ""
echo "===== STEP 5: Write enhanced discover.js store module ====="
cat > src/renderer/store/modules/discover.js << 'JSEOF'
import { DBDiscoverHandlers } from '../../../datastores/handlers/index'

const state = {
  discoverCache: [],
  discoverCacheById: {}
}

const getters = {
  getDiscoverCache(state) {
    return state.discoverCache
  },

  getDiscoverCacheById(state) {
    return state.discoverCacheById
  }
}

const actions = {
  async grabDiscover({ commit }) {
    try {
      const results = await DBDiscoverHandlers.find()

      const resultsById = {}
      results.forEach(video => {
        resultsById[video.videoId] = video
      })

      commit('setDiscoverCache', results)
      commit('setDiscoverCacheById', resultsById)
    } catch (errMessage) {
      console.error(errMessage)
    }
  },

  async addToDiscover({ commit }, record) {
    try {
      await DBDiscoverHandlers.upsert(record)
      commit('upsertToDiscoverCache', record)
    } catch (errMessage) {
      console.error(errMessage)
    }
  },

  async removeFromDiscover({ commit }, videoId) {
    try {
      await DBDiscoverHandlers.delete(videoId)
      commit('removeFromDiscoverCacheById', videoId)
    } catch (errMessage) {
      console.error(errMessage)
    }
  },

  async removeAllDiscover({ commit }) {
    try {
      await DBDiscoverHandlers.deleteAll()
      commit('setDiscoverCache', [])
      commit('setDiscoverCacheById', {})
    } catch (errMessage) {
      console.error(errMessage)
    }
  }
}

const mutations = {
  setDiscoverCache(state, discoverCache) {
    state.discoverCache = discoverCache
  },

  setDiscoverCacheById(state, discoverCacheById) {
    state.discoverCacheById = discoverCacheById
  },

  upsertToDiscoverCache(state, record) {
    const i = state.discoverCache.findIndex((currentRecord) => {
      return record.videoId === currentRecord.videoId
    })

    if (i !== -1) {
      state.discoverCache[i] = record
    } else {
      state.discoverCache.unshift(record)
    }

    state.discoverCacheById[record.videoId] = record
  },

  removeFromDiscoverCacheById(state, videoId) {
    for (let i = 0; i < state.discoverCache.length; i++) {
      if (state.discoverCache[i].videoId === videoId) {
        state.discoverCache.splice(i, 1)
        break
      }
    }

    delete state.discoverCacheById[videoId]
  }
}

export default {
  state,
  getters,
  actions,
  mutations
}
JSEOF
echo "  ✓ Wrote discover.js"

echo ""
echo "===== STEP 6: Verification ====="
echo "--- Old Explore directory gone? ---"
ls src/renderer/views/Explore/ 2>/dev/null && echo "⚠ Explore/ still exists!" || echo "  ✓ Explore/ removed"

echo ""
echo "--- New Discover directory ---"
ls -la src/renderer/views/Discover/

echo ""
echo "--- discover.js store module ---"
ls -la src/renderer/store/modules/discover.js

echo ""
echo "--- Git diff summary ---"
git diff --stat
git status --short

echo ""
echo "--- Spot checks ---"
echo "constants.js DB_DISCOVER:"
grep -n "DB_DISCOVER\|SYNC_DISCOVER" src/constants.js
echo ""
echo "router /discover route:"
grep -n "discover" src/renderer/router/index.js
echo ""
echo "SideNav /discover link:"
grep -n "discover\|Discover" src/renderer/components/SideNav/SideNav.vue
echo ""
echo "Watch.js addToDiscover:"
grep -n "addToDiscover\|archiveRecommendedVideos" src/renderer/views/Watch/Watch.js
echo ""
echo "datastore discover:"
grep -n "discover" src/datastores/index.js
echo ""
echo "store module registered:"
grep -n "discover" src/renderer/store/index.js

echo ""
echo "===== DONE ====="
echo "Note: The old explore.db file in your FreeTube profile is now orphaned."
echo "A new discover.db will be created when you run the app."
echo ""
echo "To test, run: cd ~/FreeTube && pnpm run dev"
echo ""
echo "What changed:"
echo "  - Renamed Explore → Discover everywhere (datastore, IPC, store, route, sidebar, locale)"
echo "  - Added upload date filter (Any time, 24h, 7d, 30d, 90d)"
echo "  - Added video length filter (Any, <4min, 4-20min, 20-60min, >60min)"
echo "  - Added Clear Discover button with confirmation"
echo "  - Added 13 new locale strings"
