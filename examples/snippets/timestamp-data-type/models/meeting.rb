# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Meeting < ActiveRecord::Base
  # Returns the meeting time in the local timezone.
  def local_meeting_time
    return unless meeting_time && Time.zone
    meeting_time.in_time_zone Time.zone
  end

  # Returns the time of the meeting in the timezone where the meeting is planned.
  def meeting_time_in_planned_zone
    return unless meeting_time && meeting_timezone
    meeting_time.in_time_zone meeting_timezone
  end
end
