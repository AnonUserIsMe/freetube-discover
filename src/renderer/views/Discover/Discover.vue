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
          {{ $t("Discover.Sort") }}
          <select
            v-model="sortMode"
            class="discoverFilter"
          >
            <option value="shuffle">
              {{ $t("Discover.Shuffle") }}
            </option>
            <option value="newest">
              {{ $t("Discover.Newest Added") }}
            </option>
          </select>
        </label>
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
      <p
        v-if="!isLoading && discoverCache.length > 0"
        class="discoverCount"
      >
        {{ $t("Discover.Showing Results", { shown: shownResults.length, total: discoverCache.length }) }}
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
const dateAddedFilter = ref('any')

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

// 'shuffle' (random) or 'newest' (sorted by when each video was last recommended to you).
// Persisted across sessions via the settings store.
const sortMode = ref(store.getters.getDiscoverSortMode || 'shuffle')

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

const shownResults = computed(() => {
  let results = shuffledResults.value

  // Sort first, so filters preserve the ordering of whatever survives
  if (sortMode.value === 'newest') {
    results = [...results].sort((a, b) => (b.archivedAt ?? 0) - (a.archivedAt ?? 0))
  }

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
  if (sortMode.value !== 'shuffle') {
    sortMode.value = 'shuffle'
  }
}

// Persist sort mode; switching back to shuffle deals a fresh batch
watch(sortMode, (newVal) => {
  store.dispatch('updateDiscoverSortMode', newVal)
  if (newVal === 'shuffle') {
    shuffledResults.value = shuffleArray(discoverCache.value)
  }
})

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
  if (sortMode.value === 'shuffle') {
    shuffleDiscover()
  } else {
    // DB already returns archivedAt desc; keep that order for 'newest'
    shuffledResults.value = [...discoverCache.value]
  }
  isLoading.value = false
})
</script>

<style scoped src="./Discover.css" />
