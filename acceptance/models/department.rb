class Department < ActiveRecord::Base
  belongs_to :resource, polymorphic: true
end
