<template>
  <div>
    <FtCard
      class="card"
    >
      <h2>
        <FontAwesomeIcon
          :icon="['fas', 'binoculars']"
          class="headingIcon"
        />
        {{ $t("Discover.Discover") }}
      </h2>
      <FtFlexBox
        class="discoverControls"
      >
        <button
          class="discoverShuffleButton"
          :disabled="isLoading || filteredResults.length === 0"
          @click="shuffleDiscover"
        >
          <FontAwesomeIcon :icon="['fas', 'shuffle']" />
          {{ $t("Discover.Shuffle") }}
        </button>
        <label class="discoverFilterLabel">
          {{ $t("Discover.Date Added") }}
          <select
            v-model="dateAddedFilter"
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
      <p
        v-if="!isLoading && filteredResults.length > 0"
        class="discoverCount"
      >
        {{ $t("Discover.Showing Results", { shown: shownResults.length, total: filteredResults.length }) }}
      </p>
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
      <div
        v-if="!isLoading && visibleCount < filteredResults.length"
        ref="sentinelRef"
        class="discoverSentinel"
      />
    </FtCard>
  </div>
</template>

<script setup>
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useTemplateRef, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import FtCard from '../../components/ft-card/ft-card.vue'
import FtLoader from '../../components/FtLoader/FtLoader.vue'
import FtElementList from '../../components/FtElementList/FtElementList.vue'
import FtFlexBox from '../../components/ft-flex-box/ft-flex-box.vue'

import store from '../../store/index'
import { showToast } from '../../helpers/utils'

const { t } = useI18n()

// Infinite scroll: how many results are revealed at first, and how many
// more the sentinel loads per intersection.
const INITIAL_VISIBLE = 24
const LOAD_STEP = 12
// Feed ordering: a share of the slots keep the "most recently recommended"
// order, the rest are dealt from random slots of the catalog.
const RANDOM_SHARE = 0.2

const isLoading = ref(true)
const visibleCount = ref(INITIAL_VISIBLE)
const uploadDateFilter = ref(store.getters.getDiscoverUploadDateFilter || 'any')
const videoLengthFilter = ref(store.getters.getDiscoverVideoLengthFilter || 'any')
const dateAddedFilter = ref(store.getters.getDiscoverDateAddedFilter || 'any')

const discoverCache = computed(() => {
  return store.getters.getDiscoverCache
})

const hideWatchedDiscover = computed(() => {
  return store.getters.getHideWatchedDiscover
})

const historyCacheById = computed(() => {
  return store.getters.getHistoryCacheById
})

// Seeded PRNG so a given "deal" stays stable across reactive
// re-computations instead of re-randomizing on every update.
const blendSeed = ref(1)

