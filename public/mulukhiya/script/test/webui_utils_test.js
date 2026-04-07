import { assert } from 'chai'
import {
  isDisabledTag,
  toggleTagStatus,
  buildTagStatusCommand,
  tokensToString,
  parseTokens,
  buildEndpointURL,
} from 'webui_utils'

describe('webui_utils', () => {
  describe('isDisabledTag', () => {
    it('無効タグに含まれる場合は true', () => {
      assert.isTrue(isDisabledTag(['foo', 'bar'], 'foo'))
    })

    it('含まれない場合は false', () => {
      assert.isFalse(isDisabledTag(['foo'], 'baz'))
    })

    it('null の場合は false', () => {
      assert.isFalse(isDisabledTag(null, 'foo'))
    })

    it('空配列の場合は false', () => {
      assert.isFalse(isDisabledTag([], 'foo'))
    })
  })

  describe('toggleTagStatus', () => {
    it('有効化: タグをリストから除去', () => {
      const result = toggleTagStatus(['foo', 'bar'], 'foo', true)
      assert.deepEqual(result, ['bar'])
    })

    it('有効化: 最後の1件を除去すると null', () => {
      const result = toggleTagStatus(['foo'], 'foo', true)
      assert.isNull(result)
    })

    it('無効化: タグをリストに追加', () => {
      const result = toggleTagStatus(['foo'], 'bar', false)
      assert.include(result, 'foo')
      assert.include(result, 'bar')
    })

    it('無効化: 重複は除去', () => {
      const result = toggleTagStatus(['foo'], 'foo', false)
      assert.equal(result.length, 1)
    })

    it('null のリストに無効化で追加', () => {
      const result = toggleTagStatus(null, 'foo', false)
      assert.deepEqual(result, ['foo'])
    })
  })

  describe('buildTagStatusCommand', () => {
    it('コマンドオブジェクトを生成', () => {
      const cmd = buildTagStatusCommand(['foo', 'bar'])
      assert.deepEqual(cmd, {tagging: {tags: {disabled: ['foo', 'bar']}}})
    })

    it('null の場合', () => {
      const cmd = buildTagStatusCommand(null)
      assert.deepEqual(cmd, {tagging: {tags: {disabled: null}}})
    })
  })

  describe('tokensToString', () => {
    it('アカウント配列からトークン文字列を生成', () => {
      const accounts = [{token: 'abc'}, {token: 'def'}]
      assert.equal(tokensToString(accounts), 'abc\ndef')
    })

    it('空配列は空文字列', () => {
      assert.equal(tokensToString([]), '')
    })
  })

  describe('parseTokens', () => {
    it('改行区切りの文字列をトークン配列に変換', () => {
      assert.deepEqual(parseTokens('abc\ndef\nghi'), ['abc', 'def', 'ghi'])
    })

    it('空行とスペースをフィルタ', () => {
      assert.deepEqual(parseTokens('abc\n  \n\ndef'), ['abc', 'def'])
    })

    it('前後の空白をトリム', () => {
      assert.deepEqual(parseTokens('  abc  \n  def  '), ['abc', 'def'])
    })
  })

  describe('buildEndpointURL', () => {
    it('パラメータを置換', () => {
      const result = buildEndpointURL('/api/works/:id/episodes', {id: '42'})
      assert.equal(result, '/api/works/42/episodes')
    })

    it('複数パラメータを置換', () => {
      const result = buildEndpointURL('/api/:type/:id', {type: 'works', id: '7'})
      assert.equal(result, '/api/works/7')
    })

    it('パラメータなしはそのまま', () => {
      assert.equal(buildEndpointURL('/api/health', {}), '/api/health')
    })
  })
})
