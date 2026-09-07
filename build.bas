$RESIZE:SMOOTH
$VERSIONINFO:CompanyName=Nebula Device 4
$VERSIONINFO:FileDescription=Nebula Device 4 build launcher
$VERSIONINFO:ProductName=Nebula Device 4 Build System
$VERSIONINFO:OriginalFilename=N4Build.exe
OPTION _EXPLICIT

CONST N4BuildOk = 0
CONST N4BuildUsageError = 2
CONST N4BuildDiscoveryError = 3
CONST N4BuildConfigurationError = 4
CONST N4BuildLogMaxChars = 12000
CONST N4BuildLogVisibleLines = 5
CONST N4BuildLogLineHeight = 18
CONST N4BuildStartTimeoutSeconds = 15
CONST N4BuildLogLeft = 88
CONST N4BuildLogTop = 550
CONST N4BuildLogWidth = 910
CONST N4BuildContextMenuWidth = 150
CONST N4BuildContextMenuHeight = 34

DIM SHARED gBuildSystemRoot AS STRING
DIM SHARED gConfigPath AS STRING
DIM SHARED gEngineRoot AS STRING
DIM SHARED gFBuildPath AS STRING
DIM SHARED gBffPath AS STRING
DIM SHARED gClangBin AS STRING
DIM SHARED gClangCompiler AS STRING
DIM SHARED gClangLinker AS STRING
DIM SHARED gClangLibrarian AS STRING
DIM SHARED gPythonExecutable AS STRING
DIM SHARED gQtAsanRoot AS STRING
DIM SHARED gQtStandardRoot AS STRING
DIM SHARED gQtHostBin AS STRING
DIM SHARED gVulkanSdkRoot AS STRING
DIM SHARED gVulkanInclude AS STRING
DIM SHARED gVulkanLib AS STRING
DIM SHARED gGlslangExecutable AS STRING
DIM SHARED gMsvcInclude AS STRING
DIM SHARED gMsvcLib AS STRING
DIM SHARED gWindowsSdkInclude AS STRING
DIM SHARED gWindowsSdkLib AS STRING
DIM SHARED gWindowsSdkUcrtLib AS STRING
DIM SHARED gAsanResource AS STRING
DIM SHARED gAsanRuntime AS STRING
DIM SHARED gAsanThunk AS STRING
DIM SHARED gAsanDll AS STRING
DIM SHARED gLastError AS STRING
DIM SHARED gLastErrorCode AS LONG
DIM SHARED gUiScreen AS LONG
DIM SHARED gUiTarget AS STRING
DIM SHARED gUiStatus AS STRING
DIM SHARED gUiDetail AS STRING
DIM SHARED gUiStatusKind AS LONG
DIM SHARED gUiFieldActive AS LONG
DIM SHARED gUiFieldCaret AS LONG
DIM SHARED gUiFieldViewStart AS LONG
DIM SHARED gUiFieldSelectionAnchor AS LONG
DIM SHARED gUiFieldSelectionEnd AS LONG
DIM SHARED gUiFieldSelectionDragging AS LONG
DIM SHARED gUiMouseWasDown AS LONG
DIM SHARED gUiRightMouseWasDown AS LONG
DIM SHARED gUiBusy AS LONG
DIM SHARED gUiShouldClose AS LONG
DIM SHARED gUiExitCode AS LONG
DIM SHARED gBuildCommandPath AS STRING
DIM SHARED gBuildLogPath AS STRING
DIM SHARED gBuildStatusPath AS STRING
DIM SHARED gBuildLogText AS STRING
DIM SHARED gBuildLogOffset AS LONG
DIM SHARED gBuildProcessActive AS LONG
DIM SHARED gBuildStartTime AS DOUBLE
DIM SHARED gBuildLogSelectionAnchor AS LONG
DIM SHARED gBuildLogSelectionStart AS LONG
DIM SHARED gBuildLogSelectionEnd AS LONG
DIM SHARED gBuildLogSelectionActive AS LONG
DIM SHARED gBuildLogSelectionDragging AS LONG
DIM SHARED gBuildLogFirstVisibleLine AS LONG
DIM SHARED gBuildLogFollowTail AS LONG
DIM SHARED gBuildLogFocused AS LONG
DIM SHARED gBuildContextMenuOpen AS LONG
DIM SHARED gBuildContextMenuX AS LONG
DIM SHARED gBuildContextMenuY AS LONG

DIM mode AS STRING
DIM target AS STRING
DIM engineRoot AS STRING

mode = "build"
target = "N4Editor_Debug"
engineRoot = ""
gUiExitCode = N4BuildOk

gBuildSystemRoot = NormalizePath$(Environ$("N4DC_BUILD_SYSTEM_ROOT"))
IF LEN(gBuildSystemRoot) > 0 THEN
    IF _FILEEXISTS(JoinPath$(gBuildSystemRoot, "fbuild.bff")) = 0 THEN gBuildSystemRoot = ""
END IF
IF LEN(gBuildSystemRoot) = 0 THEN gBuildSystemRoot = NormalizePath$(_CWD$)
IF _FILEEXISTS(JoinPath$(gBuildSystemRoot, "fbuild.bff")) = 0 THEN
    IF _FILEEXISTS(JoinPath$(NormalizePath$(_STARTDIR$), "fbuild.bff")) <> 0 THEN gBuildSystemRoot = NormalizePath$(_STARTDIR$)
END IF

gConfigPath = JoinPath$(gBuildSystemRoot, "N4Build.ini")
engineRoot = ReadConfigValue$(gConfigPath, "EngineRoot")
IF LEN(engineRoot) = 0 THEN engineRoot = Environ$("N4DC_ENGINE_ROOT")

ParseArguments mode, target, engineRoot

gEngineRoot = NormalizePath$(engineRoot)

target = NormalizeTarget$(target)
IF LEN(target) = 0 THEN target = "N4Editor_Debug"

gUiTarget = target
gUiStatus = "Ready. Select a target and press Build."
gUiStatusKind = 0
IF LEN(gLastError) > 0 THEN
    gUiStatus = gLastError
    gUiStatusKind = 2
END IF
IF mode = "help" THEN
    gUiStatus = "Command-line options"
    gUiDetail = "N4Build.exe [target] [engine-root]" + CHR$(10) + "Build features and paths are configured at the top of fbuild.bff."
END IF

RunLauncherUi mode
SYSTEM gUiExitCode

SUB ParseArguments (mode AS STRING, target AS STRING, engineRoot AS STRING)
    DIM index AS LONG
    DIM targetSpecified AS LONG
    DIM engineRootSpecified AS LONG
    DIM argument AS STRING
    DIM lowerArgument AS STRING

    index = 1
    DO WHILE index <= _COMMANDCOUNT
        argument = COMMAND$(index)
        lowerArgument = LCASE$(argument)

        IF lowerArgument = "--help" OR lowerArgument = "-h" OR lowerArgument = "help" THEN
            mode = "help"
            EXIT SUB
        ELSEIF lowerArgument = "doctor" OR lowerArgument = "--doctor" THEN
            mode = "doctor"
        ELSEIF lowerArgument = "--engine-root" OR lowerArgument = "-engineroot" THEN
            IF index >= _COMMANDCOUNT THEN
                Abort "Missing value for --engine-root.", N4BuildUsageError
                EXIT SUB
            END IF
            index = index + 1
            engineRoot = COMMAND$(index)
            engineRootSpecified = -1
        ELSEIF LEFT$(lowerArgument, 14) = "--engine-root=" THEN
            engineRoot = MID$(argument, 15)
            engineRootSpecified = -1
        ELSEIF lowerArgument = "--target" OR lowerArgument = "-target" THEN
            IF index >= _COMMANDCOUNT THEN
                Abort "Missing value for --target.", N4BuildUsageError
                EXIT SUB
            END IF
            index = index + 1
            target = COMMAND$(index)
            targetSpecified = -1
        ELSEIF LEFT$(lowerArgument, 9) = "--target=" THEN
            target = MID$(argument, 10)
            targetSpecified = -1
        ELSEIF LEFT$(argument, 1) = "-" THEN
            Abort "Unknown option: " + argument, N4BuildUsageError
            EXIT SUB
        ELSEIF lowerArgument = "debug" OR lowerArgument = "release" OR lowerArgument = "relwithdebinfo" OR lowerArgument = "all" OR LEFT$(UCASE$(argument), 9) = "N4EDITOR_" THEN
            IF targetSpecified = 0 AND target = "N4Editor_Debug" THEN
                target = argument
                targetSpecified = -1
            ELSEIF engineRootSpecified = 0 THEN
                engineRoot = argument
                engineRootSpecified = -1
            ELSE
                Abort "Unexpected positional argument: " + argument, N4BuildUsageError
                EXIT SUB
            END IF
        ELSE
            IF engineRootSpecified = 0 THEN
                engineRoot = argument
                engineRootSpecified = -1
            ELSE
                Abort "Unexpected positional argument: " + argument, N4BuildUsageError
                EXIT SUB
            END IF
        END IF

        index = index + 1
    LOOP
END SUB

SUB RunLauncherUi (requestedMode AS STRING)
    DIM exitSignal AS LONG

    gUiScreen = _NEWIMAGE(1100, 760, 32)
    IF gUiScreen = -1 THEN
        gUiExitCode = N4BuildConfigurationError
        EXIT SUB
    END IF

    SCREEN gUiScreen
    _TITLE "Nebula Device 4 Build"
    gUiFieldActive = -1
    gUiFieldCaret = LEN(gEngineRoot)
    gUiFieldViewStart = 0
    gUiFieldSelectionAnchor = gUiFieldCaret
    gUiFieldSelectionEnd = gUiFieldCaret
    gUiFieldSelectionDragging = 0
    gBuildLogFocused = 0
    gUiMouseWasDown = 0
    gUiRightMouseWasDown = 0
    gUiBusy = 0
    gUiShouldClose = 0
    ResetBuildLogSelection

    IF requestedMode = "doctor" AND LEN(gLastError) = 0 THEN StartUiAction "doctor"

    DO WHILE gUiShouldClose = 0
        UpdateBuildState
        DrawLauncher
        _DISPLAY
        HandleLauncherInput
        exitSignal = _EXIT
        IF exitSignal <> 0 AND gBuildProcessActive = 0 THEN gUiShouldClose = -1
        _LIMIT 60
    LOOP

    SCREEN 0
    _FREEIMAGE gUiScreen
END SUB

