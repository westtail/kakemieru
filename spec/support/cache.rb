# test 環境は rate_limit を検証するため memory_store を使う（test.rb 参照）。
# キャッシュは同一プロセス内で永続するため、例をまたいだ rate_limit カウンタの
# 累積で誤って制限が発火しないよう、各例の前にクリアする。
RSpec.configure do |config|
  config.before(:each) { Rails.cache.clear }
end
