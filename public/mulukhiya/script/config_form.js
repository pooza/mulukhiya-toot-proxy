export function dig (target, ...keys) {
  let digged = target
  for (const key of keys) {
    if (typeof digged === 'undefined' || digged === null) return undefined
    digged = typeof key === 'function' ? key(digged) : digged[key]
  }
  return digged
}

export function extractFormValues (data) {
  return {
    webhook: {
      visibility: dig(data, 'config', 'webhook', 'visibility') || 'public',
    },
    piefed: {
      url: dig(data, 'config', 'piefed', 'url'),
      user: dig(data, 'config', 'piefed', 'user'),
      community: dig(data, 'config', 'piefed', 'community'),
    },
    annict: {
      theme_works_only: dig(data, 'config', 'service', 'annict', 'theme_works_only') == true,
    },
    notify: {
      verbose: dig(data, 'config', 'notify', 'verbose') == true,
    },
    tags: dig(data, 'config', 'tagging', 'user_tags')
      ? dig(data, 'config', 'tagging', 'user_tags').join("\n")
      : '',
    decoration: {
      id: dig(data, 'config', 'decoration', 'id') || null,
    },
  }
}

export function extractVisibilityOptions (data) {
  if (!data.visibility_names) return []
  const options = []
  for (const [k, v] of Object.entries(data.visibility_names)) {
    if (!options.find(o => o.value == v)) {
      options.push({label: k == v ? k : `${v} (${k})`, value: v})
    }
  }
  return options
}

export function buildProgramOptions (programs, createProgramTags) {
  const options = Object.values(programs)
    .filter(program => program.enable)
    .map(program => ({
      value: program.key,
      label: program.minutes
        ? `${createProgramTags(program).join(', ')} (${program.minutes}分)`
        : createProgramTags(program).join(', '),
    }))
  options.unshift({label: '(固定タグのクリア)'})
  return options
}

export function convertProgramToTags (selection, programs, createProgramTags) {
  if (selection && selection.code) {
    const program = programs[selection.code]
    return {
      tags: createProgramTags(program).join("\n"),
      minutes: program.minutes,
    }
  }
  return {tags: null, minutes: null}
}

export function buildTagsCommand (form) {
  const command = {tagging: {user_tags: null, minutes: null}, decoration: {id: null}}
  if (form.tags) {
    command.tagging.user_tags = form.tags.split("\n")
    if (form.program.minutes) {
      command.tagging.minutes = form.program.minutes
    }
  } else {
    command.tagging.minutes = null
  }
  if (form.decoration.id) {
    command.decoration.id = form.decoration.id
    if (form.program.minutes) {
      command.decoration.minutes = form.program.minutes
    }
  }
  return command
}

export function buildPiefedCommand (form) {
  const command = {piefed: {url: null, user: null, community: null, host: null}}
  if (form.piefed.url) command.piefed.url = form.piefed.url
  if (form.piefed.user) command.piefed.user = form.piefed.user
  if (form.piefed.password) command.piefed.password = form.piefed.password
  if (form.piefed.community) command.piefed.community = Number(form.piefed.community)
  return command
}

export function buildWebhookCommand (form) {
  const command = {webhook: {visibility: null}}
  if (form.webhook.visibility != 'public') {
    command.webhook.visibility = form.webhook.visibility
  }
  return command
}

export function buildNotifyCommand (form) {
  const command = {notify: {verbose: null}}
  if (form.notify.verbose) command.notify.verbose = true
  return command
}

export function buildAnnictCommand (form) {
  const command = {service: {annict: {theme_works_only: null}}}
  if (form.annict.theme_works_only) command.service.annict.theme_works_only = true
  return command
}