SUB StartUiAction (actionName AS STRING)
    IF gUiBusy <> 0 THEN EXIT SUB

    gLastError = ""
    gLastErrorCode = N4BuildOk
    gUiDetail = ""
    gUiBusy = -1
    gUiFieldActive = 0
    gUiFieldSelectionDragging = 0
    gBuildLogFocused = -1

    IF actionName = "doctor" THEN
        gUiStatus = "Checking the selected engine and toolchain..."
    ELSE
        gUiStatus = "Preparing the selected build..."
    END IF
    gUiStatusKind = 0
    DrawLauncher
    _DISPLAY

    RunBuild actionName
    IF gBuildProcessActive <> 0 THEN EXIT SUB

    gUiBusy = 0
    IF LEN(gLastError) > 0 THEN
        gUiStatus = gLastError
        gUiStatusKind = 2
    ELSEIF actionName = "doctor" THEN
        gUiStatus = "Toolchain check completed successfully."
        gUiStatusKind = 1
    ELSEIF gUiExitCode = N4BuildOk THEN
        gUiStatus = "Build completed successfully."
        gUiStatusKind = 1
    END IF
END SUB

SUB HandleLauncherInput
    DIM mouseX AS LONG
    DIM mouseY AS LONG
    DIM mousePressed AS LONG
    DIM mouseRightPressed AS LONG
    DIM mouseWheel AS LONG
    DIM keyPress AS STRING

    mouseX = _MOUSEX
    mouseY = _MOUSEY
    mouseWheel = 0

    DO WHILE _MOUSEINPUT
        mouseX = _MOUSEX
        mouseY = _MOUSEY
        mouseWheel = mouseWheel + _MOUSEWHEEL
    LOOP

    IF mouseWheel <> 0 AND PointInRect(mouseX, mouseY, 70, 540, 1030, 650) THEN
        gUiFieldActive = 0
        gUiFieldSelectionDragging = 0
        gBuildLogFocused = -1
        gBuildContextMenuOpen = 0
        ScrollBuildLog -mouseWheel
    END IF

    mousePressed = _MOUSEBUTTON(1)
    mouseRightPressed = _MOUSEBUTTON(2)

    IF mousePressed <> 0 AND gUiMouseWasDown = 0 THEN
        IF gBuildContextMenuOpen <> 0 THEN
            HandleBuildContextMenuClick mouseX, mouseY
        ELSEIF PointInRect(mouseX, mouseY, 70, 540, 1030, 650) THEN
            BeginBuildLogSelection mouseX, mouseY
        ELSEIF gUiBusy = 0 AND PointInRect(mouseX, mouseY, 70, 150, 1030, 202) THEN
            BeginEngineRootSelection mouseX
        ELSEIF gUiBusy = 0 THEN
            HandleLauncherClick mouseX, mouseY
        END IF
    ELSEIF mousePressed <> 0 AND gUiMouseWasDown <> 0 THEN
        IF gUiFieldSelectionDragging <> 0 THEN
            UpdateEngineRootSelection mouseX
        ELSEIF gBuildLogSelectionDragging <> 0 THEN
            UpdateBuildLogSelection mouseX, mouseY
        END IF
    ELSEIF mousePressed = 0 AND gUiMouseWasDown <> 0 THEN
        EndEngineRootSelection
        EndBuildLogSelection
    END IF

    IF mouseRightPressed <> 0 AND gUiRightMouseWasDown = 0 THEN OpenBuildContextMenu mouseX, mouseY

    gUiMouseWasDown = mousePressed
    gUiRightMouseWasDown = mouseRightPressed

    keyPress = INKEY$
    DO WHILE LEN(keyPress) > 0
        HandleLauncherKey keyPress
        keyPress = INKEY$
    LOOP
END SUB

SUB HandleLauncherClick (mouseX AS LONG, mouseY AS LONG)
    gBuildLogFocused = 0
    gUiFieldActive = 0
    gUiFieldSelectionDragging = 0

    IF PointInRect(mouseX, mouseY, 70, 262, 300, 312) THEN
        gUiTarget = "N4Editor_Debug"
        gUiStatus = "Debug target selected."
        gUiStatusKind = 0
    ELSEIF PointInRect(mouseX, mouseY, 325, 262, 555, 312) THEN
        gUiTarget = "N4Editor_Release"
        gUiStatus = "Release target selected."
        gUiStatusKind = 0
    ELSEIF PointInRect(mouseX, mouseY, 580, 262, 850, 312) THEN
        gUiTarget = "N4Editor_RelWithDebInfo"
        gUiStatus = "RelWithDebInfo target selected."
        gUiStatusKind = 0
    ELSEIF PointInRect(mouseX, mouseY, 550, 355, 700, 415) THEN
        StartUiAction "build"
    ELSEIF PointInRect(mouseX, mouseY, 720, 355, 870, 415) THEN
        StartUiAction "doctor"
    ELSEIF PointInRect(mouseX, mouseY, 890, 355, 1030, 415) THEN
        gUiShouldClose = -1
    END IF
END SUB

SUB HandleLauncherKey (keyPress AS STRING)
    DIM keyCode AS LONG
    DIM handled AS LONG

    IF gBuildContextMenuOpen <> 0 THEN
        IF keyPress = "c" OR keyPress = "C" OR keyPress = CHR$(3) OR keyPress = CHR$(13) THEN
            CopyBuildOutput
            gBuildContextMenuOpen = 0
        ELSEIF keyPress = CHR$(27) THEN
            gBuildContextMenuOpen = 0
        END IF
        EXIT SUB
    END IF

    IF keyPress = CHR$(3) THEN
        IF gUiFieldActive <> 0 THEN
            CopyEngineRootSelection
        ELSE
            CopyBuildOutput
        END IF
        EXIT SUB
    END IF

    handled = 0
    IF gBuildLogFocused <> 0 THEN HandleBuildLogNavigation keyPress, handled
    IF handled <> 0 THEN EXIT SUB

    IF gUiBusy <> 0 THEN EXIT SUB

    IF keyPress = CHR$(27) THEN
        gUiShouldClose = -1
        EXIT SUB
    END IF

    IF gUiFieldActive = 0 THEN
        IF keyPress = CHR$(13) THEN StartUiAction "build"
        EXIT SUB
    END IF

    IF keyPress = CHR$(1) THEN
        SelectAllEngineRoot
    ELSEIF keyPress = CHR$(24) THEN
        CutEngineRootSelection
    ELSEIF keyPress = CHR$(22) THEN
        InsertEngineRootText FirstLine$(_CLIPBOARD$)
    ELSEIF keyPress = CHR$(13) THEN
        gUiFieldActive = 0
        gUiFieldSelectionDragging = 0
    ELSEIF keyPress = CHR$(8) THEN
        BackspaceEngineRoot
    ELSEIF LEN(keyPress) = 2 AND (ASC(keyPress) = 0 OR ASC(keyPress) = 224) THEN
        keyCode = ASC(RIGHT$(keyPress, 1))
        HandleEngineRootNavigation keyCode
    ELSEIF LEN(keyPress) = 1 THEN
        keyCode = ASC(keyPress)
        IF keyCode >= 32 AND keyCode <= 126 THEN InsertEngineRootText keyPress
    END IF
END SUB

SUB BeginEngineRootSelection (mouseX AS LONG)
    DIM caretPosition AS LONG

    EngineRootPointToCaret mouseX, caretPosition
    gUiFieldActive = -1
    gBuildLogFocused = 0
    gBuildContextMenuOpen = 0
    gUiFieldCaret = caretPosition
    gUiFieldSelectionAnchor = caretPosition
    gUiFieldSelectionEnd = caretPosition
    gUiFieldSelectionDragging = -1
    gUiStatus = "Engine root field active."
    gUiStatusKind = 0
END SUB

SUB UpdateEngineRootSelection (mouseX AS LONG)
    DIM caretPosition AS LONG

    IF gUiFieldSelectionDragging = 0 THEN EXIT SUB
    EngineRootPointToCaret mouseX, caretPosition
    gUiFieldCaret = caretPosition
    gUiFieldSelectionEnd = caretPosition
END SUB

SUB EndEngineRootSelection
    gUiFieldSelectionDragging = 0
END SUB

SUB EngineRootPointToCaret (mouseX AS LONG, caretPosition AS LONG)
    DIM visibleText AS STRING
    DIM characterIndex AS LONG

    UpdateEngineRootViewport
    visibleText = EngineRootVisibleText$
    caretPosition = gUiFieldViewStart + LEN(visibleText)

    IF mouseX <= 84 THEN
        caretPosition = gUiFieldViewStart
        EXIT SUB
    END IF

    FOR characterIndex = 1 TO LEN(visibleText)
        IF mouseX < 84 + _PRINTWIDTH(LEFT$(visibleText, characterIndex)) THEN
            caretPosition = gUiFieldViewStart + characterIndex - 1
            EXIT FOR
        END IF
    NEXT characterIndex

    IF caretPosition < 0 THEN caretPosition = 0
    IF caretPosition > LEN(gEngineRoot) THEN caretPosition = LEN(gEngineRoot)
END SUB

SUB HandleEngineRootNavigation (keyCode AS LONG)
    DIM selectionStart AS LONG
    DIM selectionEnd AS LONG

    selectionStart = gUiFieldSelectionAnchor
    selectionEnd = gUiFieldSelectionEnd
    IF selectionStart > selectionEnd THEN SWAP selectionStart, selectionEnd

    IF keyCode = 75 THEN
        IF selectionStart <> selectionEnd THEN
            gUiFieldCaret = selectionStart
        ELSEIF gUiFieldCaret > 0 THEN
            gUiFieldCaret = gUiFieldCaret - 1
        END IF
    ELSEIF keyCode = 77 THEN
        IF selectionStart <> selectionEnd THEN
            gUiFieldCaret = selectionEnd
        ELSEIF gUiFieldCaret < LEN(gEngineRoot) THEN
            gUiFieldCaret = gUiFieldCaret + 1
        END IF
    ELSEIF keyCode = 71 THEN
        gUiFieldCaret = 0
    ELSEIF keyCode = 79 THEN
        gUiFieldCaret = LEN(gEngineRoot)
    ELSEIF keyCode = 83 THEN
        DeleteEngineRootForward
        EXIT SUB
    ELSE
        EXIT SUB
    END IF

    gUiFieldSelectionAnchor = gUiFieldCaret
    gUiFieldSelectionEnd = gUiFieldCaret
    UpdateEngineRootViewport
END SUB

SUB BackspaceEngineRoot
    IF gUiFieldSelectionAnchor <> gUiFieldSelectionEnd THEN
        DeleteEngineRootSelection
    ELSEIF gUiFieldCaret > 0 THEN
        gEngineRoot = LEFT$(gEngineRoot, gUiFieldCaret - 1) + MID$(gEngineRoot, gUiFieldCaret + 1)
        gUiFieldCaret = gUiFieldCaret - 1
        gUiFieldSelectionAnchor = gUiFieldCaret
        gUiFieldSelectionEnd = gUiFieldCaret
    END IF
    UpdateEngineRootViewport
END SUB

