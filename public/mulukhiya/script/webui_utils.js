export function isDisabledTag (disabledTags, tag) {
  return (disabledTags || []).includes(tag)
}

export function toggleTagStatus (disabledTags, tag, enable) {
  let tags = disabledTags || []
  if (enable) {
    tags = tags.filter(v => v != tag)
    return tags.length == 0 ? null : tags
  }
  tags.push(tag)
  return Array.from(new Set(tags))
}

export function buildTagStatusCommand (disabledTags) {
  return {tagging: {tags: {disabled: disabledTags}}}
}

export function tokensToString (accounts) {
  return accounts.map(v => v.token).join("\n")
}

export function parseTokens (input) {
  return input.trim().split("\n").map(s => s.trim()).filter(s => s)
}

export function buildEndpointURL (basePath, params) {
  let endpoint = basePath
  for (const [k, v] of Object.entries(params)) {
    endpoint = endpoint.replace(`:${k}`, v)
  }
  return endpoint
}
