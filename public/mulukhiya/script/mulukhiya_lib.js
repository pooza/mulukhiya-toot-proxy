const MulukhiyaLib = {
  install (Vue, options) {
    Vue.createPath = (href) => {
      return `${href}?token=${encodeURIComponent(Vue.getToken())}`
    }

    Vue.getToken = () => {
      return localStorage.getItem('mulukhiya_token')
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
