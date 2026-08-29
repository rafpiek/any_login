require_relative "../test_helper_devise"

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
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until { @user.reload.sign_in_count.positive? }
    visit "/about"

    assert_text("This is secret page available only for logged in users")
  end

  test "search can find and log in a user outside the display limit" do
    prev_limit = AnyLogin.limit
    AnyLogin.limit = 1
    needle = User.create!(name: "needle", email: "needle-search@example.com", password: "password123", role: "user")

    visit "/"
    find("#any_login_form_toggle_label").click
    find("[data-any-login-tab='users']").click
    find("#any_login_user_search").set("")
    find("#any_login_user_search").send_keys("needle-search@example.com")
    assert_selector ".any_login_list_option[data-user-id='#{needle.id}']", wait: 5
    find(".any_login_list_option[data-user-id='#{needle.id}']").click
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until { needle.reload.sign_in_count.positive? }
    visit "/about"

    assert_text("This is secret page available only for logged in users")
  ensure
    AnyLogin.limit = prev_limit
  end

  test "pins the current user and keeps them in the Pinned tab" do
    visit "/"
    page.execute_script("window.localStorage.clear()")
    find("#any_login_form_toggle_label").click
    find("[data-any-login-tab='id']").click
    fill_in "any_login_id_input", with: @user.id
    find("#any_login_form input[type='submit']").click
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until { @user.reload.sign_in_count.positive? }

    visit "/about"
    assert_text("This is secret page available only for logged in users")
    page.execute_script("window.localStorage.clear()")
    find("#any_login_form_toggle_label").click
    find("[data-any-login-pin]").click
    find("[data-any-login-tab='pinned']").click
    assert_selector "[data-any-login-pinned-id='#{@user.id}']"

    visit "/about"
    find("#any_login_form_toggle_label").click
    find("[data-any-login-tab='pinned']").click
    assert_selector "[data-any-login-pinned-id='#{@user.id}']"

    find("[data-any-login-unpin]").click
    assert_text("No pinned users.")
  end

end
