import { Controller } from "@hotwired/stimulus"
import consumer from "./cable.Consumer"

export default class extends Controller {
  connect() {
    this.subscription = consumer.subscriptions.create("DashboardChannel", {
      received: (data) => this.handleMessage(data)
    })
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  handleMessage(data) {
    switch (data.event) {
      case "order_placed":
        this.showToast(`Order placed: ${data.side} ${data.pair}`)
        break
      case "order_filled":
        this.showToast(`Order filled: ${data.side} ${data.pair}`)
        this.refreshPage()
        break
      case "risk_violation":
        this.showToast(`Risk alert: ${data.message}`, "error")
        break
      case "signal_generated":
        this.showToast(`${data.signal_type} signal on ${data.pair}`)
        break
    }
  }

  showToast(message, type = "info") {
    const toast = document.createElement("div")
    toast.className = `fixed bottom-4 right-4 px-4 py-2 rounded-lg shadow-lg ${
      type === "error" ? "bg-red-500 text-white" : "bg-indigo-600 text-white"
    }`
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 3000)
  }

  refreshPage() {
    if (document.querySelector("[data-turbo-refresh]")) {
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }
}