import jsyaml from 'js-yaml'

export function initObject (prop) {
  const obj = {}
  for (const [k, sub] of Object.entries(prop.properties)) {
    if (sub.type === 'array') obj[k] = []
    else if (sub.type === 'object' && sub.properties) obj[k] = initObject(sub)
    else if (sub.type === 'integer') obj[k] = sub.minimum || 0
    else if (sub.type === 'boolean') obj[k] = false
    else obj[k] = ''
  }
  return obj
}

export function initObjectValue (val, prop) {
  const obj = val || {}
  for (const [k, sub] of Object.entries(prop.properties)) {
    if (obj[k] === null || obj[k] === undefined) {
      if (sub.type === 'array') obj[k] = []
      else if (sub.type === 'object' && sub.properties) obj[k] = initObject(sub)
      else if (sub.type === 'integer') obj[k] = sub.minimum || 0
      else if (sub.type === 'boolean') obj[k] = false
      else obj[k] = ''
    }
  }
  return obj
}

function normalizeArrayItem (item, itemsSchema) {
  const result = {...item}
  for (const [k, sub] of Object.entries(itemsSchema.properties)) {
    if (result[k] === null || result[k] === undefined) {
      if (sub.type === 'array') result[k] = ''
      else if (sub.type === 'object' && sub.properties) result[k] = initObject(sub)
      else if (sub.type === 'integer') result[k] = sub.minimum || 0
      else if (sub.type === 'boolean') result[k] = false
      else result[k] = ''
    } else if (sub.type === 'array' && Array.isArray(result[k])) {
      result[k] = result[k].join('\n')
    } else if (sub.type === 'object' && sub.properties) {
      result[k] = initObjectValue(result[k], sub)
    }
  }
  return result
}

function serializeArrayItem (item, itemsSchema) {
  const result = {...item}
  for (const [k, sub] of Object.entries(itemsSchema.properties)) {
    if (sub.type === 'array' && typeof result[k] === 'string') {
      result[k] = result[k].split('\n').map(s => s.trim()).filter(s => s)
    } else if (sub.type === 'integer') {
      result[k] = parseInt(result[k]) || 0
    }
  }
  return result
}

export function normalizeParams (params, schema) {
  for (const [key, prop] of Object.entries(schema)) {
    if (params[key] === null || params[key] === undefined) {
      if (prop.type === 'array' && prop.items && prop.items.properties) params[key] = []
      else if (prop.type === 'integer') params[key] = prop.minimum || 0
      else if (prop.type === 'boolean') params[key] = false
      else if (prop.type === 'object' && prop.properties) params[key] = initObject(prop)
      else params[key] = ''
    } else if (prop.type === 'array' && Array.isArray(params[key])) {
      if (prop.items && prop.items.properties) {
        params[key] = params[key].map(item => normalizeArrayItem(item, prop.items))
      } else {
        params[key] = params[key].join('\n')
      }
    } else if (prop.type === 'object' && prop.properties) {
      params[key] = initObjectValue(params[key], prop)
    } else if (prop.type === 'object' && typeof params[key] === 'object') {
      params[key] = jsyaml.dump(params[key]).trim()
    }
  }
  return params
}

export function serializeParams (values, schema) {
  const result = {...values}
  for (const [key, prop] of Object.entries(schema)) {
    if (prop.type === 'array' && prop.items && prop.items.properties) {
      result[key] = (result[key] || []).map(item => serializeArrayItem(item, prop.items))
    } else if (prop.type === 'object' && prop.properties) {
      // structured object — send as-is
    } else if (prop.type === 'array' && typeof result[key] === 'string') {
      result[key] = result[key].split('\n').map(s => s.trim()).filter(s => s)
    } else if (prop.type === 'object' && typeof result[key] === 'string') {
      try { result[key] = jsyaml.load(result[key]) } catch (_) {}
    }
  }
  return result
}

export function createArrayItem (itemsSchema) {
  const row = {}
  for (const [k, sub] of Object.entries(itemsSchema.properties)) {
    if (sub.type === 'array') row[k] = ''
    else if (sub.type === 'object' && sub.properties) row[k] = initObject(sub)
    else if (sub.type === 'integer') row[k] = sub.minimum || 0
    else if (sub.type === 'boolean') row[k] = false
    else row[k] = ''
  }
  return row
}
