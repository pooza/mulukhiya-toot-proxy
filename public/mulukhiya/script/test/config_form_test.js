import { assert } from 'chai'
import {
  dig,
  extractFormValues,
  extractVisibilityOptions,
  buildProgramOptions,
  convertProgramToTags,
  buildTagsCommand,
  buildPiefedCommand,
  buildWebhookCommand,
  buildNotifyCommand,
  buildAnnictCommand,
} from 'config_form'

describe('config_form', () => {
  describe('dig', () => {
    it('ネストされた値を取得', () => {
      const obj = {a: {b: {c: 42}}}
      assert.equal(dig(obj, 'a', 'b', 'c'), 42)
    })

    it('存在しないパスは undefined', () => {
      assert.isUndefined(dig({a: 1}, 'x', 'y'))
    })

    it('null を含むパスは undefined', () => {
      assert.isUndefined(dig({a: null}, 'a', 'b'))
    })

    it('空のキーリストは対象をそのまま返す', () => {
      assert.equal(dig(42), 42)
    })
  })

  describe('extractFormValues', () => {
    it('API レスポンスからフォーム値を抽出', () => {
      const data = {
        config: {
          webhook: {visibility: 'unlisted'},
          piefed: {url: 'https://example.com', user: 'alice', community: 5},
          service: {annict: {theme_works_only: true}},
          notify: {verbose: true},
          tagging: {user_tags: ['precure', 'fun']},
          decoration: {id: 'deco1'},
        },
      }
      const form = extractFormValues(data)
      assert.equal(form.webhook.visibility, 'unlisted')
      assert.equal(form.piefed.url, 'https://example.com')
      assert.equal(form.piefed.user, 'alice')
      assert.equal(form.piefed.community, 5)
      assert.equal(form.annict.theme_works_only, true)
      assert.equal(form.notify.verbose, true)
      assert.equal(form.tags, 'precure\nfun')
      assert.equal(form.decoration.id, 'deco1')
    })

    it('空の config ではデフォルト値', () => {
      const form = extractFormValues({config: {}})
      assert.equal(form.webhook.visibility, 'public')
      assert.isUndefined(form.piefed.url)
      assert.equal(form.annict.theme_works_only, false)
      assert.equal(form.notify.verbose, false)
      assert.equal(form.tags, '')
      assert.isNull(form.decoration.id)
    })

    it('user_tags が未設定なら空文字列', () => {
      const form = extractFormValues({config: {tagging: {}}})
      assert.equal(form.tags, '')
    })

    it('decoration.id が未設定なら null', () => {
      const form = extractFormValues({config: {decoration: {}}})
      assert.isNull(form.decoration.id)
    })
  })

  describe('extractVisibilityOptions', () => {
    it('visibility_names からオプション配列を生成', () => {
      const data = {visibility_names: {'公開': 'public', 'unlisted': 'unlisted', '非公開': 'unlisted'}}
      const options = extractVisibilityOptions(data)
      assert.equal(options.length, 2)
      assert.equal(options[0].value, 'public')
      assert.equal(options[0].label, 'public (公開)')
      assert.equal(options[1].value, 'unlisted')
    })

    it('同じキーと値なら括弧なし', () => {
      const data = {visibility_names: {'public': 'public'}}
      const options = extractVisibilityOptions(data)
      assert.equal(options[0].label, 'public')
    })

    it('visibility_names がなければ空配列', () => {
      assert.deepEqual(extractVisibilityOptions({}), [])
    })
  })

  describe('buildProgramOptions', () => {
    const mockCreateProgramTags = program => {
      const tags = [program.series]
      if (program.episode) tags.push(`${program.episode}話`)
      return tags
    }

    it('有効な番組からオプションを生成', () => {
      const programs = {
        p1: {key: 'p1', series: 'プリキュア', episode: 5, minutes: 30, enable: true},
        p2: {key: 'p2', series: '休止', enable: false},
      }
      const options = buildProgramOptions(programs, mockCreateProgramTags)
      assert.equal(options.length, 2)
      assert.equal(options[0].label, '(タグセットのクリア)')
      assert.include(options[1].label, 'プリキュア')
      assert.include(options[1].label, '30分')
    })

    it('minutes なしの番組は時間表示なし', () => {
      const programs = {
        p1: {key: 'p1', series: 'テスト', enable: true},
      }
      const options = buildProgramOptions(programs, mockCreateProgramTags)
      assert.equal(options[1].label, 'テスト')
    })
  })

  describe('convertProgramToTags', () => {
    const programs = {
      cure: {series: 'プリキュア', episode: 10, minutes: 30},
    }
    const mockCreateProgramTags = program => [program.series, `${program.episode}話`]

    it('番組選択時にタグと分数を返す', () => {
      const result = convertProgramToTags({code: 'cure'}, programs, mockCreateProgramTags)
      assert.equal(result.tags, 'プリキュア\n10話')
      assert.equal(result.minutes, 30)
    })

    it('選択クリア時は null を返す', () => {
      const result = convertProgramToTags(null, programs, mockCreateProgramTags)
      assert.isNull(result.tags)
      assert.isNull(result.minutes)
    })

    it('code なしのオブジェクトは null を返す', () => {
      const result = convertProgramToTags({}, programs, mockCreateProgramTags)
      assert.isNull(result.tags)
    })
  })

  describe('buildTagsCommand', () => {
    it('タグありの場合', () => {
      const form = {tags: 'precure\nfun', program: {minutes: 30}, decoration: {id: null}}
      const cmd = buildTagsCommand(form)
      assert.deepEqual(cmd.tagging.user_tags, ['precure', 'fun'])
      assert.equal(cmd.tagging.minutes, 30)
      assert.isNull(cmd.decoration.id)
    })

    it('タグ + デコレーションありの場合', () => {
      const form = {tags: 'precure', program: {minutes: 30}, decoration: {id: 'deco1'}}
      const cmd = buildTagsCommand(form)
      assert.deepEqual(cmd.tagging.user_tags, ['precure'])
      assert.equal(cmd.decoration.id, 'deco1')
      assert.equal(cmd.decoration.minutes, 30)
    })

    it('タグなしの場合は user_tags と minutes が null', () => {
      const form = {tags: '', program: {minutes: null}, decoration: {id: null}}
      const cmd = buildTagsCommand(form)
      assert.isNull(cmd.tagging.user_tags)
      assert.isNull(cmd.tagging.minutes)
    })

    it('minutes なしの場合は minutes を含まない', () => {
      const form = {tags: 'tag1', program: {minutes: null}, decoration: {id: null}}
      const cmd = buildTagsCommand(form)
      assert.deepEqual(cmd.tagging.user_tags, ['tag1'])
      assert.isNull(cmd.tagging.minutes)
    })
  })

  describe('buildPiefedCommand', () => {
    it('全フィールド入力時', () => {
      const form = {piefed: {url: 'https://pf.example.com', user: 'alice', password: 'secret', community: '42'}}
      const cmd = buildPiefedCommand(form)
      assert.equal(cmd.piefed.url, 'https://pf.example.com')
      assert.equal(cmd.piefed.user, 'alice')
      assert.equal(cmd.piefed.password, 'secret')
      assert.equal(cmd.piefed.community, 42)
      assert.isNull(cmd.piefed.host)
    })

    it('community を数値に変換', () => {
      const form = {piefed: {url: null, user: null, password: null, community: '7'}}
      const cmd = buildPiefedCommand(form)
      assert.strictEqual(cmd.piefed.community, 7)
    })

    it('空のフィールドは null のまま', () => {
      const form = {piefed: {url: null, user: null, password: null, community: null}}
      const cmd = buildPiefedCommand(form)
      assert.isNull(cmd.piefed.url)
      assert.isNull(cmd.piefed.user)
      assert.isUndefined(cmd.piefed.password)
      assert.isNull(cmd.piefed.community)
    })
  })

  describe('buildWebhookCommand', () => {
    it('public 以外の場合は visibility を設定', () => {
      const form = {webhook: {visibility: 'unlisted'}}
      const cmd = buildWebhookCommand(form)
      assert.equal(cmd.webhook.visibility, 'unlisted')
    })

    it('public の場合は visibility を null にする', () => {
      const form = {webhook: {visibility: 'public'}}
      const cmd = buildWebhookCommand(form)
      assert.isNull(cmd.webhook.visibility)
    })
  })

  describe('buildNotifyCommand', () => {
    it('verbose true の場合', () => {
      const form = {notify: {verbose: true}}
      const cmd = buildNotifyCommand(form)
      assert.isTrue(cmd.notify.verbose)
    })

    it('verbose false の場合は null', () => {
      const form = {notify: {verbose: false}}
      const cmd = buildNotifyCommand(form)
      assert.isNull(cmd.notify.verbose)
    })
  })

  describe('buildAnnictCommand', () => {
    it('theme_works_only true の場合', () => {
      const form = {annict: {theme_works_only: true}}
      const cmd = buildAnnictCommand(form)
      assert.isTrue(cmd.service.annict.theme_works_only)
    })

    it('theme_works_only false の場合は null', () => {
      const form = {annict: {theme_works_only: false}}
      const cmd = buildAnnictCommand(form)
      assert.isNull(cmd.service.annict.theme_works_only)
    })
  })
})
