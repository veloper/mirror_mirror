module MirrorMirror::ActiveRecordBase
  extend ActiveSupport::Concern

  included do
    
    def reflect!
      hash = self.class.mirror_request(:get, mirror_url)
      raise RecordNotFound, "Non-Hash returned from resource: #{mirror_url} => #{hash.inspect}" unless hash.is_a?(Hash)
      raise RecordNotFound, "Empty hash returned from resource."  unless hash.any?
      hash.each {|k,v| send("#{k}=", v) if respond_to?("#{k}=") }
      self.updated_at = Time.now
      save!
      self
    end

    def mirror_url
      self.class.mirror_url(id)
    end

  end

  module ClassMethods
    
    def mirror_mirrior(collection_url, options = {})
      options = {}
      options[:url]           = collection_url
      options[:find]          = options[:find].presense || false 
      options[:request]       = options[:request].to_sym if options[:request].present?
      @mirror_mirrior_options = options
    end

    def mirroring?
      @mirror_mirrior_options.present?
    end

    def mirror_find?
      mirroring? ? !!@mirror_mirrior_options[:find] : false
    end

    def mirror_url(id = nil)
      url = @mirror_mirrior_options[:url]
      url += "/#{id.to_i}" if id.to_i > 0
      url
    end

    def mirror_request!(verb = :get, url, params = {})
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

    # Active Record Polymorphing
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

    def find_or_reflect_by_id!(*args)
      record = find_or_initialize_by_id(*args)
      record.reflect! if result.new_record?
      record
    end

    def belongs_to(*args)
      options           = args.extract_options!
      association_name  = args[0].to_s
      options.delete(:auto_reflect) if auto_reflect = options[:auto_reflect].presense
      if auto_reflect
        self.class_eval <<-RUBY
          def #{association_name}
            if (result = super).blank?
              model = send("#{association_name}_type").constantize
              id    = send("#{association_name}_id")
              if id.present? && model.mirroring? 
                model.find_or_reflect_by_id!(id)
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
ActiveRecord::Base.send(:include, MirrorMirror)