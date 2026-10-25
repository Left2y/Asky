cask "asky" do
  version "0.2.9"
  sha256 "f37104f7eb55a5b165b182651007d20129a79cd3ce17d1aa6946a5e7d3d91233"

  url "https://github.com/Niall-Young/Asky/releases/download/v#{version}/Asky-#{version}-macos-arm64.dmg"
  name "Asky"
  desc "Native launcher with local search, clipboard history, and an AI assistant"
  homepage "https://github.com/Niall-Young/Asky"

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Asky.app"
end
