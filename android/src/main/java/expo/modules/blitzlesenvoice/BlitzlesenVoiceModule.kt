package expo.modules.blitzlesenvoice



import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class BlitzlesenVoiceModule : Module() {
  override fun definition() = ModuleDefinition {

    Name("BlitzlesenVoice")

      AsyncFunction("requestPermissions") { promise: Promise ->
        println("request permissions !!!")
          promise.resolve(true)
//          if Voice.hasPermissions == true {
//              promise.resolve(true)
//          } else {
//              Voice.getPermissions { hasPermissions in
//                      promise.resolve(hasPermissions)
//              }
//          }
      }

      Function("isListening") { -> true

      }

      Function("stopListening") { ->

      }

    AsyncFunction("listenFor") {
//      locale: String,
//      target: List<List<String>>,
//      timeout: Number,
//      onDeviceRecognition: Boolean,
//      mistakeConfig: Map<String, Number>,
//      firstItemDurationOffset: Number,
//      volumeThreshold: Number,
      promise: Promise ->
        println("start listening")
//      // Send an event to JavaScript.
//      sendEvent("onChange", mapOf(
//        "value" to value
//      ))

      promise.resolve( )
    }


  }
}
