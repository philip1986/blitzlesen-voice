import ExpoModulesCore
import Speech

struct ListenForResponse: Record {
  @Field
  var isCorrect: Bool?
  @Field
  var recognisedText: String?
}

struct ListenForError: Record {
  @Field
  var error: String?
}

public class BlitzlesenVoiceModule: Module {
  private var voice: Voice?

  public func definition() -> ModuleDefinition {
    Name("BlitzlesenVoice")

    Events("onVolumeChange")

    AsyncFunction("listenFor") { (locale: String, target: String, alternatives: [String], timeout: Int, onDeviceRecognition: Bool, promise: Promise) in
      voice = Voice(locale: locale, sendEvent: sendEvent)
        
      try voice?.startRecording(target: target, alternatives: alternatives, timeout: timeout, onDeviceRecognition: onDeviceRecognition) { error, isCorrect, recognisedText in
        promise.resolve([
          ListenForError(error: Field(wrappedValue: error?.localizedDescription)),
          ListenForResponse(isCorrect: Field(wrappedValue: isCorrect), recognisedText: Field(wrappedValue: recognisedText)),
        ])
      }
    }

    Function("isListening") { () in
      voice?.isListening()
    }

    Function("stopListening") { () in
      voice?.stopRecording()
    }

    AsyncFunction("requestPermissions") { (promise: Promise) in
      if Voice.hasPermissions == true {
        promise.resolve(true)
      } else {
        Voice.getPermissions { hasPermissions in
          promise.resolve(hasPermissions)
        }
      }
    }
  }
}

public class Voice {
  static var hasPermissions = false
  private var recognitionTask: SFSpeechRecognitionTask?
  private var timeout: Timer?
  private var speechRecognizer: SFSpeechRecognizer?
  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var inputNode: AVAudioInputNode!
  private var sendEvent: (String, [String: Any]) -> Void = { _, _ in }

  init(locale: String, sendEvent: @escaping (String, [String: Any]) -> Void) {
    if Voice.hasPermissions == false { Voice.getPermissions { _ in } }
    self.sendEvent = sendEvent

    print("init voice \(locale)")
    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
  }

  func isListening() -> Bool {
    return recognitionTask != nil
  }

  static func getPermissions(completion: @escaping (Bool) -> Void) {
    SFSpeechRecognizer.requestAuthorization { authStatus in
      OperationQueue.main.addOperation {
        switch authStatus {
        case .authorized:
          Voice.hasPermissions = true
          completion(true)
        default:
          Voice.hasPermissions = false
          completion(false)
        }
      }
    }
  }

  func getVolumeLevel(buffer: AVAudioPCMBuffer) {
    let arraySize = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)

    var magnitude: Float = 0.0
    for i in 0 ..< channelCount {
      let firstSample = buffer.format.isInterleaved ? i : i * arraySize

      for j in stride(from: firstSample, to: arraySize, by: buffer.stride * 2) {
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
        let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))

        magnitude += sqrt(pow(floats[j], 2) + pow(floats[j + buffer.stride], 2))
      }
    }

    let volume = round(1000 * Float(magnitude) / Float(arraySize))

    self.sendEvent("onVolumeChange", [
      "volume": volume,
    ])
  }

  func startRecording(target: String, alternatives: [String], timeout: Int, onDeviceRecognition: Bool, completion: @escaping (Error?, Bool?, String?) -> Void) throws {
    print("start recording ...")
    if recognitionTask != nil { stopRecording() }

    var isComplete = false

    if Voice.hasPermissions == false {
      return completion(NSError(domain: "No permissions", code: 0, userInfo: nil), nil, nil)
    }

    if speechRecognizer?.isAvailable != true {
      return completion(NSError(domain: "Speech recognion is not supported!", code: 0, userInfo: nil), nil, nil)
    }

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    inputNode = audioEngine.inputNode
    inputNode?.removeTap(onBus: 0)

    let recordingFormat = inputNode?.outputFormat(forBus: 0)
    inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
      self.getVolumeLevel(buffer: buffer)
      self.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
    recognitionRequest.shouldReportPartialResults = true

    recognitionRequest.taskHint = SFSpeechRecognitionTaskHint.dictation

    recognitionRequest.requiresOnDeviceRecognition = onDeviceRecognition == true && speechRecognizer?.supportsOnDeviceRecognition == true

    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
      if error != nil {
        if error!._code != 1110 {
          self.stopRecording()
          print("error \(error!.localizedDescription)")
          if !isComplete {
            isComplete = true
            completion(error, nil, nil)
          }
        }
        return
      }

      self.timeout?.invalidate()
      if let transcription = result?.bestTranscription {
        self.timeout = Timer.scheduledTimer(withTimeInterval: Double(timeout) / 1000, repeats: false) { _ in
          print("stop")
          self.timeout?.invalidate()
          self.stopRecording()

          if !isComplete {
            isComplete = true
            completion(nil, false, transcription.formattedString)
          }
        }

        print("\(transcription.formattedString)")
        if self.isTarget(text: transcription.formattedString, target: target, alternatives: alternatives) {
          self.timeout?.invalidate()
          self.stopRecording()

          if !isComplete {
            isComplete = true
            completion(nil, true, transcription.formattedString)
          }
        }
      }
    }
  }

  func isTarget(text: String, target: String, alternatives: [String]) -> Bool {
    let targets = [target] + alternatives
    return targets.contains(where: { text.lowercased().contains($0.lowercased()) })
  }

  func stopRecording() {
    recognitionTask?.finish()

    audioEngine.stop()
    inputNode?.removeTap(onBus: 0)
    Thread.sleep(forTimeInterval: 0.1)

    recognitionRequest?.endAudio()
    recognitionRequest = nil
    recognitionTask = nil
  }
}
