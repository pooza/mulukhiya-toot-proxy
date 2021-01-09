const MulukhiyaLib = {
  install (Vue, options) {
    Vue.createPath = (href, params) => {
      const url = new URL(href, location.href)
      params = params || {}
      params.query = params.query || {}
      params.query.token = params.token || Vue.getToken()
      Object.keys(params.query).map(k => {url.searchParams.set(k, params.query[k])})
      return url.href
    }

    Vue.createErrorMessage = e => {
      if ('response' in e) {
        return e.response.data.error || e.response.data.message || e.message
      } else {
        return e.message
      }
    }

    Vue.dig = (target, ...keys) => {
      let digged = target
      for (const key of keys) {
        if (typeof digged === 'undefined' || digged === null) {return undefined}
        digged = (typeof key === 'function') ? key(digged) : digged[key]
      }
      return digged
    }

    Vue.getConfig = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/config'))
        .then(e => e.data)
        .catch(e => ({account: {}, error: Vue.createErrorMessage(e)}))
        .finally(e => indicator.hide())
    }

    Vue.updateConfig = async command => {
      command.command = 'user_config'
      const values = {
        token: Vue.getToken(),
        status: JSON.stringify(command),
        text: JSON.stringify(command),
      }
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.post('/mulukhiya/api/config/update', values)
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getToken = () => {
      return localStorage.getItem('mulukhiya_token')
    }

    Vue.getTokens = () => {
      let tokens = JSON.parse(localStorage.getItem('mulukhiya_all_tokens') || '[]')
      tokens.unshift(Vue.getToken())
      tokens = tokens.filter(v => (v != null))
      tokens = Array.from(new Set(tokens))
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    Vue.registerToken = async token => {
      if (token == null) {return Promise.reject('empty token')}
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/config', {token: token}))
        .then(e => {
          localStorage.setItem('mulukhiya_token', token)
          return e.data
        }).finally(e => indicator.hide())
    }

    Vue.deleteToken = async token => {
      const tokens = Vue.getTokens().filter(v => v != token)
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    Vue.getUsers = async () => {
      const users = []
      const indicator = new ActivityIndicator()
      indicator.show()
      Vue.getTokens().forEach(t => {
        axios.get(Vue.createPath('/mulukhiya/api/config', {token: t}))
          .then(e => {
            users.push({
              username: e.data.account.username,
              token: t,
              scopes: e.data.token.scopes.join(', '),
              is_admin: e.data.account.is_admin,
              is_moderator: e.data.account.is_moderator,
            })
          }).catch(e => users.push({token: t, error: Vue.createErrorMessage(e)}))
        })
      indicator.hide()
      return users
    }

    Vue.switchUser = async user => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/config', {token: user.token}))
        .then(e => {
          localStorage.setItem('mulukhiya_token', user.token)
          return e.data
        }).finally(e => indicator.hide())
    }

    Vue.getFeeds = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/feed/list'))
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

    Vue.createProgramTags = program => {
      const label = [program.series]
      if (program.episode) {label.push(`${program.episode}話`)}
      if (program.air) {label.push('エア番組')}
      if (program.extra_tags) {program.extra_tags.map(tag => label.push(tag))}
      return label
    }

    Vue.searchTags = async keyword => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/tagging/tag/search', {query: {q: keyword}}))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getMedias = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/media'))
        .then(e => e.data)
        .finally(e => indicator.hide())
    }

    Vue.getHealth = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/health')
        .then(e => e.data)
        .finally(e => indicator.hide())
    }
  }
}
