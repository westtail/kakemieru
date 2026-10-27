# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# 家計データはこのアプリが預かる中で最も機微な情報なので、ログに残さない。
# Rails は INFO レベルでリクエストパラメータを出力するため、何も指定しないと手動入力・明細編集・
# 検索キーワードがそのまま Fly.io のログに平文で蓄積される。一度書かれると DB と違って
# 後から消すのが難しい。
#
# :amount は部分一致なので amount_override / amount_min / amount_max も覆う。
# カテゴリ名・支払方法名はネストキー指定にする。単なる :name だと部分一致で広く巻き込み、
# 障害調査で見たい値まで消えてしまうため。
# date / payment_type / sort / direction / month は機微ではなく調査で有用なので残す。
Rails.application.config.filter_parameters += [
  :merchant_name, :amount, :description, :note, :q,
  "category.name", "payment_method.name"
]
