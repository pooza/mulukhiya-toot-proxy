import { ref } from 'https://cdn.jsdelivr.net/npm/vue@3.2/dist/vue.esm-browser.js'

export default {
  setup() {
    const show_drawer = ref(false)
    const items = ref([])
    items.value = [
      { title: 'Dashboard', icon: 'mdi-view-dashboard' },
      { title: 'Photos', icon: 'mdi-image' },
      { title: 'About', icon: 'mdi-help-box' },
    ]
    const toggleNavigation = () => {
      show_drawer.value = !show_drawer.value
    }
    return {show_drawer, items, toggleNavigation}
  },
  template: `
    <v-app>
      <v-navigation-drawer>
        <v-list
          dense
          nav
        >
          <v-list-item
            v-for="item in items"
            :key="item.title"
            link
          >
            <v-list-item-icon>
              <v-icon>{{ item.icon }}</v-icon>
            </v-list-item-icon>

            <v-list-item-content>
              <v-list-item-title>{{ item.title }}</v-list-item-title>
            </v-list-item-content>
          </v-list-item>
        </v-list>
      </v-navigation-drawer>

      <v-app-bar>
        <v-app-bar-nav-icon @click="toggleNavigation"></v-app-bar-nav-icon>
        <v-toolbar-title>mulukhiya-toot-proxy</v-toolbar-title>
      </v-app-bar>

      <v-main>
      </v-main>
    </v-app>
  `,
};
