require "rails_helper"

RSpec.describe Manuscript, type: :model do
  it "returns Japanese validation messages for required fields" do
    manuscript = Manuscript.new

    expect(manuscript).not_to be_valid
    expect(manuscript.errors.full_messages).to include("原稿タイトルを入力してください")
    expect(manuscript.errors.full_messages).to include("サービス名を入力してください")
    expect(manuscript.errors.full_messages).to include("サービス概要を入力してください")
    expect(manuscript.errors.full_messages).to include("ターゲットを入力してください")
    expect(manuscript.errors.full_messages).to include("FAXDMの目的を入力してください")
    expect(manuscript.errors.full_messages).to include("問い合わせ導線を入力してください")
  end
end
