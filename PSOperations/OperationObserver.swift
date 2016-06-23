/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
This file defines the OperationObserver protocol.
*/

import Foundation

/**
    The protocol that types may implement if they wish to be notified of significant
    operation lifecycle events.
*/
public protocol OperationObserver {
    
    /// Invoked immediately prior to the `Operation`'s `execute()` method.
    func operationDidStart(operation: AdvancedOperation)
    
    /// Invoked immediately after the first time the `Operation`'s `cancel()` method is called
    func operationDidCancel(operation: AdvancedOperation)
    
    /// Invoked when `Operation.produceOperation(_:)` is executed.
    func operation(operation: AdvancedOperation, didProduceOperation newOperation: NSOperation)
    
    /**
        Invoked as an `Operation` finishes, along with any errors produced during
        execution (or readiness evaluation).
    */
    func operationDidFinish(operation: AdvancedOperation, errors: [NSError])
    
}
