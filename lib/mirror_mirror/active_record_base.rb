module MirrorMirror::ActiveRecordBase
  extend ActiveSupport::Concern

  included do
    
    def reflect!
      reflect
      save!
      self
    end

    def reflect
      hash = self.class.mirror_request!(:get, mirror_url)
      raise RecordNotFound, "Non-Hash returned from resource: #{mirror_url} => #{hash.inspect}" unless hash.is_a?(Hash)
      raise RecordNotFound, "Empty hash returned from resource."  unless hash.any?
      hash.each {|k,v| send("#{k}=", v) if respond_to?("#{k}=") }
      self
    end

    # (See #mirror_url)
    def mirror_url
      self.class.mirror_url(id)
    end

  end

  module ClassMethods
    
    # The setup/configuration method for mirror_mirror functionality.
    # @param [String] url the url of the resource collection (e.g., http://example.com/api/books)
    # @param [Hash] options
    #   * :find (Boolean) (default to: false) - If true, `#find` will automatically attempt to `#reflect!` the external record based on the given id.
    #   * :request (Symbol, Nil) (defaults to: nil) - Specify a custom class method within the model which will perform the HTTP request.
    # @return [Nil]
    def mirror_mirror(*args)
      options = args.extract_options!
      raise ArgumentError, "url is blank." if args[0].blank?
      options[:url]           = args[0]
      @mirror_mirrior_options = options
      nil
    end

    # Determine if this class has been setup to mirror an external resource using `MirrorMirror`.
    # 
    # @return [Boolean]
    def mirroring?
      mirror_mirror_options[:url].present?
    end

    # Get one, or all, of the mirror_mirror class options. 
    # 
    # @param [Symbol] option the specific option key (e.g., :find, :url, :request)
    # @return [Mixed, Hash] mixed option values, or a Hash containg all class options.
    def mirror_mirror_options(option = nil)
      @mirror_mirrior_options ||= {}
      if option.nil?
        @mirror_mirrior_options
      else
        @mirror_mirrior_options[option]
      end
    end

    # Determine if the `:find => true` option has been specified for this class.
    # 
    # @return [Boolean]
    def mirror_find?
      mirroring? ? @mirror_mirrior_options[:find] : false
    end

    # Get the url specified in the Model's `#mirror_mirror` setup. Optionally specify a record `id`.
    # 
    # @param [Integer] id the resource record id.
    # @return [String] the url.
    def mirror_url(id = nil)
      url = @mirror_mirrior_options[:url]
      url += "/#{id.to_i}" if id.to_i > 0
      url
    end

    # A universial `request` method, used internally, that maps to either the default `#MirrorMirror.request!` method, or
    # to a the optional `:request` method specified in the #mirror_mirror options of the Model. 
    # 
    # @note Will probably go through sweeping changes in the near future.
    # @param [Symbol] verb the http request verb. (`:get`, `:put`, `:post`, and `:delete` are supported)
    # @param [String] url the url to be requested.
    # @param [Hash] params the parameters sent along with the request.
    # @return [Hash, Array] dependant on the context of the call (Record vs Collection)
    def mirror_request!(verb, url, params = {})
      method = @mirror_mirrior_options[:request]
      if method.present?
        raise ArgumentError, "url is blank."          if url.blank?
        raise ArgumentError, "verb is invalid."       unless verb.in?([:get, :put, :post, :delete])
        raise ArgumentError, "params is not a Hash."  unless params.is_a?(Hash) 
        begin
          send(method, verb, url, params)
        rescue => e
          raise FailedRequest, "#{verb.to_s.upcase} #{url} :: Params: #{params} :: Initial Exception: #{e.class.name}: #{e}"
        end
      elsif MirrorMirror.request?
        MirrorMirror.request(verb, url, params)
      else
         raise FailedRequest, "No request method specified."
      end
    end

    # Attempt to reflect all items from the external collection.
    # 
    # @note Not ready for usage; just a thought worth building off from. 
    # @param [Hash] params the parameters to be passed to the request method.
    # @return [Array] of active record objects.
    def reflect_all!(params = {})
      array = mirror_request(:get, mirror_url, params)
      raise RecordNotFound, "Non-Array returned from resource: #{mirror_url} => #{hash.inspect}" unless array.is_a?(Array)
      if array.any?
        transaction do
          array.each do |hash|
            if (id = hash["id"]).present?
              record = find_or_initialize_by_id(id)
              hash.each {|k,v| record.send("#{k}=", v) if record.respond_to?("#{k}=") }
            end
            record.updated_at = Time.now
            record.save!
          end
        end
      end
      all
    end

    # Initialize a new record, set the id, and call `#reflect!`
    #
    # @param [Integer] id the id of the record.
    # @return [Object] the active record object.
    def reflect_by_id!(id)
      record = self.new
      record.id = id
      record.reflect!
      record
    end

    # Call to find_or_initialize_by_id, and `#reflect!` if the record was not found locally.
    #
    # @param [Integer] id the id of the record.
    # @return [Object] the active record object.
    def find_or_reflect_by_id!(*args)
      record = find_or_initialize_by_id(*args)
      record.reflect! if record.new_record?
      record
    end

    # Monkey-Patching of the `ActiveRecord::Base.find()` method to support the `:find => true` option (see #mirror_mirror)
    def find(*args)
      return super unless mirror_find?
      begin
        super
      rescue ActiveRecord::RecordNotFound
        if (id = args[0].to_i) > 0
          record    = self.new
          record.id = id
          record.reflect!
        end
      end
    end
    
    # Monkey-Patching of the `ActiveRecord::Base.belongs_to()` method to support an extra option `:auto_reflect => true`
    # which allows for automatic retrival of the associated record based on the `:foreign_key` using `#find()`
    def belongs_to(*args)
      options           = args.extract_options!
      association_name  = args[0].to_s
      options.delete(:auto_reflect) if auto_reflect = options[:auto_reflect].presence
      if auto_reflect
        self.class_eval <<-RUBY
          def #{association_name}
            if (result = super).blank?
              model = send("#{association_name}_type").constantize
              id    = send("#{association_name}_id")
              if id.present? && model.mirroring? 
                model.reflect_by_id!(id)
                result = super(true)
              end
            end
            result
          end
        RUBY
      end
      super(*(args << options))
    end

  end 
end