class Club < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships
  has_many :favourites, -> { where(memberships: { favourite: true }) },
           through: :memberships, source: :member
end