SUB DeleteEngineRootForward
    IF gUiFieldSelectionAnchor <> gUiFieldSelectionEnd THEN
        DeleteEngineRootSelection
    ELSEIF gUiFieldCaret < LEN(gEngineRoot) THEN
        gEngineRoot = LEFT$(gEngineRoot, gUiFieldCaret) + MID$(gEngineRoot, gUiFieldCaret + 2)
    END IF
    UpdateEngineRootViewport
END SUB

SUB DeleteEngineRootSelection
    DIM selectionStart AS LONG
    DIM selectionEnd AS LONG

    selectionStart = gUiFieldSelectionAnchor
    selectionEnd = gUiFieldSelectionEnd
    IF selectionStart > selectionEnd THEN SWAP selectionStart, selectionEnd
    IF selectionStart = selectionEnd THEN EXIT SUB

    gEngineRoot = LEFT$(gEngineRoot, selectionStart) + MID$(gEngineRoot, selectionEnd + 1)
    gUiFieldCaret = selectionStart
    gUiFieldSelectionAnchor = selectionStart
    gUiFieldSelectionEnd = selectionStart
END SUB

SUB InsertEngineRootText (insertText AS STRING)
    DIM availableCharacters AS LONG

    IF gUiFieldSelectionAnchor <> gUiFieldSelectionEnd THEN DeleteEngineRootSelection
    availableCharacters = 240 - LEN(gEngineRoot)
    IF availableCharacters <= 0 THEN EXIT SUB
    IF LEN(insertText) > availableCharacters THEN insertText = LEFT$(insertText, availableCharacters)
    IF LEN(insertText) = 0 THEN EXIT SUB

    gEngineRoot = LEFT$(gEngineRoot, gUiFieldCaret) + insertText + MID$(gEngineRoot, gUiFieldCaret + 1)
    gUiFieldCaret = gUiFieldCaret + LEN(insertText)
    gUiFieldSelectionAnchor = gUiFieldCaret
    gUiFieldSelectionEnd = gUiFieldCaret
    UpdateEngineRootViewport
END SUB

SUB SelectAllEngineRoot
    gUiFieldSelectionAnchor = 0
    gUiFieldSelectionEnd = LEN(gEngineRoot)
    gUiFieldCaret = LEN(gEngineRoot)
    UpdateEngineRootViewport
END SUB

SUB CopyEngineRootSelection
    DIM selectionStart AS LONG
    DIM selectionEnd AS LONG

    selectionStart = gUiFieldSelectionAnchor
    selectionEnd = gUiFieldSelectionEnd
    IF selectionStart > selectionEnd THEN SWAP selectionStart, selectionEnd

    IF selectionStart = selectionEnd THEN
        gUiStatus = "No engine-root text is selected."
        gUiStatusKind = 2
        EXIT SUB
    END IF

    _CLIPBOARD$ = MID$(gEngineRoot, selectionStart + 1, selectionEnd - selectionStart)
    gUiStatus = "Selected engine-root text copied."
    gUiStatusKind = 1
END SUB

SUB CutEngineRootSelection
    IF gUiFieldSelectionAnchor = gUiFieldSelectionEnd THEN EXIT SUB
    CopyEngineRootSelection
    DeleteEngineRootSelection
    UpdateEngineRootViewport
END SUB

SUB UpdateEngineRootViewport
    IF gUiFieldCaret < 0 THEN gUiFieldCaret = 0
    IF gUiFieldCaret > LEN(gEngineRoot) THEN gUiFieldCaret = LEN(gEngineRoot)
    IF gUiFieldViewStart < 0 THEN gUiFieldViewStart = 0
    IF gUiFieldViewStart > LEN(gEngineRoot) THEN gUiFieldViewStart = LEN(gEngineRoot)
    IF gUiFieldCaret < gUiFieldViewStart THEN gUiFieldViewStart = gUiFieldCaret

    DO WHILE gUiFieldViewStart < gUiFieldCaret
        IF _PRINTWIDTH(MID$(gEngineRoot, gUiFieldViewStart + 1, gUiFieldCaret - gUiFieldViewStart)) <= 900 THEN EXIT DO
        gUiFieldViewStart = gUiFieldViewStart + 1
    LOOP
END SUB

FUNCTION EngineRootVisibleText$
    DIM visibleText AS STRING

    UpdateEngineRootViewport
    visibleText = MID$(gEngineRoot, gUiFieldViewStart + 1)
    DO WHILE LEN(visibleText) > 0 AND _PRINTWIDTH(visibleText) > 920
        visibleText = LEFT$(visibleText, LEN(visibleText) - 1)
    LOOP
    EngineRootVisibleText$ = visibleText
END FUNCTION

SUB HandleBuildLogNavigation (keyPress AS STRING, handled AS LONG)
    DIM keyCode AS LONG

    handled = 0
    IF keyPress = CHR$(1) THEN
        IF LEN(gBuildLogText) > 0 THEN
            gBuildLogSelectionAnchor = 1
            gBuildLogSelectionStart = 1
            gBuildLogSelectionEnd = LEN(gBuildLogText) + 1
            gBuildLogSelectionActive = -1
        END IF
        handled = -1
        EXIT SUB
    END IF

    IF LEN(keyPress) <> 2 THEN EXIT SUB
    IF ASC(keyPress) <> 0 AND ASC(keyPress) <> 224 THEN EXIT SUB
    keyCode = ASC(RIGHT$(keyPress, 1))

    IF keyCode = 72 THEN
        ScrollBuildLog -1
    ELSEIF keyCode = 80 THEN
        ScrollBuildLog 1
    ELSEIF keyCode = 73 THEN
        ScrollBuildLog -N4BuildLogVisibleLines
    ELSEIF keyCode = 81 THEN
        ScrollBuildLog N4BuildLogVisibleLines
    ELSEIF keyCode = 71 THEN
        gBuildLogFollowTail = 0
        gBuildLogFirstVisibleLine = 0
    ELSEIF keyCode = 79 THEN
        gBuildLogFollowTail = -1
        ClampBuildLogViewport
    ELSE
        EXIT SUB
    END IF
    handled = -1
END SUB

FUNCTION BuildLogLineCount (textValue AS STRING)
    DIM startPosition AS LONG
    DIM separatorPosition AS LONG
    DIM lineCount AS LONG

    IF LEN(textValue) = 0 THEN
        BuildLogLineCount = 0
        EXIT FUNCTION
    END IF

    startPosition = 1
    DO WHILE startPosition <= LEN(textValue)
        lineCount = lineCount + 1
        separatorPosition = INSTR(startPosition, textValue, CHR$(10))
        IF separatorPosition = 0 THEN EXIT DO
        startPosition = separatorPosition + 1
    LOOP
    BuildLogLineCount = lineCount
END FUNCTION

SUB ClampBuildLogViewport
    DIM totalLines AS LONG
    DIM maximumFirstLine AS LONG

    totalLines = BuildLogLineCount(gBuildLogText)
    maximumFirstLine = totalLines - N4BuildLogVisibleLines
    IF maximumFirstLine < 0 THEN maximumFirstLine = 0

    IF gBuildLogFollowTail <> 0 THEN gBuildLogFirstVisibleLine = maximumFirstLine
    IF gBuildLogFirstVisibleLine < 0 THEN gBuildLogFirstVisibleLine = 0
    IF gBuildLogFirstVisibleLine > maximumFirstLine THEN gBuildLogFirstVisibleLine = maximumFirstLine
END SUB

SUB ScrollBuildLog (lineDelta AS LONG)
    DIM totalLines AS LONG
    DIM maximumFirstLine AS LONG

    ClampBuildLogViewport
    totalLines = BuildLogLineCount(gBuildLogText)
    maximumFirstLine = totalLines - N4BuildLogVisibleLines
    IF maximumFirstLine < 0 THEN maximumFirstLine = 0

    gBuildLogFollowTail = 0
    gBuildLogFirstVisibleLine = gBuildLogFirstVisibleLine + lineDelta
    IF gBuildLogFirstVisibleLine < 0 THEN gBuildLogFirstVisibleLine = 0
    IF gBuildLogFirstVisibleLine >= maximumFirstLine THEN
        gBuildLogFirstVisibleLine = maximumFirstLine
        gBuildLogFollowTail = -1
    END IF
END SUB

SUB ResetBuildLogSelection
    gBuildLogSelectionAnchor = 0
    gBuildLogSelectionStart = 0
    gBuildLogSelectionEnd = 0
    gBuildLogSelectionActive = 0
    gBuildLogSelectionDragging = 0
    gBuildLogFirstVisibleLine = 0
    gBuildLogFollowTail = -1
    gBuildContextMenuOpen = 0
END SUB

SUB BeginBuildLogSelection (mouseX AS LONG, mouseY AS LONG)
    DIM selectionOffset AS LONG
    DIM selectionValid AS LONG

    gUiFieldActive = 0
    gUiFieldSelectionDragging = 0
    gBuildLogFocused = -1
    BuildLogPointToOffset mouseX, mouseY, selectionOffset, selectionValid
    IF selectionValid = 0 THEN EXIT SUB
    gBuildContextMenuOpen = 0
    gBuildLogSelectionAnchor = selectionOffset
    gBuildLogSelectionStart = selectionOffset
    gBuildLogSelectionEnd = selectionOffset
    gBuildLogSelectionActive = -1
    gBuildLogSelectionDragging = -1
END SUB

SUB UpdateBuildLogSelection (mouseX AS LONG, mouseY AS LONG)
    DIM selectionOffset AS LONG
    DIM selectionValid AS LONG

    IF gBuildLogSelectionDragging = 0 THEN EXIT SUB
    BuildLogPointToOffset mouseX, mouseY, selectionOffset, selectionValid
    IF selectionValid <> 0 THEN gBuildLogSelectionEnd = selectionOffset
END SUB

SUB EndBuildLogSelection
    gBuildLogSelectionDragging = 0
    IF gBuildLogSelectionStart = gBuildLogSelectionEnd THEN gBuildLogSelectionActive = 0
END SUB

