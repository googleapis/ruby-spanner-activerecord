class Member < ActiveRecord::Base
  has_one :membership
  has_one :club, through: :membership
  has_one :favourite_club, -> { where "memberships.favourite = ?", true },
          through: :membership, source: :club
  belongs_to :member_type
end
