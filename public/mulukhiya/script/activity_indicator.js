export class ActivityIndicator {
  constructor () {
    this.progress = document.createElement('progress')
    this.progress.style.width = '200px'
    this.progress.style.margin = '0'
    this.container = document.createElement('div')
    this.container.style.display = 'none'
    this.container.style.padding = '0.5em 1em'
    this.container.style.position = 'fixed'
    this.container.style.left = '50%'
    this.container.style.top = '50%'
    this.container.style.transform = 'translate(-50%, -50%)'
    this.container.style.zIndex = 9999
    this.container.style.backgroundColor = '#fff'
    this.container.style.textAlign = 'center'
    this.container.style.borderWidth = '1px'
    this.container.style.borderStyle = 'solid'
    this.container.style.borderColor = '#000'
    this.container.style.borderRadius = '6px'
    this.container.style.opacity = 0.9
    this.container.appendChild(this.progress)
    document.getElementsByTagName('body')[0].appendChild(this.container)
  }

  show () {
    this.container.style.display = 'block'
  }

  hide () {
    this.container.style.display = 'none'
  }

  setMax (max) {
    if (max === undefined || max === null) {
      this.progress.removeAttribute('value')
      this.progress.removeAttribute('max')
    } else {
      this.progress.max = max
      this.progress.value = 0
    }
  }

  setValue (value) {
    this.progress.value = value
  }

  increment () {
    this.progress.value ++
  }
}
