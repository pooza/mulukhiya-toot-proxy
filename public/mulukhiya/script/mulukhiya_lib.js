const MulukhiyaLib = {
  install (Vue, options) {
    Vue.createURL = (href, params) => {
      const url = new URL(href, location.href)
      params = params || {}
      params.query = params.query || {}
      params.query.token = params.token || Vue.getToken()
      Object.keys(params.query).map(k => url.searchParams.set(k, params.query[k]))
      return url.href
    }

    Vue.createPath = href => (new URL(href)).pathname

    Vue.createPayload = values => {
      return {
        token: Vue.getToken(),
        status: JSON.stringify(values),
        text: JSON.stringify(values),
      }
    }

    Vue.alert = (dialog, e) => {
      if (e) {dialog.alert(Vue.createErrorMessage(e))}
    }

    Vue.createErrorMessage = e => {
      let errors
      if (errors = Vue.dig(e, 'response', 'data', 'errors')) {
        return Object.keys(errors).map(k => `${k}: ${errors[k].join()}`).join("\n")
      }
      return Vue.dig(e, 'response', 'data', 'error')
        || Vue.dig(e, 'response', 'data', 'message')
        || Vue.dig(e, 'message')
        || e
    }

    Vue.dig = (target, ...keys) => {
      let digged = target
      for (const key of keys) {
        if (typeof digged === 'undefined' || digged === null) {return undefined}
        digged = (typeof key === 'function') ? key(digged) : digged[key]
      }
      return digged
    }

    Vue.authMastodon = async (code, type = 'default') => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/mastodon/auth', {token: Vue.getToken(), code: code, type: type})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.authMisskey = async (code, type = 'default') => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/misskey/auth', {token: Vue.getToken(), code: code, type: type})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getConfig = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/config'))
        .then(e => e.data)
        .catch(e => ({account: {}, error: Vue.createErrorMessage(e)}))
        .finally(e => indicator.hide())
    }

    Vue.updateConfig = async command => {
      command.command = 'user_config'
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/config/update', Vue.createPayload(command))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.updateLivecureFlag = async flag => {
      const command = {
        command: 'filter',
        tag: '実況',
        action: flag ? 'register' : 'unregister',
      }
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/filter/add', Vue.createPayload(command))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getSuggestedKeywords = () => {
      return JSON.parse(localStorage.getItem('mulukhiya_suggested_keywords') || '[]')
    }

    Vue.registerSuggestedKeyword = keyword => {
      let keywords = Vue.getSuggestedKeywords()
      keywords.unshift(keyword)
      keywords = Array.from(new Set(keywords.filter(v => (v != null)))).slice(0, 9)
      localStorage.setItem('mulukhiya_suggested_keywords', JSON.stringify(keywords))
    }

    Vue.getToken = () => {
      return localStorage.getItem('mulukhiya_token')
    }

    Vue.setToken = token => {
      localStorage.setItem('mulukhiya_token', token)
    }

    Vue.getTokens = () => {
      let tokens = JSON.parse(localStorage.getItem('mulukhiya_all_tokens') || '[]')
      tokens.unshift(Vue.getToken())
      return Vue.setTokens(tokens)
    }

    Vue.setTokens = tokens => {
      tokens = Array.from(new Set(tokens.filter(v => (v != null))))
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    Vue.registerToken = async token => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/config', {token: token}))
        .then(e => {
          const tokens = Vue.getTokens()
          tokens.push(token)
          Vue.setTokens(tokens)
          Vue.setToken(token)
          Vue.updateConfig({})
          return e.data.account
        }).finally(e => indicator.hide())
    }

    Vue.deleteToken = async token => {
      return Vue.setTokens(Vue.getTokens().filter(v => v != token))
    }

    Vue.getAccounts = async () => {
      const accounts = []
      const tokens = Vue.getTokens()
      const indicator = new ActivityIndicator()
      indicator.show()
      indicator.setMax(tokens.length)
      return Promise.all(tokens.map(t => {
        return axios.get(Vue.createURL('/mulukhiya/api/config', {token: t}))
          .then(e => accounts.push(Vue.createAccountInfo(e.data, t)))
          .catch(e => accounts.push({token: t, error: Vue.createErrorMessage(e)}))
          .finally(e => indicator.increment)
      })).then(e => accounts)
      .finally(e => indicator.hide())
    }

    Vue.createAccountInfo = (data, token_crypted) => {
      return {
        username: data.account.username,
        token: token_crypted,
        scopes: data?.token?.scopes || [],
        is_scopes_valid: data?.token?.is_scopes_valid,
        is_admin: data.account.is_admin,
        is_operator: data.account.is_admin
        is_info_bot: data.account.is_info_bot,
        is_test_bot: data.account.is_test_bot,
        webhook: data?.webhook?.url,
      }
    }

    Vue.switchAccount = async account => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/config', {token: account.token}))
        .then(e => {
          Vue.setToken(account.token)
          return e.data
        }).finally(e => indicator.hide())
    }

    Vue.getFeeds = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/feed/list'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.updateCustomFeeds = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/feed/update', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getPrograms = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/program')
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.updatePrograms = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/program/update', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.createProgramTags = program => {
      const tags = []
      if (program) {
        tags.push(program.series)
        if (program.episode) {tags.push(`${program.episode}${program.episode_suffix || '話'}`)}
        if (program.subtitle) {tags.push(`「${program.subtitle}」`)}
        if (program.air) {tags.push('エア番組')}
        if (program.livecure) {tags.push('実況')}
        if (program.extra_tags) {tags.concat(program.extra_tags)}
      }
      return tags
    }

    Vue.getWorks = async params => {
      const indicator = new ActivityIndicator()
      indicator.show()
      if (!params.q) {params = {}}
      return axios.get(Vue.createURL(`/mulukhiya/api/program/works`, {query: params}))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getEpisodeTags = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/tagging/dic/annict/episodes')
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getEpisodes = async id => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(`/mulukhiya/api/program/works/${id}/episodes`)
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.searchTags = async keyword => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/tagging/tag/search', {q: keyword})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getFavoriteTags = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/tagging/favorites'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.updateTaggingDictionary = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/tagging/dic/update', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.clearUserTags = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/tagging/usertag/clear', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getMedias = async params => {
      params.page = Number(params.page || 1)
      params.only_person = params.only_person ? 1 : 0
      if (params.q) {
        Vue.registerSuggestedKeyword(params.q)
      } else {
        delete params.q
      }
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/media', {query: params}))
        .then(e => e.data)
        .catch(e => e.response.data)
        .finally(e => indicator.hide())
    }

    Vue.clearMediaFiles = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/media/file/clear', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.clearMediaMetadata = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/media/metadata/clear', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getStatuses = async params => {
      params.page = Number(params.page || 1)
      params.self = params.self ? 1 : 0
      if (params.q) {
        Vue.registerSuggestedKeyword(params.q)
      } else {
        delete params.q
      }
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/status/list', {query: params}))
        .then(e => e.data)
        .catch(e => e.response.data)
        .finally(e => indicator.hide())
    }

    Vue.getStatus = async id => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL(`/mulukhiya/api/status/${id}`))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.createTag = async (id, tag) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/status/tag', {token: Vue.getToken(), id: id, tag: tag})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.updateTags = async (id, tags) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/status/tags', {token: Vue.getToken(), id: id, tags: tags})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.deleteTag = async (id, tag) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.delete('/mulukhiya/api/status/tag', {data: {token: Vue.getToken(), id: id, tag: tag}})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.deleteNowplaying = async id => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.delete('/mulukhiya/api/status/nowplaying', {data: {token: Vue.getToken(), id: id}})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.attachPoipikuImage = async (id, fanart) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.put('/mulukhiya/api/status/poipiku', {token: Vue.getToken(), id: id, fanart: fanart})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getHealth = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/health')
        .then(e => e.data)
        .catch(e => e.response.data)
        .finally(e => indicator.hide())
    }

    Vue.getAbout = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/about')
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.updateAnnouncement = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/announcement/update', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getLemmyCommunities = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/lemmy/communities'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.authAnnict = async code => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/annict/auth', {token: Vue.getToken(), code: code})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getHandlers = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL('/mulukhiya/api/admin/handler/list'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.restartPuma = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/puma/restart', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.toggleHandler = async (handler, flag) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/handler/config', {token: Vue.getToken(), handler: handler, flag: flag})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.setInfoToken = async token => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/agent/config', {token: Vue.getToken(), info_token: token})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.setTestToken = async token => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/agent/config', {token: Vue.getToken(), test_token: token})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.execGET = async path => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(path)
        .then(e => e.data)
        .finally(e => indicator.hide())
    }
  }
}
