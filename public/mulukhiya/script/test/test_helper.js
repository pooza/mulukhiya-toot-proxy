import { createApp } from 'vue'
import axios from 'axios'
import { MulukhiyaLib } from 'mulukhiya_lib'

export function createMethods () {
  const app = createApp({})
  app.use(MulukhiyaLib)
  const vm = app.mount(document.createElement('div'))
  return vm.methods
}

const mockResponses = new Map()

export function mockAxios (urlPattern, data, status = 200) {
  mockResponses.set(urlPattern, { data, status })
}

export function clearMocks () {
  mockResponses.clear()
  localStorage.clear()
}

axios.defaults.adapter = config => {
  for (const [pattern, response] of mockResponses) {
    if (config.url.includes(pattern)) {
      return Promise.resolve({
        data: response.data,
        status: response.status,
        statusText: 'OK',
        headers: {},
        config,
      })
    }
  }
  return Promise.reject(new Error(`Unmocked request: ${config.url}`))
}
