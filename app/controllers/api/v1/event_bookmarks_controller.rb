module Api
  module V1
    class EventBookmarksController < ApplicationController
      before_action :require_attendee!
      before_action :set_event

      def create
        bookmark = current_user.bookmarks.build(event: @event)
        if bookmark.save
          head :created
        elsif bookmark.errors.details[:event_id].any? { |d| d[:error] == :taken }
          render json: { error: "Already bookmarked" }, status: 422
        else
          render json: { errors: bookmark.errors.full_messages }, status: 422
        end
      rescue ActiveRecord::RecordNotUnique
        render json: { error: "Already bookmarked" }, status: 422
      end

      def destroy
        bookmark = current_user.bookmarks.find_by!(event: @event)
        bookmark.destroy!
        head :no_content
      end

      private

      def set_event
        @event = Event.find(params[:event_id])
      end
    end
  end
end
