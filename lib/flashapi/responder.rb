module FlashAPI
  module Responder
    def status_code
      render[:status_code] || default_status_code
    end

    def headers
      render[:headers] || default_headers
    end

    def body
      response_body = {
        status_code: status_code,
        success: (status_code >= 200 && status_code <= 299)
      }.merge(render[:body])

      Oj.dump(response_body, mode: :compat)
    end

    def default_status_code
      200
    end

    def default_headers
      { 'Content-Type' => 'application/json' }.dup
    end
  end
end
