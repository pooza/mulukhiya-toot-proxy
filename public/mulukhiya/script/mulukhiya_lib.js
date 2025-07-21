window.MulukhiyaLib = {
  install(app, options) {
    const globals = app.config.globalProperties
    globals.methods = {}

    globals.methods.createURL = (href, params = {}) => {
      const url = new URL(href, location.href)
      params = params || {}
      params.query = params.query || {}
      params.query.token = params.token || globals.methods.getToken()
      Object.keys(params.query).map(k => url.searchParams.set(k, params.query[k]))
      return url.href
    }

    globals.methods.createPath = href => (new URL(href)).pathname

    globals.methods.createPayload = values => ({
      token: globals.methods.getToken(),
      status: JSON.stringify(values),
      text: JSON.stringify(values),
    })

    globals.methods.createErrorMessage = e => {
      const errors = globals.methods.dig(e, 'response', 'data', 'errors')
      if (errors) {
        return Object.entries(errors).map(([k, v]) => `${k}: ${v.join()}`).join('\n')
      }
      return globals.methods.dig(e, 'response', 'data', 'error')
        || globals.methods.dig(e, 'response', 'data', 'message')
        || globals.methods.dig(e, 'message') || e
    }

    globals.methods.dig = (target, ...keys) => {
      let digged = target
      for (const key of keys) {
        if (typeof digged === 'undefined' || digged === null) return undefined
        digged = typeof key === 'function' ? key(digged) : digged[key]
      }
      return digged
    }

    globals.methods.authMastodon = async (code, type = 'default') => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/mastodon/auth', {token: globals.methods.getToken(), code: code, type: type})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.authMisskey = async (code, type = 'default') => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/misskey/auth', {token: globals.methods.getToken(), code: code, type: type})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getConfig = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/config'))
        .then(e => e.data)
        .catch(e => ({account: {}, error: globals.methods.createErrorMessage(e)}))
        .finally(e => indicator.hide())
    }

    globals.methods.updateConfig = async command => {
      command.command = 'user_config'
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/config/update', globals.methods.createPayload(command))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.updateLivecureFlag = async flag => {
      const command = {
        command: 'filter',
        tag: '実況',
        action: flag ? 'register' : 'unregister',
      }
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/filter/add', globals.methods.createPayload(command))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getSuggestedKeywords = () => {
      return JSON.parse(localStorage.getItem('mulukhiya_suggested_keywords') || '[]')
    }

    globals.methods.registerSuggestedKeyword = keyword => {
      let keywords = globals.methods.getSuggestedKeywords()
      keywords.unshift(keyword)
      keywords = Array.from(new Set(keywords.filter(v => (v != null)))).slice(0, 9)
      localStorage.setItem('mulukhiya_suggested_keywords', JSON.stringify(keywords))
    }

    globals.methods.getToken = () => localStorage.getItem('mulukhiya_token')

    globals.methods.setToken = token => {
      localStorage.setItem('mulukhiya_token', token)
    }

    globals.methods.getTokens = () => {
      let tokens = JSON.parse(localStorage.getItem('mulukhiya_all_tokens') || '[]')
      tokens.unshift(globals.methods.getToken())
      return globals.methods.setTokens(tokens)
    }

    globals.methods.setTokens = tokens => {
      tokens = Array.from(new Set(tokens.filter(v => (v != null))))
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    globals.methods.registerToken = async token => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/config', {token: token}))
        .then(e => {
          const tokens = globals.methods.getTokens()
          tokens.push(token)
          globals.methods.setTokens(tokens)
          globals.methods.setToken(token)
          globals.methods.updateConfig({})
          return e.data.account
        }).finally(e => indicator.hide())
    }

    globals.methods.deleteToken = async token => {
      return globals.methods.setTokens(globals.methods.getTokens().filter(v => v != token))
    }

    globals.methods.getAccounts = async () => {
      const accounts = []
      const tokens = globals.methods.getTokens()
      const indicator = new ActivityIndicator()
      indicator.show()
      indicator.setMax(tokens.length)
      return Promise.all(tokens.map(t => {
        return axios.get(globals.methods.createURL('/mulukhiya/api/config', {token: t}))
          .then(e => accounts.push(globals.methods.createAccountInfo(e.data, t)))
          .catch(e => accounts.push({token: t, error: globals.methods.createErrorMessage(e)}))
          .finally(e => indicator.increment)
      })).then(e => accounts)
      .finally(e => indicator.hide())
    }

    globals.methods.createAccountInfo = (data, token_crypted) => {
      return {
        username: data.account.username,
        token: token_crypted,
        scopes: data?.token?.scopes || [],
        is_scopes_valid: data?.token?.is_scopes_valid,
        roles: data.account.roles,
        is_admin: data.account.is_admin,
        is_info_bot: data.account.is_info_bot,
        is_test_bot: data.account.is_test_bot,
        webhook: data?.webhook?.url,
      }
    }

    globals.methods.switchAccount = async account => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/config', {token: account.token}))
        .then(e => {
          globals.methods.setToken(account.token)
          return e.data
        }).finally(e => indicator.hide())
    }

    globals.methods.getFeeds = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/feed/list'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.updateCustomFeeds = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/feed/update', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getPrograms = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/program')
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.updatePrograms = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/program/update', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.createProgramTags = program => {
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

    globals.methods.getWorks = async params => {
      const indicator = new ActivityIndicator()
      indicator.show()
      if (!params.q) {params = {}}
      return axios.get(globals.methods.createURL(`/mulukhiya/api/program/works`, {query: params}))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getEpisodeTags = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/tagging/dic/annict/episodes')
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getEpisodes = async id => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(`/mulukhiya/api/program/works/${id}/episodes`)
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.searchTags = async keyword => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/tagging/tag/search', {q: keyword})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getFavoriteTags = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/tagging/favorites'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.updateTaggingDictionary = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/tagging/dic/update', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.clearUserTags = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/tagging/usertag/clear', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getMedias = async params => {
      params.page = Number(params.page || 1)
      params.only_person = params.only_person ? 1 : 0
      if (params.q) {
        globals.methods.registerSuggestedKeyword(params.q)
      } else {
        delete params.q
      }
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/media', {query: params}))
        .then(e => e.data)
        .catch(e => e.response.data)
        .finally(e => indicator.hide())
    }

    globals.methods.clearMediaFiles = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/media/file/clear', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.clearMediaMetadata = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/media/metadata/clear', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getStatuses = async params => {
      params.page = Number(params.page || 1)
      params.self = params.self ? 1 : 0
      if (params.q) {
        globals.methods.registerSuggestedKeyword(params.q)
      } else {
        delete params.q
      }
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/status/list', {query: params}))
        .then(e => e.data)
        .catch(e => e.response.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getStatus = async id => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL(`/mulukhiya/api/status/${id}`))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.createTag = async (id, tag) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/status/tag', {token: globals.methods.getToken(), id: id, tag: tag})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.updateTags = async (id, tags) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/status/tags', {token: globals.methods.getToken(), id: id, tags: tags})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.deleteTag = async (id, tag) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.delete('/mulukhiya/api/status/tag', {data: {token: globals.methods.getToken(), id: id, tag: tag}})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.deleteNowplaying = async id => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.delete('/mulukhiya/api/status/nowplaying', {data: {token: globals.methods.getToken(), id: id}})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.attachPoipikuImage = async (id, fanart) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.put('/mulukhiya/api/status/poipiku', {token: globals.methods.getToken(), id: id, fanart: fanart})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getHealth = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/health')
        .then(e => e.data)
        .catch(e => e.response.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getAbout = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/about')
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.updateAnnouncement = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/announcement/update', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getLemmyCommunities = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/lemmy/communities'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getPiefedCommunities = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/piefed/communities'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.authAnnict = async code => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/annict/auth', {token: globals.methods.getToken(), code: code})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.getHandlers = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(globals.methods.createURL('/mulukhiya/api/admin/handler/list'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.restartPuma = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/puma/restart', {token: globals.methods.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.toggleHandler = async (handler, flag) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/handler/config', {token: globals.methods.getToken(), handler: handler, flag: flag})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.setInfoToken = async token => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/agent/config', {token: globals.methods.getToken(), info_token: token})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.setTestToken = async token => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/admin/agent/config', {token: globals.methods.getToken(), test_token: token})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    globals.methods.execGET = async path => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(path)
        .then(e => e.data)
        .finally(e => indicator.hide())
    }
  }
}
