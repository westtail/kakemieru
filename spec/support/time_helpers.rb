# travel / travel_to / freeze_time を spec で使えるようにする（rate_limit の時間窓検証などで使用）。
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end
