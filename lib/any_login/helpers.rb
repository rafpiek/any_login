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
        @any_login_tab_config ||= begin
          tabs = []
          tabs << { key: "pinned", label: "Pinned" }
          tabs << { key: "recent", label: "Recent" } if any_login_recent_users_payload.any?
          tabs << { key: "users", label: "Users" } if AnyLogin.login_on != :id
          tabs << { key: "id", label: "ID" } if AnyLogin.login_on != :select

          default = tabs.find { |tab| tab[:key] == "recent" }&.dig(:key) ||
                    tabs.find { |tab| tab[:key] == "users" }&.dig(:key) ||
                    tabs.find { |tab| tab[:key] == "id" }&.dig(:key) ||
                    "pinned"

          { tabs: tabs, default: default, multi: tabs.size > 1 }
        end
      end

      def any_login_users_payload
        @any_login_users_payload ||= begin
          collection = AnyLogin.collection
          if collection.grouped?
            collection.to_a.flat_map do |group_name, pairs|
              pairs.map { |label, id| { id: id.to_s, label: label.to_s, group: group_name.to_s } }
            end
          else
            collection.to_a.map { |label, id| { id: id.to_s, label: label.to_s, group: nil } }
          end
        end
      end

      def any_login_recent_users_payload
        @any_login_recent_users_payload ||= any_login_previous_ids.filter_map do |id|
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
        user = any_login_detect_current_user(method_name)
        return unless user


        label, = any_login_user_label_and_id(user)
        content_tag :span, class: "any_login_user_information", data: {
          any_login_current_id: user.id,
          any_login_current_label: label
        } do
          safe_join(
            [
              content_tag(:span, class: "any_login_session_meta") do
                safe_join(
                  [
                    content_tag(:span, label, class: "any_login_session_label"),
                    content_tag(:span, user.id, class: "any_login_session_id")
                  ]
                )
              end,
              content_tag(
                :button,
                "Pin",
                type: "button",
                class: "any_login_pin_button",
                data: { any_login_pin: true },
                aria: { pressed: "false", label: "Pin current user" }
              )
            ]
          )
        end
      end

      private
      def any_login_detect_current_user(method_name)
        names = [method_name, :current_user].compact.uniq
        [self, (controller if defined?(controller))].compact.each do |source|
          names.each do |name|
            next unless source.respond_to?(name, true)

            user = source.send(name)
            return user if user
          end
        end

        request.env["warden"].user if defined?(request) && request && request.env["warden"]
      end

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