import { assert } from 'chai'
import { createMethods, mockAxios, clearMocks } from './test_helper.js'

describe('MulukhiyaLib', () => {
  let methods

  beforeEach(() => {
    clearMocks()
    methods = createMethods()
  })

  describe('dig', () => {
    it('ネストしたプロパティを取得', () => {
      const obj = { a: { b: { c: 42 } } }
      assert.equal(methods.dig(obj, 'a', 'b', 'c'), 42)
    })

    it('浅いプロパティを取得', () => {
      assert.equal(methods.dig({ x: 'hello' }, 'x'), 'hello')
    })

    it('存在しないキーで undefined', () => {
      assert.isUndefined(methods.dig({ a: 1 }, 'b'))
    })

    it('途中が null で undefined', () => {
      assert.isUndefined(methods.dig({ a: null }, 'a', 'b'))
    })

    it('途中が undefined で undefined', () => {
      assert.isUndefined(methods.dig({}, 'a', 'b', 'c'))
    })

    it('関数キーに対応', () => {
      const obj = { items: [10, 20, 30] }
      const result = methods.dig(obj, 'items', arr => arr[1])
      assert.equal(result, 20)
    })

    it('配列インデックスで取得', () => {
      const obj = { list: ['a', 'b', 'c'] }
      assert.equal(methods.dig(obj, 'list', 2), 'c')
    })
  })

  describe('createURL', () => {
    it('ベースURLにパスを付加', () => {
      const url = methods.createURL('/mulukhiya/api/config')
      assert.include(url, '/mulukhiya/api/config')
    })

    it('クエリパラメータを付加', () => {
      const url = methods.createURL('/mulukhiya/api/config', { query: { page: '2' } })
      assert.include(url, 'page=2')
    })

    it('トークンを自動付加', () => {
      methods.setToken('test-token-123')
      const url = methods.createURL('/mulukhiya/api/config')
      assert.include(url, 'token=test-token-123')
    })

    it('明示トークンを優先', () => {
      methods.setToken('default-token')
      const url = methods.createURL('/mulukhiya/api/config', { token: 'override-token' })
      assert.include(url, 'token=override-token')
    })
  })

  describe('createPayload', () => {
    it('トークンとJSON文字列を含む', () => {
      methods.setToken('my-token')
      const payload = methods.createPayload({ command: 'test' })
      assert.equal(payload.token, 'my-token')
      assert.equal(payload.status, JSON.stringify({ command: 'test' }))
      assert.equal(payload.text, JSON.stringify({ command: 'test' }))
    })
  })

  describe('createErrorMessage', () => {
    it('errors オブジェクトからメッセージ生成', () => {
      const error = {
        response: { data: { errors: { name: ['is required', 'is too short'] } } },
      }
      const msg = methods.createErrorMessage(error)
      assert.include(msg, 'name:')
      assert.include(msg, 'is required')
    })

    it('error 文字列をフォールバック', () => {
      const error = { response: { data: { error: 'Unauthorized' } } }
      assert.equal(methods.createErrorMessage(error), 'Unauthorized')
    })

    it('message をフォールバック', () => {
      const error = { response: { data: { message: 'Server Error' } } }
      assert.equal(methods.createErrorMessage(error), 'Server Error')
    })

    it('Error オブジェクトの message', () => {
      const error = { message: 'Network Error' }
      assert.equal(methods.createErrorMessage(error), 'Network Error')
    })

    it('文字列をそのまま返す', () => {
      assert.equal(methods.createErrorMessage('plain error'), 'plain error')
    })
  })

  describe('createAccountInfo', () => {
    it('API レスポンスからアカウント情報を構築', () => {
      const data = {
        account: {
          username: 'testuser',
          roles: ['admin'],
          is_admin: true,
          is_info_bot: false,
          is_test_bot: false,
        },
        token: { scopes: ['read', 'write'], is_scopes_valid: true },
        webhook: { url: 'https://example.com/hook' },
      }
      const info = methods.createAccountInfo(data, 'encrypted-token')
      assert.equal(info.username, 'testuser')
      assert.equal(info.token, 'encrypted-token')
      assert.deepEqual(info.scopes, ['read', 'write'])
      assert.isTrue(info.is_scopes_valid)
      assert.isTrue(info.is_admin)
      assert.isFalse(info.is_info_bot)
      assert.equal(info.webhook, 'https://example.com/hook')
    })

    it('token/webhook が省略可', () => {
      const data = {
        account: { username: 'u', roles: [], is_admin: false, is_info_bot: false, is_test_bot: false },
      }
      const info = methods.createAccountInfo(data, 'tok')
      assert.deepEqual(info.scopes, [])
      assert.isUndefined(info.webhook)
    })
  })

  describe('createProgramTags', () => {
    it('基本のタグ生成', () => {
      const tags = methods.createProgramTags({ series: 'プリキュア', episode: 10 })
      assert.include(tags, 'プリキュア')
      assert.include(tags, '10話')
    })

    it('サブタイトル付き', () => {
      const tags = methods.createProgramTags({ series: 'テスト', subtitle: '冒険の始まり' })
      assert.include(tags, '「冒険の始まり」')
    })

    it('カスタム話数接尾辞', () => {
      const tags = methods.createProgramTags({ series: 'テスト', episode: 3, episode_suffix: '巻' })
      assert.include(tags, '3巻')
    })

    it('エア番組フラグ', () => {
      const tags = methods.createProgramTags({ series: 'テスト', air: true })
      assert.include(tags, 'エア番組')
    })

    it('実況フラグ', () => {
      const tags = methods.createProgramTags({ series: 'テスト', livecure: true })
      assert.include(tags, '実況')
    })

    it('null で空配列', () => {
      assert.deepEqual(methods.createProgramTags(null), [])
    })
  })

  describe('token 管理', () => {
    it('setToken/getToken', () => {
      methods.setToken('abc123')
      assert.equal(methods.getToken(), 'abc123')
    })

    it('getTokens で重複除去', () => {
      methods.setToken('token-a')
      methods.setTokens(['token-a', 'token-b', 'token-a'])
      const tokens = methods.getTokens()
      assert.equal(tokens.filter(t => t === 'token-a').length, 1)
    })

    it('setTokens が null を除去', () => {
      const tokens = methods.setTokens(['a', null, 'b', null])
      assert.deepEqual(tokens, ['a', 'b'])
    })

    it('deleteToken でトークン削除', async () => {
      methods.setToken('keep')
      methods.setTokens(['keep', 'remove', 'also-keep'])
      const remaining = await methods.deleteToken('remove')
      assert.notInclude(remaining, 'remove')
      assert.include(remaining, 'keep')
    })
  })

  describe('suggestedKeywords 管理', () => {
    it('初期状態で空配列', () => {
      assert.deepEqual(methods.getSuggestedKeywords(), [])
    })

    it('キーワード登録', () => {
      methods.registerSuggestedKeyword('プリキュア')
      assert.include(methods.getSuggestedKeywords(), 'プリキュア')
    })

    it('重複を除去', () => {
      methods.registerSuggestedKeyword('テスト')
      methods.registerSuggestedKeyword('テスト')
      assert.equal(methods.getSuggestedKeywords().filter(k => k === 'テスト').length, 1)
    })

    it('最大9件に制限', () => {
      for (let i = 0; i < 12; i++) {
        methods.registerSuggestedKeyword(`keyword-${i}`)
      }
      assert.isAtMost(methods.getSuggestedKeywords().length, 9)
    })

    it('新しいキーワードが先頭', () => {
      methods.registerSuggestedKeyword('first')
      methods.registerSuggestedKeyword('second')
      assert.equal(methods.getSuggestedKeywords()[0], 'second')
    })
  })

  describe('API メソッド (axios mock)', () => {
    it('getConfig がトークン付き GET', async () => {
      methods.setToken('api-token')
      mockAxios('/mulukhiya/api/config', {
        account: { username: 'testuser' },
        config: {},
      })
      const data = await methods.getConfig()
      assert.equal(data.account.username, 'testuser')
    })

    it('getConfig エラー時にフォールバック', async () => {
      methods.setToken('bad-token')
      const data = await methods.getConfig()
      assert.property(data, 'error')
      assert.deepEqual(data.account, {})
    })

    it('updateConfig が POST', async () => {
      methods.setToken('api-token')
      mockAxios('/mulukhiya/api/config/update', { config: { updated: true } })
      const data = await methods.updateConfig({ key: 'value' })
      assert.isTrue(data.config.updated)
    })

    it('getHandlers', async () => {
      methods.setToken('admin-token')
      mockAxios('/mulukhiya/api/admin/handler/list', [
        { name: 'default_tag', disable: false },
      ])
      const data = await methods.getHandlers()
      assert.isArray(data)
      assert.equal(data[0].name, 'default_tag')
    })

    it('toggleHandler', async () => {
      methods.setToken('admin-token')
      mockAxios('/mulukhiya/api/admin/handler/config', { result: 'ok' })
      const data = await methods.toggleHandler('default_tag', true)
      assert.equal(data.result, 'ok')
    })

    it('updateHandlerParams', async () => {
      methods.setToken('admin-token')
      mockAxios('/mulukhiya/api/admin/handler/config', { result: 'ok' })
      const data = await methods.updateHandlerParams('default_tag', { tags: ['test'] })
      assert.equal(data.result, 'ok')
    })
  })
})
