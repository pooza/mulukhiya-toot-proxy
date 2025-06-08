const MulukhiyaLib = {
  install(app, options) {
    const globals = app.config.globalProperties
    globals = {methods: {}}

    globals.methods.createURL = (href, params = {}) => {
      const url = new URL(href, location.href)
      params.query = params.query || {}
      params.query.token = params.token || globals.methods.getToken()
      Object.keys(params.query).forEach(k => url.searchParams.set(k, params.query[k]))
      return url.href
    }

    globals.methods.createPath = href => (new URL(href)).pathname

    globals.methods.createPayload = values => ({
      token: globals.methods.getToken(),
      status: JSON.stringify(values),
      text: JSON.stringify(values),
    })

    globals.methods.alert = (e) => {
      alert(globals.methods.createErrorMessage(e))
    }

    globals.methods.createErrorMessage = e => {
      const errors = globals.methods.dig(e, 'response', 'data', 'errors')
      if (errors) {
        return Object.entries(errors).map(([k, v]) => `${k}: ${v.join()}`).join('\n')
      }
      return globals.methods.dig(e, 'response', 'data', 'error') ||
        globals.methods.dig(e, 'response', 'data', 'message') ||
        globals.methods.dig(e, 'message') || e
    }

    globals.methods.dig = (target, ...keys) => {
      let digged = target
      for (const key of keys) {
        if (typeof digged === 'undefined' || digged === null) return undefined
        digged = typeof key === 'function' ? key(digged) : digged[key]
      }
      return digged
    }

    globals.methods.getToken = () => localStorage.getItem('mulukhiya_token')
    globals.methods.setToken = token => localStorage.setItem('mulukhiya_token', token)

    globals.methods.getTokens = () => {
      const tokens = JSON.parse(localStorage.getItem('mulukhiya_all_tokens') || '[]')
      tokens.unshift(globals.methods.getToken())
      return globals.methods.setTokens(tokens)
    }

    globals.methods.setTokens = tokens => {
      tokens = [...new Set(tokens.filter(v => v != null))]
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    globals.methods.registerSuggestedKeyword = keyword => {
      let keywords = globals.methods.getSuggestedKeywords()
      keywords.unshift(keyword)
      keywords = [...new Set(keywords.filter(v => v != null))].slice(0, 9)
      localStorage.setItem('mulukhiya_suggested_keywords', JSON.stringify(keywords))
    }

    globals.methods.getSuggestedKeywords = () => {
      return JSON.parse(localStorage.getItem('mulukhiya_suggested_keywords') || '[]')
    }

    const withIndicator = fn => async (...args) => {
      const indicator = new ActivityIndicator()
      indicator.show()
      try {
        return await fn(...args)
      } finally {
        indicator.hide()
      }
    }

    globals.methods.authMastodon = withIndicator((code, type = 'default') => {
      return axios.post('/mulukhiya/api/mastodon/auth', {
        token: globals.methods.getToken(), code, type
      }).then(res => res.data)
    })

    globals.methods.authMisskey = withIndicator((code, type = 'default') => {
      return axios.post('/mulukhiya/api/misskey/auth', {
        token: globals.methods.getToken(), code, type
      }).then(res => res.data)
    })

    globals.methods.getConfig = withIndicator(async () => {
      try {
        const res = await axios.get(globals.methods.createURL('/mulukhiya/api/config'))
        return res.data
      } catch (e) {
        return { account: {}, error: globals.methods.createErrorMessage(e) }
      }
    })

    globals.methods.updateConfig = withIndicator((command) => {
      command.command = 'user_config'
      return axios.post('/mulukhiya/api/config/update', globals.methods.createPayload(command)).then(res => res.data)
    })

    globals.methods.updateLivecureFlag = withIndicator((flag) => {
      const command = {
        command: 'filter', tag: '実況', action: flag ? 'register' : 'unregister'
      }
      return axios.post('/mulukhiya/api/filter/add', globals.methods.createPayload(command)).then(res => res.data)
    })

    globals.methods.registerToken = withIndicator(async (token) => {
      const res = await axios.get(globals.methods.createURL('/mulukhiya/api/config', { token }))
      const tokens = globals.methods.getTokens()
      tokens.push(token)
      globals.methods.setTokens(tokens)
      globals.methods.setToken(token)
      await globals.methods.updateConfig({})
      return res.data.account
    })

    globals.methods.deleteToken = async (token) => {
      return globals.methods.setTokens(globals.methods.getTokens().filter(v => v !== token))
    }

    globals.methods.getAccounts = withIndicator(async () => {
      const accounts = []
      const tokens = globals.methods.getTokens()
      const indicator = new ActivityIndicator()
      indicator.show()
      indicator.setMax(tokens.length)
      await Promise.all(tokens.map(async t => {
        try {
          const res = await axios.get(globals.methods.createURL('/mulukhiya/api/config', { token: t }))
          accounts.push(globals.methods.createAccountInfo(res.data, t))
        } catch (e) {
          accounts.push({ token: t, error: globals.methods.createErrorMessage(e) })
        } finally {
          indicator.increment()
        }
      }))
      indicator.hide()
      return accounts
    })

    globals.methods.createAccountInfo = (data, token) => ({
      username: data.account.username,
      token,
      scopes: data?.token?.scopes || [],
      is_scopes_valid: data?.token?.is_scopes_valid,
      roles: data.account.roles,
      is_admin: data.account.is_admin,
      is_info_bot: data.account.is_info_bot,
      is_test_bot: data.account.is_test_bot,
      webhook: data?.webhook?.url,
    })

    globals.methods.switchAccount = withIndicator(async (account) => {
      const res = await axios.get(globals.methods.createURL('/mulukhiya/api/config', { token: account.token }))
      globals.methods.setToken(account.token)
      return res.data
    })

    globals.methods.getWorks = withIndicator((params = {}) => {
      if (!params.q) params = {}
      return axios.get(globals.methods.createURL('/mulukhiya/api/program/works', { query: params })).then(res => res.data)
    })

    globals.methods.getEpisodes = withIndicator((id) => {
      return axios.get(`/mulukhiya/api/program/works/${id}/episodes`).then(res => res.data)
    })

    globals.methods.notifyCommandToot = () => {
      alert('実況コマンドをクリップボードにコピーしました。')
    }
  }
}

export default MulukhiyaLib;
