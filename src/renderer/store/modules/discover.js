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
