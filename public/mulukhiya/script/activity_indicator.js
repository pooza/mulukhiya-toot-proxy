function ActivityIndicator () {
  const progress = document.createElement('progress')
  const container = document.createElement('div')
  container.style.display = 'none'
  container.style.position = 'fixed'
  container.style.left = '50%'
  container.style.top = '50%'
  container.style.zIndex = 9999
  container.style.backgroundColor = '#fff'
  container.style.textAlign = 'center'
  container.style.borderWidth = '1px'
  container.style.borderStyle = 'solid'
  container.style.borderColor = '#000'
  container.style.opacity = 0.9
  container.appendChild(progress)

  document.getElementsByTagName('body')[0].appendChild(container)

  this.show = () => {
    container.style.display = 'block'
    container.style.width = (progress.clientWidth + 8) + 'px'
    container.style.height = (progress.clientHeight + 8) + 'px'
    container.style.marginLeft = (-0.5 * progress.offsetWidth) + 'px'
    container.style.marginTop = (-0.5 * progress.offsetHeight) + 'px'
  }

  this.hide = () => {
    container.style.display = 'none'
  }

  this.setMax = max => {
    if (max === undefined || max === null) {
      progress.removeAttribute('value')
      progress.removeAttribute('max')
    } else {
      progress.max = max
      progress.value = 0
    }
  }

  this.setValue = value => {
    progress.value = value
  }
}
