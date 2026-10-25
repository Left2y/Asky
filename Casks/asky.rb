cask "asky" do
  version "0.2.10"
  sha256 "63997f7798a4dacd6ce90eb7beff8efe852aa35a03c56c400334160982e1f4ad"

  url "https://github.com/Niall-Young/Asky/releases/download/v#{version}/Asky-#{version}-macos-arm64.dmg"
  name "Asky"
  desc "Native launcher with local search, clipboard history, and an AI assistant"
  homepage "https://github.com/Niall-Young/Asky"

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Asky.app"
end
