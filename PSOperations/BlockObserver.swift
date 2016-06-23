/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
This file shows how to implement the OperationObserver protocol.
*/

import Foundation

/**
    The `BlockObserver` is a way to attach arbitrary blocks to significant events 
    in an `Operation`'s lifecycle.
*/
public struct BlockObserver: OperationObserver {
    // MARK: Properties
    
    private let startHandler: (AdvancedOperation -> Void)?
    private let cancelHandler: (AdvancedOperation -> Void)?
    private let produceHandler: ((AdvancedOperation, NSOperation) -> Void)?
    private let finishHandler: ((AdvancedOperation, [NSError]) -> Void)?
    
    public init(startHandler: (AdvancedOperation -> Void)? = nil, cancelHandler: (AdvancedOperation -> Void)? = nil, produceHandler: ((AdvancedOperation, NSOperation) -> Void)? = nil, finishHandler: ((AdvancedOperation, [NSError]) -> Void)? = nil) {
        self.startHandler = startHandler
        self.cancelHandler = cancelHandler
        self.produceHandler = produceHandler
        self.finishHandler = finishHandler
    }
    
    // MARK: OperationObserver
    
    public func operationDidStart(operation: AdvancedOperation) {
        startHandler?(operation)
    }
    
    public func operationDidCancel(operation: AdvancedOperation) {
        cancelHandler?(operation)
    }
    
    public func operation(operation: AdvancedOperation, didProduceOperation newOperation: NSOperation) {
        produceHandler?(operation, newOperation)
    }
    
    public func operationDidFinish(operation: AdvancedOperation, errors: [NSError]) {
        finishHandler?(operation, errors)
    }
}
