# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "io/console"
require_relative "../config/environment"
require_relative "models/meeting"

class Application
  def self.run
    # Set the default local timezone.
    Time.zone = "Europe/Lisbon"

    # Create a meeting using the local timezone. The timezone information will not be stored in the `meeting_time`
    # column in the database, which is why we also include a separate column where we can store the timezone name.
    meeting_time = Time.zone.local 2021, 7, 1, 10, 30, 0
    meeting = Meeting.create title: "Standup", meeting_time: meeting_time, meeting_timezone: Time.zone.name

    # The meeting_time is saved in UTC in Cloud Spanner. Reloading it will therefore lose the timezone information in
    # the meeting_time attribute. It is however stored in the separate meeting_timezone attribute, and that can be used
    # to reconstruct the meeting_time in the timezone where the meeting was planned.
    # The Meeting model class also contains two helper methods:
    # 1. `local_meeting_time`: Returns the meeting_time in the local timezone.
    # 2. `meeting_time_in_planned_zone`: Returns the meeting_time in the timezone where it is planned.
    meeting.reload
    puts ""
    puts "#{'Meeting time in UTC:'.ljust 60} #{meeting.meeting_time}"
    puts "#{'Meeting time in the timezone where it was planned:'.ljust 60} #{meeting.meeting_time_in_planned_zone}"

    # Simulate that the application is now running in the timezone America/Los_Angeles.
    Time.zone = "America/Los_Angeles"
    puts "#{'Meeting time in the local timezone (America/Los_Angeles):'.ljust 60} #{meeting.local_meeting_time}"

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
