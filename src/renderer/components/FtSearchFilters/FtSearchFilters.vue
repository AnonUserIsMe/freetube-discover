<template>
  <FtPrompt
    theme="slim"
    @click="hideSearchFilters"
  >
    <template #label="{ labelId }">
      <div class="titleContainer">
        <h2
          :id="labelId"
          class="center"
        >
          {{ title }}
        </h2>
        <button
          class="clearFilterButton"
          :title="$t('Search Filters.Clear Filters')"
          :style="{visibility: (searchFilterValueChanged ? 'visible' : 'hidden')}"
          @click="clearFilters"
        >
          <FontAwesomeIcon
            class="clearFilterIcon"
            :icon="['fas', 'filter-circle-xmark']"
          />
        </button>
      </div>
    </template>

    <FtFlexBox class="radioFlexBox">
      <FtRadioButton
        v-model="typeValue"
        :title="$t('Search Filters.Type.Type')"
        :labels="typeLabels"
        :values="TYPE_VALUES"
        class="searchRadio"
      />
      <FtRadioButton
        v-model="durationValue"
        :title="$t('Search Filters.Duration.Duration')"
        :labels="durationLabels"
        :values="DURATION_VALUES"
        class="searchRadio"
      />
      <FtRadioButton
        v-model="timeValue"
        :title="$t('Search Filters.Time.Time')"
        :labels="timeLabels"
        :values="TIME_VALUES"
        class="searchRadio"
      />
      <FtCheckboxList
        v-model="featuresValue"
        :title="$t('Search Filters.Features.Features')"
        :labels="featureLabels"
        :values="FEATURES_VALUES"
        class="searchRadio"
      />
      <FtRadioButton
        v-model="prioritizeValue"
        :title="$t('Search Filters.Prioritize.Prioritize')"
        :labels="prioritizeLabels"
        :values="PRIORITIZE_VALUES"
        class="searchRadio"
      />
    </FtFlexBox>
    <div class="searchFilterCloseButtonContainer">
      <FtButton
        :label="$t('Close')"
        background-color="null"
        text-color="null"
        @click="hideSearchFilters"
      />
    </div>
  </FtPrompt>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import FtFlexBox from '../ft-flex-box/ft-flex-box.vue'
import FtRadioButton from '../FtRadioButton/FtRadioButton.vue'
import FtPrompt from '../FtPrompt/FtPrompt.vue'
import FtButton from '../FtButton/FtButton.vue'
import FtCheckboxList from '../FtCheckboxList/FtCheckboxList.vue'

import store from '../../store/index'

const { t } = useI18n()

const PRIORITIZE_VALUES = [
  'relevance',
  'popularity'
]

const TIME_VALUES = [
  '',
  'today',
  'week',
  'month',
  'year'
]

const TYPE_VALUES = [
  'all',
  'video',
  'shorts',
  'channel',
  'playlist',
  'movie'
]

const DURATION_VALUES = [
  '',
  'under_three_mins',
  'three_to_twenty_mins',
  'over_twenty_mins'
]

const FEATURE_VALUES = [
  'live',
  '4k',
  'hd',
  'subtitles',
  'creative_commons',
  '360',
  'vr180',
  '3d',
  'hdr',
  'location',
]

// "Hide watched" is a client-side filter. It is shown in the features list,
// but is not part of searchSettings.features (which is sent to search backends)
const FEATURES_VALUES = [...FEATURE_VALUES, 'hideWatched']

const NOT_ALLOWED_FOR_MOVIES_FEATURES = [
  'live',
  'subtitles',
  '3d',
  'creative_commons'
]

const title = computed(() => t('Search Filters.Search Filters'))

const prioritizeLabels = computed(() => [
  t('Search Filters.Prioritize.Most Relevant'),
  t('Search Filters.Prioritize.Popularity')
])

const timeLabels = computed(() => [
  t('Search Filters.Time.Any Time'),
  t('Search Filters.Time.Today'),
  t('Search Filters.Time.This Week'),
  t('Search Filters.Time.This Month'),
  t('Search Filters.Time.This Year')
])

const typeLabels = computed(() => [
  t('Search Filters.Type.All Types'),
  t('Search Filters.Type.Videos'),
  t('Global.Shorts'),
  t('Search Filters.Type.Channels'),
  t('Playlists'),
  t('Search Filters.Type.Movies')
])

const durationLabels = computed(() => [
  t('Search Filters.Duration.All Durations'),
  t('Search Filters.Duration.< 3 minutes'),
  t('Search Filters.Duration.3 - 20 minutes'),
  t('Search Filters.Duration.> 20 minutes')
])

