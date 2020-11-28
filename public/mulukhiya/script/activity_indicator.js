class ActivityIndicator () {
  constructor () {
    this.progress = document.createElement('progress')
    this.container = document.createElement('div')
    this.container.style.display = 'none'
    this.container.style.position = 'fixed'
    this.container.style.left = '50%'
    this.container.style.top = '50%'
    this.container.style.zIndex = 9999
    this.container.style.backgroundColor = '#fff'
    this.container.style.textAlign = 'center'
    this.container.style.borderWidth = '1px'
    this.container.style.borderStyle = 'solid'
    this.container.style.borderColor = '#000'
    this.container.style.opacity = 0.9
    this.container.appendChild(this.pregress)
    document.getElementsByTagName('body')[0].appendChild(this.container)
  }

  show () {
    this.container.style.display = 'block'
    this.container.style.width = (this.progress.clientWidth + 8) + 'px'
    this.container.style.height = (this.progress.clientHeight + 8) + 'px'
    this.container.style.marginLeft = (-0.5 * this.progress.offsetWidth) + 'px'
    this.container.style.marginTop = (-0.5 * this.progress.offsetHeight) + 'px'
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
