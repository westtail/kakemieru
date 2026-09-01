module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session = Session.find_by(id: cookies.signed[:session_id])
      return unless session

      # cookie の expires はクライアント任せなので、サーバー側でも期限切れを拒否する
      # （盗難 cookie の有効期間を実効的に SESSION_DURATION に限定する）。
      if session.created_at < SESSION_DURATION.ago
        session.destroy
        return
      end

      session
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    # セッション cookie の有効期間。permanent（実質無期限）だと盗難 cookie の有効期間が
    # 長期化するため、妥当な期間で失効させる。
    SESSION_DURATION = 3.days

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed[:session_id] = {
          value: session.id, httponly: true, same_site: :lax, expires: SESSION_DURATION.from_now
        }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
