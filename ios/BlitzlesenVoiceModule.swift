import ExpoModulesCore
import Foundation
import Speech

struct ListenForResponse: Record {
  @Field
  var isCorrect: Bool?
  @Field
  var recognisedText: String?
  @Field
  var words: [[String: Any]]?
}

struct ListenForError: Record {
  @Field
  var error: String?
}

extension Optional {
    func `let`(_ do: (Wrapped)->()) {
        guard let v = self else { return }
        `do`(v)
    }
}

public class BlitzlesenVoiceModule: Module {
  private var voice: Voice?

  public func definition() -> ModuleDefinition {
    Name("BlitzlesenVoice")

    Events("onVolumeChange")
    Events("onPartialResult")
    Events("onMistake")
    Events("onDebug")

    AsyncFunction("listenFor") {
      (
        locale: String, target: [[String]], timeout: Int,
        onDeviceRecognition: Bool, mistakeConfig: [String: Int], promise: Promise
      ) in
        
        print(target)

      voice?.stopRecording()
      voice = Voice(locale: locale, sendEvent: sendEvent)

      try voice?.startRecording(
        target: target, timeout: timeout,
        onDeviceRecognition: onDeviceRecognition, mistakeConfig: mistakeConfig
      ) { error, isCorrect, recognisedText, words in
        promise.resolve([
          ListenForError(error: Field(wrappedValue: error?.localizedDescription)),
          ListenForResponse(
            isCorrect: Field(wrappedValue: isCorrect),
            recognisedText: Field(wrappedValue: recognisedText),
            words: Field(wrappedValue: words)),
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

    OnDestroy {
      voice?.stopRecording()
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

  func startRecording(
    target: [[String]], timeout: Int, onDeviceRecognition: Bool,
    mistakeConfig: [String: Int],
    completion: @escaping (Error?, Bool?, String?, [[String: Any]]?) -> Void
  ) throws {
    print("start recording ...")
    if recognitionTask != nil { stopRecording() }

    var isComplete = false
    var start: CFTimeInterval?
    var res: [[String: Any]] = target.map {
        ["word": $0.first!, "duration": 0, "isCorrect": false, "mistake": false]
    }
    var part = StringAccumulator()
    var mistakeCount = 0
    var mistakeTimeout: Timer?

    if Voice.hasPermissions == false {
      return completion(NSError(domain: "No permissions", code: 0, userInfo: nil), nil, nil, nil)
    }

    if speechRecognizer?.isAvailable != true {
      return completion(
        NSError(domain: "Speech recognion is not supported!", code: 0, userInfo: nil), nil, nil, nil
      )
    }

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    inputNode = audioEngine.inputNode
    inputNode?.removeTap(onBus: 0)

    let recordingFormat = inputNode?.outputFormat(forBus: 0)
    inputNode?.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) {
      (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
      DispatchQueue.global(qos: .background).async {
        let volume = Utils.getVolumeLevel(buffer: buffer)
        if start == nil && volume > 1 {
            start = CACurrentMediaTime()
        
        }
        self.sendEvent("onVolumeChange", ["volume": volume])
      }
      self.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else {
      fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
    }
    recognitionRequest.shouldReportPartialResults = true

    recognitionRequest.taskHint = SFSpeechRecognitionTaskHint.dictation

    recognitionRequest.requiresOnDeviceRecognition =
      onDeviceRecognition == true && speechRecognizer?.supportsOnDeviceRecognition == true

    speechRecognizer?.queue.qualityOfService = .userInteractive

    print("start recognition")
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
      if isComplete { return }
      if error != nil {
        if error!._code != 1110 {
          self.stopRecording()
          print("error \(error!.localizedDescription)")
          if !isComplete {
            isComplete = true
            completion(error, nil, nil, nil)
          }
        }
        return
      }

      mistakeTimeout?.invalidate()
      self.timeout?.invalidate()
      if let transcription = result?.bestTranscription {
        self.sendEvent("onDebug", ["recognisedText": transcription.formattedString])
        self.timeout = Timer.scheduledTimer(
          withTimeInterval: Double(timeout) / 1000, repeats: false
        ) { _ in
          print("stop")
          self.timeout?.invalidate()
          self.stopRecording()

          if !isComplete {
            isComplete = true
            completion(nil, false, transcription.formattedString, res)
          }
        }

        part.add(result?.bestTranscription.formattedString ?? "")

        var wordsAdded = 0
        Utils.commonWords(in: target, containedIn: part.getAccumulatedString())
          .split(separator: " ").map { String($0) }
          .enumerated().forEach { (i, el) in
            if (res[i]["isCorrect"] as? Bool) == false {
              let now = CACurrentMediaTime()
              res[i]["isCorrect"] = true
              res[i]["duration"] = Int((now - (start ?? now - 99)) * 1000)
              start = now
              wordsAdded += 1
            }
          }

        if wordsAdded > 0 {
          self.sendEvent("onPartialResult", ["partialResult": res])
          mistakeCount = 0
        } else {
          mistakeCount += 1
        }

        if self.isTarget(
          text: part.getAccumulatedString(), target: target)
        {
          self.timeout?.invalidate()
          self.stopRecording()

          if !isComplete {
            isComplete = true
            completion(nil, true, transcription.formattedString, res)
          }
        } else {
          if mistakeCount >= mistakeConfig["mistakeLimit"]! {
            mistakeCount = 0
              res.firstIndex(where: { $0["isCorrect"] as! Bool == false }).let { i in
                res[i]["mistake"] = true
                  self.sendEvent("onMistake", ["word": res[i]["word"] as! String, "reason": "tooManyMistakes"])
              }
              
            
          } else {

            if mistakeConfig["timeLimit"] ?? 0 > 0 && mistakeTimeout?.isValid != true {
              mistakeTimeout = Timer.scheduledTimer(
                withTimeInterval: Double(mistakeConfig["timeLimit"] ?? 1000) / 1000, repeats: false
              ) { _ in
                let word =
                  res.first(where: { $0["isCorrect"] as! Bool == false })?["word"] as! String
                self.sendEvent("onMistake", ["word": word, "reason": "timeout"])
                mistakeCount = 0
              }
            }
          }
        }
      }
    }
    self.sendEvent("onPartialResult", ["partialResult": res])
  }

  func isTarget(text: String, target: [[String]]) -> Bool {
      return Utils.commonWords(in: target, containedIn: text) == target.map { $0.first?.lowercased() ?? "" }.joined(separator: " ")
  }

  func stopRecording() {
    print("stop recording ...")
    recognitionTask?.finish()

    audioEngine.stop()
    inputNode?.removeTap(onBus: 0)
    Thread.sleep(forTimeInterval: 0.1)

    recognitionRequest?.endAudio()
    recognitionRequest = nil
    recognitionTask = nil
  }
}

class Utils {
    public static func commonWords(in string1: [[String]], containedIn string2: String) -> String {
    let words1 = string1.map { $0.map { $0.lowercased()} }
    let words2 = string2.lowercased().split(separator: " ")

    var commonWords: [String] = []
    var currentWords: [String] = []
    var iterator2 = words2.makeIterator()

    for word1 in words1 {
      while let word2 = iterator2.next() {
          if word1.contains(where: { word2.contains($0)}) {
              currentWords.append(word1.first ?? "")
          break
        } else if !currentWords.isEmpty {
          commonWords.append(currentWords.joined(separator: " "))
          currentWords = []
        }
      }
    }

    if !currentWords.isEmpty {
      commonWords.append(currentWords.joined(separator: " "))
    }

    return commonWords.joined(separator: " ")
  }

  public static func getVolumeLevel(buffer: AVAudioPCMBuffer) -> Float {
    let arraySize = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)

    var magnitude: Float = 0.0
    for i in 0..<channelCount {
      let firstSample = buffer.format.isInterleaved ? i : i * arraySize

      for j in stride(from: firstSample, to: arraySize, by: buffer.stride * 2) {
        let channels = UnsafeBufferPointer(
          start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
        let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))

        magnitude += sqrt(pow(floats[j], 2) + pow(floats[j + buffer.stride], 2))
      }
    }

    return round(1000 * Float(magnitude) / Float(arraySize))
  }
}

class StringAccumulator {
  private var accumulatedString: String = ""

  func add(_ newPart: String?) {
    guard let validNewPart = newPart, !validNewPart.isEmpty else {
      return
    }

    if accumulatedString.isEmpty {
      accumulatedString = validNewPart
      return
    }

    let accumulatedParts = accumulatedString.split(separator: " ")
    let newParts = validNewPart.split(separator: " ")

    // Identify common overlapping words and establish the point of difference
    var commonPrefixCount = 0
    for (accumulated, new) in zip(accumulatedParts, newParts) {
      if accumulated == new {
        commonPrefixCount += 1
      } else {
        break
      }
    }

    // Add the non-overlapping new part
    let newSuffix = newParts.dropFirst(commonPrefixCount).joined(separator: " ")
    accumulatedString += " " + newSuffix
    accumulatedString = accumulatedString.replacingOccurrences(of: "  ", with: " ")
  }

  func getAccumulatedString() -> String {
    return accumulatedString
  }

  private func cleanUpSpaces(in string: String) -> String {
    return string.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
  }
}