SUB BuildLogPointToOffset (mouseX AS LONG, mouseY AS LONG, outputOffset AS LONG, valid AS LONG)
    DIM startPosition AS LONG
    DIM lineStart AS LONG
    DIM separatorPosition AS LONG
    DIM currentLine AS STRING
    DIM displayedText AS STRING
    DIM totalLines AS LONG
    DIM targetLine AS LONG
    DIM lineNumber AS LONG
    DIM trimCount AS LONG
    DIM clickColumn AS LONG
    DIM characterIndex AS LONG

    outputOffset = 0
    valid = 0
    IF LEN(gBuildLogText) = 0 THEN EXIT SUB
    IF mouseX < N4BuildLogLeft - 18 OR mouseX > N4BuildLogLeft + N4BuildLogWidth + 18 THEN EXIT SUB
    IF mouseY < N4BuildLogTop OR mouseY >= N4BuildLogTop + N4BuildLogVisibleLines * N4BuildLogLineHeight THEN EXIT SUB

    totalLines = BuildLogLineCount(gBuildLogText)
    IF totalLines = 0 THEN EXIT SUB
    ClampBuildLogViewport
    targetLine = gBuildLogFirstVisibleLine + (mouseY - N4BuildLogTop) \ N4BuildLogLineHeight
    IF targetLine < 0 OR targetLine >= totalLines THEN EXIT SUB

    startPosition = 1
    lineNumber = 0
    DO WHILE lineNumber < targetLine
        separatorPosition = INSTR(startPosition, gBuildLogText, CHR$(10))
        IF separatorPosition = 0 THEN EXIT SUB
        startPosition = separatorPosition + 1
        lineNumber = lineNumber + 1
    LOOP

    lineStart = startPosition
    separatorPosition = INSTR(startPosition, gBuildLogText, CHR$(10))
    IF separatorPosition = 0 THEN
        currentLine = MID$(gBuildLogText, startPosition)
    ELSE
        currentLine = MID$(gBuildLogText, startPosition, separatorPosition - startPosition)
    END IF
    IF LEN(currentLine) > 0 AND RIGHT$(currentLine, 1) = CHR$(13) THEN currentLine = LEFT$(currentLine, LEN(currentLine) - 1)

    displayedText = currentLine
    DO WHILE LEN(displayedText) > 0 AND _PRINTWIDTH(displayedText) > N4BuildLogWidth
        displayedText = RIGHT$(displayedText, LEN(displayedText) - 1)
    LOOP
    trimCount = LEN(currentLine) - LEN(displayedText)
    clickColumn = LEN(displayedText)
    IF mouseX <= N4BuildLogLeft THEN
        clickColumn = 0
    ELSE
        FOR characterIndex = 1 TO LEN(displayedText)
            IF mouseX < N4BuildLogLeft + _PRINTWIDTH(LEFT$(displayedText, characterIndex)) THEN
                clickColumn = characterIndex - 1
                EXIT FOR
            END IF
        NEXT characterIndex
    END IF

    outputOffset = lineStart + trimCount + clickColumn
    IF outputOffset < lineStart THEN outputOffset = lineStart
    IF outputOffset > lineStart + LEN(currentLine) THEN outputOffset = lineStart + LEN(currentLine)
    valid = -1
END SUB

SUB CopyBuildOutput
    DIM copyText AS STRING
    DIM firstOffset AS LONG
    DIM lastOffset AS LONG
    DIM temporaryValue AS LONG
    DIM copiedSelection AS LONG

    IF gBuildLogSelectionActive <> 0 AND gBuildLogSelectionStart <> gBuildLogSelectionEnd THEN
        firstOffset = gBuildLogSelectionStart
        lastOffset = gBuildLogSelectionEnd
        IF firstOffset > lastOffset THEN
            temporaryValue = firstOffset
            firstOffset = lastOffset
            lastOffset = temporaryValue
        END IF
        IF firstOffset >= 1 AND lastOffset <= LEN(gBuildLogText) + 1 THEN
            copyText = MID$(gBuildLogText, firstOffset, lastOffset - firstOffset)
            IF LEN(copyText) > 0 THEN copiedSelection = -1
        END IF
    END IF

    IF copiedSelection = 0 THEN
        IF LEN(gBuildLogText) > 0 THEN
            copyText = gBuildLogText
        ELSEIF LEN(gUiDetail) > 0 THEN
            copyText = gUiDetail
        ELSE
            copyText = gUiStatus
        END IF
    END IF

    IF LEN(copyText) > 0 THEN
        _CLIPBOARD$ = copyText
        IF copiedSelection <> 0 THEN
            gUiStatus = "Selected text copied to clipboard."
        ELSE
            gUiStatus = "Current output copied to clipboard."
        END IF
        gUiStatusKind = 1
    ELSE
        gUiStatus = "No output is available to copy."
        gUiStatusKind = 2
    END IF
END SUB

SUB OpenBuildContextMenu (mouseX AS LONG, mouseY AS LONG)
    IF PointInRect(mouseX, mouseY, 70, 540, 1030, 650) = 0 THEN
        gBuildContextMenuOpen = 0
        EXIT SUB
    END IF

    gUiFieldActive = 0
    gUiFieldSelectionDragging = 0
    gBuildLogFocused = -1
    gBuildContextMenuX = mouseX
    gBuildContextMenuY = mouseY
    IF gBuildContextMenuX + N4BuildContextMenuWidth > 1090 THEN gBuildContextMenuX = 1090 - N4BuildContextMenuWidth
    IF gBuildContextMenuY + N4BuildContextMenuHeight > 750 THEN gBuildContextMenuY = 750 - N4BuildContextMenuHeight
    gBuildContextMenuOpen = -1
END SUB

SUB HandleBuildContextMenuClick (mouseX AS LONG, mouseY AS LONG)
    IF gBuildContextMenuOpen = 0 THEN EXIT SUB
    IF PointInRect(mouseX, mouseY, gBuildContextMenuX, gBuildContextMenuY, gBuildContextMenuX + N4BuildContextMenuWidth, gBuildContextMenuY + N4BuildContextMenuHeight) THEN CopyBuildOutput
    gBuildContextMenuOpen = 0
END SUB

FUNCTION PointInRect (pointX AS LONG, pointY AS LONG, leftPos AS LONG, topPos AS LONG, rightPos AS LONG, bottomPos AS LONG)
    IF pointX >= leftPos AND pointX <= rightPos AND pointY >= topPos AND pointY <= bottomPos THEN
        PointInRect = -1
    ELSE
        PointInRect = 0
    END IF
END FUNCTION

SUB DrawEngineRootField
    DIM visibleText AS STRING
    DIM selectionStart AS LONG
    DIM selectionEnd AS LONG
    DIM displayedStart AS LONG
    DIM displayedEnd AS LONG
    DIM highlightStart AS LONG
    DIM highlightEnd AS LONG
    DIM startColumn AS LONG
    DIM endColumn AS LONG
    DIM caretColumn AS LONG
    DIM caretX AS LONG

    visibleText = EngineRootVisibleText$
    IF LEN(gEngineRoot) = 0 THEN
        COLOR _RGB32(115, 126, 148)
        _PRINTSTRING (84, 168), "Type or paste the engine directory"
    ELSE
        displayedStart = gUiFieldViewStart
        displayedEnd = displayedStart + LEN(visibleText)
        selectionStart = gUiFieldSelectionAnchor
        selectionEnd = gUiFieldSelectionEnd
        IF selectionStart > selectionEnd THEN SWAP selectionStart, selectionEnd
        highlightStart = selectionStart
        IF highlightStart < displayedStart THEN highlightStart = displayedStart
        highlightEnd = selectionEnd
        IF highlightEnd > displayedEnd THEN highlightEnd = displayedEnd
        IF highlightEnd > highlightStart THEN
            startColumn = highlightStart - displayedStart
            endColumn = highlightEnd - displayedStart
            LINE (84 + _PRINTWIDTH(LEFT$(visibleText, startColumn)), 164)-(84 + _PRINTWIDTH(LEFT$(visibleText, endColumn)), 185), _RGB32(53, 111, 178), BF
        END IF
        COLOR _RGB32(235, 240, 248)
        _PRINTSTRING (84, 168), visibleText
    END IF

    IF gUiFieldActive <> 0 THEN
        caretColumn = gUiFieldCaret - gUiFieldViewStart
        IF caretColumn < 0 THEN caretColumn = 0
        IF caretColumn > LEN(visibleText) THEN caretColumn = LEN(visibleText)
        caretX = 84 + _PRINTWIDTH(LEFT$(visibleText, caretColumn))
        LINE (caretX, 163)-(caretX, 187), _RGB32(94, 184, 255)
    END IF
END SUB

SUB DrawLauncher
    DIM backgroundColor AS LONG
    DIM panelColor AS LONG
    DIM borderColor AS LONG
    DIM primaryColor AS LONG
    DIM secondaryColor AS LONG
    DIM warningColor AS LONG
    DIM statusColor AS LONG
    DIM targetText AS STRING
    DIM debugSelected AS LONG
    DIM releaseSelected AS LONG
    DIM relWithDebInfoSelected AS LONG

    backgroundColor = _RGB32(15, 18, 26)
    panelColor = _RGB32(27, 32, 44)
    borderColor = _RGB32(62, 72, 94)
    primaryColor = _RGB32(94, 184, 255)
    secondaryColor = _RGB32(178, 190, 210)
    warningColor = _RGB32(245, 184, 77)
    statusColor = secondaryColor

    IF gUiStatusKind = 1 THEN statusColor = _RGB32(95, 220, 145)
    IF gUiStatusKind = 2 THEN statusColor = _RGB32(255, 105, 105)

    CLS , backgroundColor
    LINE (40, 30)-(1060, 720), panelColor, BF
    LINE (40, 30)-(1060, 720), borderColor, B

    COLOR primaryColor
    _PRINTSTRING (70, 60), "NEBULA DEVICE 4"
    COLOR secondaryColor
    _PRINTSTRING (70, 88), "Standalone FastBuild launcher"

    COLOR secondaryColor
    _PRINTSTRING (70, 120), "ENGINE ROOT"
    LINE (70, 150)-(1030, 202), _RGB32(12, 15, 22), BF
    IF gUiFieldActive = -1 THEN
        LINE (70, 150)-(1030, 202), primaryColor, B
    ELSE
        LINE (70, 150)-(1030, 202), borderColor, B
    END IF
    DrawEngineRootField

    COLOR secondaryColor
    _PRINTSTRING (70, 228), "TARGET"
    debugSelected = 0
    releaseSelected = 0
    relWithDebInfoSelected = 0
    IF gUiTarget = "N4Editor_Debug" THEN debugSelected = -1
    IF gUiTarget = "N4Editor_Release" THEN releaseSelected = -1
    IF gUiTarget = "N4Editor_RelWithDebInfo" THEN relWithDebInfoSelected = -1
    DrawLauncherButton 70, 262, 300, 312, "DEBUG", debugSelected
    DrawLauncherButton 325, 262, 555, 312, "RELEASE", releaseSelected
    DrawLauncherButton 580, 262, 850, 312, "RELWITHDEBINFO", relWithDebInfoSelected

    COLOR secondaryColor
    _PRINTSTRING (70, 333), "BUILD SETTINGS: edit the marked block at the top of fbuild.bff"

    DrawLauncherButton 550, 355, 700, 415, "BUILD", 0
    DrawLauncherButton 720, 355, 870, 415, "DOCTOR", 0
    DrawLauncherButton 890, 355, 1030, 415, "QUIT", 0

    COLOR secondaryColor
    _PRINTSTRING (70, 450), "STATUS"
    LINE (70, 480)-(1030, 700), _RGB32(12, 15, 22), BF
    LINE (70, 480)-(1030, 700), borderColor, B
    COLOR statusColor
    _PRINTSTRING (88, 508), FitText$(gUiStatus, 910)
    IF LEN(gBuildLogText) > 0 THEN
        DrawBuildLog gBuildLogText, 88, 550, N4BuildLogLineHeight, _RGB32(185, 196, 215)
    ELSE
        DrawLauncherLines gUiDetail, 88, 550, 22, _RGB32(185, 196, 215)
    END IF

    COLOR warningColor
    targetText = "Target: " + gUiTarget
    _PRINTSTRING (88, 665), targetText
    COLOR _RGB32(115, 126, 148)
    _PRINTSTRING (88, 688), FitText$("Enter builds   Esc closes   Ctrl+A/C/X/V edits text   Wheel/Page/Home/End moves output", 910)
    IF gBuildContextMenuOpen <> 0 THEN DrawBuildContextMenu
