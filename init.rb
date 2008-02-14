require 'erb_template'
require 'dispatcher'

def after_method(klass, target, feature, &block)
  # Strip out punctuation on predicates or bang methods since
  # e.g. target?_without_feature is not a valid method name.
  aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1

  klass.instance_eval do
    define_method("register_#{feature}", &block)
    define_method("#{aliased_target}_with_#{feature}#{punctuation}") {
      returning send("#{aliased_target}_without_#{feature}#{punctuation}") do
        send("register_#{feature}")
      end
    }
    alias_method_chain target, "#{feature}"
    block
  end
end unless self.class.method_defined?(:after_method)

def after_reload_application(feature, &block)
  after_method(ActionController::Dispatcher, :reload_application, feature, &block)
end unless self.class.method_defined?(:after_reload_application)

after_reload_application("erb_registration") {
  Site.register_template_handler(".rhtml", ErbTemplate)
  unless BaseDrop.method_defined?(:method_missing)
    BaseDrop.class_eval do
      define_method("method_missing") { |name|
        self[name]
      }
    end
  end
}
