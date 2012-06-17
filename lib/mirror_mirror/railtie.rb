module MirrorMirror
  class Railtie < Rails::Railtie

    initializer 'mirror_mirror.active_record_base' do |app|
      ActiveSupport.on_load :active_record do
        include MirrorMirror::ActiveRecordBase
      end
    end

  end
end