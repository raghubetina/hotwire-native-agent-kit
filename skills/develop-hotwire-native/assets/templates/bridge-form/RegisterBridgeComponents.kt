package com.example.app.bridge

import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.navigation.config.registerBridgeComponents

fun registerBridgeComponents() {
    Hotwire.registerBridgeComponents(
        BridgeComponentFactory("form", ::FormComponent)
    )
}
