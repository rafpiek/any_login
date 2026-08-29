require 'any_login/engine'

module AnyLogin
  extend ActiveSupport::Autoload

  autoload :Helpers

  module Provider
    autoload :Devise,    'any_login/providers/devise'
    autoload :Authlogic, 'any_login/providers/authlogic'
    autoload :Clearance, 'any_login/providers/clearance'
    autoload :Sorcery,   'any_login/providers/sorcery'
  end

  # enable in development mode only
  mattr_accessor :enabled
  @@enabled = Rails.env.to_s == 'development'

  # current provider, depends on auth gem
  mattr_accessor :provider
  @@provider = nil

  # Account, User, Person, etc
  mattr_accessor :klass_name
  @@klass_name = 'User'

  # Sign-in Method
  mattr_accessor :sign_in
  @@sign_in = nil

  # .all, .active, .admins, .groped_collection, etc ... need to return an array (or hash with arrays) of users
  mattr_accessor :collection_method
  @@collection_method = :all

  # to format user name in dropdown list
  mattr_accessor :name_method
  @@name_method = proc { |e| [e.email, e.id] }

  # after logging in redirect user to path
  mattr_accessor :redirect_path_after_login
  @@redirect_path_after_login = :root_path

  # login on select change event OR click on button, or BOTH
  mattr_accessor :login_on
  @@login_on = :both

  # position of any_login box top_left, top_right, bottom_left, bottom_right
  mattr_accessor :position
  @@position = :bottom_left

  # label on Login button
  mattr_accessor :login_button_label
  @@login_button_label = 'Login'

  # prompt message in select
  mattr_accessor :select_prompt
  @@select_prompt = "Select #{AnyLogin.klass_name}"

  # show any_login box by default
  mattr_accessor :auto_show
  @@auto_show = false

  # limit, integer or :none
  mattr_accessor :limit
  @@limit = 50

  # Previous limit, integer or :none
  mattr_accessor :previous_limit
  @@previous_limit = 6

  # Enable http basic authentication
  mattr_accessor :http_basic_authentication_enabled
  @@http_basic_authentication_enabled = false

  # Enable http basic authentication
  mattr_accessor :http_basic_authentication_user_name
  @@http_basic_authentication_user_name = 'any_login'

  # Enable http basic authentication
  mattr_accessor :http_basic_authentication_password
  @@http_basic_authentication_password = 'password'

  # Use controller proc condition
  mattr_accessor :verify_access_proc
  @@verify_access_proc = proc { |controller| true }

  def self.setup
    yield(self)
  end

  def self.collection
    Collection.new(collection_raw)
  end

  def self.search(query)
    Collection.new(search_users(query))
  end

  def self.search_users(query)
    q = query.to_s.strip
    records = search_source
    result = if q.blank?
               apply_search_limit(records)
             elsif relation?(records)
               apply_search_limit(relation_search(records, q))
             else
               array_search(Array(records), q)
             end
    relation?(result) ? result.to_a : Array(result)
  end

  def self.user_payload(user, group = nil)
    label, = user_label_and_id(user)
    { id: user.id.to_s, label: label.to_s, group: group }
  end



  def self.klass
    @@klass = AnyLogin.klass_name.constantize
  end

  def self.cookie_name
    module_parent_name = if Rails::VERSION::MAJOR >= 6
                           Rails.application.class.module_parent_name
                         else
                           Rails.application.class.parent_name
                         end
    "any_login_previous_#{module_parent_name}".underscore
  end

  private

  def self.format_collection_raw(result)
    if result.is_a?(Hash) || (Object.const_defined?("OrderedHash") && result.is_a?(OrderedHash))
      result.to_a
    else
      result
    end
  end

  def self.search_source
    raw = format_collection_raw(klass.send(collection_method))
    if grouped_collection?(raw)
      raw.flat_map { |(_, users)| users.respond_to?(:to_a) ? users.to_a : Array(users) }
    else
      raw
    end
  end

  def self.grouped_collection?(raw)
    raw.is_a?(Array) && raw.first.is_a?(Array)
  end

  def self.relation?(records)
    defined?(ActiveRecord::Relation) && records.is_a?(ActiveRecord::Relation)
  end

  def self.relation_search(rel, q)
    model = rel.klass
    pattern = "%#{model.sanitize_sql_like(q)}%"
    matched = rel.where(model.primary_key => q)
    searchable_columns(model).each do |col|
      matched = matched.or(rel.where(model.arel_table[col].matches(pattern)))
    end
    matched
  end

  def self.searchable_columns(model)
    return [] unless model.respond_to?(:column_names)

    model.column_names & %w[email name username login]
  rescue StandardError
    []
  end

  def self.array_search(users, q)
    needle = q.downcase
    matched = users.select do |user|
      label, id = user_label_and_id(user)
      label.to_s.downcase.include?(needle) || id.to_s.downcase.include?(needle)
    end
    apply_search_limit(matched)
  end

  def self.user_label_and_id(user)
    value = if name_method.is_a?(Symbol)
              user.send(name_method)
            else
              name_method.call(user)
            end
    value.is_a?(Array) ? value : [value, user.id]
  end

  def self.apply_search_limit(records)
    return records if limit == :none

    if relation?(records)
      records.limit(limit)
    else
      records.take(limit)
    end
  end


  def self.collection_raw
    @@collection_raw = begin
      result = AnyLogin.klass.send(AnyLogin.collection_method)
      if limit == :none
        format_collection_raw(result)
      else
        if result.is_a?(ActiveRecord::Relation)
          format_collection_raw(result.limit(limit))
        else
          format_collection_raw(result.take(limit))
        end
      end
    end
  end

end

require 'any_login/collection'
require 'any_login/engine'
require 'any_login/routes'
require 'any_login/version'
