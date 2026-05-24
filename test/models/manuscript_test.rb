require "test_helper"

class ManuscriptTest < ActiveSupport::TestCase
  test "required fields produce Japanese validation messages" do
    manuscript = Manuscript.new

    assert_not manuscript.valid?
    messages = manuscript.errors.full_messages

    assert_includes messages, "原稿タイトルを入力してください"
    assert_includes messages, "サービス名を入力してください"
    assert_includes messages, "サービス概要を入力してください"
    assert_includes messages, "ターゲットを入力してください"
    assert_includes messages, "FAXDMの目的を入力してください"
    assert_includes messages, "問い合わせ導線を入力してください"
  end
end
