module Mulukhiya
  # 「書いても黙って効かない／検査されない」設定をスキーマで捕まえる (#4700)。
  #
  # ⚠ ここで見るのは**スキーマが落とすこと**。実行時の読み方（`disable` を読む・
  # `auto_update != false`）は変えていない。
  class ConfigSchemaHolesTest < TestCase
    # 🔴 実行時に読むのは `disable`。`disabled` は読まれないので、書いたら検査で落とす。
    # ⚠ 以前は全ハンドラのスキーマが `disabled` を宣言していて、検査を通って何もしなかった。
    def test_disabled_is_rejected_for_every_handler
      Handler.all_schema[:properties].each_key do |name|
        errors = validate(handler: {name => {disabled: true}})

        assert_equal(1, errors.count {|v| v.include?("#/handler/#{name}/disabled")}, name.to_s)
      end
    end

    # 🔴 **スキーマのファイルが無いハンドラは、検査が丸ごと素通りになる（PR #4825 の Codex P2）。**
    # `all_schema` はファイルから組むので、パイプラインに居るのにファイルが無いと
    # `disabled: true` も型の違う `disable` も通る。`scheduled_status_save` がそうだった。
    def test_every_handler_in_the_pipeline_has_a_schema
      declared = Handler.all_schema[:properties].keys.to_set(&:to_s)

      assert_empty(Handler.all_names.to_set - declared)
    end

    def test_disable_is_declared_as_boolean
      assert_empty(validate(handler: {default_tag: {disable: true}}))
      assert_not_empty(validate(handler: {default_tag: {disable: 'true'}}))
    end

    # ⚠ ハンドラ単体のスキーマ（`Handler#schema`）は default と合成されないので、各ファイルが
    # 自分で `disable` を持つ。`disabled` が残っていたら、また「宣言はあるが読まれない」に戻る。
    def test_each_handler_schema_declares_disable_only
      Dir.glob(File.join(Mulukhiya.dir, 'config/schema/handler/*.yaml')).each do |path|
        next if File.basename(path) == 'default.yaml'
        props = YAML.load_file(path)['properties']

        assert_equal({'type' => 'boolean'}, props['disable'], path)
        assert_not_include(props.keys, 'disabled', path)
      end
    end

    # ⚠ `disable` も `disabled` も WebUI の編集項目に出さない。
    def test_editable_schema_hides_both_spellings
      # ⚠ `new` は DB を要る（CI には無い）。スキーマを読むだけなので `allocate` で足りる。
      keys = DefaultTagHandler.allocate.editable_schema.keys

      assert_include(keys, 'tags')

      assert_not_include(keys, 'disable')
      assert_not_include(keys, 'disabled')
    end

    # `fields` に配列でない値を書くと、辞書 1 本が丸ごと空になる（`select` が NoMethodError）。
    def test_dictionary_fields_must_be_an_array_of_strings
      dic = {url: 'https://example.com/dic.json', type: 'multi_field'}

      assert_empty(validate(handler: {dictionary_tag: {dics: [dic.merge(fields: ['word', 'alias'])]}}))
      assert_not_empty(validate(handler: {dictionary_tag: {dics: [dic.merge(fields: 'word')]}}))
      assert_not_empty(validate(handler: {dictionary_tag: {dics: [dic.merge(fields: [1])]}}))
    end

    # ソースごとの取得間隔 (#4690)。秒の正の整数。
    def test_dictionary_interval_must_be_a_positive_integer
      dic = {url: 'https://example.com/dic.json'}

      assert_empty(validate(handler: {dictionary_tag: {dics: [dic.merge(interval: 3600)]}}))
      ['3600', 0, 1.5].each do |value|
        assert_not_empty(validate(handler: {dictionary_tag: {dics: [dic.merge(interval: value)]}}), value.inspect)
      end
    end

    # 🔴 `Program#auto_update?` は `!= false` で読む。クォートした "false" や 0 は真に倒れて、
    # 番組表エディタの書き込みが全部 409 になる。型の間違いを検査で落とす。
    def test_program_auto_update_must_be_boolean
      urls = ['https://example.com/program.json']

      assert_empty(validate(program: {urls:, auto_update: false}))
      ['false', 0, 'no'].each do |value|
        assert_not_empty(validate(program: {urls:, auto_update: value}), value.inspect)
      end
    end

    # 🔴 **外部サービスの宣言は `/service/*` の下 (#4869)。**以前はトップレベルにあり、
    # annict / spotify / peer_tube の検査が丸ごと効いていなかった。
    def test_service_constraints_are_applied
      assert_not_empty(validate(service: {annict: {dictionary: {keys: ['x']}}}))
      assert_not_empty(validate(service: {annict: {timeout: '5'}}))
      assert_not_empty(validate(service: {peer_tube: {hosts: 'example.com'}}))
      assert_empty(validate(service: {annict: {dictionary: {keys: ['0123456789abcdef']}}}))
    end

    # ⚠⚠ **既定値そのものが検査を通り、unknown_keys も出さない (#4869)。**`service` に properties が
    # あるので、既定に宣言の無いキーを足すと全サーバーの `Config#audit` に出る。`required` を
    # 付けると、その枝を使わないサーバーで検査が落ちる（既定が枝を持つため）。
    def test_service_defaults_are_declared
      defaults = YAML.load_file(File.join(Mulukhiya.dir, 'config/application.yaml'))['service']

      assert_empty(validate(service: defaults))
      assert_empty(config.send(:detect_unknown_keys, {'service' => defaults}, config.schema))
    end

    private

    # ⚠ 必須項目（`controller` / DSN など）の不足は環境ごとに違うので、見たい枝だけを検査する。
    def validate(values)
      schema = config.schema.merge('required' => [])
      return JSON::Validator.fully_validate(schema, values.deep_stringify_keys)
    end
  end
end
