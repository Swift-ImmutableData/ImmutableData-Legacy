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
import ImmutableData

@MainActor final package class Listener<State, Action, Dependency, Output> where State : Sendable, Action : Sendable, Dependency : Sendable, Output : Sendable {
  private var id: AnyHashable?
  private var label: String?
  private var filter: (@Sendable (State, Action) -> Bool)?
  private var dependencySelector: DependencySelector<State, Dependency>?
  private var outputSelector: OutputSelector<State, Output>
  
  private weak var store: AnyObject?
  private var listener: AsyncListener<State, Action, Dependency, Output>?
  private var task: Task<Void, any Error>?
  
  package init(
    id: some Hashable,
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    dependencySelector: DependencySelector<State, Dependency>?,
    outputSelector: OutputSelector<State, Output>
  ) {
    self.id = AnyHashable(id)
    self.label = label
    self.filter = isIncluded
    self.dependencySelector = dependencySelector
    self.outputSelector = outputSelector
  }
  
  package init(
    id: some Hashable,
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    outputSelector: OutputSelector<State, Output>
  ) where Dependency == Never {
    self.id = AnyHashable(id)
    self.label = label
    self.filter = isIncluded
    self.dependencySelector = nil
    self.outputSelector = outputSelector
  }
  
  package init(
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    dependencySelector: DependencySelector<State, Dependency>?,
    outputSelector: OutputSelector<State, Output>
  ) {
    self.id = nil
    self.label = label
    self.filter = isIncluded
    self.dependencySelector = dependencySelector
    self.outputSelector = outputSelector
  }
  
  package init(
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    outputSelector: OutputSelector<State, Output>
  ) where Dependency == Never {
    self.id = nil
    self.label = label
    self.filter = isIncluded
    self.dependencySelector = nil
    self.outputSelector = outputSelector
  }
  
  deinit {
    self.task?.cancel()
  }
}

extension Listener {
  package var output: Output {
    guard let output = self.listener?.output else { fatalError("missing output") }
    return output
  }
}

extension Listener {
  package var publisher: ObservableObjectPublisher {
    guard let publisher = self.listener?.publisher else { fatalError("missing publisher")}
    return publisher
  }
}

extension Listener {
  package func update(
    id: some Hashable,
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    dependencySelector: DependencySelector<State, Dependency>?,
    outputSelector: OutputSelector<State, Output>
  ) {
    let id = AnyHashable(id)
    if self.id != id {
      self.id = id
      self.label = label
      self.filter = isIncluded
      self.dependencySelector = dependencySelector
      self.outputSelector = outputSelector
      self.store = nil
    }
  }
}

extension Listener {
  package func update(
    id: some Hashable,
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    outputSelector: OutputSelector<State, Output>
  ) where Dependency == Never {
    let id = AnyHashable(id)
    if self.id != id {
      self.id = id
      self.label = label
      self.filter = isIncluded
      self.dependencySelector = nil
      self.outputSelector = outputSelector
      self.store = nil
    }
  }
}

extension Listener {
  package func update(
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    dependencySelector: DependencySelector<State, Dependency>?,
    outputSelector: OutputSelector<State, Output>
  ) {
    if self.id != nil {
      self.id = nil
      self.label = label
      self.filter = isIncluded
      self.dependencySelector = dependencySelector
      self.outputSelector = outputSelector
      self.store = nil
    }
  }
}

extension Listener {
  package func update(
    label: String? = nil,
    filter isIncluded: (@Sendable (State, Action) -> Bool)? = nil,
    outputSelector: OutputSelector<State, Output>
  ) where Dependency == Never {
    if self.id != nil {
      self.id = nil
      self.label = label
      self.filter = isIncluded
      self.dependencySelector = nil
      self.outputSelector = outputSelector
      self.store = nil
    }
  }
}

extension Listener {
  package func listen(to store: some ImmutableData.Selector<State> & ImmutableData.Streamer<State, Action> & AnyObject) {
    if self.store !== store {
      self.store = store
      
      let listener = AsyncListener<State, Action, Dependency, Output>(
        label: self.label,
        filter: self.filter,
        dependencySelector: self.dependencySelector,
        outputSelector: self.outputSelector
      )
      listener.update(with: store)
      self.listener = listener
      
      let stream = store.makeStream()
      
      self.task?.cancel()
      self.task = Task {
        try await listener.listen(
          to: stream,
          with: store
        )
      }
    }
  }
}
