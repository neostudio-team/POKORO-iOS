// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: session.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// Allowed values for the type of security
/// being used in a protocomm session 
enum SecSchemeVersion: SwiftProtobuf.Enum {
  typealias RawValue = Int

  ///!< Unsecured - plaintext communication 
  case secScheme0 // = 0

  ///!< Security scheme 1 - Curve25519 + AES-256-CTR
  case secScheme1 // = 1

  ///!< Security scheme 2 - SRP6a + AES-256-GCM
  case secScheme2 // = 2
  case UNRECOGNIZED(Int)

  init() {
    self = .secScheme0
  }

  init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .secScheme0
    case 1: self = .secScheme1
    case 2: self = .secScheme2
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  var rawValue: Int {
    switch self {
    case .secScheme0: return 0
    case .secScheme1: return 1
    case .secScheme2: return 2
    case .UNRECOGNIZED(let i): return i
    }
  }

}

#if swift(>=4.2)

extension SecSchemeVersion: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static let allCases: [SecSchemeVersion] = [
    .secScheme0,
    .secScheme1,
    .secScheme2,
  ]
}

#endif  // swift(>=4.2)

/// Data structure exchanged when establishing
/// secure session between Host and Client 
struct SessionData {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  ///!< Type of security 
  var secVer: SecSchemeVersion = .secScheme0

  var proto: SessionData.OneOf_Proto? = nil

  ///!< Payload data in case of security 0 
  var sec0: Sec0Payload {
    get {
      if case .sec0(let v)? = proto {return v}
      return Sec0Payload()
    }
    set {proto = .sec0(newValue)}
  }

  ///!< Payload data in case of security 1 
  var sec1: Sec1Payload {
    get {
      if case .sec1(let v)? = proto {return v}
      return Sec1Payload()
    }
    set {proto = .sec1(newValue)}
  }

  ///!< Payload data in case of security 2 
  var sec2: Sec2Payload {
    get {
      if case .sec2(let v)? = proto {return v}
      return Sec2Payload()
    }
    set {proto = .sec2(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_Proto: Equatable {
    ///!< Payload data in case of security 0 
    case sec0(Sec0Payload)
    ///!< Payload data in case of security 1 
    case sec1(Sec1Payload)
    ///!< Payload data in case of security 2 
    case sec2(Sec2Payload)

  #if !swift(>=4.1)
    static func ==(lhs: SessionData.OneOf_Proto, rhs: SessionData.OneOf_Proto) -> Bool {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch (lhs, rhs) {
      case (.sec0, .sec0): return {
        guard case .sec0(let l) = lhs, case .sec0(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      case (.sec1, .sec1): return {
        guard case .sec1(let l) = lhs, case .sec1(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      case (.sec2, .sec2): return {
        guard case .sec2(let l) = lhs, case .sec2(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      default: return false
      }
    }
  #endif
  }

  init() {}
}

#if swift(>=5.5) && canImport(_Concurrency)
extension SecSchemeVersion: @unchecked Sendable {}
extension SessionData: @unchecked Sendable {}
extension SessionData.OneOf_Proto: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension SecSchemeVersion: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "SecScheme0"),
    1: .same(proto: "SecScheme1"),
    2: .same(proto: "SecScheme2"),
  ]
}

extension SessionData: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "SessionData"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    2: .standard(proto: "sec_ver"),
    10: .same(proto: "sec0"),
    11: .same(proto: "sec1"),
    12: .same(proto: "sec2"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 2: try { try decoder.decodeSingularEnumField(value: &self.secVer) }()
      case 10: try {
        var v: Sec0Payload?
        var hadOneofValue = false
        if let current = self.proto {
          hadOneofValue = true
          if case .sec0(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.proto = .sec0(v)
        }
      }()
      case 11: try {
        var v: Sec1Payload?
        var hadOneofValue = false
        if let current = self.proto {
          hadOneofValue = true
          if case .sec1(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.proto = .sec1(v)
        }
      }()
      case 12: try {
        var v: Sec2Payload?
        var hadOneofValue = false
        if let current = self.proto {
          hadOneofValue = true
          if case .sec2(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.proto = .sec2(v)
        }
      }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if self.secVer != .secScheme0 {
      try visitor.visitSingularEnumField(value: self.secVer, fieldNumber: 2)
    }
    switch self.proto {
    case .sec0?: try {
      guard case .sec0(let v)? = self.proto else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 10)
    }()
    case .sec1?: try {
      guard case .sec1(let v)? = self.proto else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 11)
    }()
    case .sec2?: try {
      guard case .sec2(let v)? = self.proto else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 12)
    }()
    case nil: break
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SessionData, rhs: SessionData) -> Bool {
    if lhs.secVer != rhs.secVer {return false}
    if lhs.proto != rhs.proto {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
