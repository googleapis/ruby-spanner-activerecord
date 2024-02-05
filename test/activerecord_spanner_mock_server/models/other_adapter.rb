# Copyright 2024 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module MockServerTests
  class System < ActiveRecord::Base
    has_many :projects
  end

  class Plan < ActiveRecord::Base
    has_many :projects
  end

  class Project < ActiveRecord::Base
    belongs_to :system
    belongs_to :plan
  end
end