END SUB

SUB DrawBuildContextMenu
    DIM menuRight AS LONG
    DIM menuBottom AS LONG

    menuRight = gBuildContextMenuX + N4BuildContextMenuWidth
    menuBottom = gBuildContextMenuY + N4BuildContextMenuHeight
    LINE (gBuildContextMenuX, gBuildContextMenuY)-(menuRight, menuBottom), _RGB32(34, 42, 56), BF
    LINE (gBuildContextMenuX, gBuildContextMenuY)-(menuRight, menuBottom), _RGB32(125, 145, 175), B
    COLOR _RGB32(240, 245, 255)
    _PRINTSTRING (gBuildContextMenuX + 12, gBuildContextMenuY + 8), "Copy (C)"
END SUB

SUB DrawLauncherButton (leftPos AS LONG, topPos AS LONG, rightPos AS LONG, bottomPos AS LONG, labelText AS STRING, selected AS LONG)
    DIM fillColor AS LONG
    DIM lineColor AS LONG
    DIM textColor AS LONG
    DIM textLeft AS LONG
    DIM textTop AS LONG

    IF selected <> 0 THEN
        fillColor = _RGB32(40, 106, 160)
        lineColor = _RGB32(119, 211, 255)
        textColor = _RGB32(255, 255, 255)
    ELSE
        fillColor = _RGB32(40, 47, 62)
        lineColor = _RGB32(78, 92, 118)
        textColor = _RGB32(215, 224, 238)
    END IF

    LINE (leftPos, topPos)-(rightPos, bottomPos), fillColor, BF
    LINE (leftPos, topPos)-(rightPos, bottomPos), lineColor, B
    textLeft = leftPos + ((rightPos - leftPos) - _PRINTWIDTH(labelText)) \ 2
    textTop = topPos + ((bottomPos - topPos) - 16) \ 2
    COLOR textColor
    _PRINTSTRING (textLeft, textTop), labelText
END SUB

SUB DrawLauncherCheckBox (leftPos AS LONG, topPos AS LONG, labelText AS STRING, checked AS LONG)
    DIM fillColor AS LONG

    fillColor = _RGB32(40, 47, 62)
    IF checked <> 0 THEN fillColor = _RGB32(40, 106, 160)
    LINE (leftPos, topPos)-(leftPos + 32, topPos + 32), fillColor, BF
    LINE (leftPos, topPos)-(leftPos + 32, topPos + 32), _RGB32(78, 92, 118), B
    IF checked <> 0 THEN
        COLOR _RGB32(255, 255, 255)
        _PRINTSTRING (leftPos + 8, topPos + 7), "X"
    END IF
    COLOR _RGB32(215, 224, 238)
    _PRINTSTRING (leftPos + 46, topPos + 8), labelText
END SUB

SUB DrawBuildLog (textValue AS STRING, leftPos AS LONG, topPos AS LONG, lineHeight AS LONG, textColor AS LONG)
    DIM startPosition AS LONG
    DIM lineStart AS LONG
    DIM separatorPosition AS LONG
    DIM currentLine AS STRING
    DIM totalLines AS LONG
    DIM lineNumber AS LONG
    DIM displayIndex AS LONG

    IF LEN(textValue) = 0 THEN EXIT SUB
    totalLines = BuildLogLineCount(textValue)
    IF totalLines = 0 THEN EXIT SUB
    ClampBuildLogViewport

    startPosition = 1
    lineNumber = 0
    DO WHILE lineNumber < gBuildLogFirstVisibleLine
        separatorPosition = INSTR(startPosition, textValue, CHR$(10))
        IF separatorPosition = 0 THEN EXIT SUB
        startPosition = separatorPosition + 1
        lineNumber = lineNumber + 1
    LOOP

    displayIndex = 0
    DO WHILE startPosition <= LEN(textValue) AND displayIndex < N4BuildLogVisibleLines
        lineStart = startPosition
        separatorPosition = INSTR(startPosition, textValue, CHR$(10))
        IF separatorPosition = 0 THEN
            currentLine = MID$(textValue, startPosition)
        ELSE
            currentLine = MID$(textValue, startPosition, separatorPosition - startPosition)
        END IF
        IF LEN(currentLine) > 0 AND RIGHT$(currentLine, 1) = CHR$(13) THEN currentLine = LEFT$(currentLine, LEN(currentLine) - 1)
        DrawBuildLogLine currentLine, lineStart, leftPos, topPos + displayIndex * lineHeight, textColor
        displayIndex = displayIndex + 1
        IF separatorPosition = 0 THEN EXIT DO
        startPosition = separatorPosition + 1
    LOOP
END SUB

SUB DrawBuildLogLine (lineText AS STRING, lineStart AS LONG, leftPos AS LONG, topPos AS LONG, textColor AS LONG)
    DIM displayedText AS STRING
    DIM displayedStart AS LONG
    DIM displayedEnd AS LONG
    DIM selectionStart AS LONG
    DIM selectionEnd AS LONG
    DIM highlightStart AS LONG
    DIM highlightEnd AS LONG
    DIM startColumn AS LONG
    DIM endColumn AS LONG
    DIM temporaryValue AS LONG

    displayedText = lineText
    DO WHILE LEN(displayedText) > 0 AND _PRINTWIDTH(displayedText) > N4BuildLogWidth
        displayedText = RIGHT$(displayedText, LEN(displayedText) - 1)
    LOOP
    displayedStart = lineStart + LEN(lineText) - LEN(displayedText)
    displayedEnd = displayedStart + LEN(displayedText)

    IF gBuildLogSelectionActive <> 0 AND gBuildLogSelectionStart <> gBuildLogSelectionEnd THEN
        selectionStart = gBuildLogSelectionStart
        selectionEnd = gBuildLogSelectionEnd
        IF selectionStart > selectionEnd THEN
            temporaryValue = selectionStart
            selectionStart = selectionEnd
            selectionEnd = temporaryValue
        END IF
        highlightStart = selectionStart
        IF highlightStart < displayedStart THEN highlightStart = displayedStart
        highlightEnd = selectionEnd
        IF highlightEnd > displayedEnd THEN highlightEnd = displayedEnd
        IF highlightEnd > highlightStart THEN
            startColumn = highlightStart - displayedStart
            endColumn = highlightEnd - displayedStart
            LINE (leftPos + _PRINTWIDTH(LEFT$(displayedText, startColumn)), topPos)-(leftPos + _PRINTWIDTH(LEFT$(displayedText, endColumn)), topPos + 15), _RGB32(53, 111, 178), BF
        END IF
    END IF

    COLOR textColor
    _PRINTSTRING (leftPos, topPos), displayedText
END SUB

SUB DrawLauncherLines (textValue AS STRING, leftPos AS LONG, topPos AS LONG, lineHeight AS LONG, textColor AS LONG)
    DIM startPosition AS LONG
    DIM separatorPosition AS LONG
    DIM currentLine AS STRING
    DIM lineNumber AS LONG

    IF LEN(textValue) = 0 THEN EXIT SUB
    startPosition = 1
    lineNumber = 0

    DO
        separatorPosition = INSTR(startPosition, textValue, CHR$(10))
        IF separatorPosition = 0 THEN
            currentLine = MID$(textValue, startPosition)
        ELSE
            currentLine = MID$(textValue, startPosition, separatorPosition - startPosition)
        END IF
        COLOR textColor
        _PRINTSTRING (leftPos, topPos + lineNumber * lineHeight), FitText$(currentLine, 910)
        lineNumber = lineNumber + 1
        IF separatorPosition = 0 THEN EXIT DO
        startPosition = separatorPosition + 1
    LOOP
END SUB

FUNCTION FitText$ (sourceText AS STRING, maxWidth AS LONG)
    DIM resultText AS STRING
    resultText = sourceText

    DO WHILE LEN(resultText) > 4 AND _PRINTWIDTH(resultText) > maxWidth
        resultText = RIGHT$(resultText, LEN(resultText) - 1)
    LOOP

    IF resultText <> sourceText THEN resultText = "..." + resultText
    FitText$ = resultText
END FUNCTION

FUNCTION FirstLine$ (textValue AS STRING)
    DIM separatorPosition AS LONG

    separatorPosition = INSTR(1, textValue, CHR$(13))
    IF separatorPosition = 0 THEN separatorPosition = INSTR(1, textValue, CHR$(10))
    IF separatorPosition > 0 THEN
        FirstLine$ = LEFT$(textValue, separatorPosition - 1)
    ELSE
        FirstLine$ = textValue
    END IF
END FUNCTION

SUB UpdateBuildState
    DIM statusText AS STRING
    DIM elapsedSeconds AS DOUBLE
    DIM exitCode AS LONG

    IF gBuildProcessActive = 0 THEN EXIT SUB

    ReadBuildLog
    statusText = ReadBuildStatus$

    IF LEFT$(statusText, 5) = "DONE:" THEN
        ReadBuildLog
        exitCode = VAL(MID$(statusText, 6))
        gBuildProcessActive = 0
        gUiBusy = 0
        gUiExitCode = exitCode
        gUiDetail = ""
        IF exitCode <> N4BuildOk THEN
            Abort "FastBuild exited with code " + LTRIM$(STR$(exitCode)) + ".", exitCode
            gUiStatus = gLastError
            gUiStatusKind = 2
        ELSE
            gUiStatus = "Build completed successfully."
            gUiStatusKind = 1
        END IF
        EXIT SUB
    END IF

    IF LEN(statusText) = 0 THEN
        elapsedSeconds = TIMER - gBuildStartTime
        IF elapsedSeconds < 0 THEN elapsedSeconds = elapsedSeconds + 86400
        IF elapsedSeconds > N4BuildStartTimeoutSeconds THEN
            gBuildProcessActive = 0
            gUiBusy = 0
            Abort "FastBuild wrapper did not start.", N4BuildDiscoveryError
            gUiStatus = gLastError
            gUiStatusKind = 2
        END IF
    END IF
END SUB

