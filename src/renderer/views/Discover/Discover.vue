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
      </FtFlexBox>
      <p
        v-if="!isLoading && shownResults.length > 0"
        class="discoverCount"
      >
        {{ $t("Discover.Showing Results", { shown: shownResults.length, total: orderedResults.length }) }}
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
        v-if="!isLoading && visibleCount < orderedResults.length"
        ref="sentinelRef"
        class="discoverSentinel"
      />
    </FtCard>
  </div>
</template>

<script setup>
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useTemplateRef, watch } from 'vue'

import FtCard from '../../components/ft-card/ft-card.vue'
import FtLoader from '../../components/FtLoader/FtLoader.vue'
import FtElementList from '../../components/FtElementList/FtElementList.vue'
import FtFlexBox from '../../components/ft-flex-box/ft-flex-box.vue'

import store from '../../store/index'

// Infinite scroll: how many results are revealed at first, and how many
// more the sentinel loads per intersection.
const INITIAL_VISIBLE = 24
const LOAD_STEP = 12
// Feed ordering: within each freshness bucket a share of the slots are
// filled from a random queue of the WHOLE (filtered) catalog, so older
// videos still surface. The rest keep "most recently recommended" order.
const RANDOM_SHARE = 0.2

// Freshness buckets, newest first. A video lands in the bucket matching
// its most recent recommendation timestamp (archivedAt); videos without a
// timestamp fall into the last bucket.
const BUCKETS = [
  { maxAgeMs: 86400000 },
  { maxAgeMs: 604800000 },
  { maxAgeMs: 2592000000 },
  { maxAgeMs: Infinity }
]

const isLoading = ref(true)
const visibleCount = ref(INITIAL_VISIBLE)
const videoLengthFilter = ref(store.getters.getDiscoverVideoLengthFilter || 'any')

const discoverCache = computed(() => {
  return store.getters.getDiscoverCache
})

const historyCacheById = computed(() => {
  return store.getters.getHistoryCacheById
})

// Seeded PRNG so one "deal" stays stable across reactive re-computations
// instead of re-randomizing on every update. A fresh seed is rolled each
// time the page is mounted (i.e. every visit).
const blendSeed = ref(1)

const LENGTH_FILTERS = {
  short: (len) => len < 240,
  medium: (len) => len >= 240 && len < 1200,
  long: (len) => len >= 1200 && len < 3600,
  extra: (len) => len >= 3600
}

// Watched videos are always hidden: Discover is a "find me new stuff" feed.
const filteredResults = computed(() => {
  let results = [...discoverCache.value]

  if (videoLengthFilter.value !== 'any') {
    const filterFn = LENGTH_FILTERS[videoLengthFilter.value]
    results = results.filter(video => {
      if (video.liveNow || video.isUpcoming) return false
      const len = typeof video.lengthSeconds === 'number' ? video.lengthSeconds : 0
      if (len === 0) return false
      return filterFn(len)
    })
  }

  return results.filter(video => !Object.hasOwn(historyCacheById.value, video.videoId))
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

// Deal the feed bucket by bucket (newest first): each bucket block keeps
// ~80% of its videos in "most recently recommended" order and fills ~20%
// of its slots from a random queue of the whole filtered catalog. Every
// video appears exactly once; empty buckets are skipped silently.
const orderedResults = computed(() => {
  const results = filteredResults.value
  const total = results.length

  if (total === 0) return []

  const now = Date.now()
  const random = mulberry32(blendSeed.value)

  // Newest first, so each bucket block is internally time-ordered
  const resultsNewestFirst = [...results].sort((a, b) => (b.archivedAt ?? 0) - (a.archivedAt ?? 0))

  const buckets = BUCKETS.map(() => [])
  for (const video of resultsNewestFirst) {
    const age = video.archivedAt ? now - video.archivedAt : Infinity
    let placed = false
    for (let b = 0; b < BUCKETS.length; b++) {
      if (age < BUCKETS[b].maxAgeMs) {
        buckets[b].push(video)
        placed = true
        break
      }
    }
    if (!placed) {
      buckets[buckets.length - 1].push(video)
    }
  }

  const randomQueue = seededShuffle(results, random)
  let randomCursor = 0
  const ordered = []
  const taken = new Set()

  const takeRandom = () => {
    while (randomCursor < total && taken.has(randomQueue[randomCursor].videoId)) randomCursor++
    const video = randomQueue[randomCursor]
    randomCursor++
    taken.add(video.videoId)
    return video
  }

  for (const bucket of buckets) {
    const len = bucket.length
    if (len === 0) continue

    const randomSlotCount = len >= 2 ? Math.round(len * RANDOM_SHARE) : 0
    const randomSlots = new Set(seededShuffle([...Array(len).keys()], random).slice(0, randomSlotCount))

    // Advance past bucket videos that a random slot already claimed
    let keptCursor = 0

    for (let i = 0; i < len; i++) {
      if (randomSlots.has(i)) {
        ordered.push(takeRandom())
      } else {
        while (keptCursor < len && taken.has(bucket[keptCursor].videoId)) keptCursor++
        if (keptCursor < len) {
          const video = bucket[keptCursor]
          keptCursor++
          taken.add(video.videoId)
          ordered.push(video)
        } else {
          // Bucket supply exhausted (its videos were all claimed by random
          // slots) — top up from the global random queue instead
          ordered.push(takeRandom())
        }
      }
    }
  }

  return ordered
})

const shownResults = computed(() => {
  return orderedResults.value.slice(0, visibleCount.value)
})

// Persist the length filter across sessions; changing it re-reveals from the top
watch(videoLengthFilter, (newVal) => {
  store.dispatch('updateDiscoverVideoLengthFilter', newVal)
  visibleCount.value = INITIAL_VISIBLE
})

// Infinite scroll: reveal more results when the sentinel at the bottom of
// the list approaches the viewport (window-level scroll, like YouTube).
const sentinelRef = useTemplateRef('sentinelRef')
let sentinelObserver = null

function loadMoreResults() {
  if (visibleCount.value < orderedResults.value.length) {
    visibleCount.value = Math.min(visibleCount.value + LOAD_STEP, orderedResults.value.length)
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
  // Fresh deal on every visit
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
