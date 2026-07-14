// Adapted from Bridge Components by Joseph Masilotti.
// Copyright (c) 2025 Joseph Masilotti. MIT licensed; see LICENSES.md.
import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "form"
  static targets = ["submit"]

  connect() {
    super.connect()
    this.#connectNativeButton()
  }

  disconnect() {
    this.send("disconnect")
    super.disconnect()
  }

  submitStart() {
    this.submitTarget.disabled = true
    this.send("submitDisabled")
  }

  submitEnd() {
    this.submitTarget.disabled = false
    this.send("submitEnabled")
  }

  #connectNativeButton() {
    const submit = new BridgeElement(this.submitTarget)

    this.send("connect", { submitTitle: submit.title }, () => {
      this.submitTarget.click()
    })
  }
}
