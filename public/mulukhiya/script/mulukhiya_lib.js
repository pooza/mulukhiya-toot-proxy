const MulukhiyaLib = {
  install (Vue, options) {
    Vue.createPath = (href, token) => {
      const url = new URL(href, location.href)
      url.searchParams.set('token', token || Vue.getToken())
      return url.href
    }

    Vue.createErrorMessage = e => {
      if ('response' in e) {
        return e.response.data.error || e.response.data.message || e.message
      } else {
        return e.message
      }
    }

    Vue.getConfig = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/config'), {responseType: 'json'})
        .then(e => {
          indicator.hide()
          return e.data
        })
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
        .then(e => {
          indicator.hide()
          return e.data
        })
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

    Vue.registerToken = async token => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/config', token), {responseType: 'json'})
        .then(e => {
          indicator.hide()
          localStorage.setItem('mulukhiya_token', token)
          return e.data
        })
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
        axios.get(Vue.createPath('/mulukhiya/api/config', t), {responseType: 'json'}).then(e => {
          users.push({
            username: e.data.account.username,
            token: t,
            scopes: e.data.token.scopes.join(', '),
          })
        })
      })
      indicator.hide()
      return users
    }

    Vue.switchUser = async user => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/config', user.token), {responseType: 'json'})
        .then(e => {
          indicator.hide()
          localStorage.setItem('mulukhiya_token', user.token)
          return e.data
        })
    }

    Vue.getPrograms = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/program', {responseType: 'json'})
        .then(e => {
          indicator.hide()
          return e.data
        })
    }

    Vue.createProgramTags = program => {
      const label = [program.series]
      if (program.episode) {label.push(`${program.episode}話`)}
      if (program.air) {label.push('エア番組')}
      if (program.extra_tags) {program.extra_tags.map(tag => {label.push(tag)})}
      return label
    }

    Vue.getMedias = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get(Vue.createPath('/mulukhiya/api/media'), {responseType: 'json'})
        .then(e => {
          indicator.hide()
          return e.data
        })
    }

    Vue.getHealth = async () => {
      const indicator = new ActivityIndicator()
      indicator.show()
      return axios.get('/mulukhiya/api/health', {responseType: 'json'})
        .then(e => {
          indicator.hide()
          return e.data
        })
    }
  }
}
