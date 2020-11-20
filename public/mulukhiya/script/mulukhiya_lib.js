const MulukhiyaLib = {
  install (Vue, options) {
    Vue.createPath = href => {
      return `${href}?token=${encodeURIComponent(Vue.getToken())}`
    }

    Vue.createErrorMessage = e => {
      if ('response' in e) {
        return e.response.data.error || e.response.data.message || e.message
      } else {
        return e.message
      }
    }

    Vue.getConfig = async () => {
      document.body.style.cursor = 'wait'
      return axios.get(Vue.createPath('/mulukhiya/api/config'), {responseType: 'json'})
        .then(e => {return e.data})
        .finally(e => {document.body.style.cursor = 'auto'})
    }

    Vue.updateConfig = async command => {
      command.command = 'user_config'
      const values = {
        token: Vue.getToken(),
        status: JSON.stringify(command),
        text: JSON.stringify(command),
      }
      document.body.style.cursor = 'wait'
      return axios.post('/mulukhiya/api/config/update', values)
        .then(e => {return e.data})
        .finally(e => {document.body.style.cursor = 'auto'})
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
      document.body.style.cursor = 'wait'
      const href = '/mulukhiya/api/config?token=' + encodeURIComponent(token)
      return axios.get(href, {responseType: 'json'})
        .then(e => {
          localStorage.setItem('mulukhiya_token', token)
          return e.data.account
        }).finally(e => {document.body.style.cursor = 'auto'})
    }

    Vue.deleteToken = async token => {
      const tokens = Vue.getTokens().filter(v => v != token)
      localStorage.setItem('mulukhiya_all_tokens', JSON.stringify(tokens))
      return tokens
    }

    Vue.getUsers = async () => {
      const users = []
      document.body.style.cursor = 'wait'
      Vue.getTokens().forEach(t => {
        const href = '/mulukhiya/api/config?token=' + encodeURIComponent(t)
        axios.get(href, {responseType: 'json'}).then(e => {
          users.push({
            username: e.data.account.username,
            token: t,
            scopes: e.data.token.scopes.join(', '),
          })
        })
      })
      document.body.style.cursor = 'auto'
      return users
    }

    Vue.switchUser = async user => {
      document.body.style.cursor = 'wait'
      const href = '/mulukhiya/api/config?token=' + encodeURIComponent(user.token)
      return axios.get(href, {responseType: 'json'})
        .then(e => {
          localStorage.setItem('mulukhiya_token', user.token)
          return e.data.account
        }).finally(e=> {document.body.style.cursor = 'auto'})
    }

    Vue.getPrograms = async () => {
      document.body.style.cursor = 'wait'
      return axios.get('/mulukhiya/api/program', {responseType: 'json'})
        .then(e => {return e.data})
        .finally(e => {document.body.style.cursor = 'auto'})
    }

    Vue.createProgramTags = program => {
      const label = [program.series]
      if (program.episode) {label.push(`${program.episode}話`)}
      if (program.air) {label.push('エア番組')}
      if (program.extra_tags) {program.extra_tags.map(tag => {label.push(tag)})}
      return label
    }

    Vue.getMedias = async () => {
      document.body.style.cursor = 'wait'
      return axios.get(Vue.createPath('/mulukhiya/api/media'), {responseType: 'json'})
        .then(e => {return e.data})
        .finally(e => {document.body.style.cursor = 'auto'})
    }

    Vue.getHealth = async () => {
      document.body.style.cursor = 'wait'
      return axios.get('/mulukhiya/api/health', {responseType: 'json'})
        .then(e => {return e.data})
        .finally(e => {document.body.style.cursor = 'auto'})
    }
  }
}
