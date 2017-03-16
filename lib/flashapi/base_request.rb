module FlashAPI
  class BaseRequest
    ATTRIBUTES =  :protocol, :request_method, :cookie,
                  :content_type, :path_info, :uri,
                  :query_string, :post_content, :headers

    attr_accessor *ATTRIBUTES

    def initialize(params)
      ATTRIBUTES.each do |attribute|
        instance_variable_set("@#{attribute}", params[attribute])
      end
    end
  end
end
