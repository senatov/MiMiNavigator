--  OpenTerminal.applescript
--  MiMiNavigator
--
--  Created by Iakov Senatov on 08.09.2025.
--  Copyright © 2025 Senatov. All rights reserved.


on run argv
    if (count of argv) = 0 then return
    set theDir to item 1 of argv
    tell application "Terminal"
        do script "cd " & quoted form of POSIX path of theDir
        activate
    end tell
end run
