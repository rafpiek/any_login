require_relative "../test_helper_devise"

class UsersSearchTest < ActionDispatch::IntegrationTest
  setup do
    @prev_limit = AnyLogin.limit
    @prev_access = AnyLogin.verify_access_proc
    @prev_name = AnyLogin.name_method
    AnyLogin.name_method = proc { |e| [e.email, e.id] }
  end

  teardown do
    AnyLogin.limit = @prev_limit
    AnyLogin.verify_access_proc = @prev_access
    AnyLogin.name_method = @prev_name
  end

  test "users search returns a user outside the display limit" do
    AnyLogin.limit = 1
    hidden = User.create!(
      name: "Hidden Needle",
      email: "hidden-needle-json@example.com",
      password: "password123",
      role: "user"
    )

    get any_login.users_path, params: { q: "hidden-needle-json@example.com" }, as: :json

    assert_response :success
    ids = JSON.parse(response.body).fetch("users").map { |user| user["id"] }
    assert_includes ids, hidden.id.to_s
  end

  test "users search is forbidden when access is denied" do
    AnyLogin.verify_access_proc = proc { false }

    get any_login.users_path, params: { q: "anyone" }, as: :json

    assert_response :forbidden
  end
end
