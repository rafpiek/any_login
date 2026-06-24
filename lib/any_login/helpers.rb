module AnyLogin
  module Helpers
    extend ActiveSupport::Concern

    def any_login_here
      render "any_login/any_login" if AnyLogin.enabled && AnyLogin.verify_access_proc.call(self.controller)
    end

    if AnyLogin.enabled

      def any_login_submit
        submit_tag AnyLogin.login_button_label
      end

      def any_login_id_input
        text_field_tag :id, "", placeholder: "Paste user ID…", id: "any_login_id_input", autocomplete: "off"
      end

      def any_login_tab_config
        users_tab = AnyLogin.login_on != :id
        id_tab = AnyLogin.login_on != :select
        recent_tab = any_login_recent_users_payload.any?
        tabs = []
        tabs << { key: "users", label: "Users" } if users_tab
        tabs << { key: "id", label: "ID" } if id_tab
        tabs << { key: "recent", label: "Recent" } if recent_tab
        default = tabs.first&.dig(:key) || "users"
        { tabs: tabs, default: default, multi: tabs.size > 1 }
      end

      def any_login_users_payload
        collection = AnyLogin.collection
        if collection.grouped?
          collection.to_a.flat_map do |group_name, pairs|
            pairs.map { |label, id| { id: id.to_s, label: label.to_s, group: group_name.to_s } }
          end
        else
          collection.to_a.map { |label, id| { id: id.to_s, label: label.to_s, group: nil } }
        end
      end

      def any_login_recent_users_payload
        any_login_previous_ids.filter_map do |id|
          user = AnyLogin.klass.where(AnyLogin.klass.primary_key => id).first
          next unless user

          label, = any_login_user_label_and_id(user)
          { id: user.id.to_s, label: label.to_s, group: nil }
        end
      end

      def any_login_previous_ids
        (cookies[AnyLogin.cookie_name].presence || "").split(",").take(AnyLogin.previous_limit)
      end

      def any_login_klasses
        "any_login_#{AnyLogin.position || 'bottom_left'}"
      end

      def current_user_information
        method_name = AnyLogin.provider.constantize::Controller.any_login_current_user_method
        return unless respond_to?(method_name)

        user = send(method_name)
        return unless user

        label, = any_login_user_label_and_id(user)
        content_tag :span, class: "any_login_user_information" do
          raw(
            "<span class=\"any_login_session_label\">#{h(label)}</span>" \
            "<span class=\"any_login_session_id\">#{h(user.id)}</span>"
          )
        end
      end

      private

      def any_login_user_label_and_id(user)
        if AnyLogin.name_method.is_a?(Symbol)
          user.send(AnyLogin.name_method)
        else
          AnyLogin.name_method.call(user)
        end
      end
    end
  end
end