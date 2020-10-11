const MulukhiyaLib = {
  install (Vue, options) {
    Vue.createPath = (href) => {
      return `${href}?token=${encodeURIComponent(Vue.getToken())}`
    }

    Vue.getToken = () => {
      return localStorage.getItem('mulukhiya_token')
    }

    Vue.getTokens = () => {
      let tokens = JSON.parse(localStorage.getItem('mulukhiya_all_tokens') || '[]')
      tokens.unshift(Vue.getToken())
      tokens = tokens.filter(v => {return v != null})
      tokens = Array.from(new Set(tokens))
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    Vue.login = async () => {
      return axios.get(Vue.createPath('/mulukhiya/config'), {responseType: 'json'})
        .then(e => {return e.data.account})
    }

    Vue.registerToken = async token => {
      const href = '/mulukhiya/config?token=' + encodeURIComponent(token)
      return axios.get(href, {responseType: 'json'})
        .then(e => {
          localStorage.setItem('mulukhiya_token', token)
          return e.data.account
        })
    }

    Vue.getUsers = async () => {
      const users = []
      Vue.getTokens().forEach(t => {
        const href = '/mulukhiya/config?token=' + encodeURIComponent(t)
        axios.get(href, {responseType: 'json'}).then(e => {
          users.push({
            username: e.data.account.username,
            token: t,
            scopes: e.data.token.scopes.join(', '),
          })
        })
      })
      return users
    }

    Vue.switchUser = async user => {
      const href = '/mulukhiya/config?token=' + encodeURIComponent(user.token)
      return axios.get(href, {responseType: 'json'})
        .then(e => {
          localStorage.setItem('mulukhiya_token', user.token)
          return e.data.account
      })
    }

    Vue.deleteUser = async user => {
      const tokens = Vue.getTokens().filter(v => v != user.token)
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    Vue.getMedias = async () => {
      return axios.get(Vue.createPath('/mulukhiya/medias'), {responseType: 'json'})
        .then(e => {return e.data})
    }

    Vue.getHealth = async () => {
      return axios.get('/mulukhiya/health', {responseType: 'json'})
        .then(e => {return e.data})
    }
  }
}
