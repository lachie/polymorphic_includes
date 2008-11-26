$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
  
require 'smartbomb/polymorphic_includes'

ActiveRecord::Base.class_eval do
  include Smartbomb::PolymorphicIncludes
end