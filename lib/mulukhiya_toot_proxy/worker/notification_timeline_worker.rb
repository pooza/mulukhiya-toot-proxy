module MulukhiyaTootProxy
  class NotificationTimelineWorker
    include Sidekiq::Worker

    def initialize
      @logger = Logger.new
    end

    def perform(params)
      db.begin
      db.execute('notificatable_accounts', {id: params['from_account_id']}).each do |row|
        db.execute('insert_mention', {
          status_id: params['status_id'],
          account_id: row['id'],
        })
        db.execute('insert_notification', {
          activity_id: db.execute('last_mention_seq').first['id'],
          activity_type: 'Mention',
          from_account_id: params['from_account_id'],
          account_id: row['id'],
        })
      rescue => e
        @logger.error(e)
        next
      end
      db.commit
    end

    def db
      return Postgres.instance
    end
  end
end
