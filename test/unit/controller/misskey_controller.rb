module Mulukhiya
  class MisskeyControllerTest < ControllerTestCase
    def app
      return MisskeyController
    end

    def setup
      super
      config['/controller'] = 'misskey'
      config['/misskey/url'] = 'https://misskey.example.com'
    end

    def test_drive_files_create_forwards_folder_id
      stub_request(:post, upstream_url('/api/drive/files/create'))
        .to_return(
          status: 200,
          body: {id: 'abc123', name: 'test.png'}.to_json,
          headers: {'Content-Type' => 'application/json'},
        )

      file = Tempfile.new(['mulukhiya-test', '.png'])
      file.binmode
      file.write("\x89PNG\r\n\x1a\n")
      file.rewind

      post '/api/drive/files/create', {
        file: Rack::Test::UploadedFile.new(file.path, 'image/png'),
        folderId: 'a9yox52ls4',
        name: 'test.png',
      }

      assert_requested(:post, upstream_url('/api/drive/files/create')) do |req|
        body = req.body.to_s
        body.include?('name="folderId"') && body.include?('a9yox52ls4')
      end
    ensure
      file&.close
      file&.unlink
    end

    def test_notes_create_forwards_text_and_visibility
      stub_request(:post, upstream_url('/api/notes/create'))
        .to_return(
          status: 200,
          body: {createdNote: {id: 'note123', user: {id: 'u1'}}}.to_json,
          headers: {'Content-Type' => 'application/json'},
        )

      post '/api/notes/create', {
        text: 'hello world',
        visibility: 'public',
      }.to_json, {'CONTENT_TYPE' => 'application/json'}

      assert_requested(:post, upstream_url('/api/notes/create')) do |req|
        body = JSON.parse(req.body.to_s)
        body['text'] == 'hello world' && body['visibility'] == 'public'
      end
    end
  end
end