const featureLabels = computed(() => [
  t('Search Filters.Features.Live'),
  t('Search Filters.Features.4K'),
  t('Search Filters.Features.HD'),
  t('Search Filters.Features.Subtitles'),
  t('Search Filters.Features.Creative Commons'),
  t('Search Filters.Features.360 Video'),
  t('Search Filters.Features.VR180'),
  t('Search Filters.Features.3D'),
  t('Search Filters.Features.HDR'),
  t('Search Filters.Features.Location'),
  t('Search Filters.Features.Hide Watched'),
])

const searchSettings = store.getters.getSearchSettings

/** @type {import('vue').Ref<'relevance' | 'popularity'>} */
const prioritizeValue = ref(searchSettings.prioritize)

watch(prioritizeValue, (value) => {
  store.commit('setSearchPrioritize', value)
})

/** @type {import('vue').Ref<'' | 'today' | 'week' | 'month' | 'year'>} */
const timeValue = ref(searchSettings.time)

watch(timeValue, (value) => {
  if (timeValue.value !== '' && !isVideoOrMovieOrAll(typeValue.value)) {
    typeValue.value = 'all'
  }

  store.commit('setSearchTime', value)
})

/** @type {import('vue').Ref<'all' | 'video' | 'shorts' | 'channel' | 'playlist' | 'movie'>} */
const typeValue = ref(searchSettings.type)

watch(typeValue, (value) => {
  if (value === 'shorts') {
    durationValue.value = ''
  } else if (value === 'channel' || value === 'playlist') {
    timeValue.value = ''
    durationValue.value = ''
    // "Hide watched" is a client-side filter, so it can stay applied to any type
    if (featuresValue.value.length > 0) {
      featuresValue.value = featuresValue.value.filter((feature) => feature === 'hideWatched')
    }
  } else if (value === 'movie') {
    if (featuresValue.value.length > 0) {
      featuresValue.value = featuresValue.value.filter(e => !NOT_ALLOWED_FOR_MOVIES_FEATURES.includes(e))
    }
  }

  store.commit('setSearchType', value)
})

/** @type {import('vue').Ref<'' | 'under_three_mins' | 'three_to_twenty_mins' | 'over_twenty_mins'>} */
const durationValue = ref(searchSettings.duration)

watch(durationValue, (value) => {
  if (value !== '' && !isVideoOrMovieOrAll(typeValue.value)) {
    typeValue.value = 'all'
  }

  store.commit('setSearchDuration', value)
})

/** @type {import('vue').Ref<('hd' | 'subtitles' | 'creative_commons' | '3d' | 'live' | '4k' | '360' | 'location' | 'hdr' | 'vr180' | 'hideWatched')[]>} */
const featuresValue = ref([
  ...searchSettings.features,
  ...(searchSettings.hideWatched ? ['hideWatched'] : [])
])

watch(featuresValue, (values) => {
  // "Hide watched" is a client-side filter, keep it out of searchSettings.features
  const features = values.filter((value) => value !== 'hideWatched')

  if (features.length > 0 && (!isVideoOrMovieOrAll(typeValue.value) || NOT_ALLOWED_FOR_MOVIES_FEATURES.some(item => features.includes(item)))) {
    typeValue.value = 'all'
  }

  store.commit('setSearchHideWatched', values.includes('hideWatched'))
  store.commit('setSearchFeatures', [...features])
}, { deep: true })

const searchFilterValueChanged = computed(() => {
  return prioritizeValue.value !== PRIORITIZE_VALUES[0] ||
    timeValue.value !== TIME_VALUES[0] ||
    typeValue.value !== TYPE_VALUES[0] ||
    durationValue.value !== DURATION_VALUES[0] ||
    featuresValue.value.length > 0
})

watch(searchFilterValueChanged, (value) => {
  store.commit('setSearchFilterValueChanged', value)
})

function hideSearchFilters() {
  store.dispatch('hideSearchFilters')
}

/**
 * @param {'all' | 'video' | 'channel' | 'playlist' | 'movie'} type
 */
function isVideoOrMovieOrAll(type) {
  return type === 'video' || type === 'movie' || type === 'all'
}

function clearFilters() {
  prioritizeValue.value = PRIORITIZE_VALUES[0]
  timeValue.value = TIME_VALUES[0]
  typeValue.value = TYPE_VALUES[0]
  durationValue.value = DURATION_VALUES[0]
  featuresValue.value = []
}

</script>

<style scoped src="./FtSearchFilters.css" />
