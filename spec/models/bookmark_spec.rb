require "rails_helper"

RSpec.describe Bookmark, type: :model do
  describe "uniqueness" do
    it "does not allow duplicate user and event" do
      user = create(:user)
      event = create(:event)
      create(:bookmark, user: user, event: event)

      dup = build(:bookmark, user: user, event: event)
      expect(dup).not_to be_valid
      expect(dup.errors.details[:event_id].map { |d| d[:error] }).to include(:taken)
    end
  end
end
