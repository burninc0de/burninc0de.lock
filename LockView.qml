import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

Item {
  id: root
  focus: !passwordMode && inputEnabled

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  property string coreTemperature: "--°C"
  property string memoryUsage: "--%"
  property string systemUptime: "--:--"
  property string loadAverage: "--.--"
  property string userName: ""
  property string greeting: "hello"
  property var telemetryNow: new Date()
  // Each lock begins as a calm welcome screen. Any pointer or keyboard input
  // folds the circular interface into the password field.
  property bool passwordMode: false
  // Layout starts at zero-sized while the lock surface is being mapped. Keep
  // that setup invisible to the animation system so the full circle appears
  // immediately, then animate only user-triggered transitions.
  property bool geometryAnimationsReady: false

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property string clockText: Qt.formatTime(telemetryNow, "HH:mm:ss")
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    if (passwordMode && inputEnabled) passwordInput.forceActiveFocus()
  }

  function activatePasswordEntry(firstCharacter) {
    if (!passwordMode) passwordMode = true
    wakeRequested()
    Qt.callLater(function() {
      forcePasswordFocus()
      // Keep the first printable key: waking the lock should not cost a
      // keystroke when someone starts typing immediately.
      if (firstCharacter && firstCharacter.length > 0 && passwordInput.text.length === 0) {
        passwordInput.insert(0, firstCharacter)
      }
    })
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onWidthChanged: {
    if (width > 0 && height > 0 && !geometryAnimationsReady) geometryReadyTimer.restart()
  }
  onHeightChanged: {
    if (width > 0 && height > 0 && !geometryAnimationsReady) geometryReadyTimer.restart()
  }
  onInputEnabledChanged: {
    if (!inputEnabled) passwordMode = false
    else if (passwordMode) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled && passwordMode) Qt.callLater(forcePasswordFocus)
  }

  Timer {
    id: geometryReadyTimer
    interval: 120
    onTriggered: root.geometryAnimationsReady = true
  }

  Keys.onPressed: function(event) {
    if (!root.passwordMode && root.inputEnabled) {
      root.activatePasswordEntry(event.text)
      event.accepted = true
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.telemetryNow = new Date()
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.activatePasswordEntry("")
      onPositionChanged: root.wakeRequested()
    }

    BorderSurface {
      id: interfaceCore
      width: root.passwordMode ? root.fieldWidth : Math.min(352, Math.min(root.width * 0.42, root.height * 0.52))
      height: root.passwordMode ? root.fieldHeight : width
      anchors.centerIn: parent
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: root.passwordMode ? Style.cornerRadius : width / 2
      clip: true

      Behavior on width {
        enabled: root.geometryAnimationsReady
        NumberAnimation { duration: 620; easing.type: Easing.OutCubic }
      }
      Behavior on height {
        enabled: root.geometryAnimationsReady
        NumberAnimation { duration: 620; easing.type: Easing.OutCubic }
      }
      Behavior on radius {
        enabled: root.geometryAnimationsReady
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
      }

      // Concentric signal rings and ticks give the idle state a subtle,
      // sci-fi instrument-panel feeling without needing image assets.
      Repeater {
        model: 12
        Rectangle {
          required property int index
          width: 2
          height: index % 3 === 0 ? 19 : 10
          x: interfaceCore.width / 2 - width / 2
          y: interfaceCore.height / 2 - interfaceCore.width / 2 + 13
          radius: width / 2
          color: Color.lock.borderActive
          opacity: root.passwordMode ? 0 : (index % 3 === 0 ? 0.92 : 0.48)
          transform: Rotation {
            origin.x: width / 2
            origin.y: interfaceCore.height / 2 - y
            angle: index * 30
          }
          Behavior on opacity { NumberAnimation { duration: 180 } }
        }
      }

      Rectangle {
        width: Math.max(1, parent.width - 34)
        height: width
        anchors.centerIn: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Color.lock.borderActive
        opacity: root.passwordMode ? 0 : 0.44
        Behavior on opacity { NumberAnimation { duration: 180 } }
      }

      // A tiny braille "loader" grid pulses above the greeting. Each cell
      // does a slow random walk through its braille dots, so the block
      // shimmers like live noise instead of cycling on a fixed loop.
      Item {
        id: brailleLoader
        width: brailleLoader.cols * brailleLoader.cellSize + (brailleLoader.cols - 1) * 3
        height: brailleLoader.rows * brailleLoader.cellSize + (brailleLoader.rows - 1) * 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: welcomeText.top
        anchors.bottomMargin: 26
        opacity: root.passwordMode ? 0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 180 } }

        property int cols: 4
        property int rows: 1
        property int cellSize: 22
        readonly property int cellCount: cols * rows
        property var cellDots: []

        function brailleChar(mask) {
          if (isNaN(mask)) return ""
          return String.fromCodePoint(0x2800 + mask)
        }

        function tick() {
          var next = []
          for (var i = 0; i < cellDots.length; i++) {
            // Randomly toggle one dot or leave the cell alone, so the
            // pattern drifts organically instead of jumping shapes.
            if (Math.random() < 0.6) {
              var bit = 1 << Math.floor(Math.random() * 6)
              next.push((cellDots[i] & bit) ? (cellDots[i] & ~bit) : (cellDots[i] | bit))
            } else {
              next.push(cellDots[i])
            }
          }
          cellDots = next
        }

        Component.onCompleted: {
          for (var i = 0; i < cellCount; i++) cellDots.push(Math.floor(Math.random() * 64))
        }

        Timer {
          id: tickTimer
          interval: 160
          repeat: true
          running: !root.passwordMode
          onTriggered: {
            brailleLoader.tick()
            tickTimer.interval = 140 + Math.floor(Math.random() * 80)
          }
        }

        Grid {
          anchors.centerIn: parent
          columns: brailleLoader.cols
          spacing: 3
          Repeater {
            model: brailleLoader.rows * brailleLoader.cols
            Text {
              required property int index
              text: brailleLoader.brailleChar(brailleLoader.cellDots[index])
              color: Color.lock.borderActive
              font.family: Style.font.family
              font.pixelSize: brailleLoader.cellSize
              lineHeightMode: Text.FixedHeight
              lineHeight: brailleLoader.cellSize
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }

      Text {
        id: welcomeText
        anchors.centerIn: parent
        text: root.userName.length > 0 ? (root.greeting + " " + root.userName) : root.greeting
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.08)
        font.letterSpacing: 2
        opacity: root.passwordMode ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 180 } }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: 33
        text: "SYSTEM READY  //  TOUCH TO UNLOCK"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.max(10, Math.round(root.fieldFontSize * 0.42))
        font.letterSpacing: 1.5
        opacity: root.passwordMode ? 0 : 0.72
        Behavior on opacity { NumberAnimation { duration: 180 } }
      }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: interfaceCore.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: interfaceCore.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: interfaceCore.borderBottom
        anchors.leftMargin: interfaceCore.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        focus: root.passwordMode && root.inputEnabled
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && root.passwordMode && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        opacity: root.passwordMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        opacity: root.passwordMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: interfaceCore.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured && root.passwordMode
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    // A compact HUD readout keeps the welcome screen feeling alive while the
    // password transition stays clean and focused.
    Row {
      anchors.top: interfaceCore.bottom
      anchors.topMargin: 28
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 18
      opacity: root.passwordMode ? 0 : 0.9
      Behavior on opacity { NumberAnimation { duration: 180 } }

      Repeater {
        model: [
          { label: "TIME", value: root.clockText },
          { label: "CORE", value: root.coreTemperature },
          { label: "MEM", value: root.memoryUsage },
          { label: "UP", value: root.systemUptime },
          { label: "LOAD", value: root.loadAverage }
        ]

        Column {
          width: 64
          spacing: 3
          Text {
            text: modelData.label
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: Math.max(9, Math.round(root.fieldFontSize * 0.38))
            font.letterSpacing: 1.4
          }
          Text {
            text: modelData.value
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: Math.max(12, Math.round(root.fieldFontSize * 0.62))
            font.letterSpacing: 0.7
          }
        }
      }
    }
  }
}
