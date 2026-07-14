// Adapted from the Hotwire Native Android demo.
// Copyright (c) 2024 37signals LLC. MIT licensed; see LICENSES.md.
package com.example.app.bridge

import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import androidx.appcompat.widget.Toolbar
import androidx.fragment.app.Fragment
import com.example.app.R
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeComponentFragmentLifecycle
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

class FormComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate), BridgeComponentFragmentLifecycle {

    private val submitItemId = View.generateViewId()
    private var submitItem: MenuItem? = null
    private val fragment: Fragment
        get() = delegate.destination.fragment
    private val toolbar: Toolbar?
        get() = fragment.view?.findViewById(R.id.toolbar)

    override fun onReceive(message: Message) {
        when (message.event) {
            "connect" -> connect(message)
            "submitEnabled" -> submitItem?.isEnabled = true
            "submitDisabled" -> submitItem?.isEnabled = false
            "disconnect" -> removeOwnedButton()
            else -> Log.w("FormComponent", "Unknown event: ${message.event}")
        }
    }

    override fun onViewCreated() = Unit

    override fun onDestroyView() {
        removeOwnedButton()
    }

    private fun connect(message: Message) {
        val data = message.data<MessageData>() ?: return
        val menu = toolbar?.menu ?: return

        removeOwnedButton()
        submitItem = menu.add(Menu.NONE, submitItemId, 999, data.submitTitle).apply {
            setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
            setOnMenuItemClickListener { replyTo("connect") }
        }
    }

    private fun removeOwnedButton() {
        toolbar?.menu?.removeItem(submitItemId)
        submitItem = null
    }

    @Serializable
    data class MessageData(val submitTitle: String)
}
