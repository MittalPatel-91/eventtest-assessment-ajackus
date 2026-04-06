module Api
  module V1
    class BookmarksController < ApplicationController
      before_action :require_attendee!

      def index
        bookmarks = current_user.bookmarks.includes(:event).order(created_at: :desc)

        render json: bookmarks.map { |b| bookmark_json(b) }
      end

      private

      def bookmark_json(b)
        e = b.event
        {
          id: b.id,
          bookmarked_at: b.created_at,
          event: {
            id: e.id,
            title: e.title,
            venue: e.venue,
            city: e.city,
            starts_at: e.starts_at,
            ends_at: e.ends_at
          }
        }
      end
    end
  end
end
