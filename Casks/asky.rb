cask "asky" do
  version "0.2.8"
  sha256 "e596d461929dc937b672f1191402115c4fa09e774d727e0f2b387d9d6fc1af16"

  url "https://github.com/Niall-Young/Asky/releases/download/v#{version}/Asky-#{version}-macos-arm64.dmg"
  name "Asky"
  desc "Native launcher with local search, clipboard history, and an AI assistant"
  homepage "https://github.com/Niall-Young/Asky"

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Asky.app"
end
