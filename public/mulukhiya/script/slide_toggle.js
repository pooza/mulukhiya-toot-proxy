export const SlideUpDown = {
  name: 'SlideUpDown',
  props: ['active'],
  template: `
    <transition @before-enter="beforeEnter" @enter="enter" @leave="leave">
      <div v-show="active" ref="inner">
        <slot></slot>
      </div>
    </transition>
  `,
  methods: {
    beforeEnter(el) {
      el.style.height = '0'
      el.style.opacity = '0'
    },
    enter(el, done) {
      el.style.transition = 'height 0.3s ease, opacity 0.3s ease'
      const h = el.scrollHeight + 'px'
      requestAnimationFrame(() => {
        el.style.height = h
        el.style.opacity = '1'
      })
      setTimeout(done, 300)
    },
    leave(el, done) {
      el.style.transition = 'height 0.3s ease, opacity 0.3s ease'
      el.style.height = el.scrollHeight + 'px'
      el.style.opacity = '1'
      requestAnimationFrame(() => {
        el.style.height = '0'
        el.style.opacity = '0'
      })
      setTimeout(done, 300)
    }
  }
}
