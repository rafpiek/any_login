require_relative '../test_helper_clearance'

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create(name: "test", email: "test@test.com", password: "password123", role: "user")
  end

  test "user cannot navigate to about page without login" do
    visit "/about"

    assert_no_text("This is secret page available only for logged in users")
  end

  test "it properly logs users in and allows access to the secret page" do
    visit "/"

    find("#any_login_form_toggle_label").click
    find("[data-any-login-tab='id']").click
    assert_selector "#any_login_id_input", visible: true
    fill_in "any_login_id_input", with: @user.id
    find("#any_login_form input[type='submit']").click
    assert_text("Hello, #{@user.name}")

    visit "/about"

    assert_text("This is secret page available only for logged in users")
  end
end
