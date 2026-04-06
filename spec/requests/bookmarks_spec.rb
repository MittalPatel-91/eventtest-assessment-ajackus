require "rails_helper"

RSpec.describe "Bookmarks API", type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:attendee) { create(:user) }
  let(:other_attendee) { create(:user) }
  let(:event) { create(:event, user: organizer, status: "published", starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours) }

  def auth_headers(user)
    token = user.generate_jwt
    { "Authorization" => "Bearer #{token}" }
  end

  describe "POST /api/v1/events/:event_id/bookmarks" do
    it "creates a bookmark for an attendee" do
      post "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:created)
      expect(attendee.bookmarks.where(event: event)).to exist
    end

    it "rejects a duplicate bookmark" do
      create(:bookmark, user: attendee, event: event)

      post "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["error"]).to eq("Already bookmarked")
      expect(attendee.bookmarks.where(event: event).count).to eq(1)
    end

    it "forbids organizers from bookmarking" do
      post "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns unauthorized without a token" do
      post "/api/v1/events/#{event.id}/bookmarks"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/events/:event_id/bookmarks" do
    it "removes the attendee's bookmark" do
      create(:bookmark, user: attendee, event: event)

      delete "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:no_content)
      expect(attendee.bookmarks.where(event: event)).not_to exist
    end

    it "returns 404 when no bookmark exists for that event" do
      delete "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
    end

    it "does not delete another user's bookmark" do
      create(:bookmark, user: other_attendee, event: event)

      expect do
        delete "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(attendee)
      end.not_to change { Bookmark.count }

      expect(response).to have_http_status(:not_found)
      expect(other_attendee.bookmarks.where(event: event)).to exist
    end
  end

  describe "GET /api/v1/bookmarks" do
    it "lists the current user's bookmarks" do
      other_event = create(:event, user: organizer, status: "published", starts_at: 3.weeks.from_now, ends_at: 3.weeks.from_now + 3.hours)
      create(:bookmark, user: attendee, event: event)
      create(:bookmark, user: attendee, event: other_event)
      create(:bookmark, user: other_attendee, event: event)

      get "/api/v1/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(2)
      expect(data.map { |b| b.dig("event", "id") }).to contain_exactly(event.id, other_event.id)
    end

    it "forbids non-attendees" do
      get "/api/v1/bookmarks", headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/events/:id (organizer bookmark count)" do
    it "includes bookmarks_count for the event organizer" do
      create(:bookmark, user: attendee, event: event)
      create(:bookmark, user: other_attendee, event: event)

      get "/api/v1/events/#{event.id}", headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["bookmarks_count"]).to eq(2)
    end

    it "does not include bookmarks_count for an attendee viewer" do
      create(:bookmark, user: other_attendee, event: event)

      get "/api/v1/events/#{event.id}", headers: auth_headers(attendee)

      body = JSON.parse(response.body)
      expect(body).not_to have_key("bookmarks_count")
    end

    it "does not include bookmarks_count without auth" do
      create(:bookmark, user: attendee, event: event)

      get "/api/v1/events/#{event.id}"

      body = JSON.parse(response.body)
      expect(body).not_to have_key("bookmarks_count")
    end
  end
end
