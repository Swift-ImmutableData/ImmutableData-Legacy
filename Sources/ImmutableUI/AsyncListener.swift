//
//  Copyright 2024 Rick van Voorden and Bill Fisher
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Combine
import Foundation
import ImmutableData
import Observation

extension UserDefaults {
  fileprivate var isDebug: Bool {
    self.bool(forKey: "com.northbronson.ImmutableUI.Debug")
  }
}

@MainActor final fileprivate class Storage<Output>: ObservableObject {
  @Published var output: Output?
}

@MainActor final class AsyncListener<State, Action, Dependency, Output> where State : Sendable, Action : Sendable, Dependency : Sendable, Output : Sendable {
  private let label: String?
  private let filter: (@Sendable (State, Action) -> Bool)?
  private let dependencySelector: DependencySelector<State, Dependency>?
  private let outputSelector: OutputSelector<State, Output>
  
  private var oldDependency: Dependency?
  private var oldOutput: Output?
  private let storage = Storage<Output>()
  
  init(
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    dependencySelector: DependencySelector<State, Dependency>?,
    outputSelector: OutputSelector<State, Output>
  ) {
    self.label = label
    self.filter = isIncluded
    self.dependencySelector = dependencySelector
    self.outputSelector = outputSelector
  }
}

extension AsyncListener {
  var output: Output {
    guard let output = self.storage.output else { fatalError("missing output") }
    return output
  }
}

extension AsyncListener {
  var publisher: ObservableObjectPublisher {
    self.storage.objectWillChange
  }
}

extension AsyncListener {
  func update(with store: some ImmutableData.Selector<State>) {
#if DEBUG
    if let label = self.label,
       UserDefaults.standard.isDebug {
      print("[ImmutableUI][AsyncListener]: \(address(of: self)) Update: \(label)")
    }
#endif
    if self.hasDependency {
      if self.updateDependency(with: store) {
        self.updateOutput(with: store)
      }
    } else {
      self.updateOutput(with: store)
    }
  }
}

extension AsyncListener {
  func listen<S>(
    to stream: S,
    with store: some ImmutableData.Selector<State>
  ) async throws where S : AsyncSequence, S : Sendable, S.Element == (oldState: State, action: Action) {
    if let filter = self.filter {
      for try await _ in stream.filter(filter) {
        self.update(with: store)
      }
    } else {
      for try await _ in stream {
        self.update(with: store)
      }
    }
  }
}

extension AsyncListener {
  private var hasDependency: Bool {
    self.dependencySelector != nil
  }
}

extension AsyncListener {
  private func updateDependency(with store: some ImmutableData.Selector<State>) -> Bool {
#if DEBUG
    if let label = self.label,
       UserDefaults.standard.isDebug {
      print("[ImmutableUI][AsyncListener]: \(address(of: self)) Update Dependency: \(label)")
    }
#endif
    guard let dependencySelector = self.dependencySelector else { fatalError("missing dependency selector") }
    let dependency = store.select(dependencySelector.select)
    if let oldDependency = self.oldDependency {
      self.oldDependency = dependency
      return dependencySelector.didChange(
        oldDependency,
        dependency
      )
    } else {
      self.oldDependency = dependency
      return true
    }
  }
}

extension AsyncListener {
  private func updateOutput(with store: some ImmutableData.Selector<State>) {
#if DEBUG
    if let label = self.label,
       UserDefaults.standard.isDebug {
      print("[ImmutableUI][AsyncListener]: \(address(of: self)) Update Output: \(label)")
    }
#endif
    let output = store.select(self.outputSelector.select)
    if let oldOutput = self.oldOutput {
      self.oldOutput = output
      if self.outputSelector.didChange(oldOutput, output) {
        self.storage.output = output
      }
    } else {
      self.oldOutput = output
      self.storage.output = output
    }
  }
}

fileprivate func address(of x: AnyObject) -> String {
  //  https://github.com/apple/swift/blob/swift-5.10.1-RELEASE/stdlib/public/core/Runtime.swift#L516-L528
  //  https://github.com/apple/swift/blob/swift-5.10.1-RELEASE/test/Concurrency/voucher_propagation.swift#L78-L81
  
  var result = String(
    unsafeBitCast(x, to: UInt.self),
    radix: 16
  )
  for _ in 0..<(2 * MemoryLayout<UnsafeRawPointer>.size - result.utf16.count) {
    result = "0" + result
  }
  return "0x" + result
}
