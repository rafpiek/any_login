require_relative "../test_helper_devise"

class SearchTest < ActiveSupport::TestCase
  setup do
    @prev_limit = AnyLogin.limit
    @prev_method = AnyLogin.collection_method
    @prev_name = AnyLogin.name_method
    AnyLogin.name_method = proc { |e| [e.email, e.id] }
  end

  teardown do
    AnyLogin.limit = @prev_limit
    AnyLogin.collection_method = @prev_method
    AnyLogin.name_method = @prev_name
  end

  test "search finds a user outside the display limit" do
    AnyLogin.limit = 1
    hidden = User.create!(name: "Hidden Needle", email: "hidden-needle@example.com", password: "password123", role: "user")

    ids = AnyLogin.search_users("hidden-needle@example.com").map { |user| user.id.to_s }

    assert_includes ids, hidden.id.to_s
  end

  test "search filters an array collection in ruby" do
    visible = User.create!(name: "Visible", email: "array-visible@example.com", password: "password123", role: "user")
    hidden = User.create!(name: "Hidden", email: "array-hidden-needle@example.com", password: "password123", role: "user")
    User.define_singleton_method(:array_for_any_login) { [visible, hidden] }
    AnyLogin.collection_method = :array_for_any_login
    AnyLogin.limit = 10

    ids = AnyLogin.search_users("array-hidden-needle").map { |user| user.id.to_s }

    assert_includes ids, hidden.id.to_s
    refute_includes ids, visible.id.to_s
  end
end
