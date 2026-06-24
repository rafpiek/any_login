module AnyLogin
  module Helpers
    extend ActiveSupport::Concern

    def any_login_here
      render 'any_login/any_login' if AnyLogin.enabled && AnyLogin.verify_access_proc.call(self.controller)
    end

    if AnyLogin.enabled

      def any_login_id_input
        text_field_tag :id, "", placeholder: "Paste user ID…", id: "any_login_id_input", autocomplete: "off"
      end

      def any_login_submit
        submit_tag AnyLogin.login_button_label
      end

      def any_login_tab_config
        users = AnyLogin.login_on != :id
        id_tab = AnyLogin.login_on != :select
        recent = any_login_recent_users_payload.any?
        tabs = []
        tabs << { key: "users", label: "Users" } if users
        tabs << { key: "id", label: "ID" } if id_tab
        tabs << { key: "recent", label: "Recent" } if recent
        default = tabs.first&.dig(:key) || "users"
        { tabs: tabs, default: default, multi: tabs.size > 1 }
      end

      def any_login_users_payload_json
        any_login_users_payload.to_json
      end

      def any_login_recent_users_payload_json
        any_login_recent_users_payload.to_json
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
        ids = any_login_previous_ids
        return [] if ids.blank?

        ids.filter_map do |id|
          user = AnyLogin.klass.where(AnyLogin.klass.primary_key => id).first
          next unless user

          label, _pk = if AnyLogin.name_method.is_a?(Symbol)
            user.send(AnyLogin.name_method)
          else
            AnyLogin.name_method.call(user)
          end
          { id: user.id.to_s, label: label.to_s, group: nil }
        end
      end

      def any_login_select
        collection = AnyLogin.collection
        select_options =
                        if collection.grouped?
                          grouped_options_for_select(collection.to_a)
                        else
                          options_for_select(collection.to_a)
                        end
        select_tag :selected_id, select_options, select_html_options
      end

      def any_login_previous_select
        ids = any_login_previous_ids
        return if ids.blank?

        users = ids.collect do |id|
          AnyLogin.klass.where(AnyLogin.klass.primary_key => id).first
        end.compact
        collection = AnyLogin::Collection.new(users).to_a
        if collection.any?
          select_options = options_for_select(collection)
          content_tag(:div, class: "any_login_history_field") do
            safe_join([
              content_tag(:span, "Recent", class: "any_login_history_label"),
              select_tag(:back_to_previous_id, select_options, select_html_options("Switch back to…"))
            ])
          end
        end
      end

      def any_login_previous_ids
        (cookies[AnyLogin.cookie_name].presence || '').split(',').take(AnyLogin.previous_limit)
      end

      def select_html_options(prompt = AnyLogin.select_prompt)
        options = {}
        options[:prompt] = prompt
        options
      end

      def any_login_klasses
        klasses = []
        klasses << "any_login_#{AnyLogin.position || 'bottom_left'}"
        klasses.join(' ')
      end

      def current_user_information
        if respond_to?(AnyLogin.provider.constantize::Controller.any_login_current_user_method) &&
           user = send(AnyLogin.provider.constantize::Controller.any_login_current_user_method)
          label, _id = if AnyLogin.name_method.is_a?(Symbol)
            user.send(AnyLogin.name_method)
          else
            AnyLogin.name_method.call(user)
          end
          content_tag :span, class: "any_login_user_information" do
            raw("<span class=\"any_login_session_label\">#{h(label)}</span><span class=\"any_login_session_id\">#{h(user.id)}</span>")
          end
        end
      end
    end
  end
end
