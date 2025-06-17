window.VTooltip = {
  mounted(el, binding) {
    const modifiers = binding.modifiers || {};
    const placement = Object.keys(modifiers)[0] || 'top';
    tippy(el, {
      content: binding.value,
      placement,
      theme: 'mulukhiya',
    });
  },
  updated(el, binding) {
    if (el._tippy) {
      el._tippy.setContent(binding.value);
    }
  },
  unmounted(el) {
    if (el._tippy) {
      el._tippy.destroy();
    }
  }
};