// Shared range map: used by BOTH the Upload Date filter and the Date Added filter
const TIME_RANGES_MS = {
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

const filteredResults = computed(() => {
  // The DB query returns videos sorted by archivedAt (last recommended)
  // desc; re-sort defensively in case the cache order ever differs.
  let results = [...discoverCache.value].sort((a, b) => (b.archivedAt ?? 0) - (a.archivedAt ?? 0))

  if (uploadDateFilter.value !== 'any') {
    const cutoff = Date.now() - TIME_RANGES_MS[uploadDateFilter.value]
    results = results.filter(video => video.published && video.published >= cutoff)
  }

  if (dateAddedFilter.value !== 'any') {
    const cutoff = Date.now() - TIME_RANGES_MS[dateAddedFilter.value]
    results = results.filter(video => video.archivedAt && video.archivedAt >= cutoff)
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

function mulberry32(seed) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6D2B79F5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function seededShuffle(array, random) {
  const arr = [...array]
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

// Deal the feed: ~80% of the slots keep the "most recently recommended"
// ordering, while ~20% are pulled at random from anywhere in the catalog,
// so older videos still surface.
const blendedResults = computed(() => {
  const results = filteredResults.value
  const total = results.length

  if (total === 0) return []

  const random = mulberry32(blendSeed.value)
  const randomQueue = seededShuffle(results, random)
  const randomSlotCount = total >= 2 ? Math.round(total * RANDOM_SHARE) : 0
  const randomSlots = new Set(seededShuffle([...Array(total).keys()], random).slice(0, randomSlotCount))

  const ordered = []
  const taken = new Set()
  let randomCursor = 0
  let newestCursor = 0

  for (let i = 0; i < total; i++) {
    if (randomSlots.has(i)) {
      while (randomCursor < total && taken.has(randomQueue[randomCursor])) randomCursor++
      ordered.push(randomQueue[randomCursor])
      taken.add(randomQueue[randomCursor])
      randomCursor++
    } else {
      while (newestCursor < total && taken.has(results[newestCursor])) newestCursor++
      ordered.push(results[newestCursor])
      taken.add(results[newestCursor])
      newestCursor++
    }
  }

  return ordered
})

const shownResults = computed(() => {
  return blendedResults.value.slice(0, visibleCount.value)
})

function shuffleDiscover() {
  blendSeed.value = Math.floor(Math.random() * 0xFFFFFFFF)
  visibleCount.value = INITIAL_VISIBLE
  window.scrollTo({ top: 0 })
}

// Persist filter selections across sessions
watch(uploadDateFilter, (newVal) => {
  store.dispatch('updateDiscoverUploadDateFilter', newVal)
  visibleCount.value = INITIAL_VISIBLE
})

watch(videoLengthFilter, (newVal) => {
  store.dispatch('updateDiscoverVideoLengthFilter', newVal)
  visibleCount.value = INITIAL_VISIBLE
})

watch(dateAddedFilter, (newVal) => {
  store.dispatch('updateDiscoverDateAddedFilter', newVal)
  visibleCount.value = INITIAL_VISIBLE
})

watch(hideWatchedDiscover, () => {
  visibleCount.value = INITIAL_VISIBLE
})

function toggleHideWatched() {
  store.dispatch('updateHideWatchedDiscover', !hideWatchedDiscover.value)
}

function clearDiscover() {
  if (confirm(t('Discover.Clear Discover Confirm'))) {
    store.dispatch('removeAllDiscover')
    showToast(t('Discover.Cleared'))
  }
}

// Infinite scroll: reveal more results when the sentinel at the bottom of
// the list approaches the viewport (window-level scroll, like YouTube).
const sentinelRef = useTemplateRef('sentinelRef')
let sentinelObserver = null

function loadMoreResults() {
  if (visibleCount.value < filteredResults.value.length) {
    visibleCount.value = Math.min(visibleCount.value + LOAD_STEP, filteredResults.value.length)
  }
}

function setupSentinelObserver() {
  if (sentinelObserver) {
    sentinelObserver.disconnect()
    sentinelObserver = null
  }

  if (!sentinelRef.value) {
    return
  }

  sentinelObserver = new IntersectionObserver(
    (entries) => {
      if (entries.some(entry => entry.isIntersecting)) {
        loadMoreResults()
      }
    },
    { root: null, rootMargin: '600px 0px' }
  )

  sentinelObserver.observe(sentinelRef.value)
}

watch(sentinelRef, (el) => {
  if (el) {
    setupSentinelObserver()
  } else if (sentinelObserver) {
    sentinelObserver.disconnect()
    sentinelObserver = null
  }
})

onMounted(async () => {
  await store.dispatch('grabDiscover')
  blendSeed.value = Math.floor(Math.random() * 0xFFFFFFFF)
  isLoading.value = false
  await nextTick()
  setupSentinelObserver()
})

onBeforeUnmount(() => {
  if (sentinelObserver) {
    sentinelObserver.disconnect()
    sentinelObserver = null
  }
})
</script>

<style scoped src="./Discover.css" />
