-- Coordinates match background.tiff (660 × 440 points).
-- Accept a path rather than a volume name, so versions and spaces are safe.
on run argv
    set installFolder to POSIX file (item 1 of argv) as alias
    tell application "Finder"
        set installFolder to folder installFolder
        open installFolder
        tell container window of installFolder
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set pathbar visible to false
            set bounds to {160, 120, 820, 628}
        end tell
        tell icon view options of container window of installFolder
            set arrangement to not arranged
            set icon size to 88
            set text size to 13
            set background picture to file ".background:background.tiff" of installFolder
        end tell
        set position of item "Asky.app" of installFolder to {180, 252}
        set position of item "Applications" of installFolder to {480, 252}
        update installFolder without registering applications
        delay 2
        close container window of installFolder
        -- Finder persists the folder's view settings asynchronously.
        delay 2
    end tell
end run
