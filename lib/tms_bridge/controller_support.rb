require 'iron_cacher'
module TmsBridge
  module ControllerSupport
    
    module Redact
      def redacts_tms(as, _bridged_resource_names)
        extend TmsBridge::ControllerSupport::Security unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Security)
        self.secure_tms_bridge(as)
        extend TmsBridge::ControllerSupport::Redact::ClassMethods unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Redact::ClassMethods)
        
        self.bridged_resource_names=_bridged_resource_names

class_eval <<-RUBY, __FILE__, __LINE__+1
        def create
          @record_class = self.bridged_resource_class
          if @record_class
            if @record = @record_class.find_by_tms_id(json_params[:tms_id])
              @record.destroy
            end
            render ActiveSupport::VERSION::MAJOR < 5 ? {text: 'success'} : {plain: 'success'}
          else
            head :ok
          end
        end
RUBY
      end

      module ClassMethods
        def self.extended(base)
          base.class_attribute(:bridged_resource_names)
        end
      end      
    end

    module Publish
      def publishes_tms(as, options={})
        extend TmsBridge::ControllerSupport::Security unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Security)
        extend TmsBridge::ControllerSupport::Publish::ClassMethods unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Publish::ClassMethods)
        include TmsBridge::ControllerSupport::Publish::InstanceMethods unless included_modules.include?(TmsBridge::ControllerSupport::Publish::InstanceMethods)

        self.secure_tms_bridge(as)
        
        class_name = self.bridged_resources.classify

        options= options.reverse_merge({:update_only=>false, :model_params_key=>self.bridged_resource})

        self.update_only = options[:update_only]
        self.model_params_key =  options[:model_params_key] || options[:cache_key]
        self.bridged_resource_names=options[:bridged_resource_names] || [class_name]
        self.bridged_resource_name=self.bridged_resource_names.first

      class_eval <<-RUBY, __FILE__, __LINE__+1
        def create
          @#{self.bridged_resource} = #{class_name}.find_by_tms_id(json_params[:tms_id])
          
          if @#{self.bridged_resource}.nil? && #{class_name}.column_names.include?('bridge_id') && !json_params[:bridge_id].blank?
            @#{self.bridged_resource} = #{class_name}.find_by_bridge_id(json_params[:bridge_id]) 
          end
          
          @#{self.bridged_resource} = #{class_name}.new if @#{self.bridged_resource}.nil? && !self.update_only?

          if @#{self.bridged_resource}
            @#{self.bridged_resource}.attributes = self.model_attributes
            @#{self.bridged_resource}.save(validate: false)
          end
          render ActiveSupport::VERSION::MAJOR < 5 ? {text: 'success'} : {plain: 'success'}
        end        
      RUBY
  
 
      end
      
      module ClassMethods
        def self.extended(base)
          base.class_attribute :update_only
          base.class_attribute(:model_params_key)
          base.class_attribute(:bridged_resource_names)
          base.class_attribute(:bridged_resource_name)
        end
      end
      
      module InstanceMethods
        def update_only?
          self.class.update_only
        end
      end

    end
    
    module Security
      
      def secure_tms_bridge(as)
        include TmsBridge::ControllerSupport::Security::InstanceMethods
        extend TmsBridge::ControllerSupport::Security::ClassMethods
        
        if ActiveSupport::VERSION::MAJOR < 5
          before_filter :parse_iron_mq_json
        else
          before_action :parse_iron_mq_json
        end
        
        self.as = as.to_s

        self.bridged_resources = self.name.split('::').last.gsub(/Controller/, '').underscore
        self.bridged_resource = self.bridged_resources.singularize
        self.queue_name = self.as + '_'+self.bridged_resources        
      end

      module InstanceMethods
        include IronCacher
        protected
        def parse_iron_mq_json
          @json=JSON.parse(request.raw_post).with_indifferent_access unless request.raw_post.blank?
          unless @json && @json[:tms_id]
            head :ok
            return false
          end
        end

        def model_attributes
          return self.json_params.require(self.class.model_params_key).permit(self.bridged_resource_class.published_attribute_names)
        end
        
        def json_params
          return ActionController::Parameters.new( @json )
        end

        def valid_bridge_request?
          if @json && @json[:cache_key]
            value = Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@json[:tms_id]}--#{self.class.queue_name}--#{IronCacher::CACHE_NAME}--")
            return value == retrieve_from_cache(@json[:cache_key], IronCacher::CACHE_NAME)
          end
        end        
        
        def bridged_resource_class
          if json_params[:record_class]
            class_name = json_params[:record_class]
            resource_class=class_name.constantize if self.class.bridged_resource_names.include?(class_name)
          else
            resource_class=self.bridged_resource_name.constantize
          end
          return resource_class
        end
        
      end
      
  
      module ClassMethods
        def self.extended(base)
          base.class_attribute(:queue_name)
          base.class_attribute(:as)
          base.class_attribute(:bridged_resource)
          base.class_attribute(:bridged_resources)
        end
        
      end
      
    end

  end
  
  
end

ActionController::Base.send(:extend, TmsBridge::ControllerSupport::Publish)
ActionController::Base.send(:extend, TmsBridge::ControllerSupport::Redact)