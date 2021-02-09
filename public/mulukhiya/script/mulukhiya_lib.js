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
    }

    Vue.dig = (target, ...keys) => {
      let digged = target
      for (const key of keys) {
        if (typeof digged === 'undefined' || digged === null) {return undefined}
        digged = (typeof key === 'function') ? key(digged) : digged[key]
      }
      return digged
    }

    Vue.authMastodon = async code => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/mastodon/auth', {token: Vue.getToken(), code: code})
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
          Vue.updateConfig({mulukhiya: {token: token}})
          tokens = Vue.getTokens()
          tokens.push(token)
          Vue.setTokens(tokens)
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
          .then(e => accounts.push(Vue.createAccountInfo(e.data)))
          .catch(e => accounts.push({token: t, error: Vue.createErrorMessage(e)}))
          .finally(e => indicator.increment)
      })).then(e => accounts)
      .finally(e => indicator.hide())
    }

    Vue.createAccountInfo = data => {
      return {
        username: data.account.username,
        token: data.config.mulukhiya.token || data.config.webhook.token,
        scopes: data.token.scopes.join(', '),
        is_admin: data.account.is_admin,
        is_moderator: data.account.is_moderator,
        webhook: data.webhook.url,
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

    Vue.updateFeeds = async () => {
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
        tags.push('実況')
        tags.push(program.series)
        if (program.episode) {tags.push(`${program.episode}話`)}
        if (program.air) {tags.push('エア番組')}
        if (program.extra_tags) {tags.concat(program.extra_tags)}
      }
      return tags
    }

    Vue.searchTags = async keyword => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/tagging/tag/search', {q: keyword})
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

    Vue.getMedias = async page => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createURL(Vue.createURL('/mulukhiya/api/media', {query: {page: page || 1}})))
        .then(e => e.data)
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

    Vue.authAnnict = async code => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/annict/auth', {token: Vue.getToken(), code: code})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.crawlAnnict = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/annict/crawl', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.clearOAuthClient = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/oauth/client/clear', {token: Vue.getToken()})
        .then(e => e.data)
        .finally(e => indicator.hide())
    }
  }
}
