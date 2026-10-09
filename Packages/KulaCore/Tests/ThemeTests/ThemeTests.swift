import Testing
@testable import Theme

@Suite struct ThemeTests {
    @Test func everySemanticColorResolvesInBothModes() {
        for name in SemanticColors.sourceTable.keys {
            for mode in Appearance.allCases {
                #expect(SemanticColors.resolve(name, mode) != nil, "\(name) \(mode)")
            }
        }
    }

    @Test func everyNativeNameMapsToASource() {
        for native in SemanticColors.nativeToSource.keys {
            #expect(SemanticColors.color(native: native, .light) != nil, "\(native)")
        }
    }

    @Test func paletteAlphaFollowsStep() {
        #expect(Palette.values["black90"]?.alpha == 0.9)
        #expect(Palette.values["white0"]?.alpha == 0)
    }

    @Test func capsuleRadius() {
        #expect(Radius.isCapsule("radius99999"))
        #expect(!Radius.isCapsule("radius8"))
    }
}
