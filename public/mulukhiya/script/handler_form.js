import jsyaml from 'js-yaml'

export function initObject (prop) {
  const obj = {}
  for (const [k, sub] of Object.entries(prop.properties)) {
    if (sub.type === 'array') obj[k] = []
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
      else if (sub.type === 'integer') obj[k] = sub.minimum || 0
      else if (sub.type === 'boolean') obj[k] = false
      else obj[k] = ''
    }
  }
  return obj
}

export function normalizeParams (params, schema) {
  for (const [key, prop] of Object.entries(schema)) {
    if (params[key] === null || params[key] === undefined) {
      if (prop.type === 'integer') params[key] = prop.minimum || 0
      else if (prop.type === 'boolean') params[key] = false
      else if (prop.type === 'object' && prop.properties) params[key] = initObject(prop)
      else params[key] = ''
    } else if (prop.type === 'object' && prop.properties) {
      params[key] = initObjectValue(params[key], prop)
    } else if (prop.type === 'array' && Array.isArray(params[key])) {
      params[key] = params[key].join('\n')
    } else if (prop.type === 'object' && typeof params[key] === 'object') {
      params[key] = jsyaml.dump(params[key]).trim()
    }
  }
  return params
}

export function serializeParams (values, schema) {
  const result = {...values}
  for (const [key, prop] of Object.entries(schema)) {
    if (prop.type === 'object' && prop.properties) {
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
  for (const k of Object.keys(itemsSchema.properties)) { row[k] = '' }
  return row
}