SUB ReadBuildLog
    DIM fileNumber AS INTEGER
    DIM fileLength AS LONG
    DIM chunk AS STRING
    DIM separatorPosition AS LONG

    IF LEN(gBuildLogPath) = 0 OR _FILEEXISTS(gBuildLogPath) = 0 THEN EXIT SUB

    fileNumber = FREEFILE
    OPEN gBuildLogPath FOR BINARY AS #fileNumber
    fileLength = LOF(fileNumber)

    IF fileLength < gBuildLogOffset THEN
        gBuildLogOffset = 0
        gBuildLogText = ""
        ResetBuildLogSelection
    END IF

    IF fileLength > gBuildLogOffset THEN
        SEEK #fileNumber, gBuildLogOffset + 1
        chunk = INPUT$(fileLength - gBuildLogOffset, #fileNumber)
        gBuildLogText = gBuildLogText + chunk
        gBuildLogOffset = fileLength
    END IF

    CLOSE #fileNumber

    IF LEN(gBuildLogText) > N4BuildLogMaxChars THEN
        gBuildLogText = RIGHT$(gBuildLogText, N4BuildLogMaxChars)
        separatorPosition = INSTR(1, gBuildLogText, CHR$(10))
        IF separatorPosition > 0 THEN gBuildLogText = MID$(gBuildLogText, separatorPosition + 1)
        ResetBuildLogSelection
    END IF
END SUB

FUNCTION ReadBuildStatus$
    DIM fileNumber AS INTEGER
    DIM lineText AS STRING

    IF LEN(gBuildStatusPath) = 0 OR _FILEEXISTS(gBuildStatusPath) = 0 THEN EXIT FUNCTION

    fileNumber = FREEFILE
    OPEN gBuildStatusPath FOR INPUT AS #fileNumber
    IF EOF(fileNumber) = 0 THEN LINE INPUT #fileNumber, lineText
    CLOSE #fileNumber
    ReadBuildStatus$ = LTRIM$(RTRIM$(lineText))
END FUNCTION

SUB WriteBuildCommandFile (buildTarget AS STRING)
    DIM fileNumber AS INTEGER
    DIM wrapperPath AS STRING

    gBuildCommandPath = JoinPath$(gBuildSystemRoot, "n4build-fastbuild.cmd")
    gBuildLogPath = JoinPath$(gBuildSystemRoot, "n4build-fastbuild.log")
    gBuildStatusPath = JoinPath$(gBuildSystemRoot, "n4build-fastbuild.status")
    wrapperPath = JoinPath$(gBuildSystemRoot, "build-and-compdb.cmd")

    IF _FILEEXISTS(wrapperPath) = 0 THEN
        Abort "Build wrapper was not found: " + wrapperPath, N4BuildDiscoveryError
        EXIT SUB
    END IF

    IF _FILEEXISTS(gBuildCommandPath) <> 0 THEN KILL gBuildCommandPath
    IF _FILEEXISTS(gBuildLogPath) <> 0 THEN KILL gBuildLogPath
    IF _FILEEXISTS(gBuildStatusPath) <> 0 THEN KILL gBuildStatusPath

    gBuildLogText = ""
    gBuildLogOffset = 0
    ResetBuildLogSelection

    fileNumber = FREEFILE
    OPEN gBuildCommandPath FOR OUTPUT AS #fileNumber
    PRINT #fileNumber, "@echo off"
    PRINT #fileNumber, "> " + Quote$(gBuildStatusPath) + " echo RUNNING"
    PRINT #fileNumber, "cd /d " + Quote$(gEngineRoot)
    PRINT #fileNumber, "CALL " + Quote$(wrapperPath) + " " + buildTarget + " > " + Quote$(gBuildLogPath) + " 2>&1"
    PRINT #fileNumber, "set " + CHR$(34) + "N4BUILD_EXIT=%ERRORLEVEL%" + CHR$(34)
    PRINT #fileNumber, "> " + Quote$(gBuildStatusPath) + " echo DONE:%N4BUILD_EXIT%"
    PRINT #fileNumber, "exit /b %N4BUILD_EXIT%"
    CLOSE #fileNumber
END SUB

SUB RunBuild (requestedMode AS STRING)
    DIM buildTarget AS STRING
    DIM commandLine AS STRING
    DIM commandProcessor AS STRING

    gBuildProcessActive = 0
    gBuildLogText = ""
    gBuildLogOffset = 0
    gUiExitCode = N4BuildOk
    gLastError = ""
    gLastErrorCode = N4BuildOk
    gUiDetail = ""

    gEngineRoot = NormalizePath$(gEngineRoot)
    IF LEN(gEngineRoot) = 0 THEN
        Abort "Engine root is empty. Enter the engine directory first.", N4BuildUsageError
        EXIT SUB
    END IF

    buildTarget = NormalizeTarget$(gUiTarget)
    IF requestedMode = "build" AND LEN(buildTarget) = 0 THEN
        Abort "Unknown build target.", N4BuildUsageError
        EXIT SUB
    END IF

    gFBuildPath = JoinPath$(gBuildSystemRoot, "FBuild.exe")
    IF _FILEEXISTS(gFBuildPath) = 0 THEN
        gFBuildPath = ResolveExecutable$("FBuild.exe")
        IF LEN(gFBuildPath) = 0 THEN
            Abort "FBuild.exe was not found beside the launcher or on PATH.", N4BuildDiscoveryError
            EXIT SUB
        END IF
    END IF

    gBffPath = JoinPath$(gBuildSystemRoot, "fbuild.bff")
    IF _FILEEXISTS(gBffPath) = 0 THEN
        Abort "fbuild.bff was not found beside FBuild.exe: " + gBffPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    ValidateEngineRoot
    IF LEN(gLastError) > 0 THEN EXIT SUB

    DiscoverToolchain
    IF LEN(gLastError) > 0 THEN EXIT SUB

    IF requestedMode = "doctor" THEN
        PrintResolvedConfiguration
        EXIT SUB
    END IF

    WriteBuildCommandFile buildTarget
    IF LEN(gLastError) > 0 THEN EXIT SUB
    commandProcessor = Environ$("ComSpec")
    IF LEN(commandProcessor) = 0 THEN
        Abort "ComSpec was not found in the environment.", N4BuildDiscoveryError
        EXIT SUB
    END IF

    gUiStatus = "FastBuild is running..."
    gUiDetail = "Waiting for FastBuild output..."
    gBuildStartTime = TIMER
    commandLine = Quote$(commandProcessor) + " /d /c " + Quote$(Quote$(gBuildCommandPath))
    SHELL _DONTWAIT _HIDE commandLine
    gBuildProcessActive = -1
END SUB

SUB PrintUsage
    gUiStatus = "Command-line options"
    gUiDetail = "N4Build.exe [target] [engine-root]" + CHR$(10) + "debug, release, relwithdebinfo, all" + CHR$(10) + "--shaders  Compile shaders" + CHR$(10) + "--validation  Deploy Vulkan validation"
END SUB

SUB ValidateEngineRoot
    DIM requiredPath AS STRING
    DIM relativePath AS STRING

    IF _DIREXISTS(gEngineRoot) = 0 THEN
        Abort "Engine root does not exist: " + gEngineRoot, N4BuildDiscoveryError
        EXIT SUB
    END IF

    relativePath = "src"
    requiredPath = JoinPath$(gEngineRoot, relativePath)
    IF _DIREXISTS(requiredPath) = 0 THEN
        Abort "Missing engine directory: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF

    relativePath = "libs"
    requiredPath = JoinPath$(gEngineRoot, relativePath)
    IF _DIREXISTS(requiredPath) = 0 THEN
        Abort "Missing engine directory: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF

    relativePath = "schemas"
    requiredPath = JoinPath$(gEngineRoot, relativePath)
    IF _DIREXISTS(requiredPath) = 0 THEN
        Abort "Missing engine directory: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF

    relativePath = "shaders"
    requiredPath = JoinPath$(gEngineRoot, relativePath)
    IF _DIREXISTS(requiredPath) = 0 THEN
        Abort "Missing engine directory: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF

    relativePath = "tools"
    requiredPath = JoinPath$(gEngineRoot, relativePath)
    IF _DIREXISTS(requiredPath) = 0 THEN
        Abort "Missing engine directory: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
END SUB

SUB DiscoverToolchain
    DIM mocPath AS STRING
    DIM qtRoot AS STRING
    DIM qtHostRoot AS STRING
    DIM qtAsanRoot AS STRING
    DIM qtStandardRoot AS STRING
    DIM sdkRoot AS STRING
    DIM sdkVersion AS STRING
    DIM vcToolsRoot AS STRING
    DIM pathToken AS STRING
    DIM resourceRoot AS STRING
    DIM qtHostBin AS STRING
    DIM configValue AS STRING

    gClangCompiler = ResolveExecutable$("clang-cl.exe")
    IF LEN(gClangCompiler) = 0 THEN
        Abort "clang-cl.exe was not found on PATH.", N4BuildDiscoveryError
        EXIT SUB
    END IF
    gClangBin = ParentPath$(gClangCompiler)

    gClangLinker = ResolveExecutable$("lld-link.exe")
    IF LEN(gClangLinker) = 0 THEN
        Abort "lld-link.exe was not found on PATH.", N4BuildDiscoveryError
        EXIT SUB
    END IF

    gClangLibrarian = ResolveExecutable$("llvm-lib.exe")
    IF LEN(gClangLibrarian) = 0 THEN
        Abort "llvm-lib.exe was not found on PATH.", N4BuildDiscoveryError
        EXIT SUB
    END IF

    gPythonExecutable = ResolveExecutable$("python.exe")
    IF LEN(gPythonExecutable) = 0 THEN
        Abort "python.exe was not found on PATH.", N4BuildDiscoveryError
        EXIT SUB
    END IF

    qtHostBin = NormalizePath$(ReadConfigValue$(gConfigPath, "QtHostBin"))
    qtHostRoot = NormalizePath$(ReadConfigValue$(gConfigPath, "QtHostRoot"))
    IF LEN(qtHostRoot) = 0 THEN qtHostRoot = FirstEnvironmentValue$("N4DC_QT_HOST_ROOT", "QT_HOST_ROOT")
    IF LEN(qtHostBin) > 0 THEN mocPath = JoinPath$(qtHostBin, "moc.exe")
    IF LEN(mocPath) = 0 AND LEN(qtHostRoot) > 0 THEN mocPath = JoinPath$(NormalizePath$(qtHostRoot), "bin\moc.exe")
    IF LEN(mocPath) = 0 OR _FILEEXISTS(mocPath) = 0 THEN mocPath = ResolveExecutable$("moc.exe")
    IF LEN(mocPath) = 0 THEN
        Abort "moc.exe was not found. Set QtHostBin or QtHostRoot in N4Build.ini, put Qt's host bin directory on PATH, or set QT_HOST_ROOT.", N4BuildDiscoveryError
        EXIT SUB
    END IF

    gQtHostBin = ParentPath$(mocPath)
    IF LEN(qtHostRoot) = 0 THEN qtHostRoot = ParentPath$(gQtHostBin)

    qtRoot = NormalizePath$(ReadConfigValue$(gConfigPath, "QtRoot"))
    IF LEN(qtRoot) = 0 THEN qtRoot = FirstEnvironmentValue$("N4DC_QT_ROOT", "QT_ROOT")
    IF LEN(qtRoot) = 0 THEN qtRoot = Environ$("QTDIR")
    IF LEN(qtRoot) = 0 THEN qtRoot = ParentPath$(gQtHostBin)

    qtAsanRoot = NormalizePath$(ReadConfigValue$(gConfigPath, "QtAsanRoot"))
    IF LEN(qtAsanRoot) = 0 THEN qtAsanRoot = FirstEnvironmentValue$("N4DC_QT_ASAN_ROOT", "QT_ASAN_ROOT")
    IF LEN(qtAsanRoot) = 0 THEN qtAsanRoot = qtRoot
    qtStandardRoot = NormalizePath$(ReadConfigValue$(gConfigPath, "QtStandardRoot"))
    IF LEN(qtStandardRoot) = 0 THEN qtStandardRoot = FirstEnvironmentValue$("N4DC_QT_STANDARD_ROOT", "QT_STANDARD_ROOT")
    IF LEN(qtStandardRoot) = 0 THEN qtStandardRoot = qtRoot

    gQtAsanRoot = NormalizePath$(qtAsanRoot)
    gQtStandardRoot = NormalizePath$(qtStandardRoot)
    ValidateQtRoot gQtAsanRoot, "Qt ASAN"
    IF LEN(gLastError) > 0 THEN EXIT SUB
    IF UCASE$(gQtStandardRoot) <> UCASE$(gQtAsanRoot) THEN
        ValidateQtRoot gQtStandardRoot, "Qt standard"
        IF LEN(gLastError) > 0 THEN EXIT SUB
    END IF

    sdkRoot = NormalizePath$(ReadConfigValue$(gConfigPath, "VulkanSdk"))
    IF LEN(sdkRoot) = 0 THEN sdkRoot = FirstEnvironmentValue$("VULKAN_SDK", "VK_SDK_PATH")
    IF LEN(sdkRoot) = 0 THEN
        pathToken = ResolveExecutable$("glslangValidator.exe")
        IF LEN(pathToken) > 0 THEN sdkRoot = ParentPath$(ParentPath$(pathToken))
    END IF
    gVulkanSdkRoot = NormalizePath$(sdkRoot)
    IF LEN(gVulkanSdkRoot) = 0 THEN
        Abort "Vulkan SDK was not found. Set VULKAN_SDK or put glslangValidator.exe on PATH.", N4BuildDiscoveryError
        EXIT SUB
    END IF

    gVulkanInclude = JoinPath$(gVulkanSdkRoot, "Include")
    gVulkanLib = JoinPath$(gVulkanSdkRoot, "Lib\vulkan-1.lib")
    IF _DIREXISTS(gVulkanInclude) = 0 THEN
        Abort "Vulkan SDK include directory is missing: " + gVulkanInclude, N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF _FILEEXISTS(JoinPath$(gVulkanInclude, "vulkan\vulkan.h")) = 0 THEN
        Abort "Vulkan headers are missing: " + JoinPath$(gVulkanInclude, "vulkan\vulkan.h"), N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF _FILEEXISTS(gVulkanLib) = 0 THEN
        Abort "Vulkan import library is missing: " + gVulkanLib, N4BuildDiscoveryError
        EXIT SUB
    END IF

    gGlslangExecutable = JoinPath$(gVulkanSdkRoot, "Bin\glslangValidator.exe")
    IF _FILEEXISTS(gGlslangExecutable) = 0 THEN gGlslangExecutable = ResolveExecutable$("glslangValidator.exe")
    IF LEN(gGlslangExecutable) = 0 THEN gGlslangExecutable = "glslangValidator.exe"

    vcToolsRoot = NormalizePath$(Environ$("VCToolsInstallDir"))
    IF LEN(vcToolsRoot) > 0 THEN
        gMsvcInclude = JoinPath$(vcToolsRoot, "include")
        gMsvcLib = JoinPath$(vcToolsRoot, "lib\x64")
    END IF

    IF LEN(gMsvcInclude) = 0 OR _DIREXISTS(gMsvcInclude) = 0 THEN
        pathToken = FindPathToken$(Environ$("INCLUDE"), "\VC\Tools\MSVC\", "\include")
        IF LEN(pathToken) > 0 THEN gMsvcInclude = pathToken
    END IF
    IF LEN(gMsvcLib) = 0 OR _DIREXISTS(gMsvcLib) = 0 THEN
        pathToken = FindPathToken$(Environ$("LIB"), "\VC\Tools\MSVC\", "\lib\x64")
        IF LEN(pathToken) > 0 THEN gMsvcLib = pathToken
    END IF

    sdkRoot = NormalizePath$(Environ$("WindowsSdkDir"))
    sdkVersion = NormalizePath$(Environ$("WindowsSDKVersion"))
    IF LEN(sdkRoot) > 0 AND LEN(sdkVersion) > 0 THEN
        gWindowsSdkInclude = JoinPath$(JoinPath$(sdkRoot, "Include"), sdkVersion)
        gWindowsSdkLib = JoinPath$(JoinPath$(sdkRoot, "Lib"), JoinPath$(sdkVersion, "um\x64"))
        gWindowsSdkUcrtLib = JoinPath$(JoinPath$(sdkRoot, "Lib"), JoinPath$(sdkVersion, "ucrt\x64"))
    END IF

    IF LEN(gWindowsSdkInclude) = 0 OR _DIREXISTS(gWindowsSdkInclude) = 0 THEN
        pathToken = FindPathToken$(Environ$("INCLUDE"), "\Windows Kits\10\Include\", "\ucrt")
        IF LEN(pathToken) = 0 THEN pathToken = FindPathToken$(Environ$("INCLUDE"), "\Windows Kits\10\Include\", "\shared")
        IF LEN(pathToken) > 0 THEN gWindowsSdkInclude = ParentPath$(pathToken)
    END IF
    IF LEN(gWindowsSdkLib) = 0 OR _DIREXISTS(gWindowsSdkLib) = 0 THEN
        pathToken = FindPathToken$(Environ$("LIB"), "\Windows Kits\10\Lib\", "\um\x64")
        IF LEN(pathToken) > 0 THEN gWindowsSdkLib = pathToken
    END IF
    IF LEN(gWindowsSdkUcrtLib) = 0 OR _DIREXISTS(gWindowsSdkUcrtLib) = 0 THEN
        pathToken = FindPathToken$(Environ$("LIB"), "\Windows Kits\10\Lib\", "\ucrt\x64")
        IF LEN(pathToken) > 0 THEN gWindowsSdkUcrtLib = pathToken
    END IF

    IF LEN(gMsvcInclude) = 0 OR _DIREXISTS(gMsvcInclude) = 0 THEN
        gMsvcInclude = "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\include"
    END IF
    IF LEN(gMsvcLib) = 0 OR _DIREXISTS(gMsvcLib) = 0 THEN
        gMsvcLib = "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\lib\x64"
    END IF
    IF LEN(gWindowsSdkInclude) = 0 OR _DIREXISTS(gWindowsSdkInclude) = 0 THEN
        gWindowsSdkInclude = "C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0"
    END IF
    IF LEN(gWindowsSdkLib) = 0 OR _DIREXISTS(gWindowsSdkLib) = 0 THEN
        gWindowsSdkLib = "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64"
    END IF
    IF LEN(gWindowsSdkUcrtLib) = 0 OR _DIREXISTS(gWindowsSdkUcrtLib) = 0 THEN
        gWindowsSdkUcrtLib = "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64"
    END IF

    IF LEN(gMsvcInclude) = 0 OR _DIREXISTS(gMsvcInclude) = 0 THEN
        Abort "MSVC headers were not found. Run from a Visual Studio Developer Command Prompt or set VCToolsInstallDir/INCLUDE.", N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF LEN(gMsvcLib) = 0 OR _DIREXISTS(gMsvcLib) = 0 THEN
        Abort "MSVC libraries were not found. Run from a Visual Studio Developer Command Prompt or set VCToolsInstallDir/LIB.", N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF LEN(gWindowsSdkInclude) = 0 OR _DIREXISTS(gWindowsSdkInclude) = 0 THEN
        Abort "Windows SDK headers were not found. Set WindowsSdkDir and WindowsSDKVersion or run a Developer Command Prompt.", N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF LEN(gWindowsSdkLib) = 0 OR _DIREXISTS(gWindowsSdkLib) = 0 THEN
        Abort "Windows SDK libraries were not found.", N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF LEN(gWindowsSdkUcrtLib) = 0 OR _DIREXISTS(gWindowsSdkUcrtLib) = 0 THEN
        Abort "Windows SDK UCRT libraries were not found.", N4BuildDiscoveryError
        EXIT SUB
    END IF

    configValue = NormalizePath$(ReadConfigValue$(gConfigPath, "ClangResourceRoot"))
    resourceRoot = configValue
    IF LEN(resourceRoot) = 0 THEN resourceRoot = FirstEnvironmentValue$("N4DC_CLANG_RESOURCE_ROOT", "LLVM_RESOURCE_DIR")
    IF LEN(resourceRoot) = 0 THEN resourceRoot = ResolveClangResourceRoot$(gClangCompiler)
    gAsanResource = JoinPath$(resourceRoot, "lib\windows")
    gAsanRuntime = JoinPath$(gAsanResource, "clang_rt.asan_dynamic-x86_64.lib")
    gAsanThunk = JoinPath$(gAsanResource, "clang_rt.asan_dynamic_runtime_thunk-x86_64.lib")
    gAsanDll = JoinPath$(gAsanResource, "clang_rt.asan_dynamic-x86_64.dll")

    IF _FILEEXISTS(gAsanRuntime) = 0 OR _FILEEXISTS(gAsanThunk) = 0 OR _FILEEXISTS(gAsanDll) = 0 THEN
        Abort "LLVM AddressSanitizer runtime is incomplete under: " + gAsanResource, N4BuildDiscoveryError
        EXIT SUB
    END IF
END SUB

SUB ValidateQtRoot (root AS STRING, label AS STRING)
    DIM requiredPath AS STRING

    IF LEN(root) = 0 THEN
        Abort label + " root is empty.", N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF _DIREXISTS(JoinPath$(root, "include")) = 0 THEN
        Abort label + " include directory is missing: " + JoinPath$(root, "include"), N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF _DIREXISTS(JoinPath$(root, "lib")) = 0 THEN
        Abort label + " library directory is missing: " + JoinPath$(root, "lib"), N4BuildDiscoveryError
        EXIT SUB
    END IF
    IF _DIREXISTS(JoinPath$(root, "plugins\platforms")) = 0 THEN
        Abort label + " platform plugin directory is missing: " + JoinPath$(root, "plugins\platforms"), N4BuildDiscoveryError
        EXIT SUB
    END IF

    requiredPath = JoinPath$(root, "lib\Qt6Core.lib")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " library is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "lib\Qt6Gui.lib")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " library is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "lib\Qt6Widgets.lib")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " library is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "lib\Qt6Svg.lib")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " library is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "lib\Qt6Concurrent.lib")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " library is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF

    requiredPath = JoinPath$(root, "bin\Qt6Core.dll")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " runtime is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "bin\Qt6Gui.dll")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " runtime is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "bin\Qt6Widgets.dll")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " runtime is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "bin\Qt6Svg.dll")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " runtime is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "bin\Qt6Concurrent.dll")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " runtime is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
    requiredPath = JoinPath$(root, "plugins\platforms\qwindows.dll")
    IF _FILEEXISTS(requiredPath) = 0 THEN
        Abort label + " Windows platform plugin is missing: " + requiredPath, N4BuildDiscoveryError
        EXIT SUB
    END IF
END SUB

SUB PrintResolvedConfiguration
    gUiStatus = "Toolchain discovery succeeded."
    gUiStatusKind = 1
    gUiDetail = "FBuild=" + gFBuildPath + CHR$(10) + "Clang=" + gClangCompiler + CHR$(10) + "Qt=" + gQtAsanRoot + CHR$(10) + "VulkanSDK=" + gVulkanSdkRoot + CHR$(10) + "MSVC=" + gMsvcLib + CHR$(10) + "WindowsSDK=" + gWindowsSdkLib
END SUB

FUNCTION ReadConfigValue$ (configPath AS STRING, keyName AS STRING)
    DIM fileNumber AS INTEGER
    DIM lineText AS STRING
    DIM currentKey AS STRING
    DIM currentValue AS STRING
    DIM separatorPosition AS LONG

    IF _FILEEXISTS(configPath) = 0 THEN EXIT FUNCTION

    fileNumber = FREEFILE
    OPEN configPath FOR INPUT AS #fileNumber
    DO WHILE EOF(fileNumber) = 0
        LINE INPUT #fileNumber, lineText
        lineText = LTRIM$(RTRIM$(lineText))
        IF LEN(lineText) > 0 THEN
            IF LEFT$(lineText, 1) <> "[" THEN
                separatorPosition = INSTR(1, lineText, "=")
                IF separatorPosition > 1 THEN
                    currentKey = LCASE$(LTRIM$(RTRIM$(LEFT$(lineText, separatorPosition - 1))))
                    IF currentKey = LCASE$(keyName) THEN
                        currentValue = LTRIM$(RTRIM$(MID$(lineText, separatorPosition + 1)))
                        IF LEN(currentValue) >= 2 THEN
                            IF (LEFT$(currentValue, 1) = CHR$(34) AND RIGHT$(currentValue, 1) = CHR$(34)) OR (LEFT$(currentValue, 1) = CHR$(39) AND RIGHT$(currentValue, 1) = CHR$(39)) THEN
                                currentValue = MID$(currentValue, 2, LEN(currentValue) - 2)
                            END IF
                        END IF
                        CLOSE #fileNumber
                        ReadConfigValue$ = currentValue
                        EXIT FUNCTION
                    END IF
                END IF
            END IF
        END IF
    LOOP
    CLOSE #fileNumber
END FUNCTION

FUNCTION ResolveExecutable$ (executableName AS STRING)
    DIM candidate AS STRING

    IF _FILEEXISTS(executableName) <> 0 THEN
        ResolveExecutable$ = NormalizePath$(executableName)
        EXIT FUNCTION
    END IF

    candidate = FindOnPath$(executableName)
    IF LEN(candidate) > 0 THEN ResolveExecutable$ = NormalizePath$(candidate)
END FUNCTION

FUNCTION FindOnPath$ (executableName AS STRING)
    DIM pathList AS STRING
    DIM entry AS STRING
    DIM candidate AS STRING
    DIM startPosition AS LONG
    DIM separatorPosition AS LONG

    pathList = Environ$("PATH")
    startPosition = 1

    DO
        separatorPosition = INSTR(startPosition, pathList, ";")
        IF separatorPosition = 0 THEN
            entry = MID$(pathList, startPosition)
        ELSE
            entry = MID$(pathList, startPosition, separatorPosition - startPosition)
        END IF

        entry = NormalizePath$(entry)
        IF LEN(entry) = 0 THEN entry = NormalizePath$(_CWD$)
        candidate = JoinPath$(entry, executableName)
        IF _FILEEXISTS(candidate) <> 0 THEN
            FindOnPath$ = candidate
            EXIT FUNCTION
        END IF

        IF separatorPosition = 0 THEN EXIT DO
        startPosition = separatorPosition + 1
    LOOP
END FUNCTION

FUNCTION FindPathToken$ (pathList AS STRING, containsText AS STRING, endsWithText AS STRING)
    DIM entry AS STRING
    DIM startPosition AS LONG
    DIM separatorPosition AS LONG
    DIM lowerEntry AS STRING
    DIM lowerContains AS STRING
    DIM lowerSuffix AS STRING

    lowerContains = LCASE$(containsText)
    lowerSuffix = LCASE$(endsWithText)
    startPosition = 1

    DO
        separatorPosition = INSTR(startPosition, pathList, ";")
        IF separatorPosition = 0 THEN
            entry = MID$(pathList, startPosition)
        ELSE
            entry = MID$(pathList, startPosition, separatorPosition - startPosition)
        END IF

        entry = NormalizePath$(entry)
        lowerEntry = LCASE$(entry)
        IF INSTR(1, lowerEntry, lowerContains) > 0 THEN
            IF LEN(lowerEntry) >= LEN(lowerSuffix) THEN
                IF RIGHT$(lowerEntry, LEN(lowerSuffix)) = lowerSuffix THEN
                    FindPathToken$ = entry
                    EXIT FUNCTION
                END IF
            END IF
        END IF

        IF separatorPosition = 0 THEN EXIT DO
        startPosition = separatorPosition + 1
    LOOP
END FUNCTION

FUNCTION ResolveClangResourceRoot$ (compilerPath AS STRING)
    DIM temporaryPath AS STRING
    DIM resourceRoot AS STRING
    DIM fileNumber AS INTEGER

    temporaryPath = JoinPath$(_DIR$("temp"), "nd4-clang-resource.txt")
    IF _FILEEXISTS(temporaryPath) <> 0 THEN KILL temporaryPath

    SHELL _HIDE Quote$(compilerPath) + " -print-resource-dir > " + Quote$(temporaryPath)

    IF _FILEEXISTS(temporaryPath) = 0 THEN EXIT FUNCTION

    fileNumber = FREEFILE
    OPEN temporaryPath FOR INPUT AS #fileNumber
    IF EOF(fileNumber) = 0 THEN LINE INPUT #fileNumber, resourceRoot
    CLOSE #fileNumber
    KILL temporaryPath

    ResolveClangResourceRoot$ = NormalizePath$(LTRIM$(RTRIM$(resourceRoot)))
END FUNCTION

FUNCTION FirstEnvironmentValue$ (firstName AS STRING, secondName AS STRING)
    DIM value AS STRING

    value = Environ$(firstName)
    IF LEN(value) = 0 THEN value = Environ$(secondName)
    FirstEnvironmentValue$ = value
END FUNCTION

FUNCTION NormalizeTarget$ (value AS STRING)
    DIM lowerValue AS STRING

    lowerValue = LCASE$(value)
    SELECT CASE lowerValue
        CASE "debug"
            NormalizeTarget$ = "N4Editor_Debug"
        CASE "release"
            NormalizeTarget$ = "N4Editor_Release"
        CASE "relwithdebinfo"
            NormalizeTarget$ = "N4Editor_RelWithDebInfo"
        CASE "all"
            NormalizeTarget$ = "all"
        CASE "n4editor_debug"
            NormalizeTarget$ = "N4Editor_Debug"
        CASE "n4editor_release"
            NormalizeTarget$ = "N4Editor_Release"
        CASE "n4editor_relwithdebinfo"
            NormalizeTarget$ = "N4Editor_RelWithDebInfo"
        CASE ELSE
            NormalizeTarget$ = ""
    END SELECT
END FUNCTION

FUNCTION NormalizePath$ (value AS STRING)
    DIM result AS STRING

    result = LTRIM$(RTRIM$(value))
    IF LEN(result) >= 2 THEN
        IF LEFT$(result, 1) = CHR$(34) AND RIGHT$(result, 1) = CHR$(34) THEN
            result = MID$(result, 2, LEN(result) - 2)
        END IF
    END IF

    DO WHILE LEN(result) > 3 AND (RIGHT$(result, 1) = "\" OR RIGHT$(result, 1) = "/")
        result = LEFT$(result, LEN(result) - 1)
    LOOP

    NormalizePath$ = result
END FUNCTION

FUNCTION JoinPath$ (basePath AS STRING, child AS STRING)
    DIM normalizedBase AS STRING
    DIM normalizedChild AS STRING

    normalizedBase = NormalizePath$(basePath)
    normalizedChild = child
    IF LEN(normalizedBase) = 0 THEN
        JoinPath$ = normalizedChild
    ELSEIF LEN(normalizedChild) = 0 THEN
        JoinPath$ = normalizedBase
    ELSEIF RIGHT$(normalizedBase, 1) = "\" OR RIGHT$(normalizedBase, 1) = "/" THEN
        JoinPath$ = normalizedBase + normalizedChild
    ELSE
        JoinPath$ = normalizedBase + "\" + normalizedChild
    END IF
END FUNCTION

FUNCTION ParentPath$ (value AS STRING)
    DIM normalizedValue AS STRING
    DIM index AS LONG
    DIM separatorIndex AS LONG
    DIM character AS STRING

    normalizedValue = NormalizePath$(value)
    IF LEN(normalizedValue) <= 3 THEN
        ParentPath$ = normalizedValue
        EXIT FUNCTION
    END IF

    separatorIndex = 0
    FOR index = LEN(normalizedValue) TO 1 STEP -1
        character = MID$(normalizedValue, index, 1)
        IF character = "\" OR character = "/" THEN
            separatorIndex = index
            EXIT FOR
        END IF
    NEXT index

    IF separatorIndex <= 3 THEN
        ParentPath$ = LEFT$(normalizedValue, 3)
    ELSE
        ParentPath$ = LEFT$(normalizedValue, separatorIndex - 1)
    END IF
END FUNCTION

FUNCTION Quote$ (value AS STRING)
    Quote$ = CHR$(34) + value + CHR$(34)
END FUNCTION

SUB Abort (message AS STRING, code AS LONG)
    gLastError = message
    gLastErrorCode = code
    gUiExitCode = code
END SUB
