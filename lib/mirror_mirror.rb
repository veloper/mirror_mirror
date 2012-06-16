require "mirror_mirror/version"

module MirrorMirror
  autoload :ActiveRecordBase, 'mirror_mirror/active_record_base' 

  class RecordNotFound < ::StandardError; end
  class FailedRequest < ::StandardError; end

  class << self
    def request!(verb = :get, url = nil, params = {}, &block)
      unless block_given?
        raise ArgumentError, "url is blank."          if url.blank?
        raise ArgumentError, "verb is invalid."       unless verb.in?([:get, :put, :post, :delete])
        raise ArgumentError, "params is not a Hash."  unless params.is_a?(Hash)
        begin
          return @request_proc.call(verb, url, params)
        rescue => e
          raise FailedRequest, "#{verb.to_s.upcase} #{url} :: Params: #{params} :: Initial Exception: #{e.class.name}: #{e}"
        end
      end
      @request_proc = Proc.new(&block)
    end

    def request?
      @request_proc.present?
    end
  end
end
