#!/bin/bash
set -euo pipefail
cd ~/FreeTube

echo "===== STEP 1: Add discoverPageSize setting to settings.js ====="
cat > /tmp/add-pagesize.mjs << 'NODEEOF'
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

// Add discoverPageSize to state (auto-generates getter/setter/action)
modifyFile(
  'src/renderer/store/modules/settings.js',
  '  hideWatchedDiscover: true,',
  '  hideWatchedDiscover: true,\n  discoverPageSize: 24,'
)

// Add locale strings
modifyFile(
  'static/locales/en-US.yaml',
  '  Over 60 Minutes: Over 60 Minutes',
  `  Over 60 Minutes: Over 60 Minutes
  Page Size: Videos per page
  Shuffle: Shuffle`
)

console.log('Settings and locale updated!')
NODEEOF

node /tmp/add-pagesize.mjs

echo ""
echo "===== STEP 2: Rewrite Discover.vue with page size limiting ====="
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
        <label class="discoverFilterLabel">
          {{ $t("Discover.Page Size") }}
          <input
            v-model.number="pageSizeInput"
            type="number"
            min="3"
            max="100"
            class="discoverPageSizeInput"
            @change="updatePageSize"
          >
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
import { computed, onMounted, ref, shallowRef, watch } from 'vue'
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

const pageSize = computed(() => {
  return store.getters.getDiscoverPageSize
})

const pageSizeInput = ref(pageSize.value)

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

  return results.slice(0, pageSize.value)
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

function updatePageSize() {
  let val = pageSizeInput.value
  if (val < 3) val = 3
  if (val > 100) val = 100
  pageSizeInput.value = val
  store.dispatch('updateDiscoverPageSize', val)
}

function clearDiscover() {
  if (confirm(t('Discover.Clear Discover Confirm'))) {
    store.dispatch('removeAllDiscover')
    shuffledResults.value = []
    showToast(t('Discover.Cleared'))
  }
}

// Keep pageSizeInput in sync if the store value changes elsewhere
watch(pageSize, (newVal) => {
  pageSizeInput.value = newVal
})

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
echo "===== STEP 3: Update Discover.css with page size input styles ====="
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

.discoverPageSizeInput {
  width: 60px;
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
echo "===== STEP 4: Verification ====="
echo "--- discoverPageSize in settings.js ---"
grep -n "discoverPageSize" src/renderer/store/modules/settings.js

echo ""
echo "--- Page Size locale string ---"
grep -n "Page Size" static/locales/en-US.yaml

echo ""
echo "--- shownResults slice in Discover.vue ---"
grep -n "slice\|pageSize" src/renderer/views/Discover/Discover.vue

echo ""
echo "--- Git diff summary ---"
git diff --stat

echo ""
echo "===== DONE ====="
echo "To test: cd ~/FreeTube && pnpm run dev"
echo ""
echo "Changes:"
echo "  - Discover page now shows a limited batch (default 24 videos)"
echo "  - Shuffle button gives you a new batch of the same size"
echo "  - Number input on the page lets you adjust batch size (3-100)"
echo "  - Setting persists across sessions via the settings DB"
echo "  - Filters apply first, then results are sliced to page size"
