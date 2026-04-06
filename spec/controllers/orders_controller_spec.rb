require "rails_helper"

RSpec.describe Api::V1::OrdersController, type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:attendee) { create(:user) }
  let(:other_attendee) { create(:user) }
  let(:event) { create(:event, user: organizer, status: "published", starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours) }
  let(:tier) { create(:ticket_tier, event: event, quantity: 100, sold_count: 0) }

  def auth_headers(user)
    token = user.generate_jwt
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/orders" do
    it "returns only the current user's orders" do
      mine = create(:order, user: attendee, event: event)
      create(:order, user: other_attendee, event: event)

      get "/api/v1/orders", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
      expect(data.first["id"]).to eq(mine.id)
    end
  end

  describe "GET /api/v1/orders/:id" do
    it "returns order details when the order belongs to the current user" do
      order = create(:order, user: attendee, event: event)

      get "/api/v1/orders/#{order.id}", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(order.id)
    end

    it "does not return another user's order" do
      other_order = create(:order, user: other_attendee, event: event)

      get "/api/v1/orders/#{other_order.id}", headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/orders/:id/cancel" do
    it "cancels a pending order belonging to the current user" do
      order = create(:order, user: attendee, event: event, status: "pending")

      post "/api/v1/orders/#{order.id}/cancel", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("cancelled")
    end

    it "does not cancel another user's order" do
      other_order = create(:order, user: other_attendee, event: event, status: "pending")

      post "/api/v1/orders/#{other_order.id}/cancel", headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
      expect(other_order.reload.status).to eq("pending")
    end
  end
end
