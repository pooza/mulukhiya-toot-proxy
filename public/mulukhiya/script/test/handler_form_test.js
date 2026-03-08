import { assert } from 'chai'
import {
  initObject,
  initObjectValue,
  normalizeParams,
  serializeParams,
  createArrayItem,
} from 'handler_form'

describe('handler_form', () => {
  describe('initObject', () => {
    it('各型のデフォルト値を生成', () => {
      const prop = {
        properties: {
          name: {type: 'string'},
          count: {type: 'integer', minimum: 1},
          flag: {type: 'boolean'},
          items: {type: 'array'},
        },
      }
      const obj = initObject(prop)
      assert.equal(obj.name, '')
      assert.equal(obj.count, 1)
      assert.equal(obj.flag, false)
      assert.deepEqual(obj.items, [])
    })

    it('minimum 未指定の integer は 0', () => {
      const prop = {properties: {n: {type: 'integer'}}}
      assert.equal(initObject(prop).n, 0)
    })

    it('未知の型は空文字列', () => {
      const prop = {properties: {x: {type: 'number'}}}
      assert.equal(initObject(prop).x, '')
    })
  })

  describe('initObjectValue', () => {
    it('null/undefined のプロパティを補完', () => {
      const val = {name: 'existing', count: null}
      const prop = {
        properties: {
          name: {type: 'string'},
          count: {type: 'integer', minimum: 5},
          flag: {type: 'boolean'},
        },
      }
      const obj = initObjectValue(val, prop)
      assert.equal(obj.name, 'existing')
      assert.equal(obj.count, 5)
      assert.equal(obj.flag, false)
    })

    it('val が null なら全プロパティをデフォルト生成', () => {
      const prop = {properties: {a: {type: 'string'}, b: {type: 'boolean'}}}
      const obj = initObjectValue(null, prop)
      assert.equal(obj.a, '')
      assert.equal(obj.b, false)
    })

    it('既存値を保持', () => {
      const val = {tags: ['a', 'b']}
      const prop = {properties: {tags: {type: 'array'}}}
      const obj = initObjectValue(val, prop)
      assert.deepEqual(obj.tags, ['a', 'b'])
    })
  })

  describe('normalizeParams', () => {
    it('未設定の値にデフォルトを設定', () => {
      const params = {}
      const schema = {
        limit: {type: 'integer', minimum: 1},
        enabled: {type: 'boolean'},
        label: {type: 'string'},
      }
      normalizeParams(params, schema)
      assert.equal(params.limit, 1)
      assert.equal(params.enabled, false)
      assert.equal(params.label, '')
    })

    it('配列を改行区切り文字列に変換', () => {
      const params = {tags: ['foo', 'bar']}
      const schema = {tags: {type: 'array'}}
      normalizeParams(params, schema)
      assert.equal(params.tags, 'foo\nbar')
    })

    it('structured object のデフォルト生成', () => {
      const params = {}
      const schema = {
        media_tag: {
          type: 'object',
          properties: {
            tags: {type: 'array'},
            enabled: {type: 'boolean'},
          },
        },
      }
      normalizeParams(params, schema)
      assert.deepEqual(params.media_tag, {tags: [], enabled: false})
    })

    it('structured object の既存値を補完', () => {
      const params = {media_tag: {tags: ['a']}}
      const schema = {
        media_tag: {
          type: 'object',
          properties: {
            tags: {type: 'array'},
            enabled: {type: 'boolean'},
          },
        },
      }
      normalizeParams(params, schema)
      assert.deepEqual(params.media_tag.tags, ['a'])
      assert.equal(params.media_tag.enabled, false)
    })

    it('非structured object を YAML 文字列に変換', () => {
      const params = {custom: {key: 'val'}}
      const schema = {custom: {type: 'object'}}
      normalizeParams(params, schema)
      assert.isString(params.custom)
      assert.include(params.custom, 'key: val')
    })

    it('既存の integer/boolean/string 値を保持', () => {
      const params = {limit: 10, enabled: true, label: 'test'}
      const schema = {
        limit: {type: 'integer'},
        enabled: {type: 'boolean'},
        label: {type: 'string'},
      }
      normalizeParams(params, schema)
      assert.equal(params.limit, 10)
      assert.equal(params.enabled, true)
      assert.equal(params.label, 'test')
    })
  })

  describe('serializeParams', () => {
    it('改行区切り文字列を配列に戻す', () => {
      const values = {tags: 'foo\nbar\nbaz'}
      const schema = {tags: {type: 'array'}}
      const result = serializeParams(values, schema)
      assert.deepEqual(result.tags, ['foo', 'bar', 'baz'])
    })

    it('空行をフィルタ', () => {
      const values = {tags: 'foo\n\n  \nbar'}
      const schema = {tags: {type: 'array'}}
      const result = serializeParams(values, schema)
      assert.deepEqual(result.tags, ['foo', 'bar'])
    })

    it('YAML 文字列をオブジェクトに戻す', () => {
      const values = {custom: 'key: val\nnum: 42'}
      const schema = {custom: {type: 'object'}}
      const result = serializeParams(values, schema)
      assert.deepEqual(result.custom, {key: 'val', num: 42})
    })

    it('structured object はそのまま', () => {
      const obj = {tags: ['a'], enabled: true}
      const values = {media_tag: obj}
      const schema = {media_tag: {type: 'object', properties: {tags: {type: 'array'}, enabled: {type: 'boolean'}}}}
      const result = serializeParams(values, schema)
      assert.deepEqual(result.media_tag, obj)
    })

    it('元の values を変更しない', () => {
      const values = {tags: 'a\nb'}
      const schema = {tags: {type: 'array'}}
      serializeParams(values, schema)
      assert.equal(values.tags, 'a\nb')
    })

    it('不正な YAML でも例外を投げない', () => {
      const values = {custom: '{ invalid yaml ['}
      const schema = {custom: {type: 'object'}}
      assert.doesNotThrow(() => serializeParams(values, schema))
    })
  })

  describe('createArrayItem', () => {
    it('全プロパティが空文字列の行を生成', () => {
      const itemsSchema = {properties: {pattern: {type: 'string'}, replacement: {type: 'string'}}}
      const row = createArrayItem(itemsSchema)
      assert.deepEqual(row, {pattern: '', replacement: ''})
    })
  })

  describe('normalizeParams → serializeParams の対称性', () => {
    it('配列の往復変換', () => {
      const original = {tags: ['foo', 'bar']}
      const schema = {tags: {type: 'array'}}
      const normalized = normalizeParams({...original}, schema)
      assert.equal(normalized.tags, 'foo\nbar')
      const serialized = serializeParams(normalized, schema)
      assert.deepEqual(serialized.tags, ['foo', 'bar'])
    })

    it('非structured object の往復変換', () => {
      const original = {custom: {key: 'val'}}
      const schema = {custom: {type: 'object'}}
      const normalized = normalizeParams({...original}, schema)
      assert.isString(normalized.custom)
      const serialized = serializeParams(normalized, schema)
      assert.deepEqual(serialized.custom, {key: 'val'})
    })
  })
})
