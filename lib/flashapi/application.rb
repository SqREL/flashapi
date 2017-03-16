module FlashAPI
  module Application
    extend self

    def run(request, scope)
      route = scope::Routes.paths[request.uri]
      raise 'NoRouteMatch' unless route
      raise 'NoRouteMatch' unless String(route[:method]) == String(request.request_method).downcase

      Kernel.const_get("#{scope}::#{route[:responder]}")
    end
  end
end
